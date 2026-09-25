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


## True if a duration in milliseconds lands exactly on a tick boundary.
static func is_whole_ticks(ms: int) -> bool:
	return ms % MS_PER_TICK == 0


## Converts milliseconds to ticks. Data durations must be whole ticks
## (the content loader rejects anything else), so this never rounds.
static func ms_to_ticks(ms: int) -> int:
	@warning_ignore("integer_division")
	return ms / MS_PER_TICK
