class_name Signatures
extends RefCounted
## Signatures and their triggers (docs/plans/rebuild-phase1-arena-sim.md,
## section 5; the data is AbilityDef and TriggerDef).
##
## In each unit's update every tick, right after its mana regen (act;
## CombatSim calls it only when something may fire: fires queued, a cast
## under way, a full bar, or a once-a-fight trigger not yet spent):
##   - mana: a full bar fires it, and the bar empties. Not while Stunned: the
##     bar waits, full. With cast_ms, the unit first stands still for the cast
##     (CAST); a Stun cancels it (CAST_CANCELLED) and the bar stays full.
##   - hp_below, fight_start, at_time: once a fight, when the condition first
##     holds.
##   - count: every Nth event (Events) queues a fire for the next tick.
## Everything but mana fires even while the unit is Stunned. A signature
## picks a fresh target each time it fires; with none in reach, it waits
## (a mana bar stays full, and other fires stay queued). A hero with a
## signature_threshold tactic also waits, full, until the ally lowest on HP
## in its reach is hurt enough (Tactics.hurt_enough).
##   - would_fall runs in the deaths step instead: the first time the unit
##     would fall, it's left at 1 HP (SAVED) and the signature fires at once.
##   - ally_falls: each ally that falls (the deaths step, ally_fell) queues a
##     fire for the unit's next update.
##   - ally_fires (once): an ally's fire of the named ability (read from the
##     log with the events, ally_fired) queues a fire at that fire's target,
##     wherever it stands (the FIRE entry notes "with <ally>").
## A sigil adds (phase 5, AbilityDef):
##   - extra triggers (also): hp_below (once) and ally_falls queue fires like
##     their own kinds, free of mana, whatever the main trigger; the FIRE
##     entry notes why ("an ally fell").
##   - an echo: echo_ticks after each fire, the echo (a weaker copy, its own
##     source, "Mend (Echo)") fires at a fresh target by the same rule and
##     reach, even while Stunned; with none, it's lost. A fire while an echo
##     waits moves the echo later.


## The signature's part of the unit's update. Returns true if the unit is
## casting, so it does nothing else this tick.
static func act(sim: CombatSim, unit: UnitState) -> bool:
	var signature: AbilityState = unit.signature
	if signature == null:
		return false
	if signature.echo_at >= 0 and sim.tick >= signature.echo_at:
		_fire_echo(sim, unit)
	var stunned: bool = not unit.statuses.is_empty() and Statuses.has_kind(unit, StatusDef.Kind.STUN)
	if signature.casting():
		if stunned:
			cancel_cast(sim, unit, "stunned")
			return false
		if sim.tick < signature.cast_ends_at:
			return true
		_land_cast(sim, unit)
		return false
	if signature.also_waiting:
		_check_also(unit)
	var trigger: TriggerDef = signature.def.trigger
	match trigger.kind:
		TriggerDef.Kind.MANA:
			if not stunned and Mana.is_full(unit):
				var target: UnitState = pick_target(sim, unit)
				if target == null:
					return false
				if unit.tactic != null and unit.tactic.kind == TacticDef.Kind.SIGNATURE_THRESHOLD and not Tactics.hurt_enough(sim, unit):
					return false
				# Wait for a crowd and Save it for the kill (phase 5c step 6c).
				if unit.tactic != null and unit.tactic.kind == TacticDef.Kind.SIGNATURE_CROWD and not Tactics.crowd_ready(sim, unit, target):
					return false
				if unit.tactic != null and unit.tactic.kind == TacticDef.Kind.SIGNATURE_FINISH and not Tactics.finish_ready(sim, unit, target):
					return false
				if signature.def.cast_ticks > 0:
					_start_cast(sim, unit, target)
					return true
				var bar: int = unit.mana
				_spend_bar(sim, unit)
				if not _fire(sim, unit, target):
					unit.mana = bar
				elif unit.mana_store > 0:
					_overcharge(sim, unit)
		TriggerDef.Kind.HP_BELOW:
			if not signature.fired and unit.hp > 0 and unit.hp * FixedMath.BP_ONE < unit.max_hp * trigger.threshold_bp:
				_queue_once(signature)
		TriggerDef.Kind.FIGHT_START:
			_queue_once(signature)
		TriggerDef.Kind.AT_TIME:
			if sim.tick >= trigger.at_ticks:
				_queue_once(signature)
	while signature.pending > 0:
		var target: UnitState = signature.pending_target
		if target == null or not target.alive:
			target = pick_target(sim, unit)
		if target == null or not _fire(sim, unit, target, signature.pending_note):
			break
		signature.pending -= 1
		signature.pending_target = null
	if signature.pending == 0:
		signature.pending_note = ""
	return false


