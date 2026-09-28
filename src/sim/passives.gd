class_name Passives
extends RefCounted
## Passives (PartDef) in a fight (docs/plans/rebuild-phase1-arena-sim.md,
## section 2):
##   aura            while its holder stands and its window is open, it
##                   boosts the holder or all its allies. Auras are folded
##                   into each unit's stats and output multipliers when the
##                   fight starts, when a window opens or closes, and when a
##                   holder falls (rederive). Each start and end is logged
##                   (AURA). Several on one stat multiply, in the fight's
##                   order, then each passive's.
##   ability         its effects run on the unit's events (Events). Each
##                   effect counts its own events and runs on every Nth. What
##                   they do is marked from_event, so it never sets off
##                   another event. Three triggers aren't events
##                   (docs/plans/rebuild-phase2-heroes-enemies.md, section 4):
##                   on_interval and on_ally_below_hp are checked after the
##                   events each tick (run_timed), and on_fall as the unit
##                   falls (on_fall).
##   replace_status  statuses the unit applies as `from` land as `to`.
## An aura with "while": "taunting" is on only while one of its holder's
## Taunts is in effect on a standing enemy; auras are folded in again when
## a Taunt starts or ends, or a taunted unit falls (CombatSim.taunt_auras).


## One event effect of one of a unit's ability passives, with its count.
class Listener:
	var part: PartDef
	var effect: EffectDef
	var source: EffectSource
	var count: int = 0
	## on_ally_below_hp: the allies it has run for.
	var allies_done: Array[String] = []


## AuraDef stats with no aura: x1 multipliers, +0 additions.
static func no_auras() -> Array[int]:
	var values: Array[int] = []
	for stat: int in AuraDef.Stat.size():
		values.append(0 if _is_additive(stat) else FixedMath.BP_ONE)
	return values


## Readies the unit's listeners and status swaps.
static func set_up(unit: UnitState) -> void:
	for part: PartDef in unit.def.passives:
		match part.kind:
			PartDef.Kind.ABILITY:
				for effect: EffectDef in part.ability.effects:
					var listener := Listener.new()
					listener.part = part
					listener.effect = effect
					listener.source = EffectSource.make(unit.id, part.id, part.name)
					unit.listeners.append(listener)
			PartDef.Kind.REPLACE_STATUS:
				unit.status_swaps[part.from_status] = part.to_status


# --- auras ---------------------------------------------------------------------

## Ticks where some aura window opens or closes (a lookup, never iterated).
static func aura_boundaries(sim: CombatSim) -> Dictionary[int, bool]:
	var ticks: Dictionary[int, bool] = {}
	for unit: UnitState in sim.units:
		for part: PartDef in unit.def.passives:
			if part.kind == PartDef.Kind.AURA:
				if part.aura.window_from_ticks > 0:
					ticks[part.aura.window_from_ticks] = true
				if part.aura.window_until_ticks > 0:
					ticks[part.aura.window_until_ticks] = true
	return ticks


static func has_aura(unit: UnitState) -> bool:
	for part: PartDef in unit.def.passives:
		if part.kind == PartDef.Kind.AURA:
			return true
	return false


## Folds every active aura into every unit again, and logs the auras that
## started or ended since the last time. `was_active` holds "unit:part" keys
## of the auras active before; returns the ones active now.
static func rederive(sim: CombatSim, was_active: Array[String]) -> Array[String]:
	for unit: UnitState in sim.units:
		unit.aura_bp = no_auras()
	var now_active: Array[String] = []
	for holder: UnitState in sim.units:
		if not holder.alive:
			continue
		for part: PartDef in holder.def.passives:
			if part.kind != PartDef.Kind.AURA or not part.aura.active_at(sim.tick):
				continue
			if part.aura.while_taunting and not taunting(sim, holder):
				continue
			now_active.append("%s:%s" % [holder.id, part.id])
			var targets: Array[UnitState] = [holder]
			if part.aura.target == AuraDef.Target.ALL_ALLIES:
				targets = sim.standing_allies_of(holder)
			for target: UnitState in targets:
				if _is_additive(part.aura.stat):
					target.aura_bp[part.aura.stat] += part.aura.value
				else:
					target.aura_bp[part.aura.stat] = FixedMath.apply_bp(target.aura_bp[part.aura.stat], part.aura.value)
	for unit: UnitState in sim.units:
		unit.stats = unit.base_stats.copy()
		for aura_stat: int in AuraDef.Stat.size():
			if not AuraDef.UNIT_STAT_FOR.has(aura_stat):
				continue
			var stat: int = AuraDef.UNIT_STAT_FOR[aura_stat]
			unit.stats.values[stat] = FixedMath.apply_bp(unit.base_stats.values[stat], unit.aura_bp[aura_stat])
		unit.attack.set_cooldown_add(unit.aura_bp[AuraDef.Stat.COOLDOWN_BP])
		unit.attack_rate_bp = sim.attack_rate_bp(unit)
		unit.refresh_reach()
	_log_changes(sim, was_active, now_active)
	return now_active


