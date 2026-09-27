class_name AbilityState
extends RefCounted
## An ability in a fight (docs/plans/rebuild-phase1-arena-sim.md, section 5).
## A basic attack has a cooldown, which runs all the time and waits, full,
## until it can fire; progress is in basis points of a tick, so attack speed
## stays an integer. A signature has its trigger's state instead (Signatures).

var def: AbilityDef
var progress_bp: int = 0
## From auras (AuraDef cooldown_bp): -1500 makes the cooldown 15% shorter.
var cooldown_add_bp: int = 0

# Signatures.
## A once-a-fight trigger has fired (or, for would_fall, saved the unit).
var fired: bool = false
## count: events seen so far.
var count: int = 0
## Fires waiting for the unit's turn (count, and once-a-fight triggers
## waiting for a target).
var pending: int = 0
## A cast under way ends on this tick (-1: not casting), aimed at cast_target.
var cast_ends_at: int = -1
var cast_target: UnitState:
	get:
		return _cast_target.get_ref() as UnitState if _cast_target != null else null
	set(value):
		_cast_target = weakref(value) if value != null else null
var _cast_target: WeakRef = null


static func make(ability: AbilityDef) -> AbilityState:
	var state := AbilityState.new()
	state.def = ability
	return state


func needed_bp() -> int:
	return maxi(def.cooldown_ticks * (FixedMath.BP_ONE + cooldown_add_bp), FixedMath.BP_ONE)


## Runs the cooldown for one tick at `rate_bp` (10000 = normal speed). A full
## cooldown waits; it never banks a second fire.
func advance(rate_bp: int) -> void:
	progress_bp = mini(progress_bp + rate_bp, needed_bp())


func ready() -> bool:
	return progress_bp >= needed_bp()


## Fires: the cooldown starts again.
func spend() -> void:
	progress_bp = 0


func casting() -> bool:
	return cast_ends_at >= 0
