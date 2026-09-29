extends GutTest
## The units' figures on the board (FigureArt, UnitToken, ArenaView): every
## hero and enemy has one, each stands on its unit's point with its bars
## over its head, faces its target, and the nearer figures are drawn (and
## clicked) in front.

const FigureBounds := preload("res://tools/art/figure_bounds.gd")

var _content: ContentDb


func before_all() -> void:
	_content = ContentDb.load_dir("res://data")


func _player(encounter_id: String) -> FightPlayer:
	var errors: Array[String] = []
	return FightPlayer.make(Encounters.setup(_content, encounter_id, PracticeSession.DEFAULT_FORMATION, 3, errors), _content)


func _view(player: FightPlayer, view_size: Vector2 = Vector2(1000, 900)) -> ArenaView:
	var view := ArenaView.new()
	add_child_autofree(view)
	view.size = view_size
	view.show_setup(player.setup, player.content)
	view.sync_fight(player)
	return view


func test_every_hero_and_enemy_has_a_figure() -> void:
	for hero_id: String in _content.hero_ids:
		assert_true(FigureArt.has_figure(FigureArt.key_for(hero_id, true)), "%s's base form" % hero_id)
	for enemy_id: String in _content.enemy_ids:
		assert_true(FigureArt.has_figure(FigureArt.key_for(enemy_id, false)), enemy_id)
	assert_false(FigureArt.has_figure("enemies/nobody"))
	assert_eq(FigureArt.bounds("enemies/nobody"), Rect2(Vector2.ZERO, FigureArt.CANVAS), "no art: the whole canvas")


func test_the_bounds_file_matches_the_figures() -> void:
	var measured: Dictionary = FigureBounds.measure_all()
	assert_eq(FileAccess.get_file_as_string(FigureArt.BOUNDS), FigureBounds.to_json(measured),
		"art/figures/bounds.json is up to date (run tools/art/figure_bounds.gd after changing the figures)")
	var pup: Rect2 = FigureArt.bounds("enemies/rift_pup")
	var sentinel: Rect2 = FigureArt.bounds("enemies/rift_worn_sentinel")
	assert_gt(pup.position.y, sentinel.position.y, "a pup stands lower than a sentinel")
	assert_almost_eq(pup.end.y, FigureArt.FEET.y, 20.0, "figures stand on the canvas's feet")


func test_a_figure_stands_on_its_units_point_with_bars_over_its_head() -> void:
	var view: ArenaView = _view(_player("sentinel_gate"))
	for token: UnitToken in view.tokens:
		assert_true(token.has_figure(), token.unit_id)
		assert_almost_eq(token.center(), view.to_pixel(token.plane_pos), Vector2(0.01, 0.01), "%s stands on its point" % token.unit_id)
		var drawn := Rect2(token.figure_rect().position + token.center(), token.figure_rect().size)
		assert_true(token.get_rect().encloses(drawn.grow(-0.01)), "%s: its rect covers its figure" % token.unit_id)
		assert_lt(token.head_offset().y, -view.hex_px() * 0.2, "%s: its head is over its point" % token.unit_id)
		assert_lt(token.over_bars_offset().y, token.head_offset().y, "%s: the bars are over its head" % token.unit_id)
		assert_gte(token.position.y + token.feet.y + token.over_bars_offset().y, 0.0, "%s: its bars fit on the view" % token.unit_id)
	var sentinel: UnitToken = view.token("rift_worn_sentinel")
	assert_lt(sentinel.head_offset().y, view.token("vell").head_offset().y * 0.9, "a sentinel stands taller than Vell")
	assert_almost_eq(sentinel.figure_rect().size.y, FigureArt.bounds("enemies/rift_worn_sentinel").size.y * UnitToken.FIGURE_HEXES * view.hex_px() / FigureArt.CANVAS.y, 0.01,
		"figures are FIGURE_HEXES tall, canvas and all")


