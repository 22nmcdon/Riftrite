class_name SetupBuilder
extends RefCounted
## Turns content (heroes, enemies, encounters, fixed layouts) into the
## UnitSetups a fight takes. Loadout references must already be valid
## (ContentDb.check_loadout); FightSetup.validate still runs before a fight.


static func item_setups(content: ContentDb, entries: Array[LoadoutEntry]) -> Array[ItemSetup]:
	var result: Array[ItemSetup] = []
	for entry: LoadoutEntry in entries:
		result.append(ItemSetup.make(content.items[entry.item_id], entry.essence_ids, entry.tier, entry.xp))
	return result


## A hero at a rank, standing in a row, carrying a loadout, with an optional
## specialization id.
static func hero(content: ContentDb, hero_id: String, rank: int, row: UnitSetup.Row, entries: Array[LoadoutEntry], specialization_id: String = "") -> UnitSetup:
	var def: HeroDef = content.heroes[hero_id]
	var setup: UnitSetup = UnitSetup.make(def.id, def.name, def.stats, row, HeroDef.slots_at_rank(rank), def.basic_attack, item_setups(content, entries), rank)
	setup.backup = def.backup
	setup.unit_class = def.hero_class
	if not specialization_id.is_empty():
		setup.specialization = content.specializations.get(specialization_id, null)
	return setup


## The relics an encounter's enemy team carries.
static func encounter_relics(content: ContentDb, encounter_id: String) -> Array[String]:
	return content.encounters[encounter_id].relics.duplicate()


## An encounter's enemy team. Unit ids get a position number so twins can be
## told apart in the log: "rift_hound_1", "rift_hound_2", ...
static func encounter_units(content: ContentDb, encounter_id: String) -> Array[UnitSetup]:
	var encounter: EncounterDef = content.encounters[encounter_id]
	var result: Array[UnitSetup] = []
	for i: int in encounter.units.size():
		var slot: EncounterDef.Slot = encounter.units[i]
		var def: EnemyDef = content.enemies[slot.enemy_id]
		var unit_id: String = "%s_%d" % [def.id, i + 1]
		result.append(UnitSetup.make(unit_id, def.name, def.stats, slot.row, def.slots, def.basic_attack, item_setups(content, def.items), def.rank))
	return result