## True if the signature fires when an ally falls (its trigger or an extra).
static func fires_on_ally_falls(ability: AbilityDef) -> bool:
	if ability.trigger != null and ability.trigger.kind == TriggerDef.Kind.ALLY_FALLS:
		return true
	return ability.also.any(func(trigger: TriggerDef) -> bool: return trigger.kind == TriggerDef.Kind.ALLY_FALLS)


## The deaths step: `fallen` fell, so each standing ally whose signature
## fires when an ally falls queues a fire.
static func ally_fell(sim: CombatSim, fallen: UnitState) -> void:
	for unit: UnitState in sim.units:
		if unit == fallen or not unit.alive or unit.side != fallen.side or unit.signature == null or not fires_on_ally_falls(unit.signature.def):
			continue
		unit.signature.pending += 1
		unit.signature.pending_note = "an ally fell"


## Events read `ally` firing `ability_id` at `target`: each standing ally
## of it whose signature fires on that (ally_fires, once) queues a fire there.
static func ally_fired(sim: CombatSim, ally: UnitState, ability_id: String, target: UnitState) -> void:
	for unit: UnitState in sim.units:
		if unit == ally or not unit.alive or unit.side != ally.side or unit.signature == null:
			continue
		var trigger: TriggerDef = unit.signature.def.trigger
		if trigger.kind != TriggerDef.Kind.ALLY_FIRES or trigger.ability != ability_id or unit.signature.fired:
			continue
		unit.signature.fired = true
		unit.signature.pending += 1
		unit.signature.pending_target = target
		unit.signature.pending_note = "with %s" % ally.id


## Extra hp_below triggers: each queues one fire, the first time the unit is
## below its share.
static func _check_also(unit: UnitState) -> void:
	var signature: AbilityState = unit.signature
	signature.also_waiting = false
	for i: int in signature.def.also.size():
		var trigger: TriggerDef = signature.def.also[i]
		if trigger.kind != TriggerDef.Kind.HP_BELOW or signature.also_fired[i]:
			continue
		if unit.hp > 0 and unit.hp * FixedMath.BP_ONE < unit.max_hp * trigger.threshold_bp:
			signature.also_fired[i] = true
			signature.pending += 1
			signature.pending_note = trigger.reason()
		else:
			signature.also_waiting = true


## The echo's time: it fires at a fresh target by the signature's rule and
## reach, or is lost with none.
static func _fire_echo(sim: CombatSim, unit: UnitState) -> void:
	var signature: AbilityState = unit.signature
	signature.echo_at = -1
	var target: UnitState = pick_target(sim, unit)
	if target != null:
		EffectRunner.fire(sim, unit, signature.echo, target, signature.echo.def.reach_for(unit.stats.get_stat(UnitStats.Stat.RANGE)))


## Events counts toward a count signature. A count that reaches its "every"
## queues a fire for the next tick.
static func on_event(unit: UnitState, event: EffectDef.Trigger) -> void:
	var signature: AbilityState = unit.signature
	if signature == null or signature.def.trigger.kind != TriggerDef.Kind.COUNT or signature.def.trigger.event != event:
		return
	signature.count += 1
	if signature.count % signature.def.trigger.every == 0:
		signature.pending += 1


## The deaths step: a unit at 0 HP with an unspent would_fall signature is
## left at 1 HP, and the signature fires. Returns true if it was saved.
static func would_fall(sim: CombatSim, unit: UnitState) -> bool:
	var signature: AbilityState = unit.signature
	if signature == null or signature.fired or signature.def.trigger.kind != TriggerDef.Kind.WOULD_FALL:
		return false
	signature.fired = true
	unit.hp = 1
	var saved: LogEntry = sim.new_entry(LogEntry.Kind.SAVED, signature.source)
	saved.target = unit.id
	saved.note = "would fall"
	sim.combat_log.add(saved)
	var target: UnitState = pick_target(sim, unit)
	if target == null or not _fire(sim, unit, target):
		signature.pending += 1
	return true


