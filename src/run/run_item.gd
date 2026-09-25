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


static func make(item_uid: int, id: String, item_tier: int = 0) -> RunItem:
	var item := RunItem.new()
	item.uid = item_uid
	item.item_id = id
	item.tier = item_tier
	return item


## The item as a fixed layout entry, for building a fight.
func to_entry() -> LoadoutEntry:
	var entry := LoadoutEntry.new()
	entry.item_id = item_id
	entry.tier = tier
	entry.essence_ids = essence_ids.duplicate()
	entry.xp = xp
	return entry


func to_dict() -> Dictionary:
	return {"uid": uid, "item": item_id, "tier": tier, "essences": essence_ids.duplicate(), "xp": xp}


static func from_dict(reader: DataReader) -> RunItem:
	var item := RunItem.new()
	item.uid = reader.req_int("uid", 1)
	item.item_id = reader.req_string("item")
	item.tier = reader.req_int("tier", 0, 3)
	item.essence_ids = reader.req_string_array("essences")
	item.xp = reader.req_int("xp", 0)
	reader.finish()
	return item
