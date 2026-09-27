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


func test_a_walker_on_crumbled_ground_can_leave() -> void:
	var nav: NavGrid = _nav([], [], grid.safe_rect(1))
	var start: Vector2i = _hex(0, 3)
	assert_false(nav.is_free(nav.cell_at(start)), "it stands on crumbled ground")
	var goal: int = nav.find_path(start, 1, _hex(3, 3), MELEE)
	assert_ne(goal, -1, "the start cell is always free")
	for at: int in nav.path_to(goal):
		assert_true(nav.is_free(at), "every step after the first is on safe ground")


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
