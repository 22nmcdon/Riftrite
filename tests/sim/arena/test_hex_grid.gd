extends GutTest
## The placement board (docs/plans/rebuild-phase1-arena-sim.md, section 1):
## flat-topped hexes in columns, 8 x 7, with 3-row zones.

var grid: HexGrid = HexGrid.make()


func test_coordinates_both_ways() -> void:
	assert_eq(grid.size(), 56)
	for hex: int in grid.size():
		assert_eq(grid.index(grid.col_of(hex), grid.row_of(hex)), hex)
	assert_eq([grid.col_of(13), grid.row_of(13)], [5, 1])
	assert_true(grid.has(7, 6))
	assert_false(grid.has(8, 0))
	assert_false(grid.has(0, -1))


func test_zones() -> void:
	var zones: Array[HexGrid.Zone] = []
	for row: int in grid.height:
		zones.append(grid.zone(row))
	assert_eq(zones, [HexGrid.Zone.HEROES, HexGrid.Zone.HEROES, HexGrid.Zone.HEROES, HexGrid.Zone.NEUTRAL,
		HexGrid.Zone.ENEMIES, HexGrid.Zone.ENEMIES, HexGrid.Zone.ENEMIES] as Array[HexGrid.Zone])
	var back: Array[bool] = []
	for row: int in grid.height:
		back.append(grid.is_back_row(row))
	assert_eq(back, [true, true, false, false, false, true, true] as Array[bool], "each side's back two rows")


func test_rings() -> void:
	var counts: Array[int] = [0, 0, 0, 0]
	for hex: int in grid.size():
		counts[grid.ring(grid.col_of(hex), grid.row_of(hex))] += 1
	assert_eq(counts, [26, 18, 10, 2] as Array[int], "the rings of an 8 x 7 board")
	assert_eq(grid.last_ring(), 3)
	assert_eq(grid.ring(3, 3), 3)
	assert_eq(grid.ring(4, 3), 3)
	assert_eq(grid.ring(0, 3), 0)


func test_centers_are_a_hex_apart() -> void:
	assert_eq(grid.center(0, 0), Vector2i(500, 500))
	assert_eq(grid.center(1, 0), Vector2i(1366, 1000), "odd columns sit half a hex toward the enemy")
	assert_eq(grid.center(7, 6), Vector2i(6562, 7000))
	for hex: int in grid.size():
		var col: int = grid.col_of(hex)
		var row: int = grid.row_of(hex)
		var here: Vector2i = grid.center(col, row)
		var around: Array[Vector2i] = grid.neighbors(col, row)
		assert_between(around.size(), 2, 6)
		for next: Vector2i in around:
			assert_between(ArenaPlane.distance(here, grid.center(next.x, next.y)), 999, 1000, "neighbors of (%d, %d)" % [col, row])
		for other: int in grid.size():
			if other != hex and not around.has(Vector2i(grid.col_of(other), grid.row_of(other))):
				assert_gt(ArenaPlane.distance(here, grid.center(grid.col_of(other), grid.row_of(other))), 1000, "only neighbors are a hex apart")


func test_bounds_and_the_safe_rectangle() -> void:
	assert_eq(grid.bounds(), Rect2i(0, 0, 7062, 7500))
	for hex: int in grid.size():
		assert_true(ArenaPlane.inside(grid.bounds(), grid.center(grid.col_of(hex), grid.row_of(hex)), 500), "every hex fits inside")
	assert_eq(grid.safe_rect(0), grid.bounds())
	assert_eq(grid.safe_rect(1), Rect2i(866, 1250, 5330, 5000))
	assert_eq(grid.safe_rect(3), Rect2i(2598, 3250, 1866, 1000))
	assert_eq(grid.safe_rect(9), grid.safe_rect(3), "the last ring never crumbles")
	for hex: int in grid.size():
		var col: int = grid.col_of(hex)
		var row: int = grid.row_of(hex)
		for crumbled: int in range(1, 4):
			assert_eq(grid.safe_rect(crumbled).has_point(grid.center(col, row)), grid.ring(col, row) >= crumbled,
				"(%d, %d) with %d rings crumbled" % [col, row, crumbled])


func test_nearest_hex() -> void:
	assert_eq(grid.nearest_hex(grid.center(5, 2)), grid.index(5, 2))
	assert_eq(grid.nearest_hex(grid.center(5, 2) + Vector2i(100, 200)), grid.index(5, 2))
	assert_eq(grid.nearest_hex(Vector2i(-400, -400)), grid.index(0, 0))
