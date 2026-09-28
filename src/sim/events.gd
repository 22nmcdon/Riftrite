class_name Events
extends RefCounted
## A unit's events, read from the combat log (docs/plans/rebuild-phase1-arena-sim.md,
## section 3, step 6; the trigger names are EffectDef's event triggers):
##   on_basic_attack  its basic attack fires
##   on_ability       its signature fires (for passives)
##   on_holder_crit   one of its hits crits
##   on_shielded      it gains Shield
##   on_hit_taken     an enemy's hit lands on it
##   on_heal          it restores HP to a unit
##   on_status        it applies a status
##   on_kill          an enemy it hit last falls
## After every unit has acted, CombatSim hands over the entries logged since
## the last read, in log order (so what happens in the deaths step is read
## on the next tick); kills are raised as deaths are settled. Relic effects
## and entries made by event effects (LogEntry.from_event) raise nothing, so
## event effects never set each other off.
## Count signatures (Signatures.on_event) and ability passives
## (Passives.on_event) listen.


## The log kinds that raise events (the rest are skipped at once).
const _RAISES: Array[LogEntry.Kind] = [LogEntry.Kind.FIRE, LogEntry.Kind.DAMAGE, LogEntry.Kind.SHIELD, LogEntry.Kind.HEAL, LogEntry.Kind.STATUS_APPLIED]


## Raises the events in log entries [from, to).
static func dispatch(sim: CombatSim, from: int, to: int) -> void:
	for i: int in range(from, to):
		var entry: LogEntry = sim.combat_log.entries[i]
		if not _RAISES.has(entry.kind) or entry.source_relic_side >= 0 or entry.from_event or entry.source_unit.is_empty():
			continue
		var source: UnitState = sim.unit_by_id(entry.source_unit)
		var target: UnitState = sim.unit_by_id(entry.target) if not entry.target.is_empty() else null
		match entry.kind:
			LogEntry.Kind.FIRE:
				var basic: bool = entry.source_ability == source.def.basic_attack.id
				_raise(sim, source, EffectDef.Trigger.ON_BASIC_ATTACK if basic else EffectDef.Trigger.ON_ABILITY)
			LogEntry.Kind.DAMAGE:
				if target == null:
					continue
				if entry.crit:
					_raise(sim, source, EffectDef.Trigger.ON_HOLDER_CRIT, target, entry.amount)
				if source.side != target.side:
					_raise(sim, target, EffectDef.Trigger.ON_HIT_TAKEN, source, entry.amount)
			LogEntry.Kind.SHIELD:
				if target != null and entry.amount > 0:
					_raise(sim, target, EffectDef.Trigger.ON_SHIELDED, target)
			LogEntry.Kind.HEAL:
				if target != null and entry.amount > 0:
					_raise(sim, source, EffectDef.Trigger.ON_HEAL, target)
			LogEntry.Kind.STATUS_APPLIED:
				if target != null:
					_raise(sim, source, EffectDef.Trigger.ON_STATUS, target, 0, entry.status)


## on_kill for a unit that just fell, credited to whoever hit it last (an
## enemy of it that still stands).
static func kill(sim: CombatSim, fallen: UnitState) -> void:
	if fallen.last_attacker.is_empty():
		return
	var killer: UnitState = sim.unit_by_id(fallen.last_attacker)
	if killer != null and killer.alive and killer.side != fallen.side:
		_raise(sim, killer, EffectDef.Trigger.ON_KILL)


## `other`: the unit the event names; `damage`: the hit it's about;
## `status`: the status applied (on_status).
static func _raise(sim: CombatSim, unit: UnitState, event: EffectDef.Trigger, other: UnitState = null, damage: int = 0, status: String = "") -> void:
	if unit == null or not unit.alive:
		return
	if unit.signature != null:
		Signatures.on_event(unit, event)
	if not unit.listeners.is_empty():
		Passives.on_event(sim, unit, event, other, damage, status)
