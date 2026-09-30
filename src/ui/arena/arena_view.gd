class_name ArenaView
extends Control
## The arena on screen (docs/plans/rebuild-phase3-fight-sandbox.md, section
## 2): one view for placement and the fight. It maps the sim's plane to
## pixels, draws the board, and keeps a token per unit. It only reads the
## setup or the fight; it never changes them.
##   - The board fits the view, centered, `MARGIN` pixels in, with the
##     heroes at the bottom and the enemies at the top
##     (docs/plans/rebuild-phase5b-art.md, Decision 1). The plane's x (the
##     columns) grows to the right and its y (the sim's rows; row 0 is the
##     heroes' back row) grows up the screen, so the sim's flat-top hexes
##     are drawn flat-top. A hex's corners reach past the plane's edge at
##     the columns' ends, so the drawn area is that much wider than the
##     plane (`drawn_rect`), and room is kept over it for the top row's
##     figures and bars (`TOP_ROOM_HEXES`).
##   - Placement mode shades each hex by zone (yours, no one's, theirs); fight
##     mode keeps the hexes faint, since distances still count in hexes.
##   - Hexes and rocks are drawn with `_draw()`; units are `UnitToken` nodes,
##     each a figure standing on its point, drawn in order down the screen
##     so the nearer stand in front (`_stack_tokens`).
##   - The fight: sync_fight() moves the tokens to where a FightPlayer draws
##     each unit (with its bars and statuses), adds a token for each summon
##     as it joins, and hides the fallen (section 4). The log entries the
##     player hands out go to `fx`, the layer of momentary things drawn over
##     the tokens (section 5).
##   - Clicking reports the token under the pointer (`unit_clicked`: the log
##     filters to it, and a hero's details open while the fight isn't
##     playing; sections 6 and 7), or the bare board (`ground_clicked`).
##   - Placement: a hero's token can be dragged onto a hex (section 3). The
##     view only reports the drop (`hero_dropped`); whoever shows it decides
##     whether the move is legal, and calls `flash_hex` if it isn't.
##   - Paths (docs/plans/rebuild-phase4-paths.md, section 6): a transformed
##     hero stands as its path's figure; a vowed one keeps its base figure.
##     Either way the path is named under it while placing, with its
##     tactic. A transformed Trapper's snares are markers on their hexes,
##     dragged like heroes (`snare_dropped`), and the same rule decides.

signal hero_dropped(hero_id: String, hex: Vector2i)
## One of a hero's placed snares was dropped on a hex (placement).
signal snare_dropped(hero_id: String, index: int, hex: Vector2i)
signal unit_hovered(unit_id: String)
signal unit_unhovered(unit_id: String)
## A unit's token was clicked (the left button let go on it, not a drag).
signal unit_clicked(unit_id: String)
## The board was clicked away from every token.
signal ground_clicked
## A click on the bare board, on a hex (phase 5: Dig In's rock).
signal hex_clicked(hex: Vector2i)

enum Mode { PLACEMENT, FIGHT }

const MARGIN: float = 12.0
## Extra room over the board, in hexes, for the top row's figures and bars.
const TOP_ROOM_HEXES: float = 0.6
## A flat-top hex's corner radius on the plane: rows are HEX apart, so the
## corners are HEX / sqrt(3) from the center.
const HEX_CORNER: float = HexGrid.HEX / 1.7320508
## Your side teal-tinted navy, the middle row plain, theirs violet-tinted.
const ZONE_FILLS: Array[Color] = [Color("1c3340"), Color("1b2433"), Color("241f3a")]
const HEX_LINE := Color("395265")
const FIGHT_HEX_LINE := Color(0.22, 0.32, 0.4, 0.45)
const ROCK_FILL := Color("4a5161")
const ROCK_LINE := Color("6b7385")
const FLASH := Color(0.84, 0.35, 0.31, 0.7)
## How long a refused hex flashes, in seconds.
const FLASH_SECONDS: float = 0.5
## A placed snare's marker.
const SNARE_COLOR := Color("8fbf5a")

var mode: Mode = Mode.PLACEMENT
var grid: HexGrid
## The board on the plane: every hex, half a hex beyond the outermost ones.
var board: Rect2i
## What's drawn: the board, widened at the sides to take in the hexes'
## corners.
var drawn_rect: Rect2i
var rocks: Array[ArenaPlane.Circle] = []
## One per unit, in the fight's order.
var tokens: Array[UnitToken] = []
## Shots, swipes, numbers, and names over the tokens.
var fx: FightFx
## Pixels per plane unit, and where the board's top-left corner is drawn.
var scale_px: float = 0.1
var _origin: Vector2 = Vector2.ZERO
## A refused hex, and how long it still flashes.
var flashing: Vector2i = Vector2i(-1, -1)
var _flash_left: float = 0.0
## While placing: the snares the heroes place, one per marker.
var snare_markers: Array[SnareMarker] = []


