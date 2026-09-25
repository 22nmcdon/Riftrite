class_name RunFight
extends RefCounted
## The bridge between a run and the combat sim: builds a fight from the run,
## and writes what a fight changes back into it (infusion XP, discovered
## synergies, the win or loss). Rewards, drops, and replays come with the
## day structure (step 5).


## A fight between the guild and an encounter. Draws the fight's seed from
## the run's RNG, so the same run and actions give the same fights.
static func setup_for(state: RunState, content: ContentDb, encounter_id: String) -> FightSetup:
	var fielded: Array[UnitSetup] = []
	var bench: Array[UnitSetup] = []
	for hero: RunHero in state.heroes:
		var entries: Array[LoadoutEntry] = []
		for item: RunItem in hero.items:
			entries.append(item.to_entry())
		var unit: UnitSetup = SetupBuilder.hero(content, hero.hero_id, hero.rank, hero.row, entries, hero.specialization_id)
		if hero.benched:
			bench.append(unit)
		else:
			fielded.append(unit)
	var fight_seed: int = state.rng.next_u32()
	return FightSetup.make(fielded, SetupBuilder.encounter_units(content, encounter_id), fight_seed,
		content.encounters[encounter_id].act, bench, state.relics.duplicate(), SetupBuilder.encounter_relics(content, encounter_id))


## Writes a finished fight back into the run: each infused item's XP
## (matched by hero and slot), newly found synergies, and the result (a tie
## counts as a win).
static func apply_result(state: RunState, content: ContentDb, result: FightResult) -> void:
	for infusion: FightResult.InfusionResult in result.infusions:
		var item: RunItem = _item_at(state, content, infusion.unit_id, infusion.slot)
		if item != null and item.item_id == infusion.item_id:
			item.xp = infusion.xp_after
	for found: FightResult.SynergyResult in result.synergies:
		if not state.discovered.has(found.synergy_id):
			state.discovered.append(found.synergy_id)
	if result.guild_won():
		state.wins += 1
	else:
		state.losses += 1


## The item on a hero's row starting at `slot` (slots count item sizes, as in
## the sim), or null.
static func _item_at(state: RunState, content: ContentDb, hero_id: String, slot: int) -> RunItem:
	var hero: RunHero = state.hero(hero_id)
	if hero == null:
		return null
	var at: int = 0
	for item: RunItem in hero.items:
		if at == slot:
			return item
		at += content.items[item.item_id].size
	return null
