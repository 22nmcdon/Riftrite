extends GutTest
## Integer geometry on the arena's plane (docs/plans/rebuild-phase1-arena-sim.md,
## sections 1, 6, and 7). 1 hex = 1000 units.

const P = preload("res://src/sim/arena/arena_plane.gd")


func test_distances_and_directions() -> void:
	assert_eq(P.distance(Vector2i(0, 0), Vector2i(3000, 4000)), 5000)
	assert_true(P.within(Vector2i(0, 0), Vector2i(600, 800), 1000), "exactly at reach counts")
	assert_false(P.within(Vector2i(0, 0), Vector2i(600, 801), 1000))
	assert_eq(P.direction(Vector2i(0, 0), Vector2i(0, 5000)), Vector2i(0, 1000))
	assert_eq(P.direction(Vector2i(100, 100), Vector2i(3100, 4100)), Vector2i(600, 800))
	assert_eq(P.direction(Vector2i(5, 5), Vector2i(5, 5), Vector2i(0, -1000)), Vector2i(0, -1000), "the same point: the fallback")
	for target: Vector2i in [Vector2i(1, 0), Vector2i(-7000, 3), Vector2i(2345, -6789)]:
		assert_between(P.length(P.direction(Vector2i.ZERO, target)), 999, 1001, "a direction is 1000 long")


func test_moving() -> void:
	assert_eq(P.step_toward(Vector2i(0, 0), Vector2i(3000, 4000), 500), Vector2i(300, 400))
	assert_eq(P.step_toward(Vector2i(0, 0), Vector2i(30, 40), 500), Vector2i(30, 40), "never past the goal")
	assert_eq(P.along(Vector2i(100, 100), Vector2i(0, -1000), 250), Vector2i(100, -150))


func test_overlap_and_inside() -> void:
	assert_true(P.overlaps(Vector2i(0, 0), 400, Vector2i(799, 0), 400))
	assert_false(P.overlaps(Vector2i(0, 0), 400, Vector2i(800, 0), 400), "touching isn't overlapping")
	var rect := Rect2i(0, 0, 1000, 1000)
	assert_true(P.inside(rect, Vector2i(400, 400), 400))
	assert_false(P.inside(rect, Vector2i(399, 500), 400))
	assert_false(P.inside(rect, Vector2i(500, 601), 400))


func test_circle_and_ring() -> void:
	var c := Vector2i(3000, 3000)
	assert_true(P.in_circle(c, 2000, c + Vector2i(1200, 1600)))
	assert_false(P.in_circle(c, 2000, c + Vector2i(1200, 1601)))
	assert_false(P.in_ring(c, 2000, c + Vector2i(1500, 0)), "the inner edge is out")
	assert_true(P.in_ring(c, 2000, c + Vector2i(1501, 0)))
	assert_true(P.in_ring(c, 2000, c + Vector2i(0, 2500)), "the outer edge is in")
	assert_false(P.in_ring(c, 2000, c + Vector2i(0, 2501)))
	assert_true(P.in_ring(c, 0, c + Vector2i(0, 300)), "a ring of radius 0 is a small circle")


func test_line() -> void:
	var origin := Vector2i(1000, 1000)
	var down := Vector2i(0, 1000)
	assert_true(P.in_line(origin, down, 3000, origin))
	assert_true(P.in_line(origin, down, 3000, origin + Vector2i(500, 3000)), "the far corner")
	assert_false(P.in_line(origin, down, 3000, origin + Vector2i(501, 1500)), "wider than a hex")
	assert_false(P.in_line(origin, down, 3000, origin + Vector2i(0, 3001)), "past its end")
	assert_false(P.in_line(origin, down, 3000, origin + Vector2i(0, -1)), "behind the caster")
	var slanted: Vector2i = P.direction(Vector2i.ZERO, Vector2i(3, 4))
	assert_true(P.in_line(Vector2i.ZERO, slanted, 5000, Vector2i(3000, 4000)), "no snapping: it runs exactly at the target")


func test_cone_widens_one_two_three() -> void:
	var down := Vector2i(0, 1000)
	var o := Vector2i(0, 0)
	# Half-widths: 500 at the caster, 1000 a hex out, 1500 at the end.
	assert_true(P.in_cone(o, down, 3000, Vector2i(500, 0)))
	assert_false(P.in_cone(o, down, 3000, Vector2i(501, 0)))
	assert_true(P.in_cone(o, down, 3000, Vector2i(1000, 1500)))
	assert_false(P.in_cone(o, down, 3000, Vector2i(1001, 1500)))
	assert_true(P.in_cone(o, down, 3000, Vector2i(-1500, 3000)))
	assert_false(P.in_cone(o, down, 3000, Vector2i(-1501, 3000)))
	assert_false(P.in_cone(o, down, 3000, Vector2i(0, 3001)), "3 hexes deep")
	assert_false(P.in_cone(o, down, 3000, Vector2i(0, -10)), "not behind")


func test_sweeps_stop_at_circles_and_edges() -> void:
	var bounds := Rect2i(0, 0, 10000, 10000)
	var rock: ArenaPlane.Circle = ArenaPlane.Circle.make(Vector2i(5000, 2000), 500, "rock")
	var unit: ArenaPlane.Circle = ArenaPlane.Circle.make(Vector2i(2000, 5000), 400, "unit")
	var clear: ArenaPlane.Sweep = P.sweep(Vector2i(1000, 1000), Vector2i(1000, 3000), 400, [rock, unit], bounds)
	assert_eq([clear.point, clear.hit, clear.circle], [Vector2i(1000, 3000), ArenaPlane.Hit.NONE, -1])
	var to_rock: ArenaPlane.Sweep = P.sweep(Vector2i(1000, 2000), Vector2i(9000, 2000), 400, [unit, rock], bounds)
	assert_eq([to_rock.hit, to_rock.circle], [ArenaPlane.Hit.CIRCLE, 1])
	assert_between(to_rock.point.x, 4050, 4100, "stops at the last clear step before the rock")
	assert_false(P.overlaps(to_rock.point, 400, rock.center, rock.radius))
	var to_edge: ArenaPlane.Sweep = P.sweep(Vector2i(5000, 8000), Vector2i(5000, 12000), 400, [] as Array[ArenaPlane.Circle], bounds)
	assert_eq(to_edge.hit, ArenaPlane.Hit.EDGE)
	assert_between(to_edge.point.y, 9550, 9600)
	assert_true(P.inside(bounds, to_edge.point, 400))
	var nowhere: ArenaPlane.Sweep = P.sweep(Vector2i(5, 5), Vector2i(5, 5), 400, [rock], bounds)
	assert_eq([nowhere.point, nowhere.hit], [Vector2i(5, 5), ArenaPlane.Hit.NONE])
