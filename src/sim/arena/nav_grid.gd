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
## The search's estimate counts the shorter of the x and y distances at this
## share extra (a diagonal step's extra, rounded down), and takes off the
## reach times OCTILE_REACH_BP (the most the estimate's measure can exceed a
## straight line), so it never overestimates.
const OCTILE_EXTRA_BP: int = 4142
const OCTILE_REACH_BP: int = 10824
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
## _pocket_closed gives up past this many cells.
const POCKET_CAP: int = 120
## The checks before a suspect search run only for a reach up to this: a
## melee walker's goal cells are few and easily taken or walled in, while a
## ranged one's are many and the checks would cost more than they save.
const CHECK_REACH: int = 1500
## ...and for at most this many targets: a `nearest` over a crowd of enemies
## has too many goal cells to close off.
const CHECK_TARGETS: int = 4

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
## Each obstacle's center, and how close the walker's center may come
## (squared): plain arrays, since every cell check reads them.
var _obstacle_xs: PackedInt32Array = PackedInt32Array()
var _obstacle_ys: PackedInt32Array = PackedInt32Array()
var _obstacle_reach_sq: PackedInt32Array = PackedInt32Array()
## Where the walker's center must stay (inside the safe ground, or the whole
## arena when it's leaving crumbled ground), and the first cell's center.
var _min_x: int
var _min_y: int
var _max_x: int
var _max_y: int
var _x0: int
var _y0: int
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
	@warning_ignore("integer_division")
	grid._x0 = grid.origin.x + cell_size / 2
	@warning_ignore("integer_division")
	grid._y0 = grid.origin.y + cell_size / 2
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
	_set_limits()
	_obstacle_xs.clear()
	_obstacle_ys.clear()
	_obstacle_reach_sq.clear()
	for i: int in _buckets.size():
		_buckets[i] = PackedInt32Array()
	_free.fill(0)


## A circle the walker mustn't overlap: a unit or a rock of `obstacle_radius`.
func add_obstacle(point: Vector2i, obstacle_radius: int) -> void:
	var index: int = _obstacle_xs.size()
	var reach: int = obstacle_radius + _radius
	_obstacle_xs.append(point.x)
	_obstacle_ys.append(point.y)
	_obstacle_reach_sq.append(reach * reach)
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
## (Written out by hand, since every search runs it hundreds of times.)
func _work_out(at_cell: int) -> int:
	@warning_ignore("integer_division")
	var row: int = at_cell / cols
	var px: int = _x0 + (at_cell - row * cols) * cell
	var py: int = _y0 + row * cell
	var result: int = 1
	if px < _min_x or px > _max_x or py < _min_y or py > _max_y:
		result = 2
	else:
		@warning_ignore("integer_division")
		var bucket_col: int = clampi((px - origin.x) / BUCKET, 0, _bucket_cols - 1)
		@warning_ignore("integer_division")
		var bucket_row: int = clampi((py - origin.y) / BUCKET, 0, _bucket_rows - 1)
		for index: int in _buckets[bucket_row * _bucket_cols + bucket_col]:
			var dx: int = _obstacle_xs[index] - px
			var dy: int = _obstacle_ys[index] - py
			if dx * dx + dy * dy < _obstacle_reach_sq[index]:
				result = 2
				break
	_free[at_cell] = result
	return result


## Where the walker's center may be: inside the safe ground (or the whole
## arena while it's leaving crumbled ground), a radius in from the edge.
func _set_limits() -> void:
	var area: Rect2i = bounds if _leaving else _safe
	_min_x = area.position.x + _radius
	_min_y = area.position.y + _radius
	_max_x = area.end.x - _radius
	_max_y = area.end.y - _radius


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
## `suspect`: the walker's last search like this found nothing, so first check
## cheaply whether the goal cells are all taken or closed off
## (_pocket_closed). It only changes how fast a search fails,
## never what it finds; a first search skips the checks, since they cost
## something when the way is open, and so does a ranged walker or a search
## over many targets (CHECK_REACH, CHECK_TARGETS).
func find_path(start: Vector2i, forward: int, target: Vector2i, reach: int, suspect: bool = false) -> int:
	var targets: Array[Vector2i] = [target]
	return _search(start, forward, targets, reach, true, false, suspect).x


## The index of the target in `targets` with the shortest path to a free cell
## within `reach` of it, or -1 if none can be reached. Ties go to the lower
## index (list the targets in fight order).
func find_nearest(start: Vector2i, forward: int, targets: Array[Vector2i], reach: int, suspect: bool = false) -> int:
	return _search(start, forward, targets, reach, false, false, suspect).y


## A* from `start`, on crumbled ground, to the nearest free cell (not the
## one it starts in, which may not be free) where the walker stands wholly on
## safe ground again. Returns that cell, or -1 if there's none.
func find_safe(start: Vector2i, forward: int) -> int:
	var targets: Array[Vector2i] = []
	return _search(start, forward, targets, 0, true, true).x