## One placed snare's marker on the board.
class SnareMarker:
	var hero_id: String
	var index: int
	var hex: Vector2i


## What's drawn under the pointer while a snare is dragged.
class SnarePreview:
	extends Control
	var reach: float = 8.0

	func _draw() -> void:
		ArenaView.draw_snare(self, Vector2.ZERO, reach, SNARE_COLOR)


## Shows a fight's setup: its board, rocks, and every unit on its hex.
func show_setup(setup: FightSetup, content: ContentDb) -> void:
	grid = content.tuning.make_grid()
	board = grid.bounds()
	var overhang: int = ceili(HEX_CORNER) - HexGrid.HALF_HEX
	drawn_rect = board.grow_individual(overhang, 0, overhang, 0)
	rocks.clear()
	for rock: Vector2i in setup.rocks:
		rocks.append(ArenaPlane.Circle.make(grid.center(rock.x, rock.y), content.tuning.rock_radius, "rock"))
	for token: UnitToken in tokens:
		token.queue_free()
	tokens.clear()
	fx.clear()
	snare_markers.clear()
	for unit: UnitSetup in setup.units():
		var token: UnitToken = UnitToken.make(unit.id, label_for(unit.def, content), unit.side, content.tuning.unit_radius, unit.def.has_trait("flying"), figure_for(unit.def, unit.side, form_of(unit)))
		token.plane_pos = grid.center(unit.col, unit.row)
		token.tactic_label = unit.tactic.name if unit.tactic != null else ""
		token.path_label = path_tag(unit)
		_add_token(token)
		for i: int in unit.snares.size():
			var marker := SnareMarker.new()
			marker.hero_id = unit.id
			marker.index = i
			marker.hex = unit.snares[i]
			snare_markers.append(marker)
	_layout()


## A hero's form: its path's once transformed, else "base".
static func form_of(unit: UnitSetup) -> String:
	return unit.path.id if unit.path != null and unit.stage == PathDef.Stage.TRANSFORMED else "base"


## What's named under a hero on a path while placing: "Deadeye (vow)" or,
## transformed, "Deadeye" ("": no path).
static func path_tag(unit: UnitSetup) -> String:
	if unit.path == null:
		return ""
	return unit.path.name if unit.stage == PathDef.Stage.TRANSFORMED else "%s (vow)" % unit.path.name


## Puts every unit where `player` draws it: a token for each unit the fight
## has (summons included, as they join), hidden once it falls.
func sync_fight(player: FightPlayer) -> void:
	for unit: UnitState in player.sim.units:
		var unit_token: UnitToken = token(unit.id)
		if unit_token == null:
			unit_token = UnitToken.make(unit.id, label_for(unit.def, player.content), unit.side, unit.radius, unit.flying, figure_for(unit.def, unit.side))
			_add_token(unit_token)
		unit_token.plane_pos = unit.pos
		unit_token.visible = unit.alive
		unit_token.facing_left = faces_left(unit, unit_token.facing_left)
		unit_token.show_state(unit, player.sim.tick)
		unit_token.place_at(self, fx.moved_position(unit.id, player.drawn_position(unit), player.drawn_time()))
	_stack_tokens()
	fx.update(player)
	queue_redraw()


func _add_token(unit_token: UnitToken) -> void:
	tokens.append(unit_token)
	add_child(unit_token)
	unit_token.mouse_entered.connect(func() -> void:
		fx.hovered = unit_token.unit_id
		unit_hovered.emit(unit_token.unit_id))
	unit_token.mouse_exited.connect(func() -> void:
		if fx.hovered == unit_token.unit_id:
			fx.hovered = ""
		unit_unhovered.emit(unit_token.unit_id))


func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	queue_redraw()


func _init() -> void:
	fx = FightFx.make(self)
	add_child(fx)


func _ready() -> void:
	set_process(false)


## A left click let go on the board (tokens pass their clicks up to here).
func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or click.pressed:
		return
	var hit: UnitToken = token_at(click.position)
	if hit != null:
		unit_clicked.emit(hit.unit_id)
	else:
		ground_clicked.emit()
		var hex: Vector2i = hex_at(click.position)
		if hex.x >= 0:
			hex_clicked.emit(hex)


