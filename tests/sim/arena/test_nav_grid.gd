extends GutTest
## Pathfinding on the plane's hidden grid, and the text board
## (docs/plans/rebuild-phase1-arena-sim.md, sections 4 and 11).

const UNIT_R: int = 400
const ROCK_R: int = 500
const MELEE: int = 1000

var grid: HexGrid = HexGrid.make()


func _hex(col: int, row: int) -> Vector2i:
	return grid.center(col, row)


## A nav grid for a unit-sized walker with units (and rocks) on these hexes.
func _nav(units: Array[Vector2i] = [], rocks: Array[Vector2i] = [], safe: Rect2i = grid.bounds()) -> NavGrid:
	var nav: NavGrid = NavGrid.make(grid.bounds())
	nav.begin(safe, UNIT_R)
	for hex: Vector2i in units:
		nav.add_obstacle(_hex(hex.x, hex.y), UNIT_R)
	for hex: Vector2i in rocks:
		nav.add_obstacle(_hex(hex.x, hex.y), ROCK_R)
	return nav


func _row(row: int, skip: Array[int] = []) -> Array[Vector2i]:
	var hexes: Array[Vector2i] = []
	for col: int in grid.width:
		if not skip.has(col):
			hexes.append(Vector2i(col, row))
	return hexes


## Walks the path's legs and checks the walker never overlaps anything on the
## way (in steps of 25).
func _assert_clear(nav: NavGrid, from: Vector2i, legs: Array[Vector2i], blockers: Array[ArenaPlane.Circle]) -> void:
	var at: Vector2i = from
	for leg: Vector2i in legs:
		while at != leg:
			at = ArenaPlane.step_toward(at, leg, 25)
			assert_true(ArenaPlane.inside(grid.bounds(), at, UNIT_R), "inside at %s" % at)
			for blocker: ArenaPlane.Circle in blockers:
				assert_false(ArenaPlane.overlaps(at, UNIT_R, blocker.center, blocker.radius), "clear of %s at %s" % [blocker.tag, at])


func test_the_grid() -> void:
	var nav: NavGrid = NavGrid.make(grid.bounds())
	assert_eq([nav.cell, nav.cols, nav.rows], [125, 57, 60], "eighth-hex cells by default")
	assert_eq(nav.center(0), Vector2i(62, 62))
	assert_eq(nav.cell_at(Vector2i(130, 380)), 3 * 57 + 1)
	assert_eq(nav.cell_at(Vector2i(-50, 99999)), 59 * 57, "points outside clamp to the edge")
	nav.begin(grid.bounds(), UNIT_R)
	assert_false(nav.is_free(0), "a walker can't stand at the very edge")
	assert_true(nav.is_free(nav.cell_at(_hex(3, 3))))


func test_a_clear_path_is_one_straight_leg() -> void:
	var nav: NavGrid = _nav()
	var goal: int = nav.find_path(_hex(2, 0), 1, _hex(2, 6), MELEE)
	assert_ne(goal, -1)
	assert_true(ArenaPlane.within(nav.center(goal), _hex(2, 6), MELEE), "it ends in reach")
	assert_eq(nav.corners(nav.path_to(goal)), [nav.center(goal)] as Array[Vector2i], "straight down, no turns")
	assert_between(nav.distance_to(goal), 5000 - 125, 5000 + 125, "about 5 hexes")


func test_routes_around_rocks() -> void:
	# A wall of rocks across the middle, open only at its right end.
	var nav: NavGrid = _nav([], _row(3, [6, 7]))
	var start: Vector2i = _hex(1, 1)
	var goal: int = nav.find_path(start, 1, _hex(1, 5), MELEE)
	assert_ne(goal, -1, "round the end of the wall")
	assert_gt(nav.distance_to(goal), 8000, "the long way round")
	var legs: Array[Vector2i] = nav.corners(nav.path_to(goal))
	assert_gt(legs.size(), 1, "it turns")
	var rocks: Array[ArenaPlane.Circle] = []
	for hex: Vector2i in _row(3, [6, 7]):
		rocks.append(ArenaPlane.Circle.make(_hex(hex.x, hex.y), ROCK_R, "rock"))
	_assert_clear(nav, start, legs, rocks)


