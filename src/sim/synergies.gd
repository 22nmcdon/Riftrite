class_name Synergies
extends RefCounted
## Finds the guild's active synergies at fight start (docs/plans/
## synergies-in-sim.md). Nothing a synergy looks at changes during a fight,
## so this runs once. Enemies don't get synergies (for now).
##
## Each active synergy becomes a RelicState holding its bonus, so its auras,
## grants, and effects run through the relic code. A transformation also
## marks its item (ItemState.transformation), which ItemState.derive uses.


## The active synergies, in data/synergies.json order. Logs one SYNERGY line
## each.
static func find_active(sim: CombatSim) -> Array[RelicState]:
	var active: Array[RelicState] = []
	for synergy_id: String in sim.content.synergy_ids:
		var synergy: SynergyDef = sim.content.synergies[synergy_id]
		if synergy.is_tiered():
			var count: int = _essence_count(sim, synergy.essence) if synergy.layer == SynergyDef.Layer.RESONANCE else _class_count(sim, synergy.unit_class)
			var tier: SynergyDef.Tier = synergy.tier_for(count)
			if tier != null:
				var state: RelicState = _state(synergy, tier.bonus)
				state.count = count
				active.append(state)
				_log(sim, state, "%s: %d %s" % [tier.bonus.name, count, _count_label(sim, synergy, count)])
			continue
		for u: int in sim.units.size():
			var hero: UnitState = sim.units[u]
			if hero.side != UnitSetup.Side.HEROES or hero.benched:
				continue
			var matched: Array[ItemState] = _match_items(synergy, hero)
			if matched.is_empty():
				continue
			var state: RelicState = _state(synergy, synergy.bonus)
			state.holder_index = u
			for item: ItemState in matched:
				state.matched_slots.append(item.slot)
			if synergy.layer == SynergyDef.Layer.TRANSFORMATION:
				matched[0].transform(synergy)
			active.append(state)
			var names: Array[String] = []
			for item: ItemState in matched:
				names.append(item.def.name)
			if synergy.layer == SynergyDef.Layer.TRANSFORMATION:
				names.append(sim.content.essences[synergy.essence].name)
			_log(sim, state, "%s: %s · %s" % [synergy.name, hero.id, " + ".join(names)])
	return active


## The items on `hero` that satisfy an item-layer synergy, or none.
static func _match_items(synergy: SynergyDef, hero: UnitState) -> Array[ItemState]:
	var matched: Array[ItemState] = []
	if synergy.layer == SynergyDef.Layer.SIGNATURE and hero.id != synergy.hero:
		return matched
	for item_id: String in synergy.items:
		var found: ItemState = null
		for item: ItemState in hero.row_items():
			if item.def.id != item_id or matched.has(item):
				continue
			if synergy.layer == SynergyDef.Layer.TRANSFORMATION and (item.transformation != null or not item.has_essence(synergy.essence)):
				continue
			found = item
			break
		if found == null:
			matched.clear()
			return matched
		matched.append(found)
	return matched


## Essences of one kind socketed across fielded and backup heroes' items:
## a single counts 1, an alloy 1 per half, a pure double 2.
static func _essence_count(sim: CombatSim, essence_id: String) -> int:
	var count: int = 0
	for unit_setup: UnitSetup in sim.setup.heroes + sim.setup.bench:
		for item: ItemSetup in unit_setup.items:
			count += item.essence_ids.count(essence_id)
	return count


## Fielded heroes of a class.
static func _class_count(sim: CombatSim, unit_class: String) -> int:
	var count: int = 0
	for hero: UnitState in sim.heroes:
		if hero.unit_class == unit_class:
			count += 1
	return count


static func _count_label(sim: CombatSim, synergy: SynergyDef, count: int) -> String:
	if synergy.layer == SynergyDef.Layer.RESONANCE:
		return sim.content.essences[synergy.essence].name
	return "hero" if count == 1 else "heroes"


static func _state(synergy: SynergyDef, bonus: RelicDef) -> RelicState:
	var state: RelicState = RelicState.make(bonus, UnitSetup.Side.HEROES)
	state.synergy = synergy
	return state


static func _log(sim: CombatSim, state: RelicState, note: String) -> void:
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.SYNERGY, state.source())
	entry.note = note
	sim.combat_log.add(entry)
