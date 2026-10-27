class_name FixedMath
extends RefCounted
## Integer math helpers shared by the whole sim. See CLAUDE.md rule 1:
## no floats in src/sim, percentages are basis points, time is ticks.

## 10000 basis points = 100%.
const BP_ONE: int = 10000
const TICKS_PER_SECOND: int = 20
const MS_PER_TICK: int = 1000 / TICKS_PER_SECOND


## Returns value * bp / 10000, rounded to the nearest integer with halves
## rounded away from zero (so 30% of 5 is 2 and 30% of -5 is -2).
## This is the one rounding rule for the sim; use it for every percentage.
static func apply_bp(value: int, bp: int) -> int:
	var product: int = value * bp
	var half: int = BP_ONE / 2
	if product >= 0:
		@warning_ignore("integer_division")
		return (product + half) / BP_ONE
	@warning_ignore("integer_division")
	return -((-product + half) / BP_ONE)


## Returns value * numerator / denominator, rounded to the nearest integer
## (halves away from zero). For ratios that aren't basis points, like defense.
static func mul_div(value: int, numerator: int, denominator: int) -> int:
	assert(denominator > 0, "FixedMath.mul_div: denominator must be positive")
	var product: int = value * numerator
	if product >= 0:
		@warning_ignore("integer_division")
		return (2 * product + denominator) / (2 * denominator)
	@warning_ignore("integer_division")
	return -((2 * -product + denominator) / (2 * denominator))


## True if a duration in milliseconds lands exactly on a tick boundary.
static func is_whole_ticks(ms: int) -> bool:
	return ms % MS_PER_TICK == 0


## Converts milliseconds to ticks. Data durations must be whole ticks
## (the content loader rejects anything else), so this never rounds.
static func ms_to_ticks(ms: int) -> int:
	@warning_ignore("integer_division")
	return ms / MS_PER_TICK


## The integer square root: the largest r with r * r <= n (n must be >= 0).
## The arena uses it for distances and directions on the plane.
static func isqrt(n: int) -> int:
	assert(n >= 0, "FixedMath.isqrt: n must not be negative")
	if n < 2:
		return n
	# Newton's method from a power of two at least as big as the root (so it
	# steps down in a few iterations), stopping once it stops shrinking.
	var x: int = 1
	var rest: int = n
	while rest > 0:
		rest >>= 2
		x <<= 1
	@warning_ignore("integer_division")
	var y: int = (x + n / x) / 2
	while y < x:
		x = y
		@warning_ignore("integer_division")
		y = (x + n / x) / 2
	return x
