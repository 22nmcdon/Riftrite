extends GutTest
## ArenaView and UnitToken (docs/plans/rebuild-phase3-fight-sandbox.md,
## section 2): the plane-to-pixel mapping, the board, and a token per unit.

const GUARDED: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(3, 0), "vell": Vector2i(4, 0)}

var _content: ContentDb


func before_all() -> void:
	_content = ContentDb.load_dir("res://data")


func _view(encounter_id: String = "sentinel_gate", view_size: Vector2 = Vector2(1200, 900)) -> ArenaView:
	var view := ArenaView.new()
	add_child_autofree(view)
	view.size = view_size
	var errors: Array[String] = []
	view.show_setup(Encounters.setup(_content, encounter_id, GUARDED, 1, errors), _content)
	return view


func test_the_plane_maps_to_pixels_and_back() -> void:
	var view: ArenaView = _view()
	for point: Vector2i in [Vector2i(0, 0), Vector2i(3098, 3000), Vector2i(6562, 7500), Vector2i(1234, 5678)]:
		var back: Vector2i = view.to_plane(view.to_pixel(point))
		assert_lte((back - point).length(), 1.0 / view.scale_px + 1.0, "%s comes back as %s" % [point, back])
	assert_gt(view.to_pixel(view.grid.center(3, 0)).y, view.to_pixel(view.grid.center(3, 6)).y, "the heroes' rows are at the bottom (phase 5b)")
	assert_almost_eq(view.to_pixel(view.grid.center(2, 0)).x, view.to_pixel(view.grid.center(2, 6)).x, 0.01, "a column runs up")
	assert_almost_eq(view.to_pixel(view.grid.center(2, 3)).y, view.to_pixel(view.grid.center(4, 3)).y, 0.01, "a row runs across")
	assert_lt(view.to_pixel(view.grid.center(0, 3)).x, view.to_pixel(view.grid.center(7, 3)).x, "the first column on the left")


func test_every_hex_is_found_under_its_center_and_near_its_edge() -> void:
	var view: ArenaView = _view()
	for index: int in view.grid.size():
		var hex := Vector2i(view.grid.col_of(index), view.grid.row_of(index))
		var middle: Vector2 = view.to_pixel(view.grid.center(hex.x, hex.y))
		assert_eq(view.hex_at(middle), hex)
		assert_eq(view.hex_at(middle + Vector2(0.0, view.hex_px() * 0.45)), hex, "just inside its flat edge")
	assert_eq(view.hex_at(Vector2(-50, -50)), Vector2i(-1, -1), "off the board")


func test_the_whole_board_fits_the_view_centered() -> void:
	for view_size: Vector2 in [Vector2(1200, 900), Vector2(600, 1000), Vector2(1600, 400)]:
		var view: ArenaView = _view("sentinel_gate", view_size)
		var inside := Rect2(Vector2(ArenaView.MARGIN, ArenaView.MARGIN), view_size - Vector2(ArenaView.MARGIN, ArenaView.MARGIN) * 2.0).grow(0.5)
		for index: int in view.grid.size():
			for corner: Vector2 in view.hex_corners(view.grid.center(view.grid.col_of(index), view.grid.row_of(index))):
				assert_true(inside.has_point(corner), "%s: a corner at %s" % [view_size, corner])
		var drawn: Rect2 = view.rect_to_pixels(view.drawn_rect)
		var left: float = drawn.position.x
		var right: float = drawn.end.x
		var top: float = drawn.position.y
		var bottom: float = drawn.end.y
		assert_almost_eq(left, view_size.x - right, 1.0, "centered across")
		var top_room: float = ArenaView.TOP_ROOM_HEXES * view.hex_px()
		assert_almost_eq(top - top_room, view_size.y - bottom, 1.0, "centered up and down, with room over it for bars")
		assert_true(is_equal_approx(right - left, view_size.x - 2 * ArenaView.MARGIN) or is_equal_approx(bottom - top + top_room, view_size.y - 2 * ArenaView.MARGIN),
			"it fills one way")