func test_units_close_gaps_but_one_empty_hex_is_wide_enough() -> void:
	assert_eq(_nav(_row(3)).find_path(_hex(2, 1), 1, _hex(2, 5), MELEE), -1, "a line of units on neighboring hexes closes the board")
	for gap: int in grid.width:
		var nav: NavGrid = _nav(_row(3, [gap]))
		var start: Vector2i = _hex(gap, 1)
		var goal: int = nav.find_path(start, 1, _hex(gap, 5), MELEE)
		assert_ne(goal, -1, "one empty hex at column %d is a gap wide enough" % gap)
		var units: Array[ArenaPlane.Circle] = []
		for hex: Vector2i in _row(3, [gap]):
			units.append(ArenaPlane.Circle.make(_hex(hex.x, hex.y), UNIT_R, "unit"))
		_assert_clear(nav, start, nav.corners(nav.path_to(goal)), units)


func test_a_rock_gap_one_hex_wide_is_too_narrow() -> void:
	# Rocks are bigger than units: a single missing rock between two in the
	# same row leaves 732 of room, and a unit needs 800.
	assert_eq(_nav([], _row(3, [4])).find_path(_hex(4, 1), 1, _hex(4, 5), MELEE), -1)
	assert_ne(_nav([], _row(3, [3, 4])).find_path(_hex(4, 1), 1, _hex(4, 5), MELEE), -1, "two missing rocks let a unit through")


func test_nearest_is_by_path_not_straight_line() -> void:
	var enemies: Array[Vector2i] = [_hex(6, 4), _hex(2, 5)]
	var open: NavGrid = _nav()
	assert_eq(open.find_nearest(_hex(2, 1), 1, enemies, MELEE), 1, "straight down is nearest")
	# Rocks around (2, 5) make it a long walk; (6, 4) is closer by path.
	var walled: NavGrid = _nav([], [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(1, 5), Vector2i(3, 5)])
	assert_eq(walled.find_nearest(_hex(2, 1), 1, enemies, MELEE), 0)


func test_nearest_ties_go_to_the_earlier_target() -> void:
	var nav: NavGrid = _nav()
	# A cell's center, so both targets really are the same distance away.
	var start: Vector2i = nav.center(nav.cell_at(_hex(3, 3)))
	var left: Vector2i = start + Vector2i(-3000, 0)
	var right: Vector2i = start + Vector2i(3000, 0)
	assert_eq(nav.find_nearest(start, 1, [left, right] as Array[Vector2i], MELEE), 0)
	assert_eq(nav.find_nearest(start, 1, [right, left] as Array[Vector2i], MELEE), 0)
	assert_eq(nav.find_nearest(start, -1, [left, right] as Array[Vector2i], MELEE), 0, "the same for the other side")


func test_no_route() -> void:
	var nav: NavGrid = _nav()
	assert_eq(nav.find_nearest(_hex(0, 0), 1, [] as Array[Vector2i], MELEE), -1)
	# Rocks all around a target: nobody can get within reach.
	var target: Vector2i = _hex(4, 5)
	var boxed: Array[Vector2i] = []
	for next: Vector2i in grid.neighbors(4, 5):
		boxed.append(next)
	var walled: NavGrid = _nav([], boxed)
	assert_eq(walled.find_path(_hex(4, 1), 1, target, MELEE), -1)
	assert_eq(walled.find_nearest(_hex(4, 1), 1, [target] as Array[Vector2i], MELEE), -1)
	assert_eq(walled.path_to(-1), [] as Array[int])
	assert_ne(walled.find_path(_hex(4, 1), 1, target, 2000), -1, "a longer reach can still get there")


