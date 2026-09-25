class_name RelicRunner
extends RefCounted
## Runs relics' own effects (auras and grants go through
## CombatSim.rederive_all). A relic has no holder, so:
##   - its numbers are flat, boosted only by side-wide auras
##     (AuraDef.covers_everything): no stats, tier, or crit
##   - its damage is a hit (DEF applies) that triggers nothing further
##   - its cooldown runs at a fixed pace (no Slow, Freeze, or ATSP)
## When it acts:
##   on_fight_start    at tick 0, guild relics first
##   on_fire, at_time  in the firing phase, right after its side's units
##   on_ally_below_hp  once per tick after all firings, before deaths
## Specialization abilities with these triggers run here too, just before
## their side's relics, but through EffectRunner: they belong to a hero, so
## their numbers scale from the hero's stats. (Their on_fire effects fire on
## a cooldown like any item.)


static func fight_start(sim: CombatSim) -> void:
	for item: ItemState in _abilities(sim, -1):
		for sourced: SourcedEffect in _own_effects(item):
			if sourced.effect.trigger == EffectDef.Trigger.ON_FIGHT_START:
				EffectRunner.run_triggered(sim, item, sourced, null)
	for relic: RelicState in sim.bonuses():
		for effect: EffectDef in relic.def.effects:
			if effect.trigger == EffectDef.Trigger.ON_FIGHT_START:
				_run(sim, relic, effect, null)


## on_fire (every cooldown) and at_time effects of one side's relics.
static func fire_due(sim: CombatSim, side: UnitSetup.Side) -> void:
	for item: ItemState in _abilities(sim, side):
		for sourced: SourcedEffect in _own_effects(item):
			if sourced.effect.trigger == EffectDef.Trigger.AT_TIME and sourced.effect.at_ticks == sim.tick:
				EffectRunner.run_triggered(sim, item, sourced, null)
	for relic: RelicState in sim.bonuses():
		if relic.side != side:
			continue
		if relic.def.cooldown_ticks > 0 and sim.tick % relic.def.cooldown_ticks == 0:
			sim.combat_log.add(sim.new_entry(LogEntry.Kind.FIRE, relic.source()))
			for effect: EffectDef in relic.def.effects:
				if effect.trigger == EffectDef.Trigger.ON_FIRE:
					_run(sim, relic, effect, null)
		for effect: EffectDef in relic.def.effects:
			if effect.trigger == EffectDef.Trigger.AT_TIME and effect.at_ticks == sim.tick:
				_run(sim, relic, effect, null)


## on_ally_below_hp: each standing ally now below the threshold sets the
## effect off once (with "once", only the first ally in the fight does).
## Allies are checked in resolution order; fielded heroes only.
static func check_below_hp(sim: CombatSim) -> void:
	for item: ItemState in _abilities(sim, -1):
		var own: Array[SourcedEffect] = _own_effects(item)
		for e: int in own.size():
			var effect: EffectDef = own[e].effect
			if effect.trigger != EffectDef.Trigger.ON_ALLY_BELOW_HP:
				continue
			for ally: UnitState in sim.side_units(sim.owner_of(item).side):
				if effect.once and not item.ability_triggered[e].is_empty():
					break
				if not ally.is_standing() or item.ability_triggered[e].has(ally.id):
					continue
				if ally.hp * FixedMath.BP_ONE < ally.max_hp * effect.threshold_bp:
					item.ability_triggered[e].append(ally.id)
					EffectRunner.run_triggered(sim, item, own[e], ally)
	for relic: RelicState in sim.bonuses():
		for e: int in relic.def.effects.size():
			var effect: EffectDef = relic.def.effects[e]
			if effect.trigger != EffectDef.Trigger.ON_ALLY_BELOW_HP:
				continue
			for ally: UnitState in sim.side_units(relic.side):
				if effect.once and not relic.triggered_by[e].is_empty():
					break
				if not ally.is_standing() or relic.triggered_by[e].has(ally.id):
					continue
				if ally.hp * FixedMath.BP_ONE < ally.max_hp * effect.threshold_bp:
					relic.triggered_by[e].append(ally.id)
					_run(sim, relic, effect, ally)


## Ability items of living units on a side (-1: both sides), in resolution
## order.
static func _abilities(sim: CombatSim, side: int) -> Array[ItemState]:
	var result: Array[ItemState] = []
	for unit: UnitState in sim.units:
		if not unit.alive or (side >= 0 and unit.side != side):
			continue
		for item: ItemState in unit.items:
			if item.def.is_ability:
				result.append(item)
	return result


## An ability's own effects (they come first in its effect list, in the same
## order as def.effects).
static func _own_effects(item: ItemState) -> Array[SourcedEffect]:
	var result: Array[SourcedEffect] = []
	for i: int in item.def.effects.size():
		result.append(item.effects[i])
	return result


static func _run(sim: CombatSim, relic: RelicState, effect: EffectDef, trigger_ally: UnitState) -> void:
	if not effect.active_at(sim.tick):
		return
	var source: EffectSource = relic.source()
	var boosts: Array[ValueBreakdown.Multiplier] = sim.side_boosts[relic.side].multipliers_for(Conversions.output_kind(effect, sim.content), true)
	var amount: int = ValueBreakdown.compute(effect.base_value(), effect.scaling, UnitStats.new(), boosts).final
	for target: UnitState in Targeting.for_relic(effect.target, relic.side, trigger_ally, sim):
		match effect.type:
			EffectDef.Type.DAMAGE:
				EffectRunner.deal_hit(sim, source, target, amount, false)
			EffectDef.Type.HEAL:
				EffectRunner.heal(sim, target, amount, source)
			EffectDef.Type.SHIELD:
				EffectRunner.give_shield(sim, target, amount, source)
			EffectDef.Type.CLEANSE:
				Statuses.cleanse_over_time(sim, target, mini(amount, FixedMath.BP_ONE), source)
			EffectDef.Type.APPLY_STATUS:
				Statuses.apply(sim, target, effect.status_id, amount, source)
