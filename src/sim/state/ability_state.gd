class_name AbilityState
extends RefCounted
## An ability in a fight: its cooldown, which runs all the time and waits,
## full, until the ability can fire (docs/plans/rebuild-phase1-arena-sim.md,
## section 5). Progress is in basis points of a tick, so attack speed stays
## an integer.

var def: AbilityDef
var progress_bp: int = 0


static func make(ability: AbilityDef) -> AbilityState:
	var state := AbilityState.new()
	state.def = ability
	return state


func needed_bp() -> int:
	return def.cooldown_ticks * FixedMath.BP_ONE


## Runs the cooldown for one tick at `rate_bp` (10000 = normal speed). A full
## cooldown waits; it never banks a second fire.
func advance(rate_bp: int) -> void:
	progress_bp = mini(progress_bp + rate_bp, needed_bp())


func ready() -> bool:
	return progress_bp >= needed_bp()


## Fires: the cooldown starts again.
func spend() -> void:
	progress_bp = 0
