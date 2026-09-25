class_name AuraFilter
extends RefCounted
## Narrows an aura (or a relic grant) to the items or units that match every
## key given. An optional "filter" object:
##   items: {"item": "rust_hook"}   that item
##          {"tag": "weapon"}       items with that tag
##          {"size": 1}             items of that size (the basic auto-attack
##                                  has no size and never matches)
##          {"applies": "burn"}     items that apply that status (own effects,
##                                  infusion, or spill; Inferno's Golden Flame
##                                  counts as both)
##          {"essence": "frost"}    items infused with that essence
##   units: {"row": "front"}        units in that row
##          {"class": "warden"}     heroes of that class
## Adding a key is a code change; say so when you make one.

const ITEM_KEYS: Array[String] = ["item", "tag", "size", "applies", "essence"]
const UNIT_KEYS: Array[String] = ["row", "class"]
const ROW_NAMES: Array[String] = ["front", "back"]

var item_id: String = ""
var tag: String = ""
## 0 = any size.
var size: int = 0
var applies: String = ""
var essence: String = ""
## -1 = any row.
var row: int = -1
var unit_class: String = ""


## Reads the "filter" object. `for_items` says whether the aura reaches items
## (item keys) or units (unit keys).
static func read(reader: DataReader, for_items: bool) -> AuraFilter:
	var filter := AuraFilter.new()
	var allowed: Array[String] = ITEM_KEYS if for_items else UNIT_KEYS
	var other: Array[String] = UNIT_KEYS if for_items else ITEM_KEYS
	var keys: Array[String] = reader.map_keys()
	if keys.is_empty():
		reader.error("a filter needs at least one of: %s" % ", ".join(allowed))
	for key: String in keys:
		if other.has(key):
			reader.error("\"%s\" filters %s, but this reaches %s" % [key, "units" if for_items else "items", "items" if for_items else "units"])
		elif not allowed.has(key):
			reader.error("unknown filter \"%s\" (expected one of: %s)" % [key, ", ".join(allowed)])
	if for_items:
		if reader.has("item"):
			filter.item_id = reader.req_string("item")
		if reader.has("tag"):
			filter.tag = reader.req_choice("tag", ItemDef.TAGS)
		if reader.has("size"):
			filter.size = reader.req_int("size", 1, ItemDef.MAX_SIZE)
		if reader.has("applies"):
			filter.applies = reader.req_string("applies")
		if reader.has("essence"):
			filter.essence = reader.req_string("essence")
	else:
		if reader.has("row"):
			filter.row = maxi(ROW_NAMES.find(reader.req_choice("row", ROW_NAMES)), 0)
		if reader.has("class"):
			filter.unit_class = reader.req_choice("class", HeroDef.CLASSES)
	reader.finish()
	return filter


func matches_item(item: ItemState) -> bool:
	if not item_id.is_empty() and item.def.id != item_id:
		return false
	if not tag.is_empty() and not item.def.tags.has(tag):
		return false
	if size > 0 and (item.slot < 0 or item.def.size != size):
		return false
	if not applies.is_empty() and not item.applies_status(applies):
		return false
	if not essence.is_empty() and not item.essences.any(func(e: EssenceDef) -> bool: return e.id == essence):
		return false
	return true


func matches_unit(unit: UnitState) -> bool:
	if row >= 0 and unit.row != row:
		return false
	if not unit_class.is_empty() and unit.unit_class != unit_class:
		return false
	return true


## For the log, e.g. " (weapon, size 1)".
func describe() -> String:
	var parts: Array[String] = []
	for part: String in [item_id, tag, applies, essence, unit_class]:
		if not part.is_empty():
			parts.append(part)
	if size > 0:
		parts.append("size %d" % size)
	if row >= 0:
		parts.append("%s row" % ROW_NAMES[row])
	return " (%s)" % ", ".join(parts)
