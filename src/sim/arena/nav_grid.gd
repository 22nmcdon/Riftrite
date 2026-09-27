class_name NavGrid
extends RefCounted
## Pathfinding on the plane (docs/plans/rebuild-phase1-arena-sim.md, section 4):
## a hidden grid of square cells (an eighth of a hex by default, fine enough
## to find a one-hex gap between two units) that nothing snaps to. A walker
## describes what blocks it (begin, then add_obstacle), then searches from
## where it stands:
##   find_path     A* to any free cell within `reach` of a target
##   find_nearest  the target with the shortest path (ties: the earlier one)
## Then path_to and corners turn the result into straight legs.
##
## A cell is free when the walker standing on its center would fit inside the
## safe rectangle and overlap no obstacle (exact, never optimistic, so a path
## never leads into a gap the walker can't fit through). Cells are checked
## lazily, only when a search reaches them. The start cell is always free,
## and a walker starting on crumbled ground may cross crumbled cells, so it
## can always walk back to safe ground.
##
## Costs are integers (a cell straight, about 1.414 cells diagonally, never
## cutting past a blocked cell). Neighbors are tried in a fixed order,
## forward-first for each side, and ties go to whatever was queued first, so
## a search is the same every time and neither side drifts toward one flank.

## Diagonal cost per straight cost, in basis points.
const DIAGONAL_BP: int = 14142
## Neighbor offsets for a walker heading toward larger y (the heroes):
## forward, the forward diagonals, the sides, the back diagonals, back. The
## enemies use the same list turned around.
const FORWARD_NEIGHBORS: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, 0),
	Vector2i(-1, 0), Vector2i(1, -1), Vector2i(-1, -1), Vector2i(0, -1),
]
const UNREACHED: int = -1
## Obstacles are filed in square buckets this wide, so a cell only checks
## the obstacles near it.
const BUCKET: int = 1000

var cell: int
var cols: int
var rows: int
var origin: Vector2i
var bounds: Rect2i
var _straight: int
var _diagonal: int

# What blocks the current walker.
var _safe: Rect2i
## The walker started on crumbled ground: crumbled cells are free for it.
var _leaving: bool = false
var _radius: int
var _centers: Array[Vector2i] = []
var _reaches: PackedInt32Array = PackedInt32Array()
var _bucket_cols: int
var _bucket_rows: int
var _buckets: Array[PackedInt32Array] = []
# Cell -> 0 unknown, 1 free, 2 blocked, for the current walker.
var _free: PackedByteArray = PackedByteArray()

# The last search.
var _start: int = -1
var _distance: PackedInt32Array = PackedInt32Array()
var _previous: PackedInt32Array = PackedInt32Array()
var _settled: PackedByteArray = PackedByteArray()


static func make(arena: Rect2i, cell_size: int = 125) -> NavGrid:
	var grid := NavGrid.new()
	grid.cell = cell_size
	grid.bounds = arena
	grid.origin = arena.position
	@warning_ignore("integer_division")
	grid.cols = (arena.size.x + cell_size - 1) / cell_size
	@warning_ignore("integer_division")
	grid.rows = (arena.size.y + cell_size - 1) / cell_size
	grid._straight = cell_size
	grid._diagonal = FixedMath.apply_bp(cell_size, DIAGONAL_BP)
	@warning_ignore("integer_division")
	grid._bucket_cols = (arena.size.x + BUCKET - 1) / BUCKET
	@warning_ignore("integer_division")
	grid._bucket_rows = (arena.size.y + BUCKET - 1) / BUCKET
	grid._buckets.resize(grid._bucket_cols * grid._bucket_rows)
	grid._free.resize(grid.size())
	grid._distance.resize(grid.size())
	grid._previous.resize(grid.size())
	grid._settled.resize(grid.size())
	grid.begin(arena, 0)
	return grid


func size() -> int:
	return cols * rows


func cell_at(point: Vector2i) -> int:
	@warning_ignore("integer_division")
	var col: int = clampi((point.x - origin.x) / cell, 0, cols - 1)
	@warning_ignore("integer_division")
	var row: int = clampi((point.y - origin.y) / cell, 0, rows - 1)
	return row * cols + col


func center(at_cell: int) -> Vector2i:
	@warning_ignore("integer_division")
	var half: int = cell / 2
	@warning_ignore("integer_division")
	return origin + Vector2i((at_cell % cols) * cell + half, (at_cell / cols) * cell + half)


