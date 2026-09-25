class_name EventDef
extends RefCounted
## An event stop from data/events.json. Each is one outcome the player takes
## or passes on:
##   gold             "amount" gold
##   item_by_rarity   a random item, rarity by the economy's rarity weights
##   item_by_tier     a random item, tier by the loot tier weights
##   relic_by_rarity  a random relic, by the relic rarity weights
##   relic_merchant   buy 1 of the economy's relic_choices relics, or leave
##   essence          a random essence
##   key              a key

const KINDS: Array[String] = ["gold", "item_by_rarity", "item_by_tier", "relic_by_rarity", "relic_merchant", "essence", "key"]

var id: String
var name: String
var text: String
var kind: String
var amount: int = 0
var weight: int = 1


static func read(reader: DataReader) -> EventDef:
	var def := EventDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.text = reader.req_string("text")
	def.kind = reader.req_choice("kind", KINDS)
	if def.kind == "gold":
		def.amount = reader.req_int("amount", 1)
	def.weight = reader.opt_int("weight", 1, 1)
	reader.finish()
	return def