## The shown token whose rect covers a pixel (its figure, and at least
## UnitToken.HIT_PX around its point, so small units are easy to click; the
## one drawn in front), or null.
func token_at(pixel: Vector2) -> UnitToken:
	var children: Array[Node] = get_children()
	for i: int in range(children.size() - 1, -1, -1):
		var found: UnitToken = children[i] as UnitToken
		if found != null and found.visible and not found.is_queued_for_deletion() and found.get_rect().has_point(pixel):
			return found
	return null


## Keeps the tokens in order down the screen, so a unit nearer the bottom
## (nearer the viewer) is drawn over the ones behind it; ties keep the
## fight's order.
func _stack_tokens() -> void:
	var order: Array[UnitToken] = tokens.duplicate()
	var rank: Dictionary[UnitToken, int] = {}
	for i: int in tokens.size():
		rank[tokens[i]] = i
	order.sort_custom(func(a: UnitToken, b: UnitToken) -> bool:
		var a_y: float = a.center().y
		var b_y: float = b.center().y
		return a_y < b_y if a_y != b_y else rank[a] < rank[b])
	# The tokens trade places among the children's slots they already hold
	# (the view has other children: the effects, banners, and the popup).
	var slots: Array[int] = []
	for unit_token: UnitToken in tokens:
		slots.append(unit_token.get_index())
	slots.sort()
	for i: int in order.size():
		if order[i].get_index() != slots[i]:
			move_child(order[i], slots[i])


func token(unit_id: String) -> UnitToken:
	for found: UnitToken in tokens:
		if found.unit_id == unit_id:
			return found
	return null


## Which way a unit faces on the screen: toward its target's side, or as it
## was when its target is (nearly) straight above or below it or it has none.
func faces_left(unit: UnitState, was_left: bool) -> bool:
	if unit.target == null:
		return was_left
	var across: float = to_pixel(unit.target.pos).x - to_pixel(unit.pos).x
	return was_left if absf(across) < hex_px() / 10.0 else across < 0.0


## A unit's figure (FigureArt): a hero's form (base, or a transformed
## hero's path), or its enemy's.
static func figure_for(kit: UnitDef, team: EffectSource.Team, form: String = "base") -> String:
	return FigureArt.key_for(kit.id, team == EffectSource.Team.HEROES, form)


## A token's short label: a hero's name (its id), or the last word of an
## enemy's ("Rift Pup" -> "Pup").
static func label_for(kit: UnitDef, content: ContentDb) -> String:
	if content.heroes.has(kit.id):
		return kit.id.capitalize()
	var words: PackedStringArray = kit.name.split(" ", false)
	return words[words.size() - 1] if not words.is_empty() else kit.id


# --- the plane and the screen ------------------------------------------------------

## Where a point on the plane is drawn (its x across, its y up).
func to_pixel(point: Vector2i) -> Vector2:
	return to_pixel_f(Vector2(point))


## to_pixel for a point between whole units (a unit drawn mid-step).
func to_pixel_f(point: Vector2) -> Vector2:
	return _origin + Vector2(point.x - drawn_rect.position.x, drawn_rect.end.y - point.y) * scale_px


## The point on the plane under a pixel (rounded to a whole unit).
func to_plane(pixel: Vector2) -> Vector2i:
	var along: Vector2 = (pixel - _origin) / scale_px
	return Vector2i(roundi(along.x) + drawn_rect.position.x, drawn_rect.end.y - roundi(along.y))


## Where a rect on the plane is drawn.
func rect_to_pixels(rect: Rect2i) -> Rect2:
	return Rect2(to_pixel(Vector2i(rect.position.x, rect.end.y)), Vector2(rect.size) * scale_px)


## The hex under a pixel, or (-1, -1) off the board.
func hex_at(pixel: Vector2) -> Vector2i:
	var point: Vector2i = to_plane(pixel)
	if not board.has_point(point):
		return Vector2i(-1, -1)
	var index: int = grid.nearest_hex(point)
	return Vector2i(grid.col_of(index), grid.row_of(index))


## Pixels per hex (HEX plane units).
func hex_px() -> float:
	return scale_px * HexGrid.HEX


# --- placement --------------------------------------------------------------------

## True for a hero's token while placing: it can be dragged.
func can_drag(unit_token: UnitToken) -> bool:
	return mode == Mode.PLACEMENT and unit_token.is_hero()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return mode == Mode.PLACEMENT and data is Dictionary and ((data as Dictionary).has("hero") or (data as Dictionary).has("snare"))


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var hex: Vector2i = hex_at(at_position)
	if hex.x < 0:
		return
	var dropped: Dictionary = data
	if dropped.has("snare"):
		snare_dropped.emit(String(dropped["snare"]), int(dropped["index"]), hex)
	else:
		hero_dropped.emit(String(dropped["hero"]), hex)