func test_every_unit_gets_a_token_on_its_hex() -> void:
	var view: ArenaView = _view()
	var encounter: EncounterDef = _content.encounters["sentinel_gate"]
	assert_eq(view.tokens.map(func(token: UnitToken) -> String: return token.unit_id), ["brannoc", "maren", "vell", "rift_worn_sentinel", "hollow_archer", "hollow_archer#2"])
	assert_eq(view.tokens.map(func(token: UnitToken) -> String: return token.label_text), ["Brannoc", "Maren", "Vell", "Sentinel", "Archer", "Archer"])
	var hexes: Array[Vector2i] = [GUARDED["brannoc"], GUARDED["maren"], GUARDED["vell"]]
	for placed: EncounterDef.Placed in encounter.enemies:
		hexes.append(placed.hex)
	for i: int in view.tokens.size():
		var token: UnitToken = view.tokens[i]
		assert_eq(token.plane_pos, view.grid.center(hexes[i].x, hexes[i].y), token.unit_id)
		assert_almost_eq(token.center(), view.to_pixel(token.plane_pos), Vector2(0.01, 0.01))
		assert_almost_eq(token.radius_px, _content.tuning.unit_radius * view.scale_px, 0.001)
		assert_eq(token.is_hero(), i < 3)
	assert_eq(view.rocks.size(), 2)
	assert_eq(view.token("vell"), view.tokens[2])
	assert_null(view.token("nobody"))


func test_tokens_follow_a_resize_and_fliers_are_marked() -> void:
	var view: ArenaView = _view("moth_cloud")
	var moth: UnitToken = view.token("cinder_moth")
	assert_true(moth.flying)
	assert_false(view.token("rift_pup").flying)
	var before: Vector2 = moth.center()
	view.size = Vector2(800, 600)
	assert_ne(moth.center(), before)
	assert_almost_eq(moth.center(), view.to_pixel(moth.plane_pos), Vector2(0.01, 0.01))


func test_showing_another_setup_replaces_the_tokens() -> void:
	var view: ArenaView = _view("pup_warren")
	assert_eq(view.tokens.size(), 9)
	var errors: Array[String] = []
	view.show_setup(Encounters.setup(_content, "the_pack", GUARDED, 1, errors), _content)
	assert_eq(view.tokens.size(), 6)
	await wait_process_frames(1)
	assert_eq(view.get_children().filter(func(child: Node) -> bool: return child is UnitToken).size(), 6, "the old tokens are gone")
	assert_eq(view.rocks.size(), 1)


func test_every_kit_has_a_short_label() -> void:
	var labels: Array = []
	for enemy_id: String in _content.enemy_ids:
		labels.append(ArenaView.label_for((_content.enemies[enemy_id] as EnemyDef).kit, _content))
	assert_eq(labels, ["Pup", "Ashling", "Hound", "Moth", "Archer", "Sentinel", "Guardian", "Lurker", "Witch", "Alpha", "Hound", "Totem", "Hound", "Ash",
		"Eel", "Slinger", "Tidecaller", "Warden", "Bellringer", "Thrall", "Shambler", "Shard", "Shard", "Shard", "Matron", "Shambler", "Shard", "Tidecaller", "Mournwater"])
	assert_eq(ArenaView.label_for((_content.heroes["vell"] as HeroDef).kit, _content), "Vell", "a hero by their id, not \"Sister\"")


func test_modes_switch() -> void:
	var view: ArenaView = _view()
	assert_eq(view.mode, ArenaView.Mode.PLACEMENT)
	view.set_mode(ArenaView.Mode.FIGHT)
	assert_eq(view.mode, ArenaView.Mode.FIGHT)


