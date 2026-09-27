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
## Queue keys are an estimate times this, plus the push count (so ties go
## to whatever was queued first).
const ORDER: int = 1 << 24

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
	if known == 0:
		known = _work_out(at_cell)
	return known == 1


## Works out whether the walker fits on the cell's center, and remembers it:
## 1 if it does, 2 if not.
func _work_out(at_cell: int) -> int:
	var point: Vector2i = center(at_cell)
	var free: bool = ArenaPlane.inside(bounds if _leaving else _safe, point, _radius)
	if free:
		var bucket: Vector2i = _bucket_of(point)
		for index: int in _buckets[bucket.y * _bucket_cols + bucket.x]:
			if ArenaPlane.overlaps(point, 0, _centers[index], _reaches[index]):
				free = false
				break
	_free[at_cell] = 1 if free else 2
	return _free[at_cell]


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
## guided by how far the closest target's reach at least is: the larger of
## the x and y distances, less the reach (never more than the straight-line
## distance, so never an overestimate, and it changes by no more than a step
## costs, so A* stays exact). With `first`, it stops at the first goal;
## otherwise it keeps settling every cell that could still be as close, so
## ties go to the lower index. Cells are queued by (estimate, then the order
## they were queued in), so the search settles them the same way every time.
##
## This runs a lot, so it's written for speed: plain integer arrays, the
## queue inline, and a cell's blocking looked up before it's worked out.
func _search(start: Vector2i, forward: int, targets: Array[Vector2i], reach: int, first: bool) -> Vector2i:
	_start = cell_at(start)
	var leaving: bool = not ArenaPlane.inside(_safe, start, _radius)
	if leaving != _leaving:
		_leaving = leaving
		_free.fill(0)
	_distance.fill(UNREACHED)
	_previous.fill(-1)
	_settled.fill(0)
	var target_count: int = targets.size()
	var xs := PackedInt32Array()
	var ys := PackedInt32Array()
	for target: Vector2i in targets:
		xs.append(target.x)
		ys.append(target.y)
	@warning_ignore("integer_division")
	var half: int = cell / 2
	var x0: int = origin.x + half
	var y0: int = origin.y + half
	var reach_sq: int = reach * reach
	var steps_x := PackedInt32Array()
	var steps_y := PackedInt32Array()
	for offset: Vector2i in FORWARD_NEIGHBORS:
		steps_x.append(offset.x * forward)
		steps_y.append(offset.y * forward)
	# The queue: a binary min-heap of keys (estimate x ORDER + push count).
	var keys := PackedInt64Array()
	var queued := PackedInt32Array()
	var pushes: int = 0
	var best_cell: int = -1
	var best_target: int = -1
	var best_distance: int = UNREACHED
	_distance[_start] = 0
	keys.append(_estimate(_start % cols, _start / cols, xs, ys, target_count, reach, x0, y0) * ORDER + pushes)
	queued.append(_start)
	pushes += 1
	while not keys.is_empty():
		# Pop the smallest.
		var at: int = queued[0]
		var last: int = keys.size() - 1
		keys[0] = keys[last]
		queued[0] = queued[last]
		keys.resize(last)
		queued.resize(last)
		var i: int = 0
		while true:
			var smallest: int = i
			var left: int = 2 * i + 1
			if left < last and keys[left] < keys[smallest]:
				smallest = left
			if left + 1 < last and keys[left + 1] < keys[smallest]:
				smallest = left + 1
			if smallest == i:
				break
			var key: int = keys[i]
			keys[i] = keys[smallest]
			keys[smallest] = key
			var cell_at_i: int = queued[i]
			queued[i] = queued[smallest]
			queued[smallest] = cell_at_i
			i = smallest
		if _settled[at] != 0:
			continue
		var col: int = at % cols
		@warning_ignore("integer_division")
		var row: int = at / cols
		var here: int = _distance[at]
		if best_distance != UNREACHED and here + _estimate(col, row, xs, ys, target_count, reach, x0, y0) > best_distance:
			break
		_settled[at] = 1
		var px: int = x0 + col * cell
		var py: int = y0 + row * cell
		for t: int in target_count:
			var dx: int = xs[t] - px
			var dy: int = ys[t] - py
			if dx * dx + dy * dy > reach_sq:
				continue
			if best_distance == UNREACHED or t < best_target:
				best_cell = at
				best_target = t
				best_distance = here
			if first:
				return Vector2i(best_cell, best_target)
			break
		# Queue its neighbors.
		for n: int in 8:
			var step_x: int = steps_x[n]
			var step_y: int = steps_y[n]
			var next_col: int = col + step_x
			var next_row: int = row + step_y
			if next_col < 0 or next_col >= cols or next_row < 0 or next_row >= rows:
				continue
			var next: int = next_row * cols + next_col
			if _settled[next] != 0:
				continue
			var known: int = _free[next]
			if known == 0:
				known = _work_out(next)
			if known != 1:
				continue
			var cost: int = _straight
			if step_x != 0 and step_y != 0:
				# Never cut a corner past a blocked cell.
				var side_a: int = row * cols + next_col
				var side_b: int = next_row * cols + col
				if (_free[side_a] if _free[side_a] != 0 else _work_out(side_a)) != 1:
					continue
				if (_free[side_b] if _free[side_b] != 0 else _work_out(side_b)) != 1:
					continue
				cost = _diagonal
			var reached_at: int = here + cost
			if _distance[next] != UNREACHED and reached_at >= _distance[next]:
				continue
			_distance[next] = reached_at
			_previous[next] = at
			# Push, then sift up.
			keys.append((reached_at + _estimate(next_col, next_row, xs, ys, target_count, reach, x0, y0)) * ORDER + pushes)
			queued.append(next)
			pushes += 1
			var j: int = keys.size() - 1
			while j > 0:
				@warning_ignore("integer_division")
				var parent: int = (j - 1) / 2
				if keys[parent] <= keys[j]:
					break
				var parent_key: int = keys[parent]
				keys[parent] = keys[j]
				keys[j] = parent_key
				var parent_cell: int = queued[parent]
				queued[parent] = queued[j]
				queued[j] = parent_cell
				j = parent
	return Vector2i(best_cell, best_target)


## The estimate for the cell at (col, row): see _search.
func _estimate(col: int, row: int, xs: PackedInt32Array, ys: PackedInt32Array, target_count: int, reach: int, x0: int, y0: int) -> int:
	var px: int = x0 + col * cell
	var py: int = y0 + row * cell
	var best: int = -1
	for t: int in target_count:
		var estimate: int = maxi(maxi(absi(xs[t] - px), absi(ys[t] - py)) - reach, 0)
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
