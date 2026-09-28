class_name ArenaView
extends Control
## The arena on screen (docs/plans/rebuild-phase3-fight-sandbox.md, section
## 2): one view for placement and the fight. It maps the sim's plane to
## pixels, draws the board, and keeps a token per unit. It only reads the
## setup or the fight; it never changes them.
##   - The board fits the view, centered, `MARGIN` pixels in. The heroes'
##     rows are at the bottom of the screen: the plane's y grows up the
##     screen (the sim's row 0 is the heroes' back row). A flat-top hex's
##     corners reach past the plane's edge at the sides, so the drawn area is
##     that much wider than the plane (`drawn_rect`).
##   - Placement mode shades each hex by zone (yours, no one's, theirs); fight
##     mode keeps the hexes faint, since distances still count in hexes.
##   - Hexes and rocks are drawn with `_draw()`; units are `UnitToken` nodes
##     (for hover and tweening later).

enum Mode { PLACEMENT, FIGHT }

const MARGIN: float = 12.0
## A flat-top hex's corner radius on the plane: rows are HEX apart, so the
## corners are HEX / sqrt(3) from the center.
const HEX_CORNER: float = HexGrid.HEX / 1.7320508
const ZONE_FILLS: Array[Color] = [Color("3a2c22"), Color("241e2a"), Color("1f2233")]
const HEX_LINE := Color("5b4a3a")
const FIGHT_HEX_LINE := Color(0.36, 0.29, 0.23, 0.35)
const ROCK_FILL := UiStyle.OAK_600
const ROCK_LINE := UiStyle.OAK_400

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
## Pixels per plane unit, and where the board's top-left corner is drawn.
var scale_px: float = 0.1
var _origin: Vector2 = Vector2.ZERO


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
	for unit: UnitSetup in setup.units():
		var token: UnitToken = UnitToken.make(unit.id, label_for(unit.def, content), unit.side, content.tuning.unit_radius, unit.def.has_trait("flying"))
		token.plane_pos = grid.center(unit.col, unit.row)
		tokens.append(token)
		add_child(token)
	_layout()


func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	queue_redraw()


func token(unit_id: String) -> UnitToken:
	for found: UnitToken in tokens:
		if found.unit_id == unit_id:
			return found
	return null


## A token's short label: a hero's name (its id), or the last word of an
## enemy's ("Rift Pup" -> "Pup").
static func label_for(kit: UnitDef, content: ContentDb) -> String:
	if content.heroes.has(kit.id):
		return kit.id.capitalize()
	var words: PackedStringArray = kit.name.split(" ", false)
	return words[words.size() - 1] if not words.is_empty() else kit.id


# --- the plane and the screen ------------------------------------------------------

## Where a point on the plane is drawn.
func to_pixel(point: Vector2i) -> Vector2:
	return Vector2(_origin.x + (point.x - board.position.x) * scale_px, _origin.y + (board.end.y - point.y) * scale_px)


## The point on the plane under a pixel (rounded to a whole unit).
func to_plane(pixel: Vector2) -> Vector2i:
	return Vector2i(roundi((pixel.x - _origin.x) / scale_px) + board.position.x, board.end.y - roundi((pixel.y - _origin.y) / scale_px))


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


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	if grid == null:
		return
	var room: Vector2 = size - Vector2(MARGIN, MARGIN) * 2.0
	scale_px = maxf(minf(room.x / drawn_rect.size.x, room.y / drawn_rect.size.y), 0.001)
	var drawn: Vector2 = Vector2(drawn_rect.size) * scale_px
	# _origin is where the plane's board.position.x, board.end.y lands.
	_origin = (size - drawn) / 2.0 + Vector2(board.position.x - drawn_rect.position.x, drawn_rect.end.y - board.end.y) * scale_px
	for unit_token: UnitToken in tokens:
		unit_token.place(self)
	queue_redraw()


# --- drawing -------------------------------------------------------------------

func _draw() -> void:
	if grid == null:
		return
	var top_left: Vector2 = to_pixel(Vector2i(drawn_rect.position.x, drawn_rect.end.y))
	draw_rect(Rect2(top_left, Vector2(drawn_rect.size) * scale_px), UiStyle.INK_700)
	for index: int in grid.size():
		var col: int = grid.col_of(index)
		var row: int = grid.row_of(index)
		var corners: PackedVector2Array = hex_corners(grid.center(col, row))
		if mode == Mode.PLACEMENT:
			draw_colored_polygon(corners, ZONE_FILLS[grid.zone(row)])
		var outline: PackedVector2Array = corners.duplicate()
		outline.append(corners[0])
		draw_polyline(outline, HEX_LINE if mode == Mode.PLACEMENT else FIGHT_HEX_LINE, 1.5, true)
	for rock: ArenaPlane.Circle in rocks:
		var center: Vector2 = to_pixel(rock.center)
		draw_circle(center, rock.radius * scale_px, ROCK_FILL)
		draw_arc(center, rock.radius * scale_px, 0.0, TAU, 32, ROCK_LINE, 2.0, true)


## A hex's six corners in pixels, flat top and bottom.
func hex_corners(center: Vector2i) -> PackedVector2Array:
	var middle: Vector2 = to_pixel(center)
	var corners := PackedVector2Array()
	for i: int in 6:
		var angle: float = i * TAU / 6.0
		corners.append(middle + Vector2(cos(angle), sin(angle)) * HEX_CORNER * scale_px)
	return corners
