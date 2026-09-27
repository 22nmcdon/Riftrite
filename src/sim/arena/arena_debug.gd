class_name ArenaDebug
extends RefCounted
## A plain-text picture of the arena, one character per nav cell (a quarter
## hex), for tests and debugging (docs/plans/rebuild-phase1-arena-sim.md,
## section 11). It only reads; it never touches a fight.
##   .  open ground        ~  crumbled ground (outside the safe rectangle)
##   #  rock               !  a warned area
##   a letter: a unit (its tag's first character; later circles draw on top)

const GROUND: String = "."
const CRUMBLED: String = "~"
const ROCK: String = "#"
const WARNED: String = "!"


## The arena `bounds`, with `safe` ground, `rocks`, `units` (each drawn with
## its tag's first character), and `warned` points (e.g. an area's hits),
## one row of text per row of cells.
static func draw(bounds: Rect2i, safe: Rect2i, rocks: Array[ArenaPlane.Circle], units: Array[ArenaPlane.Circle], warned: Array[Vector2i] = [], cell: int = 250) -> String:
	var nav: NavGrid = NavGrid.make(bounds, cell)
	var chars: PackedStringArray = PackedStringArray()
	chars.resize(nav.size())
	for at: int in nav.size():
		chars[at] = GROUND if safe.has_point(nav.center(at)) else CRUMBLED
	for point: Vector2i in warned:
		chars[nav.cell_at(point)] = WARNED
	for rock: ArenaPlane.Circle in rocks:
		_fill(nav, chars, rock, ROCK)
	for unit: ArenaPlane.Circle in units:
		_fill(nav, chars, unit, unit.tag.substr(0, 1) if not unit.tag.is_empty() else "?")
	var lines: PackedStringArray = PackedStringArray()
	for row: int in nav.rows:
		lines.append("".join(chars.slice(row * nav.cols, (row + 1) * nav.cols)))
	return "\n".join(lines)


static func _fill(nav: NavGrid, chars: PackedStringArray, circle: ArenaPlane.Circle, mark: String) -> void:
	for at: int in nav.size():
		if ArenaPlane.within(nav.center(at), circle.center, circle.radius):
			chars[at] = mark
	# Always mark the cell under the center, however small the circle.
	chars[nav.cell_at(circle.center)] = mark