## A fresh target for the signature by its rule, within its reach; null if
## nothing fits.
static func pick_target(sim: CombatSim, unit: UnitState) -> UnitState:
	var ability: AbilityDef = unit.signature.def
	var reach: int = unit.reach_of(ability)
	return Targeting.pick(sim, unit, ability.targeting, reach * reach, ability.prefer)


static func _queue_once(signature: AbilityState) -> void:
	if not signature.fired:
		signature.fired = true
		signature.pending += 1


## Fires the signature at `target`. False if it couldn't (a leap with no room
## to land): it waits, and the failure is logged once until it next fires.
static func _fire(sim: CombatSim, unit: UnitState, target: UnitState, note: String = "") -> bool:
	var signature: AbilityState = unit.signature
	var ability: AbilityDef = signature.def
	if not EffectRunner.fire(sim, unit, signature, target, ability.reach_for(unit.stats.get_stat(UnitStats.Stat.RANGE)), not signature.failing, note):
		signature.failing = true
		return false
	signature.failing = false
	if signature.echo != null:
		signature.echo_at = sim.tick + ability.echo_ticks
	# Wait to heal's twist (phase 5c step 6c): the heal that waited cleanses.
	if unit.tactic != null and unit.tactic.cleanse_one and unit.tactic.kind == TacticDef.Kind.SIGNATURE_THRESHOLD:
		Tactics.cleanse_one(sim, unit, target)
	return true


static func _start_cast(sim: CombatSim, unit: UnitState, target: UnitState) -> void:
	var signature: AbilityState = unit.signature
	signature.cast_ends_at = sim.tick + signature.def.cast_ticks
	signature.cast_target = target
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.CAST, signature.source)
	entry.target = target.id
	entry.end_tick = signature.cast_ends_at
	sim.combat_log.add(entry)


## The cast is done: it lands on its target, or (if that one fell or left its
## reach) a fresh one. With none, it's cancelled and the bar stays full.
static func _land_cast(sim: CombatSim, unit: UnitState) -> void:
	var signature: AbilityState = unit.signature
	var target: UnitState = signature.cast_target
	if target == null or not target.alive or (target != unit and not _in_reach(unit, target)):
		target = pick_target(sim, unit)
	if target == null:
		cancel_cast(sim, unit, "no target")
		return
	signature.cast_ends_at = -1
	signature.cast_target = null
	var bar: int = unit.mana
	_spend_bar(sim, unit)
	if not _fire(sim, unit, target):
		unit.mana = bar
	elif unit.mana_store > 0:
		_overcharge(sim, unit)


## A mana signature fires: the bar empties, or under Overcharge (phase 5c
## step 5c) loses one full bar.
static func _spend_bar(_sim: CombatSim, unit: UnitState) -> void:
	unit.mana = maxi(unit.mana - unit.mana_cap, 0) if unit.mana_store > 0 else 0


## Overcharge: each further full bar fires the signature again at once (a
## fresh target, no cast), each power_bp more than the last (and Chain of
## Echoes' growth), up to its steps.
static func _overcharge(sim: CombatSim, unit: UnitState) -> void:
	var rules: SideRules = sim.hero_rules
	for step: int in range(1, rules.overcharge_steps + rules.deeper_steps + 1):
		if unit.mana < unit.mana_cap:
			return
		var target: UnitState = pick_target(sim, unit)
		if target == null:
			return
		unit.mana -= unit.mana_cap
		unit.fire_power_bp = rules.overcharge_power_bp * step + (rules.growth_bp(step) - FixedMath.BP_ONE)
		var fired: bool = _fire(sim, unit, target, "Overcharge %d" % step)
		unit.fire_power_bp = 0
		if not fired:
			unit.mana += unit.mana_cap
			return


static func cancel_cast(sim: CombatSim, unit: UnitState, reason: String) -> void:
	var signature: AbilityState = unit.signature
	signature.cast_ends_at = -1
	signature.cast_target = null
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.CAST_CANCELLED, signature.source)
	entry.note = reason
	sim.combat_log.add(entry)


static func _in_reach(unit: UnitState, target: UnitState) -> bool:
	var reach: int = unit.reach_of(unit.signature.def)
	return _distance_squared(unit, target) <= reach * reach


static func _distance_squared(unit: UnitState, other: UnitState) -> int:
	var dx: int = other.pos.x - unit.pos.x
	var dy: int = other.pos.y - unit.pos.y
	return dx * dx + dy * dy