func test_crumbled_ground_is_walkable_but_costs_more() -> void:
	var nav: NavGrid = _nav([], [], grid.safe_rect(1))
	var start: Vector2i = _hex(0, 3)
	assert_true(nav.is_free(nav.cell_at(start)), "crumbled ground is walkable (phase 5c)")
	var goal: int = nav.find_path(start, 1, _hex(3, 3), MELEE)
	assert_ne(goal, -1)
	var open: NavGrid = _nav([], [], grid.bounds())
	var open_goal: int = open.find_path(start, 1, _hex(3, 3), MELEE)
	assert_gt(nav.distance_to(goal), open.distance_to(open_goal), "the steps on crumbled ground cost more")


## True if a walker at `point` stands wholly on `safe` ground.
func _wholly_safe(point: Vector2i, safe: Rect2i) -> bool:
	return ArenaPlane.inside(safe, point, UNIT_R)


func test_the_way_back_to_safe_ground() -> void:
	# Every step but the last is on crumbled ground (NavGrid.CRUMBLED_COST_BP),
	# so the way back is the one with the fewest steps.
	var safe: Rect2i = grid.safe_rect(1)
	var nav: NavGrid = _nav([], [], safe)
	for start: Vector2i in [_hex(0, 3), _hex(3, 0), _hex(4, 6), _hex(0, 0), _hex(7, 6)]:
		var goal: int = nav.find_safe(start, 1)
		assert_true(_wholly_safe(nav.center(goal), safe), "from %s to %s" % [start, nav.center(goal)])
		assert_lt(nav.settled_count(), 200, "guided (%d cells)" % nav.settled_count())
		var fewest: int = -1
		for at: int in nav.size():
			if _wholly_safe(nav.center(at), safe):
				var d: Vector2i = (nav.center(at) - nav.center(nav.cell_at(start))).abs() / nav.cell
				if fewest < 0 or maxi(d.x, d.y) < fewest:
					fewest = maxi(d.x, d.y)
		assert_eq(nav.path_to(goal).size(), fewest, "the fewest steps, from %s" % start)


func test_the_way_back_never_ends_where_it_starts() -> void:
	# The walker's cell center is on safe ground, but the walker isn't.
	var safe: Rect2i = grid.safe_rect(1)
	var nav: NavGrid = _nav([], [], safe)
	# The walker's center must stay at x >= 1266; the cell from 1250 to 1375
	# has its center at 1312.
	var start: Vector2i = Vector2i(1255, _hex(3, 3).y)
	assert_false(_wholly_safe(start, safe))
	assert_true(_wholly_safe(nav.center(nav.cell_at(start)), safe))
	var goal: int = nav.find_safe(start, 1)
	assert_ne(goal, nav.cell_at(start))
	assert_eq(nav.path_to(goal).size(), 1)


func test_no_way_back() -> void:
	var nav: NavGrid = _nav([], [Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(0, 3)], grid.safe_rect(1))
	assert_eq(nav.find_safe(_hex(0, 2), 1), -1)


func test_the_way_back_estimate() -> void:
	var safe: Rect2i = grid.safe_rect(1)
	var nav: NavGrid = _nav([], [], safe)
	var corner: Vector2i = safe.position + Vector2i(UNIT_R, UNIT_R)
	assert_eq(nav.estimate_safe(corner - Vector2i(1000, 1000)), 1414, "straight and diagonal, as on open ground")
	assert_eq(nav.estimate_safe(corner - Vector2i(0, 700)), 700)
	assert_eq(nav.estimate_safe(corner + Vector2i(100, 100)), 0, "on safe ground already")
	var end: Vector2i = safe.end - Vector2i(UNIT_R, UNIT_R)
	assert_eq(nav.estimate_safe(end + Vector2i(300, 200)), 300 + 200 * 4142 / 10000)


## A nav grid with unit obstacles at plane points (not hexes).
func _nav_at(points: Array[Vector2i]) -> NavGrid:
	var nav: NavGrid = NavGrid.make(grid.bounds())
	nav.begin(grid.bounds(), UNIT_R)
	for point: Vector2i in points:
		nav.add_obstacle(point, UNIT_R)
	return nav


