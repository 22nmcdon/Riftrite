class_name RunHero
extends RefCounted
## One hero in the guild's roster between fights.

var hero_id: String
## 0 = C ... 3 = S.
var rank: int = 0
## Their rank-B specialization's id, or "".
var specialization_id: String = ""
## Reached B (or joined at B+) without a specialization: the player must pick.
var needs_specialization: bool = false
var row: UnitSetup.Row = UnitSetup.Row.FRONT
## In a backup slot instead of a field slot.
var benched: bool = false
## Their row, left to right.
var items: Array[RunItem] = []


static func make(id: String, hero_rank: int = 0) -> RunHero:
	var hero := RunHero.new()
	hero.hero_id = id
	hero.rank = hero_rank
	return hero


## Item slots at their rank (4 at C, +1 per rank).
func slots() -> int:
	return HeroDef.slots_at_rank(rank)


func used_slots(content: ContentDb) -> int:
	var used: int = 0
	for item: RunItem in items:
		if content.items.has(item.item_id):
			used += content.items[item.item_id].size
	return used


func to_dict() -> Dictionary:
	var item_list: Array = []
	for item: RunItem in items:
		item_list.append(item.to_dict())
	var data: Dictionary = {
		"hero": hero_id, "rank": rank, "needs_specialization": needs_specialization,
		"row": EncounterDef.ROW_NAMES[row], "benched": benched, "items": item_list,
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
	hero.benched = reader.opt_bool("benched", false)
	for item_reader: DataReader in reader.opt_object_array("items"):
		hero.items.append(RunItem.from_dict(item_reader))
	reader.finish()
	return hero

