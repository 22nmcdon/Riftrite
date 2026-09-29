class_name AbilityState
extends RefCounted
## An ability in a fight (docs/plans/rebuild-phase1-arena-sim.md, section 5).
## A basic attack has a cooldown, which runs all the time and waits, full,
## until it can fire; progress is in basis points of a tick, so attack speed
## stays an integer. A signature has its trigger's state instead (Signatures).

var def: AbilityDef
## What the log credits for it ("unit · ability"), made once.
var source: EffectSource
var progress_bp: int = 0
## The cooldown in basis points of a tick (progress it needs), with auras.
var needed: int = FixedMath.BP_ONE
## From auras (AuraDef cooldown_bp): -1500 makes the cooldown 15% shorter.
var cooldown_add_bp: int = 0
## The signature's trigger is mana, or fires once a fight (read each tick,
## so worked out once).
var mana_trigger: bool = false
var once_trigger: bool = false

# Signatures.
## A once-a-fight trigger has fired (or, for would_fall, saved the unit).
var fired: bool = false
## How many times it has fired (an on_fire effect's "every", phase 4).
var fires: int = 0
## count: events seen so far.
var count: int = 0
## Its last try to fire failed (a leap with no room), and that's logged.
var failing: bool = false
## Fires waiting for the unit's next update (count, and once-a-fight triggers
## waiting for a target).
var pending: int = 0
## Why the waiting fires were queued, if an extra trigger did (the FIRE
## entry's note).
var pending_note: String = ""
## Extra triggers (AbilityDef.also): which hp_below ones have fired, and
## whether one hasn't yet (so the unit's update looks each tick).
var also_fired: Array[bool] = []
var also_waiting: bool = false
## ally_fires: the target the ally's fire had (the queued fire goes there,
## if it still stands).
var pending_target: UnitState:
	get:
		return _pending_target.get_ref() as UnitState if _pending_target != null else null
	set(value):
		_pending_target = weakref(value) if value != null else null
var _pending_target: WeakRef = null
## A sigil's echo (AbilityDef.echo): its own state, and the tick it fires on
## (-1: none waiting).
var echo: AbilityState = null
var echo_at: int = -1
## A cast under way ends on this tick (-1: not casting), aimed at cast_target.
var cast_ends_at: int = -1
var cast_target: UnitState:
	get:
		return _cast_target.get_ref() as UnitState if _cast_target != null else null
	set(value):
		_cast_target = weakref(value) if value != null else null
var _cast_target: WeakRef = null


static func make(ability: AbilityDef, unit_id: String) -> AbilityState:
	var state := AbilityState.new()
	state.def = ability
	state.source = EffectSource.make(unit_id, ability.id, ability.name)
	state.set_cooldown_add(0)
	if ability.trigger != null:
		state.mana_trigger = ability.trigger.kind == TriggerDef.Kind.MANA
		state.once_trigger = ability.trigger.kind == TriggerDef.Kind.HP_BELOW or ability.trigger.kind == TriggerDef.Kind.FIGHT_START or ability.trigger.kind == TriggerDef.Kind.AT_TIME
	for trigger: TriggerDef in ability.also:
		state.also_fired.append(false)
		state.also_waiting = state.also_waiting or trigger.kind == TriggerDef.Kind.HP_BELOW
	if ability.echo != null:
		state.echo = AbilityState.make(ability.echo, unit_id)
	return state


## Auras changed its cooldown by `bp` (-1500: 15% shorter). Never under a tick.
func set_cooldown_add(bp: int) -> void:
	cooldown_add_bp = bp
	needed = maxi(def.cooldown_ticks * (FixedMath.BP_ONE + bp), FixedMath.BP_ONE)


func needed_bp() -> int:
	return needed


## Runs the cooldown for one tick at `rate_bp` (10000 = normal speed). A full
## cooldown waits; it never banks a second fire.
func advance(rate_bp: int) -> void:
	progress_bp = mini(progress_bp + rate_bp, needed)


func ready() -> bool:
	return progress_bp >= needed


## Fires: the cooldown starts again.
func spend() -> void:
	progress_bp = 0


func casting() -> bool:
	return cast_ends_at >= 0
