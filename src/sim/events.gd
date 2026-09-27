class_name Events
extends RefCounted
## Runs event-trigger effects (see EffectDef: on_ability, on_basic_attack,
## on_holder_crit, on_shielded, on_hit_taken, on_heal, on_status, on_kill;
## docs/plans/keywords-and-affinities.md). CombatSim reads the log entries
## made since the last read once everything has fired, in log order; kills
## are read when deaths are processed. What an event effect does is marked
## (LogEntry.from_event) and never read, so event effects never set each
## other off.


## Runs the event effects for log entries [from, to).
static func dispatch(sim: CombatSim, from: int, to: int) -> void:
	for i: int in range(from, to):
		var entry: LogEntry = sim.combat_log.entries[i]
		if entry.source_relic_side >= 0 or entry.from_event:
			continue
		var source: UnitState = sim.unit_by_id(entry.source_unit) if not entry.source_unit.is_empty() else null
		var target: UnitState = sim.unit_by_id(entry.target) if not entry.target.is_empty() else null
		match entry.kind:
			LogEntry.Kind.FIRE:
				if source == null:
					continue
				var fired: ItemState = _fired_item(source, entry.source_item)
				if fired == null:
					continue
				if fired.is_auto_attack:
					_raise(sim, source, EffectDef.Trigger.ON_BASIC_ATTACK, null, 0, fired)
				elif fired.def.slot == ItemDef.Slot.ABILITY or fired.def.is_ability:
					_raise(sim, source, EffectDef.Trigger.ON_ABILITY, null, 0, fired)
			LogEntry.Kind.DAMAGE:
				if source == null or target == null:
					continue
				if entry.crit:
					_raise(sim, source, EffectDef.Trigger.ON_HOLDER_CRIT, target, entry.amount)
				if source.side != target.side:
					_raise(sim, target, EffectDef.Trigger.ON_HIT_TAKEN, source, entry.amount)
			LogEntry.Kind.SHIELD:
				if target != null and entry.amount > 0:
					_raise(sim, target, EffectDef.Trigger.ON_SHIELDED, target, 0)
			LogEntry.Kind.HEAL:
				if source != null and target != null and entry.amount > 0:
					_raise(sim, source, EffectDef.Trigger.ON_HEAL, target, 0)
			LogEntry.Kind.STATUS_APPLIED:
				if source != null and target != null:
					_raise(sim, source, EffectDef.Trigger.ON_STATUS, target, 0, null, entry.status)


## on_kill for each unit that just fell, credited to whoever hit it last
## (an enemy of it that's still alive).
static func kills(sim: CombatSim, fallen: Array[UnitState]) -> void:
	for unit: UnitState in fallen:
		if unit.last_attacker.is_empty():
			continue
		var killer: UnitState = sim.unit_by_id(unit.last_attacker)
		if killer != null and killer.alive and killer.side != unit.side:
			_raise(sim, killer, EffectDef.Trigger.ON_KILL, null, 0)


## The holder's item that fired (by id; the first match), or null.
static func _fired_item(holder: UnitState, item_id: String) -> ItemState:
	for item: ItemState in holder.items:
		if item.def.id == item_id:
			return item
	return null


## Runs `holder`'s effects with `trigger` (the holder must be alive). `unit`
## and `damage` are what hit_target and amount_bp_of_damage refer to;
## `fired` (on_ability, on_basic_attack) is the item that fired, whose own
## effects don't answer it; `status` is the status applied (on_status).
static func _raise(sim: CombatSim, holder: UnitState, trigger: EffectDef.Trigger, unit: UnitState, damage: int, fired: ItemState = null, status: String = "") -> void:
	if not holder.alive:
		return
	for item: ItemState in holder.items:
		if item == fired:
			continue
		for e: int in item.effects.size():
			var sourced: SourcedEffect = item.effects[e]
			var effect: EffectDef = sourced.effect
			if effect.trigger != trigger:
				continue
			if trigger == EffectDef.Trigger.ON_ABILITY and not effect.keyword.is_empty() and not fired.def.keywords.has(effect.keyword):
				continue
			if trigger == EffectDef.Trigger.ON_STATUS and not effect.statuses.is_empty() and not effect.statuses.has(status):
				continue
			var count: int = item.event_counts.get(e, 0) + 1
			item.event_counts[e] = count
			if count % effect.every == 0:
				var first: int = sim.combat_log.entries.size()
				EffectRunner.run_event(sim, item, sourced, unit, damage)
				for i: int in range(first, sim.combat_log.entries.size()):
					sim.combat_log.entries[i].from_event = true
