class_name RunItem
extends RefCounted
## One item the guild holds between fights: on a hero's row or in the stash.

## Unique within the run, so two copies of the same item can be told apart.
var uid: int
var item_id: String
## 0 = C ... 3 = S.
var tier: int = 0
## Socketed essences, in socket order.
var essence_ids: Array[String] = []
var xp: int = 0
## A Legendary's progress toward its next tier (see LegendaryDef).
var progress: int = 0
## A Devourer's meals: the eaten items' ids, in order.
var eaten: Array[String] = []


static func make(item_uid: int, id: String, item_tier: int = 0) -> RunItem:
	var item := RunItem.new()
	item.uid = item_uid
	item.item_id = id
	item.tier = item_tier
	return item


## The item as a fixed layout entry, for building a fight.
func to_entry(content: ContentDb) -> LoadoutEntry:
	var entry := LoadoutEntry.new()
	entry.item_id = item_id
	entry.tier = tier
	entry.essence_ids = essence_ids.duplicate()
	entry.xp = xp
	entry.trace_bp = trace_bp(content)
	return entry


## A Devourer's trace: the sum of what each meal left (0 for other items).
func trace_bp(content: ContentDb) -> int:
	var def: ItemDef = content.items.get(item_id, null)
	if def == null or def.legendary == null:
		return 0
	var total: int = 0
	for eaten_id: String in eaten:
		if content.items.has(eaten_id):
			total += def.legendary.trace_for(content.items[eaten_id].rarity)
	return total


func to_dict() -> Dictionary:
	var data: Dictionary = {"uid": uid, "item": item_id, "tier": tier, "essences": essence_ids.duplicate(), "xp": xp}
	if progress != 0:
		data["progress"] = progress
	if not eaten.is_empty():
		data["eaten"] = eaten.duplicate()
	return data


static func from_dict(reader: DataReader) -> RunItem:
	var item := RunItem.new()
	item.uid = reader.req_int("uid", 1)
	item.item_id = reader.req_string("item")
	item.tier = reader.req_int("tier", 0, 3)
	item.essence_ids = reader.req_string_array("essences")
	item.xp = reader.req_int("xp", 0)
	item.progress = reader.opt_int("progress", 0)
	if reader.has("eaten"):
		item.eaten = reader.req_string_array("eaten")
	reader.finish()
	return item