## Returns (goal cell, target index), or (-1, -1). Both searches are A*,
## guided by how far the closest target's reach at least is: the octile
## distance (the longer of the x and y distances, plus 0.4142 of the shorter,
## as if walked straight and diagonally on open ground), less the reach
## stretched to the octile measure. It never overestimates, and it changes by
## no more than a step costs, so A* stays exact; on open ground it's close to
## the true cost, so a search spreads little beyond its path. With `first`, it stops at the first goal;
## otherwise it keeps settling every cell that could still be as close, so
## ties go to the lower index. With `to_safe`, there are no targets: the
## goal is any cell inside the safe ground, and the estimate is the octile
## distance to it. Cells are queued by (estimate, then the order
## they were queued in), so the search settles them the same way every time.
##
## This runs a lot, so it's written for speed: plain integer arrays, the
## queue inline, and a cell's blocking looked up before it's worked out.
func _search(start: Vector2i, forward: int, targets: Array[Vector2i], reach: int, first: bool, to_safe: bool = false, suspect: bool = false) -> Vector2i:
	_start = cell_at(start)
	var leaving: bool = not ArenaPlane.inside(_safe, start, _radius)
	if leaving != _leaving:
		_leaving = leaving
		_set_limits()
		_free.fill(0)
	_distance.fill(UNREACHED)
	_previous.fill(-1)
	_settled.fill(0)
	if suspect and not to_safe and reach <= CHECK_REACH and targets.size() <= CHECK_TARGETS and _pocket_closed(targets, reach):
		# No goal cell is free, or every one is cut off from the walker (in a
		# crowd, the spots beside a target are taken or walled in), so the
		# search would flood everything it can reach and find nothing.
		_settled.fill(0)
		return Vector2i(-1, -1)
	if suspect:
		_settled.fill(0)
	var target_count: int = targets.size()
	# The safe ground's limits for the walker's center (to_safe's goal).
	var safe_x0: int = _safe.position.x + _radius
	var safe_y0: int = _safe.position.y + _radius
	var safe_x1: int = _safe.end.x - _radius
	var safe_y1: int = _safe.end.y - _radius
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
	@warning_ignore("integer_division")
	var slack: int = (reach * OCTILE_REACH_BP + FixedMath.BP_ONE - 1) / FixedMath.BP_ONE
	var steps_x := PackedInt32Array()
	var steps_y := PackedInt32Array()
	for offset: Vector2i in FORWARD_NEIGHBORS:
		steps_x.append(offset.x * forward)
		steps_y.append(offset.y * forward)
	# The queue: a binary min-heap of keys (estimate x ORDER + push count),
	# the first `size` entries of its arrays (kept, not shrunk, as it drains).
	var keys := PackedInt64Array()
	var queued := PackedInt32Array()
	var size: int = 0
	var pushes: int = 0
	var best_cell: int = -1
	var best_target: int = -1
	var best_distance: int = UNREACHED
	_distance[_start] = 0
	var first_guess: int = _estimate_safe(center(_start)) if to_safe else _estimate(_start % cols, _start / cols, xs, ys, target_count, slack, x0, y0)
	keys.append(first_guess * ORDER + pushes)
	queued.append(_start)
	size = 1
	pushes += 1
	while size > 0:
		# Pop the smallest.
		var at: int = queued[0]
		var last: int = size - 1
		keys[0] = keys[last]
		queued[0] = queued[last]
		size = last
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
		if best_distance != UNREACHED and here + _estimate(col, row, xs, ys, target_count, slack, x0, y0) > best_distance:
			break
		_settled[at] = 1
		var px: int = x0 + col * cell
		var py: int = y0 + row * cell
		if to_safe and at != _start and px >= safe_x0 and px <= safe_x1 and py >= safe_y0 and py <= safe_y1:
			return Vector2i(at, 0)
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
			# Its estimate (as _estimate works it out, written out here since
			# it runs for every cell queued).
			var nx: int = x0 + next_col * cell
			var ny: int = y0 + next_row * cell
			var guess: int = -1
			if to_safe:
				guess = _estimate_safe(Vector2i(nx, ny))
			for t: int in target_count:
				var gx: int = absi(xs[t] - nx)
				var gy: int = absi(ys[t] - ny)
				@warning_ignore("integer_division")
				var one: int = maxi(maxi(gx, gy) + mini(gx, gy) * OCTILE_EXTRA_BP / FixedMath.BP_ONE - slack, 0)
				if guess < 0 or one < guess:
					guess = one
			# Push, then sift up.
			var pushed: int = (reached_at + guess) * ORDER + pushes
			if size < keys.size():
				keys[size] = pushed
				queued[size] = next
			else:
				keys.append(pushed)
				queued.append(next)
			size += 1
			pushes += 1
			var j: int = size - 1
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


