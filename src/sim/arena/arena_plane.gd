class_name ArenaPlane
extends RefCounted
## Integer geometry on the arena's plane (docs/plans/phases/rebuild-phase1-arena-sim.md,
## sections 1, 6, and 7). Points are Vector2i in plane units (1 hex = 1000).
## No floats: distances use FixedMath.isqrt and are compared squared where
## possible, and a direction is a vector scaled to length DIR (1000).

## A direction's length.
const DIR: int = 1000
## How far a sweep moves between checks.
const SWEEP_STEP: int = 50

enum Hit { NONE, CIRCLE, EDGE }


## A round obstacle: a unit or a rock. `tag` is the caller's id for it.
class Circle:
	var center: Vector2i
	var radius: int
	var tag: String

	static func make(at: Vector2i, r: int, circle_tag: String = "") -> Circle:
		var circle := Circle.new()
		circle.center = at
		circle.radius = r
		circle.tag = circle_tag
		return circle


## Where a sweep stopped, and what stopped it.
class Sweep:
	var point: Vector2i
	var hit: Hit = Hit.NONE
	## The circle it hit (Hit.CIRCLE), else -1.
	var circle: int = -1


static func length_sq(v: Vector2i) -> int:
	return v.x * v.x + v.y * v.y


static func length(v: Vector2i) -> int:
	return FixedMath.isqrt(length_sq(v))


static func distance(a: Vector2i, b: Vector2i) -> int:
	return length(b - a)


static func within(a: Vector2i, b: Vector2i, reach: int) -> bool:
	return length_sq(b - a) <= reach * reach


static func dot(a: Vector2i, b: Vector2i) -> int:
	return a.x * b.x + a.y * b.y


## The 2D cross product; its sign says which side of `a` the vector `b` is on.
static func cross(a: Vector2i, b: Vector2i) -> int:
	return a.x * b.y - a.y * b.x


## The direction from `from` to `to`, scaled to length DIR. `fallback` when
## the two points are the same.
static func direction(from: Vector2i, to: Vector2i, fallback: Vector2i = Vector2i(0, DIR)) -> Vector2i:
	var d: Vector2i = to - from
	var size: int = length(d)
	if size == 0:
		return fallback
	return Vector2i(FixedMath.mul_div(d.x, DIR, size), FixedMath.mul_div(d.y, DIR, size))


## The point `amount` along the way from `from` to `to`, or `to` itself if
## it's that close.
static func step_toward(from: Vector2i, to: Vector2i, amount: int) -> Vector2i:
	var d: Vector2i = to - from
	var size: int = length(d)
	if size <= amount:
		return to
	return from + Vector2i(FixedMath.mul_div(d.x, amount, size), FixedMath.mul_div(d.y, amount, size))


## `from` moved `amount` along a direction (length DIR).
static func along(from: Vector2i, dir: Vector2i, amount: int) -> Vector2i:
	return from + Vector2i(FixedMath.mul_div(dir.x, amount, DIR), FixedMath.mul_div(dir.y, amount, DIR))


## True if two circles overlap (touching doesn't count).
static func overlaps(a: Vector2i, a_radius: int, b: Vector2i, b_radius: int) -> bool:
	var reach: int = a_radius + b_radius
	return length_sq(b - a) < reach * reach


## True if a circle at `point` sits wholly inside `rect`.
static func inside(rect: Rect2i, point: Vector2i, radius: int) -> bool:
	return point.x - radius >= rect.position.x and point.y - radius >= rect.position.y \
		and point.x + radius <= rect.end.x and point.y + radius <= rect.end.y


# --- shapes (section 7): a point is inside if it's within the shape ---------

static func in_circle(center: Vector2i, radius: int, point: Vector2i) -> bool:
	return within(center, point, radius)


## Between radius - HALF and radius + HALF, a ring one hex wide.
static func in_ring(center: Vector2i, radius: int, point: Vector2i) -> bool:
	var d: int = length_sq(point - center)
	var inner: int = maxi(radius - HexGrid.HALF_HEX, 0)
	var outer: int = radius + HexGrid.HALF_HEX
	return d > inner * inner and d <= outer * outer


## A line `length` long and one hex wide, starting at `origin` and running
## along `dir` (length DIR).
static func in_line(origin: Vector2i, dir: Vector2i, line_length: int, point: Vector2i, half_width: int = HexGrid.HALF_HEX) -> bool:
	var v: Vector2i = point - origin
	# Both are in plane units x DIR, so no division is needed.
	var along_scaled: int = dot(v, dir)
	var across_scaled: int = absi(cross(dir, v))
	return along_scaled >= 0 and along_scaled <= line_length * DIR and across_scaled <= half_width * DIR


## A cone `depth` long from `origin` along `dir`, widening evenly from
## `near_width` at the origin to `far_width` at its end (1, then 2, then 3
## hexes for the default 3-hex cone: decided).
static func in_cone(origin: Vector2i, dir: Vector2i, depth: int, point: Vector2i, near_width: int = HexGrid.HEX, far_width: int = 3 * HexGrid.HEX) -> bool:
	var v: Vector2i = point - origin
	var along_scaled: int = dot(v, dir)
	if along_scaled < 0 or along_scaled > depth * DIR or depth <= 0:
		return false
	var across_scaled: int = absi(cross(dir, v))
	# across <= near/2 + (far - near)/2 x along/depth, multiplied through by
	# 2 x depth (and DIR, which both sides already carry).
	return across_scaled * 2 * depth <= near_width * depth * DIR + (far_width - near_width) * along_scaled


# --- sweeps (section 6) ----------------------------------------------------------

## Moves a circle of `radius` from `from` toward `to` in steps of
## SWEEP_STEP, stopping at the last point where it overlaps none of
## `circles` and stays inside `bounds`. Reports what stopped it.
static func sweep(from: Vector2i, to: Vector2i, radius: int, circles: Array[Circle], bounds: Rect2i) -> Sweep:
	var result := Sweep.new()
	result.point = from
	var d: Vector2i = to - from
	var size: int = length(d)
	if size == 0:
		return result
	@warning_ignore("integer_division")
	var steps: int = (size + SWEEP_STEP - 1) / SWEEP_STEP
	# It runs on every route planned, so FixedMath.mul_div's rounding, inside,
	# and overlaps are inlined.
	var twice_steps: int = 2 * steps
	var min_x: int = bounds.position.x + radius
	var min_y: int = bounds.position.y + radius
	var max_x: int = bounds.end.x - radius
	var max_y: int = bounds.end.y - radius
	var count: int = circles.size()
	for i: int in range(1, steps + 1):
		var x: int = d.x * i
		var y: int = d.y * i
		@warning_ignore("integer_division")
		x = (2 * x + steps) / twice_steps if x >= 0 else -((2 * -x + steps) / twice_steps)
		@warning_ignore("integer_division")
		y = (2 * y + steps) / twice_steps if y >= 0 else -((2 * -y + steps) / twice_steps)
		var point: Vector2i = from + Vector2i(x, y)
		if point.x < min_x or point.y < min_y or point.x > max_x or point.y > max_y:
			result.hit = Hit.EDGE
			return result
		for c: int in count:
			var circle: Circle = circles[c]
			var dx: int = circle.center.x - point.x
			var dy: int = circle.center.y - point.y
			var reach: int = radius + circle.radius
			if dx * dx + dy * dy < reach * reach:
				result.hit = Hit.CIRCLE
				result.circle = c
				return result
		result.point = point
	return result