func test_heroes_face_right_and_enemies_left_until_they_have_targets() -> void:
	var player: FightPlayer = _player("the_pack")
	var view: ArenaView = _view(player)
	for token: UnitToken in view.tokens:
		assert_eq(token.facing_left, not token.is_hero(), token.unit_id)
	player.advance(3.0)
	view.sync_fight(player)
	var turned: int = 0
	for unit: UnitState in player.sim.units:
		var token: UnitToken = view.token(unit.id)
		if unit.alive and unit.target != null and absi(unit.target.pos.x - unit.pos.x) >= HexGrid.HEX / 10:
			assert_eq(token.facing_left, unit.target.pos.x < unit.pos.x, "%s faces %s" % [unit.id, unit.target.id])
			turned += 1
	assert_gt(turned, 0)


func test_a_flipped_figure_covers_the_other_side() -> void:
	var view: ArenaView = _view(_player("sentinel_gate"))
	var maren: UnitToken = view.token("maren")
	var right: Rect2 = maren.figure_rect()
	maren.facing_left = true
	var left: Rect2 = maren.figure_rect()
	assert_almost_eq(left.position.x, -right.end.x, 0.01)
	assert_eq(left.size, right.size)


func test_nearer_units_are_drawn_and_clicked_in_front() -> void:
	var view: ArenaView = _view(_player("pup_warren"))
	var children: Array[Node] = view.get_children().filter(func(child: Node) -> bool: return child is UnitToken)
	for i: int in range(1, children.size()):
		assert_lte((children[i - 1] as UnitToken).center().y, (children[i] as UnitToken).center().y, "drawn down the screen")
	# Two units stood close: the lower one is drawn over the other, and a
	# click where they overlap finds it.
	var back: UnitToken = view.token("rift_pup")
	var front: UnitToken = view.token("rift_pup#2")
	back.place_at(view, Vector2(3000, 3000))
	front.place_at(view, Vector2(3000, 2900))
	view._stack_tokens()
	assert_gt(front.get_index(), back.get_index())
	assert_eq(view.token_at(front.center() + Vector2(0, -2)), front)
	assert_eq(view.token_at(back.position + Vector2(back.size.x / 2.0, 2.0)), back, "the back unit's head, over the front one")
	var head: Vector2 = view.token("maren").center() + view.token("maren").head_offset() + Vector2(0, 3)
	assert_eq(view.token_at(head), view.token("maren"), "a click on a hero's head finds the hero")


func test_a_kit_without_art_is_a_circle() -> void:
	var view: ArenaView = _view(_player("sentinel_gate"))
	var token: UnitToken = UnitToken.make("stray", "Stray", EffectSource.Team.ENEMIES, _content.tuning.unit_radius, false, "enemies/nobody")
	view.add_child(token)
	token.place_at(view, Vector2(3000, 3000))
	assert_false(token.has_figure())
	assert_eq(token.size, Vector2(UnitToken.HIT_PX, UnitToken.HIT_PX) * 2.0)
	assert_eq(token.head_offset(), Vector2(0, -token.body_px()))
	assert_eq(token.body_offset(), Vector2.ZERO)


func test_numbers_rise_over_the_bars_and_shots_fly_at_the_body() -> void:
	var player: FightPlayer = _player("sentinel_gate")
	var view: ArenaView = _view(player)
	var archer: UnitToken = view.token("hollow_archer")
	assert_eq(view.fx._lift("hollow_archer", FightFx.Lift.OVER_BARS), archer.over_bars_offset())
	assert_eq(view.fx._lift("hollow_archer", FightFx.Lift.BODY), archer.body_offset())
	assert_lt(archer.body_offset().y, 0.0, "the body is over the feet")
	assert_gt(archer.body_offset().y, archer.head_offset().y, "and under the head")
	assert_eq(view.fx._lift("nobody", FightFx.Lift.BODY), Vector2.ZERO)
