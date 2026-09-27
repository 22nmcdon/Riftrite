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
## Deed progress (docs/plans/deeds.md): the calling's from the start of the
## run, the specialization's from its pick. Level 2's chosen option on each
## track (0 or 1), or -1 while that level waits, unspent.
var calling_progress: int = 0
var calling_choice: int = -1
var spec_progress: int = 0
var spec_choice: int = -1


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
	data["deeds"] = {"calling": calling_progress, "calling_choice": calling_choice, "specialization": spec_progress, "specialization_choice": spec_choice}
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
	var deeds: DataReader = reader.req_object("deeds")
	if deeds != null:
		hero.calling_progress = deeds.req_int("calling", 0)
		hero.calling_choice = deeds.req_int("calling_choice", -1, 1)
		hero.spec_progress = deeds.req_int("specialization", 0)
		hero.spec_choice = deeds.req_int("specialization_choice", -1, 1)
		deeds.finish()
	reader.finish()
	return hero


## The hero's deed tracks for a fight: the calling, then the
## specialization's (if picked), with their progress.
func deed_setups(content: ContentDb) -> Array[DeedSetup]:
	var result: Array[DeedSetup] = []
	var def: HeroDef = content.heroes.get(hero_id)
	if def != null and def.calling != null:
		result.append(DeedSetup.make(DeedSetup.CALLING, def.calling, calling_progress, calling_choice))
	if content.specializations.has(specialization_id):
		result.append(DeedSetup.make(DeedSetup.SPECIALIZATION, content.specializations[specialization_id].track, spec_progress, spec_choice))
	return result


## The level reached on a track (DeedSetup.CALLING or SPECIALIZATION).
func deed_level(content: ContentDb, track_id: String) -> int:
	for deed: DeedSetup in deed_setups(content):
		if deed.track_id == track_id:
			return deed.level()
	return 0


## True if a track has reached its choice level with no option picked.
func choice_waiting(content: ContentDb, track_id: String) -> bool:
	var choice: int = calling_choice if track_id == DeedSetup.CALLING else spec_choice
	return choice < 0 and deed_level(content, track_id) > DeedTrackDef.CHOICE_LEVEL