## Logs, in the fight's order, each aura that ended and each that started.
static func _log_changes(sim: CombatSim, was_active: Array[String], now_active: Array[String]) -> void:
	for holder: UnitState in sim.units:
		for part: PartDef in holder.def.passives:
			if part.kind != PartDef.Kind.AURA:
				continue
			var key: String = "%s:%s" % [holder.id, part.id]
			var was: bool = was_active.has(key)
			if was == now_active.has(key):
				continue
			var entry: LogEntry = sim.new_entry(LogEntry.Kind.AURA, EffectSource.make(holder.id, part.id, part.name))
			entry.note = ("starts: %s" % part.aura.describe()) if not was else "ends"
			sim.combat_log.add(entry)


## True if one of `holder`'s Taunts is in effect on a standing enemy.
static func taunting(sim: CombatSim, holder: UnitState) -> bool:
	for enemy: UnitState in sim.standing_enemies_of(holder):
		for state: StatusState in enemy.statuses:
			if state.def.kind == StatusDef.Kind.TAUNT and state.source != null and state.source.unit_id == holder.id:
				return true
	return false


## True if the unit has an aura that holds only while it's taunting.
static func has_taunting_aura(unit: UnitState) -> bool:
	for part: PartDef in unit.def.passives:
		if part.kind == PartDef.Kind.AURA and part.aura.while_taunting:
			return true
	return false


## True if the unit has passive effects on on_interval or on_ally_below_hp.
static func has_timed(unit: UnitState) -> bool:
	for listener: Listener in unit.listeners:
		if listener.effect.trigger == EffectDef.Trigger.ON_INTERVAL or listener.effect.trigger == EffectDef.Trigger.ON_ALLY_BELOW_HP:
			return true
	return false


static func _is_additive(stat: int) -> bool:
	return stat == AuraDef.Stat.CRIT_CHANCE_BP or stat == AuraDef.Stat.COOLDOWN_BP


## The effect's number after the unit's output auras (damage, heal, shield,
## or damage-over-time stacks).
static func boosted(unit: UnitState, effect: EffectDef, amount: int) -> int:
	var stat: int = -1
	match effect.type:
		EffectDef.Type.DAMAGE:
			stat = AuraDef.Stat.DAMAGE_BP
		EffectDef.Type.HEAL:
			stat = AuraDef.Stat.HEAL_BP
		EffectDef.Type.SHIELD:
			stat = AuraDef.Stat.SHIELD_BP
		EffectDef.Type.APPLY_STATUS:
			stat = AuraDef.Stat.OVER_TIME_BP
	if stat < 0 or unit.aura_bp[stat] == FixedMath.BP_ONE:
		return amount
	return FixedMath.apply_bp(amount, unit.aura_bp[stat])


# --- events ------------------------------------------------------------------------

## Runs the unit's event effects for `event`. `other` is the unit the event
## names (hit_target), `damage` the hit it's about (amount_bp_of_damage),
## `status` the status applied (on_status).
static func on_event(sim: CombatSim, unit: UnitState, event: EffectDef.Trigger, other: UnitState, damage: int, status: String) -> void:
	for listener: Listener in unit.listeners:
		var effect: EffectDef = listener.effect
		if effect.trigger != event or not effect.active_at(sim.tick):
			continue
		if event == EffectDef.Trigger.ON_STATUS and not effect.statuses.is_empty() and not effect.statuses.has(status):
			continue
		listener.count += 1
		if listener.count % effect.every != 0:
			continue
		_run(sim, unit, listener, other, damage)


## Runs the on_interval passives that are due and the on_ally_below_hp ones
## an ally has just set off, for every standing unit in the fight's order
## (the allies, too, in the fight's order).
static func run_timed(sim: CombatSim) -> void:
	for unit: UnitState in sim.units:
		if not unit.alive or unit.listeners.is_empty():
			continue
		for listener: Listener in unit.listeners:
			var effect: EffectDef = listener.effect
			if not effect.active_at(sim.tick):
				continue
			match effect.trigger:
				EffectDef.Trigger.ON_INTERVAL:
					var since: int = sim.tick - unit.joined_at
					if since > 0 and since % effect.interval_ticks == 0:
						_run(sim, unit, listener, null, 0)
				EffectDef.Trigger.ON_ALLY_BELOW_HP:
					for ally: UnitState in sim.standing_allies_of(unit):
						if effect.once and not listener.allies_done.is_empty():
							break
						if ally == unit or ally.hp <= 0 or listener.allies_done.has(ally.id):
							continue
						if ally.hp * FixedMath.BP_ONE < ally.max_hp * effect.threshold_bp:
							listener.allies_done.append(ally.id)
							_run(sim, unit, listener, ally, 0)


## The unit has just fallen: its on_fall passives run, from where it fell.
## Returns true if any did.
static func on_fall(sim: CombatSim, unit: UnitState) -> bool:
	var ran: bool = false
	for listener: Listener in unit.listeners:
		if listener.effect.trigger == EffectDef.Trigger.ON_FALL and listener.effect.active_at(sim.tick):
			_run(sim, unit, listener, null, 0)
			ran = true
	return ran


## Runs one listener's effect; what it does is marked from_event.
static func _run(sim: CombatSim, unit: UnitState, listener: Listener, other: UnitState, damage: int) -> void:
	var first: int = sim.combat_log.entries.size()
	EffectRunner.run_event(sim, unit, listener.part.ability, listener.source, listener.effect, other, damage)
	for i: int in range(first, sim.combat_log.entries.size()):
		sim.combat_log.entries[i].from_event = true