## True if the goal cells (free cells within `reach` of a target) and
## everything joined to them make up a closed pocket the walker's cell isn't
## in (or there are none): then no path reaches a goal. It floods out from the goals, with the
## search's own moves (which work the same both ways), and gives up (false)
## after POCKET_CAP cells, since then the pocket is too big to be worth it.
## Uses _settled as its marks: it must start clear, and the caller clears it
## again after.
func _pocket_closed(targets: Array[Vector2i], reach: int) -> bool:
	var reach_sq: int = reach * reach
	@warning_ignore("integer_division")
	var half: int = cell / 2
	var queue := PackedInt32Array()
	var start_center: Vector2i = center(_start)
	for target: Vector2i in targets:
		if ArenaPlane.length_sq(start_center - target) <= reach_sq:
			return false
		@warning_ignore("integer_division")
		var col0: int = maxi((target.x - reach - origin.x - half) / cell, 0)
		@warning_ignore("integer_division")
		var col1: int = mini((target.x + reach - origin.x - half) / cell + 1, cols - 1)
		@warning_ignore("integer_division")
		var row0: int = maxi((target.y - reach - origin.y - half) / cell, 0)
		@warning_ignore("integer_division")
		var row1: int = mini((target.y + reach - origin.y - half) / cell + 1, rows - 1)
		for row: int in range(row0, row1 + 1):
			var dy: int = origin.y + half + row * cell - target.y
			for col: int in range(col0, col1 + 1):
				var dx: int = origin.x + half + col * cell - target.x
				var at: int = row * cols + col
				if dx * dx + dy * dy > reach_sq or _settled[at] != 0:
					continue
				if (_free[at] if _free[at] != 0 else _work_out(at)) != 1:
					continue
				_settled[at] = 1
				queue.append(at)
				if queue.size() > POCKET_CAP:
					return false
	var next_index: int = 0
	while next_index < queue.size():
		var at: int = queue[next_index]
		next_index += 1
		var col: int = at % cols
		@warning_ignore("integer_division")
		var row: int = at / cols
		for offset: Vector2i in FORWARD_NEIGHBORS:
			var next_col: int = col + offset.x
			var next_row: int = row + offset.y
			if next_col < 0 or next_col >= cols or next_row < 0 or next_row >= rows:
				continue
			var next: int = next_row * cols + next_col
			if offset.x != 0 and offset.y != 0:
				var side_a: int = row * cols + next_col
				var side_b: int = next_row * cols + col
				if (_free[side_a] if _free[side_a] != 0 else _work_out(side_a)) != 1:
					continue
				if (_free[side_b] if _free[side_b] != 0 else _work_out(side_b)) != 1:
					continue
			if next == _start:
				return false
			if _settled[next] != 0 or (_free[next] if _free[next] != 0 else _work_out(next)) != 1:
				continue
			_settled[next] = 1
			queue.append(next)
			if queue.size() > POCKET_CAP:
				return false
	return true


## The search's estimate from the cell holding `point` to the nearest of
## `targets` within `reach` (see _search). The search computes it inline;
## this is for tests.
func estimate(point: Vector2i, targets: Array[Vector2i], reach: int) -> int:
	var xs := PackedInt32Array()
	var ys := PackedInt32Array()
	for target: Vector2i in targets:
		xs.append(target.x)
		ys.append(target.y)
	@warning_ignore("integer_division")
	var half: int = cell / 2
	@warning_ignore("integer_division")
	var slack: int = (reach * OCTILE_REACH_BP + FixedMath.BP_ONE - 1) / FixedMath.BP_ONE
	var at: int = cell_at(point)
	@warning_ignore("integer_division")
	return _estimate(at % cols, at / cols, xs, ys, targets.size(), slack, origin.x + half, origin.y + half)


## The estimate for the cell at (col, row): see _search.
func _estimate(col: int, row: int, xs: PackedInt32Array, ys: PackedInt32Array, target_count: int, slack: int, x0: int, y0: int) -> int:
	var px: int = x0 + col * cell
	var py: int = y0 + row * cell
	var best: int = -1
	for t: int in target_count:
		var dx: int = absi(xs[t] - px)
		var dy: int = absi(ys[t] - py)
		# Clamped to 0 before comparing: -1 means "none yet".
		@warning_ignore("integer_division")
		var estimate: int = maxi(maxi(dx, dy) + mini(dx, dy) * OCTILE_EXTRA_BP / FixedMath.BP_ONE - slack, 0)
		if best < 0 or estimate < best:
			best = estimate
	return best


## find_safe's estimate from `point`: the octile distance to the nearest
## point where the walker stands wholly on safe ground (for the walker set
## by begin).
func estimate_safe(point: Vector2i) -> int:
	return _estimate_safe(point)


func _estimate_safe(point: Vector2i) -> int:
	var dx: int = maxi(maxi(_safe.position.x + _radius - point.x, point.x - (_safe.end.x - _radius)), 0)
	var dy: int = maxi(maxi(_safe.position.y + _radius - point.y, point.y - (_safe.end.y - _radius)), 0)
	@warning_ignore("integer_division")
	return maxi(dx, dy) + mini(dx, dy) * OCTILE_EXTRA_BP / FixedMath.BP_ONE


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
