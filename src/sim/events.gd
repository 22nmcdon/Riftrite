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
##   on_hop           it hops away (hop_away)
## Phase 5c step 3 (docs/plans/rebuild-phase5c-combos.md, section 8.4):
##   on_holder_hit    one of its hits lands on an enemy
##   on_shield_broken a hit or damage over time takes the last of its Shield
##   on_ally_ability  an ally's signature fires
## After every unit has acted, CombatSim hands over the entries logged since
## the last read, in log order (so what happens in the deaths step is read
## on the next tick); kills are raised as deaths are settled. Relic effects
## raise nothing.
## Chains (section 8.5): what a passive's effect does can raise more events.
## Each entry carries its depth (LogEntry.chain: one more than the entry that
## set the effect off), and dispatch keeps reading while the log grows, so a
## chain resolves in the tick it starts; an entry at the fight's chain_limit
## raises nothing. A kill carries the chain of the hit that felled the unit.
## Count signatures (Signatures.on_event) and ability passives
## (Passives.on_event) listen, and so do ally_fires signatures (a FIRE of
## their ally's ability; Signatures.ally_fired).


## The log kinds that raise events (the rest are skipped at once).
const _RAISES: Array[LogEntry.Kind] = [LogEntry.Kind.FIRE, LogEntry.Kind.DAMAGE, LogEntry.Kind.SHIELD, LogEntry.Kind.HEAL,
	LogEntry.Kind.STATUS_APPLIED, LogEntry.Kind.HOP, LogEntry.Kind.STATUS_DAMAGE]


## Raises the events in the log from entry `from` on, including those the
## events themselves add (a chain), and returns where it stopped. `to` is
## where the log ended when the units had acted.
static func dispatch(sim: CombatSim, from: int, to: int) -> int:
	var i: int = from
	var limit: int = sim.tuning.chain_limit
	while i < maxi(to, sim.combat_log.entries.size()):
		var entry: LogEntry = sim.combat_log.entries[i]
		i += 1
		if not _RAISES.has(entry.kind) or entry.source_relic_side >= 0 or entry.chain >= limit or entry.source_unit.is_empty():
			continue
		var source: UnitState = sim.unit_by_id(entry.source_unit)
		var target: UnitState = sim.unit_by_id(entry.target) if not entry.target.is_empty() else null
		var chain: int = entry.chain
		match entry.kind:
			LogEntry.Kind.FIRE:
				var basic: bool = entry.source_ability == source.def.basic_attack.id
				_raise(sim, source, EffectDef.Trigger.ON_BASIC_ATTACK if basic else EffectDef.Trigger.ON_ABILITY, chain)
				if not basic and sim.ally_ability_listeners:
					for ally: UnitState in (sim.heroes if source.side == EffectSource.Team.HEROES else sim.enemies):
						if ally != source:
							_raise(sim, ally, EffectDef.Trigger.ON_ALLY_ABILITY, chain, source)
				if sim.ally_fire_listeners:
					Signatures.ally_fired(sim, source, entry.source_ability, target)
			LogEntry.Kind.DAMAGE:
				if target == null:
					continue
				if entry.crit:
					_raise(sim, source, EffectDef.Trigger.ON_HOLDER_CRIT, chain, target, entry.amount)
				if source.side != target.side:
					_raise(sim, source, EffectDef.Trigger.ON_HOLDER_HIT, chain, target, entry.amount)
					_raise(sim, target, EffectDef.Trigger.ON_HIT_TAKEN, chain, source, entry.amount)
				if entry.broke_shield:
					_raise(sim, target, EffectDef.Trigger.ON_SHIELD_BROKEN, chain, source, entry.absorbed)
			LogEntry.Kind.STATUS_DAMAGE:
				if target != null and entry.broke_shield:
					_raise(sim, target, EffectDef.Trigger.ON_SHIELD_BROKEN, chain, source, entry.absorbed)
			LogEntry.Kind.SHIELD:
				if target != null and entry.amount > 0:
					_raise(sim, target, EffectDef.Trigger.ON_SHIELDED, chain, target)
			LogEntry.Kind.HEAL:
				if target != null and entry.amount > 0:
					_raise(sim, source, EffectDef.Trigger.ON_HEAL, chain, target)
			LogEntry.Kind.STATUS_APPLIED:
				# Engaged comes from the Engage trait, not an effect.
				if target != null and entry.status != sim.content.engaged_status.id:
					_raise(sim, source, EffectDef.Trigger.ON_STATUS, chain, target, 0, entry.status)
			LogEntry.Kind.HOP:
				_raise(sim, source, EffectDef.Trigger.ON_HOP, chain)
	return i


## on_kill for a unit that just fell, credited to whoever hit it last (an
## enemy of it that still stands), naming the fallen (Decision 13).
static func kill(sim: CombatSim, fallen: UnitState) -> void:
	if fallen.last_attacker.is_empty() or fallen.last_hit_chain >= sim.tuning.chain_limit:
		return
	var killer: UnitState = sim.unit_by_id(fallen.last_attacker)
	if killer != null and killer.alive and killer.side != fallen.side:
		_raise(sim, killer, EffectDef.Trigger.ON_KILL, fallen.last_hit_chain, fallen)


## `chain`: the depth of the entry that raised it; `other`: the unit the
## event names; `damage`: the hit (or Shield) it's about; `status`: the
## status applied (on_status).
static func _raise(sim: CombatSim, unit: UnitState, event: EffectDef.Trigger, chain: int, other: UnitState = null, damage: int = 0, status: String = "") -> void:
	if unit == null or not unit.alive:
		return
	if unit.signature != null:
		Signatures.on_event(unit, event)
	if not unit.listeners.is_empty():
		Passives.on_event(sim, unit, event, other, damage, status, chain)