## Units packed around `center`, every 800 on a ring of 800: no gap a walker
## fits through, and no free spot within 1 hex of it.
func _ringed(center: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for dir: Vector2i in Displacement.LEAP_DIRECTIONS:
		points.append(ArenaPlane.along(center, dir, 800))
	return points


## A ring of 24 units 1500 around `center`: a closed wall with free ground
## inside.
func _walled(center: Vector2i) -> Array[Vector2i]:
	var wall: Array[Vector2i] = []
	for i: int in 12:
		var dir: Vector2i = Displacement.LEAP_DIRECTIONS[i]
		wall.append(ArenaPlane.along(center, dir, 1500))
		wall.append(ArenaPlane.along(center, ArenaPlane.direction(Vector2i.ZERO, dir + Displacement.LEAP_DIRECTIONS[(i + 1) % 12]), 1500))
	return wall


func test_a_suspect_search_fails_fast_when_every_goal_is_taken() -> void:
	var target: Vector2i = _hex(3, 4)
	var nav: NavGrid = _nav_at(_ringed(target))
	assert_eq(nav.find_path(_hex(3, 0), 1, target, MELEE), -1)
	assert_gt(nav.settled_count(), 1000, "a plain search floods the board")
	assert_eq(nav.find_path(_hex(3, 0), 1, target, MELEE, true), -1)
	assert_eq(nav.settled_count(), 0, "a suspect one sees every goal cell is taken")
	var targets: Array[Vector2i] = [target]
	assert_eq(nav.find_nearest(_hex(3, 0), 1, targets, MELEE, true), -1)
	assert_eq(nav.settled_count(), 0)


func test_a_suspect_search_fails_fast_when_the_goals_are_walled_in() -> void:
	# The target stands in a pocket of free cells, walled in by a ring of
	# units 1500 out: the goal cells are free, but no way leads there.
	var target: Vector2i = _hex(3, 4)
	var nav: NavGrid = _nav_at(_walled(target))
	assert_eq(nav.find_path(_hex(3, 0), 1, target, MELEE), -1)
	assert_gt(nav.settled_count(), 1000)
	assert_eq(nav.find_path(_hex(3, 0), 1, target, MELEE, true), -1)
	assert_eq(nav.settled_count(), 0, "the pocket around the target is closed")


func test_a_suspect_search_still_finds_the_way() -> void:
	var nav: NavGrid = _nav()
	var plain: int = nav.find_path(_hex(3, 0), 1, _hex(3, 6), MELEE)
	var plain_distance: int = nav.distance_to(plain)
	var suspect: int = nav.find_path(_hex(3, 0), 1, _hex(3, 6), MELEE, true)
	assert_eq([suspect, nav.distance_to(suspect)], [plain, plain_distance])
	# A walker already inside the walled pocket: the check sees it there and
	# the search finds its way.
	var target: Vector2i = _hex(3, 4)
	var walled: NavGrid = _nav_at(_walled(target))
	var inside: Vector2i = target + Vector2i(0, -600)
	assert_ne(walled.find_path(inside, 1, target, 500, true), -1)
	var outside_goal: int = walled.find_path(inside, 1, target + Vector2i(0, 500), 300)
	assert_eq(walled.find_path(inside, 1, target + Vector2i(0, 500), 300, true), outside_goal)


func test_the_checks_skip_ranged_and_crowded_searches() -> void:
	var target: Vector2i = _hex(3, 4)
	var nav: NavGrid = _nav_at(_ringed(target))
	# Reach 2: the goal cells reach past the ring, so there is a way.
	assert_ne(nav.find_path(_hex(3, 0), 1, target, 2 * MELEE, true), -1)
	# Five targets, all ringed: no way to any, but too many to check first.
	var many: Array[Vector2i] = []
	var points: Array[Vector2i] = []
	for col: int in [1, 2, 3, 4, 5]:
		many.append(_hex(col, 5))
	for point: Vector2i in many:
		points.append_array(_ringed(point))
	var crowded: NavGrid = _nav_at(points)
	assert_eq(crowded.find_nearest(_hex(3, 0), 1, many, MELEE, true), -1)
	assert_gt(crowded.settled_count(), 0, "it searches as usual")
	assert_eq(crowded.find_nearest(_hex(3, 0), 1, many.slice(0, 4), MELEE, true), -1)
	assert_eq(crowded.settled_count(), 0, "four targets are checked first")


func test_suspect_searches_match_plain_ones() -> void:
	# Random crowds: whatever the board, a suspect search gives exactly what
	# a plain one does.
	var rng := SimRng.new(7)
	for layout: int in 60:
		var points: Array[Vector2i] = []
		for i: int in 10 + rng.range_int(30):
			points.append(Vector2i(400 + rng.range_int(6262), 400 + rng.range_int(6700)))
		var nav: NavGrid = _nav_at(points)
		var start: Vector2i = Vector2i(400 + rng.range_int(6262), 400 + rng.range_int(6700))
		var targets: Array[Vector2i] = []
		for i: int in 1 + rng.range_int(4):
			targets.append(points[rng.range_int(points.size())])
		var reach: int = MELEE if rng.range_int(3) > 0 else 1400
		var plain: int = nav.find_nearest(start, 1, targets, reach)
		var suspect: int = nav.find_nearest(start, 1, targets, reach, true)
		var plain_path: int = nav.find_path(start, 1, targets[0], reach)
		var plain_distance: int = nav.distance_to(plain_path) if plain_path >= 0 else -1
		var suspect_path: int = nav.find_path(start, 1, targets[0], reach, true)
		var suspect_distance: int = nav.distance_to(suspect_path) if suspect_path >= 0 else -1
		if [plain, plain_path, plain_distance] != [suspect, suspect_path, suspect_distance]:
			fail_test("layout %d: plain %s, suspect %s" % [layout, [plain, plain_path, plain_distance], [suspect, suspect_path, suspect_distance]])
			return
	pass_test("60 random layouts")


func test_searches_are_repeatable_and_lean_forward() -> void:
	var start: Vector2i = _hex(3, 3)
	var units: Array[Vector2i] = [Vector2i(3, 4), Vector2i(4, 4), Vector2i(2, 4)]
	var first: NavGrid = _nav(units)
	var goal: int = first.find_path(start, 1, _hex(3, 6), MELEE)
	var again: NavGrid = _nav(units)
	assert_eq(again.find_path(start, 1, _hex(3, 6), MELEE), goal)
	assert_eq(again.path_to(goal), first.path_to(goal), "the same search, the same path")
	# Straight ahead and straight back are equally short; heroes settle
	# forward first, enemies the other way.
	var nav: NavGrid = _nav()
	start = nav.center(nav.cell_at(start))
	var ahead: Vector2i = start + Vector2i(0, 3000)
	var behind: Vector2i = start - Vector2i(0, 3000)
	assert_eq(nav.find_nearest(start, 1, [behind, ahead] as Array[Vector2i], MELEE), 0, "a tie still goes to the earlier target")
	var hero_goal: int = nav.find_path(start, 1, start, 0 + 500)
	var enemy_goal: int = nav.find_path(start, -1, start, 0 + 500)
	assert_eq(hero_goal, nav.cell_at(start), "already in reach: nowhere to go")
	assert_eq(enemy_goal, hero_goal)


func test_each_side_detours_its_own_way() -> void:
	# A rock straight ahead: the detours either side are equally long. Heroes
	# lean to larger x, and the enemies (the board turned around) to smaller x.
	var nav: NavGrid = _nav()
	var start: Vector2i = nav.center(nav.cell_at(_hex(3, 3)))
	nav.add_obstacle(start + Vector2i(0, 1500), 300)
	var hero_goal: int = nav.find_path(start, 1, start + Vector2i(0, 3000), 0)
	var hero_xs: Array[int] = []
	for corner: Vector2i in nav.corners(nav.path_to(hero_goal)):
		hero_xs.append(corner.x)
	assert_gt(hero_xs.max(), start.x, "heroes go round on the right: %s" % str(hero_xs))
	assert_eq(hero_xs.min(), start.x)
	nav.begin(grid.bounds(), UNIT_R)
	nav.add_obstacle(start - Vector2i(0, 1500), 300)
	var enemy_goal: int = nav.find_path(start, -1, start - Vector2i(0, 3000), 0)
	var enemy_xs: Array[int] = []
	for corner: Vector2i in nav.corners(nav.path_to(enemy_goal)):
		enemy_xs.append(corner.x)
	assert_lt(enemy_xs.min(), start.x, "enemies go round on their right, the heroes' left: %s" % str(enemy_xs))
	assert_eq(enemy_xs.max(), start.x)


func test_the_search_is_guided() -> void:
	var nav: NavGrid = _nav()
	nav.find_path(_hex(3, 0), 1, _hex(3, 6), MELEE)
	assert_lt(nav.settled_count(), 200, "A* heads straight for the target instead of flooding the board (%d cells)" % nav.settled_count())
	nav.find_nearest(_hex(3, 0), 1, [_hex(3, 6), _hex(6, 6)] as Array[Vector2i], MELEE)
	assert_lt(nav.settled_count(), 1000, "so does the nearest search (%d of %d cells)" % [nav.settled_count(), nav.size()])
	nav.find_path(_hex(0, 0), 1, _hex(7, 6), MELEE)
	assert_lt(nav.settled_count(), 400, "a diagonal too: the estimate counts diagonal steps at their cost (%d cells)" % nav.settled_count())


func test_the_estimate_never_overshoots() -> void:
	# From every cell around a target, the estimate is at most the real walk,
	# or A* could settle for a longer path. The target is off a cell center, so
	# the goal ring's edge isn't lined up with the cells.
	var nav: NavGrid = _nav()
	var target: Vector2i = _hex(3, 3) + Vector2i(37, 61)
	var targets: Array[Vector2i] = [target]
	var checked: int = 0
	for dx: int in range(-2500, 2501, 125):
		for dy: int in range(-2500, 2501, 125):
			var start: Vector2i = nav.center(nav.cell_at(target + Vector2i(dx, dy)))
			var goal: int = nav.find_path(start, 1, target, MELEE)
			if goal < 0:
				continue
			var estimate: int = nav.estimate(start, targets, MELEE)
			if estimate > nav.distance_to(goal):
				fail_test("from %s: estimate %d, walk %d" % [start, estimate, nav.distance_to(goal)])
				return
			checked += 1
	assert_gt(checked, 1000)


func test_diagonals_never_cut_a_corner() -> void:
	var nav: NavGrid = NavGrid.make(Rect2i(0, 0, 375, 375))
	nav.begin(Rect2i(0, 0, 375, 375), 0)
	# Block the cells right and below the start: the diagonal between them is closed.
	nav.add_obstacle(nav.center(1), 10)
	nav.add_obstacle(nav.center(3), 10)
	assert_eq(nav.find_path(nav.center(0), 1, nav.center(4), 0), -1)
	nav.begin(Rect2i(0, 0, 375, 375), 0)
	nav.add_obstacle(nav.center(1), 10)
	var goal: int = nav.find_path(nav.center(0), 1, nav.center(4), 0)
	assert_eq(goal, 4)
	assert_eq(nav.distance_to(goal), 250, "around the corner, not across it")


func test_the_text_board() -> void:
	var bounds := Rect2i(0, 0, 2000, 1000)
	var rocks: Array[ArenaPlane.Circle] = [ArenaPlane.Circle.make(Vector2i(375, 375), 100, "rock")]
	# The hound is smaller than a cell and off its center: it still shows.
	var units: Array[ArenaPlane.Circle] = [ArenaPlane.Circle.make(Vector2i(1125, 625), 100, "maren"), ArenaPlane.Circle.make(Vector2i(1560, 700), 10, "hound")]
	var text: String = ArenaDebug.draw(bounds, Rect2i(0, 0, 1500, 1000), rocks, units, [Vector2i(625, 875)] as Array[Vector2i], 250)
	assert_eq(text, "\n".join([
		"......~~",
		".#....~~",
		"....m.h~",
		"..!...~~",
	]), "\n" + text)