# --- what blocks the walker ---------------------------------------------------

## Starts describing a walker of `radius` that must stay inside `safe`.
func begin(safe: Rect2i, radius: int) -> void:
	_safe = safe
	_radius = radius
	_centers.clear()
	_reaches.clear()
	for i: int in _buckets.size():
		_buckets[i] = PackedInt32Array()
	_free.fill(0)


## A circle the walker mustn't overlap: a unit or a rock of `obstacle_radius`.
func add_obstacle(point: Vector2i, obstacle_radius: int) -> void:
	var index: int = _centers.size()
	var reach: int = obstacle_radius + _radius
	_centers.append(point)
	_reaches.append(reach)
	var low: Vector2i = _bucket_of(point - Vector2i(reach, reach))
	var high: Vector2i = _bucket_of(point + Vector2i(reach, reach))
	for row: int in range(low.y, high.y + 1):
		for col: int in range(low.x, high.x + 1):
			_buckets[row * _bucket_cols + col].append(index)
	_free.fill(0)


## True if the walker fits on the cell's center.
func is_free(at_cell: int) -> bool:
	var known: int = _free[at_cell]
	if known != 0:
		return known == 1
	var point: Vector2i = center(at_cell)
	var free: bool = ArenaPlane.inside(bounds if _leaving else _safe, point, _radius)
	if free:
		var bucket: Vector2i = _bucket_of(point)
		for index: int in _buckets[bucket.y * _bucket_cols + bucket.x]:
			if ArenaPlane.overlaps(point, 0, _centers[index], _reaches[index]):
				free = false
				break
	_free[at_cell] = 1 if free else 2
	return free


func _bucket_of(point: Vector2i) -> Vector2i:
	@warning_ignore("integer_division")
	var col: int = clampi((point.x - origin.x) / BUCKET, 0, _bucket_cols - 1)
	@warning_ignore("integer_division")
	var row: int = clampi((point.y - origin.y) / BUCKET, 0, _bucket_rows - 1)
	return Vector2i(col, row)


# --- searches ------------------------------------------------------------------

## A* from `start` to the nearest free cell whose center is within `reach` of
## `target`. Returns that cell, or -1 if there's none. `forward` is +1 for a
## walker heading toward larger y (the heroes), -1 for the enemies.
func find_path(start: Vector2i, forward: int, target: Vector2i, reach: int) -> int:
	var targets: Array[Vector2i] = [target]
	return _search(start, forward, targets, reach, true).x


## The index of the target in `targets` with the shortest path to a free cell
## within `reach` of it, or -1 if none can be reached. Ties go to the lower
## index (list the targets in fight order).
func find_nearest(start: Vector2i, forward: int, targets: Array[Vector2i], reach: int) -> int:
	return _search(start, forward, targets, reach, false).y


## Returns (goal cell, target index), or (-1, -1). Both searches are A*,
## guided by how far the closest target's reach at least is (_estimate). With
## `first`, it stops at the first goal; otherwise it keeps settling every
## cell that could still be as close, so ties go to the lower index.
func _search(start: Vector2i, forward: int, targets: Array[Vector2i], reach: int, first: bool) -> Vector2i:
	_start = cell_at(start)
	var leaving: bool = not ArenaPlane.inside(_safe, start, _radius)
	if leaving != _leaving:
		_leaving = leaving
		_free.fill(0)
	_distance.fill(UNREACHED)
	_previous.fill(-1)
	_settled.fill(0)
	var heap := _Heap.new()
	_distance[_start] = 0
	heap.push(_estimate(_start, targets, reach), _start)
	var best_cell: int = -1
	var best_target: int = -1
	var best_distance: int = UNREACHED
	var reach_sq: int = reach * reach
	while not heap.is_empty():
		var at: int = heap.pop()
		if _settled[at] != 0:
			continue
		if best_distance != UNREACHED and _distance[at] + _estimate(at, targets, reach) > best_distance:
			break
		_settled[at] = 1
		var point: Vector2i = center(at)
		for t: int in targets.size():
			if ArenaPlane.length_sq(targets[t] - point) > reach_sq:
				continue
			if best_distance == UNREACHED or t < best_target:
				best_cell = at
				best_target = t
				best_distance = _distance[at]
			if first:
				return Vector2i(best_cell, best_target)
			break
		_expand(at, forward, heap, targets, reach)
	return Vector2i(best_cell, best_target)


