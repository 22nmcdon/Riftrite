class_name ShopDef
extends RefCounted
## What a shop node sells (data/nodes.json, "kind": "shop";
## docs/plans/new-day.md). Every key is optional; {} is the Caravan (any item):
##   keyword   only items with this keyword ("blade")
##   slot      only items for this slot ("passive")
##   essence   also sells this essence, for the economy's essence_price
##   keywords  with "essence": the item keywords that suit it
##   partners  items that complete a synergy with what the guild holds (the
##             Synergy Peddler)
##   tier      every item at this tier (a tier shop), instead of the act's
##             shop tier odds; a tier shop ignores the held-tier rule
##   count     how many items (default: the economy's shop_items)
## A filter that finds too few items tops up with any item.

var keyword: String = ""
var slot: int = -1
var essence: String = ""
var keywords: Array[String] = []
var partners: bool = false
## -1: the act's shop tier odds.
var tier: int = -1
## 0: the economy's shop_items.
var count: int = 0


static func read(reader: DataReader) -> ShopDef:
	var def := ShopDef.new()
	def.keyword = reader.opt_string("keyword", "")
	if reader.has("slot"):
		def.slot = maxi(ItemDef.SLOT_NAMES.find(reader.req_choice("slot", ItemDef.SLOT_NAMES)), 0)
	def.essence = reader.opt_string("essence", "")
	if reader.has("keywords"):
		def.keywords = reader.req_string_array("keywords")
		if def.essence.is_empty():
			reader.error("keywords go with an essence merchant's essence")
	def.partners = reader.opt_bool("partners", false)
	if reader.has("tier"):
		def.tier = maxi(TuningDef.TIER_NAMES.find(reader.req_choice("tier", TuningDef.TIER_NAMES)), 0)
	def.count = reader.opt_int("count", 0, 1)
	reader.finish()
	return def


## Whether an item fits the shop's filter (the Caravan's: any item).
func fits(item: ItemDef) -> bool:
	if not keyword.is_empty() and not item.keywords.has(keyword):
		return false
	if slot >= 0 and item.slot != slot:
		return false
	if not keywords.is_empty() and not keywords.any(func(k: String) -> bool: return item.keywords.has(k)):
		return false
	return true


## The keywords and essence the shop names, for content checks.
func named_keywords() -> Array[String]:
	var names: Array[String] = keywords.duplicate()
	if not keyword.is_empty():
		names.append(keyword)
	return names