## Dragging a snare's marker (a drag that starts on a token is the token's).
func _get_drag_data(at_position: Vector2) -> Variant:
	var marker: SnareMarker = snare_at(at_position)
	if mode != Mode.PLACEMENT or marker == null:
		return null
	var preview := SnarePreview.new()
	preview.reach = snare_px()
	preview.modulate.a = 0.8
	set_drag_preview(preview)
	return {"snare": marker.hero_id, "index": marker.index}


## The snare marker under a pixel while placing, or null.
func snare_at(pixel: Vector2) -> SnareMarker:
	var reach: float = maxf(snare_px(), UnitToken.HIT_PX)
	for marker: SnareMarker in snare_markers:
		if to_pixel(grid.center(marker.hex.x, marker.hex.y)).distance_to(pixel) <= reach:
			return marker
	return null


## A snare's radius on screen.
func snare_px() -> float:
	return maxf(Snares.RADIUS * scale_px * 0.7, 6.0)


## A snare's mark: a ring with a cross in it.
static func draw_snare(canvas: CanvasItem, at: Vector2, reach: float, color: Color) -> void:
	canvas.draw_arc(at, reach, 0.0, TAU, 20, color, 2.0, true)
	canvas.draw_line(at - Vector2(reach, reach) * 0.6, at + Vector2(reach, reach) * 0.6, color, 2.0, true)
	canvas.draw_line(at - Vector2(reach, -reach) * 0.6, at + Vector2(reach, -reach) * 0.6, color, 2.0, true)


## Flashes a hex red for a moment (a refused move).
func flash_hex(hex: Vector2i) -> void:
	flashing = hex
	_flash_left = FLASH_SECONDS
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if _flash_left <= 0.0:
		set_process(false)
		return
	_flash_left -= delta
	if _flash_left <= 0.0:
		flashing = Vector2i(-1, -1)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	if grid == null:
		return
	var room: Vector2 = size - Vector2(MARGIN, MARGIN) * 2.0
	# Across the screen: the plane's columns; up it: its rows, and the room
	# over them.
	var wide: float = drawn_rect.size.x
	var tall: float = drawn_rect.size.y + TOP_ROOM_HEXES * HexGrid.HEX
	scale_px = maxf(minf(room.x / wide, room.y / tall), 0.001)
	# _origin is where the drawn area's top-left corner (its first column's
	# edge, its last row's) lands.
	_origin = (size - Vector2(wide, tall) * scale_px) / 2.0 + Vector2(0.0, TOP_ROOM_HEXES * HexGrid.HEX * scale_px)
	for unit_token: UnitToken in tokens:
		unit_token.place(self)
	_stack_tokens()
	queue_redraw()


# --- drawing -------------------------------------------------------------------

func _draw() -> void:
	if grid == null:
		return
	draw_rect(rect_to_pixels(drawn_rect), UiStyle.NAVY_850)
	for index: int in grid.size():
		var col: int = grid.col_of(index)
		var row: int = grid.row_of(index)
		var corners: PackedVector2Array = hex_corners(grid.center(col, row))
		if mode == Mode.PLACEMENT:
			draw_colored_polygon(corners, ZONE_FILLS[grid.zone(row)])
		var outline: PackedVector2Array = corners.duplicate()
		outline.append(corners[0])
		draw_polyline(outline, HEX_LINE if mode == Mode.PLACEMENT else FIGHT_HEX_LINE, 1.5, true)
	if flashing.x >= 0:
		var flash := FLASH
		flash.a *= clampf(_flash_left / FLASH_SECONDS, 0.0, 1.0)
		draw_colored_polygon(hex_corners(grid.center(flashing.x, flashing.y)), flash)
	if mode == Mode.FIGHT:
		fx.draw_ground(self)
	else:
		for marker: SnareMarker in snare_markers:
			draw_snare(self, to_pixel(grid.center(marker.hex.x, marker.hex.y)), snare_px(), SNARE_COLOR)
	for rock: ArenaPlane.Circle in rocks:
		var center: Vector2 = to_pixel(rock.center)
		draw_circle(center, rock.radius * scale_px, ROCK_FILL)
		draw_arc(center, rock.radius * scale_px, 0.0, TAU, 32, ROCK_LINE, 2.0, true)


## A hex's six corners in pixels (flat-top, on the plane and the screen).
func hex_corners(center: Vector2i) -> PackedVector2Array:
	var corners := PackedVector2Array()
	for i: int in 6:
		var angle: float = i * TAU / 6.0
		corners.append(to_pixel_f(Vector2(center) + Vector2(cos(angle), sin(angle)) * HEX_CORNER))
	return corners