func _expand(at: int, forward: int, heap: _Heap, targets: Array[Vector2i], reach: int) -> void:
	var col: int = at % cols
	@warning_ignore("integer_division")
	var row: int = at / cols
	for offset: Vector2i in FORWARD_NEIGHBORS:
		var dx: int = offset.x * forward
		var dy: int = offset.y * forward
		var next_col: int = col + dx
		var next_row: int = row + dy
		if next_col < 0 or next_col >= cols or next_row < 0 or next_row >= rows:
			continue
		var next: int = next_row * cols + next_col
		if _settled[next] != 0 or not is_free(next):
			continue
		var cost: int = _straight
		if dx != 0 and dy != 0:
			# Never cut a corner past a blocked cell.
			if not is_free(row * cols + next_col) or not is_free(next_row * cols + col):
				continue
			cost = _diagonal
		var reached_at: int = _distance[at] + cost
		if _distance[next] == UNREACHED or reached_at < _distance[next]:
			_distance[next] = reached_at
			_previous[next] = at
			heap.push(reached_at + _estimate(next, targets, reach), next)


## How far the cell at least is from getting within reach of any target:
## the larger of the x and y distances (never more than the straight-line
## distance, so never an overestimate, and it changes by no more than a step
## costs, so A* stays exact), less the reach.
func _estimate(at: int, targets: Array[Vector2i], reach: int) -> int:
	var point: Vector2i = center(at)
	var best: int = -1
	for target: Vector2i in targets:
		var estimate: int = maxi(maxi(absi(target.x - point.x), absi(target.y - point.y)) - reach, 0)
		if best < 0 or estimate < best:
			best = estimate
	return maxi(best, 0)


## How many cells the last search settled (for tests and speed checks).
func settled_count() -> int:
	return _settled.count(1)


## The path length (plane units) from the last search's start to `at_cell`,
## or UNREACHED.
func distance_to(at_cell: int) -> int:
	return _distance[at_cell]


## The cells from the start (not included) to `at_cell`, or [] if it wasn't
## reached.
func path_to(at_cell: int) -> Array[int]:
	var path: Array[int] = []
	if at_cell < 0 or _distance[at_cell] == UNREACHED:
		return path
	var at: int = at_cell
	while at != _start:
		path.push_front(at)
		at = _previous[at]
	return path


## A path's corners on the plane: the center of every cell where it turns,
## then its last cell. A walker goes straight from corner to corner.
func corners(path: Array[int]) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var before: int = _start
	for i: int in path.size():
		var at: int = path[i]
		if i + 1 < path.size() and _step(before, at) == _step(at, path[i + 1]):
			before = at
			continue
		points.append(center(at))
		before = at
	return points


func _step(from: int, to: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(to % cols - from % cols, to / cols - from / cols)


## A binary min-heap of cells by key, ties broken by push order, so a search
## settles cells in the same order every time.
class _Heap:
	const ORDER: int = 1 << 24
	var _keys: PackedInt64Array = PackedInt64Array()
	var _cells: PackedInt32Array = PackedInt32Array()
	var _pushes: int = 0

	func is_empty() -> bool:
		return _keys.is_empty()

	func push(key: int, at: int) -> void:
		_keys.append(key * ORDER + _pushes)
		_cells.append(at)
		_pushes += 1
		var i: int = _keys.size() - 1
		while i > 0:
			@warning_ignore("integer_division")
			var parent: int = (i - 1) / 2
			if _keys[parent] <= _keys[i]:
				break
			_swap(i, parent)
			i = parent

	## Pops the cell with the smallest key.
	func pop() -> int:
		var at: int = _cells[0]
		var last: int = _keys.size() - 1
		_swap(0, last)
		_keys.resize(last)
		_cells.resize(last)
		var i: int = 0
		while true:
			var smallest: int = i
			var left: int = 2 * i + 1
			var right: int = left + 1
			if left < last and _keys[left] < _keys[smallest]:
				smallest = left
			if right < last and _keys[right] < _keys[smallest]:
				smallest = right
			if smallest == i:
				break
			_swap(i, smallest)
			i = smallest
		return at

	func _swap(a: int, b: int) -> void:
		var key: int = _keys[a]
		_keys[a] = _keys[b]
		_keys[b] = key
		var at: int = _cells[a]
		_cells[a] = _cells[b]
		_cells[b] = at
