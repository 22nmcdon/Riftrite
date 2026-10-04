class_name HexGrid
extends RefCounted
## The placement board (docs/plans/rebuild-phase1-arena-sim.md, section 1):
## flat-topped hexes in columns, odd columns shifted half a hex toward the
## enemy ("odd-q"). Hexes are only for placing units before the fight; the
## fight happens on the plane, where every hex has a center.
##
## Coordinates are (col, row): col 0 is the left edge, row 0 the heroes' back
## row, and the last row the enemies' back row. A hex is also stored as one
## int, `row * width + col`.
##
## On the plane, 1 hex = HEX units: the distance between two neighboring
## centers. Neighbors in a column are exactly HEX apart; neighbors in the
## next column are 999.98 apart (COL_STEP is 1000 x cos 30 degrees), which
## is close enough and stays integer.

enum Zone { HEROES, NEUTRAL, ENEMIES }

const HEX: int = 1000
const COL_STEP: int = 866
## How far odd columns sit toward the enemy, and how far the arena's edge is
## beyond the outermost centers.
const HALF_HEX: int = 500

## Neighbor offsets (dcol, drow) for even and odd columns.
const EVEN_NEIGHBORS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, -1), Vector2i(-1, -1), Vector2i(0, -1)]
const ODD_NEIGHBORS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]

var width: int
var height: int
## Rows in each side's zone; the rows between belong to no one.
var zone_rows: int


static func make(board_width: int = 8, board_height: int = 7, rows_per_zone: int = 3) -> HexGrid:
	assert(board_width > 0 and board_height > 2 * rows_per_zone and rows_per_zone > 0, "HexGrid: the zones need a neutral row between them")
	var grid := HexGrid.new()
	grid.width = board_width
	grid.height = board_height
	grid.zone_rows = rows_per_zone
	return grid


func size() -> int:
	return width * height


func index(col: int, row: int) -> int:
	return row * width + col


func col_of(hex: int) -> int:
	return hex % width


func row_of(hex: int) -> int:
	@warning_ignore("integer_division")
	return hex / width


func has(col: int, row: int) -> bool:
	return col >= 0 and col < width and row >= 0 and row < height


func zone(row: int) -> Zone:
	if row < zone_rows:
		return Zone.HEROES
	if row >= height - zone_rows:
		return Zone.ENEMIES
	return Zone.NEUTRAL


## True if the row is one of its side's back two rows (the "back-liners"
## rule, decided: fixed by where a unit starts).
func is_back_row(row: int) -> bool:
	return row < 2 or row >= height - 2


## The collapse ring: 0 on the border, counting inward.
func ring(col: int, row: int) -> int:
	return mini(mini(col, width - 1 - col), mini(row, height - 1 - row))


## The deepest ring; it never crumbles.
func last_ring() -> int:
	@warning_ignore("integer_division")
	return ring(width / 2, height / 2)


## The hex's neighbors on the board, in a fixed order.
func neighbors(col: int, row: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for offset: Vector2i in (ODD_NEIGHBORS if col % 2 == 1 else EVEN_NEIGHBORS):
		if has(col + offset.x, row + offset.y):
			found.append(Vector2i(col + offset.x, row + offset.y))
	return found


## The hex's center on the plane.
func center(col: int, row: int) -> Vector2i:
	return Vector2i(col * COL_STEP + HALF_HEX, row * HEX + HALF_HEX + (HALF_HEX if col % 2 == 1 else 0))


## The arena on the plane: the rectangle around every center, half a hex
## beyond the outermost ones.
func bounds() -> Rect2i:
	return Rect2i(0, 0, (width - 1) * COL_STEP + HEX, (height - 1) * HEX + HALF_HEX + HEX)


## What's left of the arena once `rings` rings have crumbled: each moves the
## edge in by one column at the sides and one row at the ends. The ends sit a
## further quarter hex in, because odd columns are shifted half a hex: that
## way a hex's center is on safe ground exactly when its ring hasn't
## crumbled.
func safe_rect(rings: int) -> Rect2i:
	var full: Rect2i = bounds()
	var r: int = clampi(rings, 0, last_ring())
	if r == 0:
		return full
	@warning_ignore("integer_division")
	var quarter: int = HALF_HEX / 2
	return Rect2i(full.position.x + r * COL_STEP, full.position.y + r * HEX + quarter,
		full.size.x - 2 * r * COL_STEP, full.size.y - 2 * (r * HEX + quarter))


## The hex whose center is nearest the point (ties go to the lower index).
func nearest_hex(point: Vector2i) -> int:
	var best: int = 0
	var best_distance: int = -1
	for hex: int in size():
		var d: Vector2i = center(col_of(hex), row_of(hex)) - point
		var distance: int = d.x * d.x + d.y * d.y
		if best_distance < 0 or distance < best_distance:
			best = hex
			best_distance = distance
	return best


## The hex whose center is nearest the point, as nearest_hex finds it (ties
## to the lower index), but looking only at the columns either side of it
## (and one more, for a point off the board's ends) and the two nearest rows
## in each: the nearest center is always among them (phase 8 part 3, water).
func hex_at(point: Vector2i) -> int:
	var left: int = _floor_div(point.x - HALF_HEX, COL_STEP)
	var best: int = -1
	var best_distance: int = -1
	for col: int in range(maxi(left - 1, 0), mini(left + 2, width - 1) + 1):
		var shift: int = HALF_HEX if col % 2 == 1 else 0
		var top: int = clampi(_floor_div(point.y - HALF_HEX - shift, HEX), 0, height - 1)
		for row: int in [top, mini(top + 1, height - 1)]:
			var d: Vector2i = center(col, row) - point
			var distance: int = d.x * d.x + d.y * d.y
			var hex: int = index(col, row)
			if best_distance < 0 or distance < best_distance or (distance == best_distance and hex < best):
				best = hex
				best_distance = distance
	return best


static func _floor_div(a: int, b: int) -> int:
	@warning_ignore("integer_division")
	var q: int = a / b
	if a % b != 0 and (a < 0) != (b < 0):
		q -= 1
	return q

