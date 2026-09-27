class_name RunHero
extends RefCounted
## One of the run's three heroes (docs/plans/heroes-and-deeds.md). All three
## always fight; there's no bench.

var hero_id: String
## 0 = C ... 3 = S.
var rank: int = 0
## Their rank-B specialization's id, or "".
var specialization_id: String = ""
## Reached B without a specialization: the player must pick.
var needs_specialization: bool = false
var row: UnitSetup.Row = UnitSetup.Row.FRONT
## Their loadout, in order: at most one basic-attack item, and abilities and
## passives up to their rank's slot counts (see slot_problem). The UI shows
## them grouped by slot type.
var items: Array[RunItem] = []


static func make(id: String, hero_rank: int = 0) -> RunHero:
	var hero := RunHero.new()
	hero.hero_id = id
	hero.rank = hero_rank
	return hero


## How many slots of a type the hero has at their rank.
func slots_for(content: ContentDb, slot: ItemDef.Slot) -> int:
	match slot:
		ItemDef.Slot.BASIC_ATTACK:
			return 1
		ItemDef.Slot.ABILITY:
			return content.tuning.ability_slots[rank]
	return content.tuning.passive_slots[rank]


## How many of their items take a slot type.
func used_for(content: ContentDb, slot: ItemDef.Slot) -> int:
	var used: int = 0
	for item: RunItem in items:
		if content.items.has(item.item_id) and content.items[item.item_id].slot == slot:
			used += 1
	return used


## Why the loadout breaks a slot rule, in plain words, or "".
func slot_problem(content: ContentDb) -> String:
	for slot: int in ItemDef.SLOT_NAMES.size():
		var used: int = used_for(content, slot as ItemDef.Slot)
		var room: int = slots_for(content, slot as ItemDef.Slot)
		if used > room:
			var kind: String = (ItemDef.SLOT_LABELS[slot] if room == 1 else ItemDef.SLOT_PLURALS[slot]).to_lower()
			return "%s has room for %d %s" % [hero_id, room, kind]
	return ""


func to_dict() -> Dictionary:
	var item_list: Array = []
	for item: RunItem in items:
		item_list.append(item.to_dict())
	var data: Dictionary = {
		"hero": hero_id, "rank": rank, "needs_specialization": needs_specialization,
		"row": EncounterDef.ROW_NAMES[row], "items": item_list,
	}
	if not specialization_id.is_empty():
		data["specialization"] = specialization_id
	return data


static func from_dict(reader: DataReader) -> RunHero:
	var hero := RunHero.new()
	hero.hero_id = reader.req_string("hero")
	hero.rank = reader.req_int("rank", 0, 3)
	if reader.has("specialization"):
		hero.specialization_id = reader.req_string("specialization")
	hero.needs_specialization = reader.opt_bool("needs_specialization", false)
	hero.row = maxi(EncounterDef.ROW_NAMES.find(reader.req_choice("row", EncounterDef.ROW_NAMES)), 0) as UnitSetup.Row
	for item_reader: DataReader in reader.opt_object_array("items"):
		hero.items.append(RunItem.from_dict(item_reader))
	reader.finish()
	return hero