## The island (docs/plans/rebuild-phase5b-art.md, section 3): its frame's
## inner square covers the board, and each rock is a ruin picked by its hex.
func test_the_board_stands_on_the_island() -> void:
	var view: ArenaView = _view()
	var board_px: Rect2 = view.rect_to_pixels(view.drawn_rect)
	var frame: Rect2 = view.frame_rect()
	var inner := Rect2(frame.position + ArenaView.FRAME_INNER.position * frame.size / ArenaView.FRAME_SIZE, ArenaView.FRAME_INNER.size * frame.size / ArenaView.FRAME_SIZE)
	assert_almost_eq(inner.position, board_px.position, Vector2(0.01, 0.01))
	assert_almost_eq(inner.size, board_px.size, Vector2(0.01, 0.01))
	for name: String in ["island_frame", "ground_tile", "collapse_tile", "collapse_warn_tile", "backdrop"]:
		assert_not_null(ArenaView.art(ArenaView.ART_DIR + name + ".svg"), name)
	assert_eq(view.rock_props.size(), view.rocks.size())
	for i: int in view.rocks.size():
		var prop: ArenaView.RockProp = view.rock_props[i]
		assert_not_null(prop.texture, prop.prop)
		assert_almost_eq(prop.center(), view.to_pixel(view.rocks[i].center), Vector2(0.01, 0.01), "the ruin stands on the rock's point")
		assert_eq(prop.mouse_filter, Control.MOUSE_FILTER_IGNORE, "it takes no clicks")
	assert_eq(ArenaView.prop_for(Vector2i(3, 3)), ArenaView.prop_for(Vector2i(3, 3)), "the same hex, the same ruin")
	var seen: Dictionary[String, bool] = {}
	for col: int in 8:
		for row: int in 7:
			seen[ArenaView.prop_for(Vector2i(col, row))] = true
	assert_eq(seen.size(), ArenaView.PROPS.size(), "every ruin turns up")
	# A ruin stacks with the units: a unit behind it (higher on the screen)
	# is drawn under it.
	var maren: UnitToken = view.token("maren")
	var prop: ArenaView.RockProp = view.rock_props[0]
	maren.place_at(view, Vector2(prop.plane_pos + Vector2i(0, 200)))
	view._stack_tokens()
	assert_lt(maren.get_index(), prop.get_index())


func test_water_is_drawn_from_the_setup_then_the_fight() -> void:
	var errors: Array[String] = []
	var setup: FightSetup = Encounters.setup(_content, "sentinel_gate", GUARDED, 1, errors)
	setup.water = [Vector2i(3, 0), Vector2i(3, 3)] as Array[Vector2i]
	var view := ArenaView.new()
	add_child_autofree(view)
	view.size = Vector2(1200, 900)
	view.show_setup(setup, _content)
	assert_eq(view.water, setup.water, "placing: the setup's water")
	assert_true(view.token("maren").in_water, "a hero placed on water shows its ripple")
	assert_false(view.token("brannoc").in_water)
	var player: FightPlayer = FightPlayer.make(setup, _content)
	player.advance(0.5)
	view.set_mode(ArenaView.Mode.FIGHT)
	view.sync_fight(player)
	assert_eq(view.water, player.sim.water.hexes, "fighting: the fight's water")
	assert_eq(view.token("maren").in_water, player.sim.unit_by_id("maren").on_water)


## The void (phase 8 part 3): open sky between the islands, from the setup
## while placing and from the fight's islands once it runs.
func test_the_void_is_drawn_from_the_setup_then_the_fight() -> void:
	var errors: Array[String] = []
	var setup: FightSetup = Encounters.setup(_content, "sentinel_gate", GUARDED, 1, errors)
	setup.void_hexes = [Vector2i(0, 3), Vector2i(1, 3)] as Array[Vector2i]
	var view := ArenaView.new()
	add_child_autofree(view)
	view.size = Vector2(1200, 900)
	view.show_setup(setup, _content)
	assert_eq(view.void_hexes, setup.void_hexes, "placing: the setup's void")
	var player: FightPlayer = FightPlayer.make(setup, _content)
	player.advance(0.5)
	view.set_mode(ArenaView.Mode.FIGHT)
	view.sync_fight(player)
	assert_eq(view.void_hexes, player.sim.islands.hexes, "fighting: the fight's void")
	view.queue_redraw()
	await wait_process_frames(1)
