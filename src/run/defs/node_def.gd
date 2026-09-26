class_name NodeDef
extends RefCounted
## A stop the day's node choice can offer (data/nodes.json;
## docs/plans/stop-nodes.md). Every event is a node too (its own name, text,
## and weight in data/events.json), so the pool is these plus the events.
##   {"id": "loot_item", "name": "A Fallen Cache", "text": "...",
##    "kind": "loot", "loot": "item", "weight": 7}
## Kinds:
##   forge    reforge items (only when something is infused)
##   loot     a free "item", "essence", or "gold" (the "loot" key)
##   vault    spend a key on a chest (only with a key)
##   retrain  switch a hero's specialization (only when one has one)
##   fight    an extra fight against another of the day's normal encounters;
##            a win gives a normal win's rewards, a loss just gives nothing

const KINDS: Array[String] = ["forge", "loot", "vault", "retrain", "fight"]
const LOOT_KINDS: Array[String] = ["item", "essence", "gold"]

var id: String
var name: String
var text: String
var kind: String
## loot: what it gives.
var loot: String = ""
var weight: int = 1


static func read(reader: DataReader) -> NodeDef:
	var def := NodeDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.text = reader.req_string("text")
	def.kind = reader.req_choice("kind", KINDS)
	if def.kind == "loot":
		def.loot = reader.req_choice("loot", LOOT_KINDS)
	def.weight = reader.req_int("weight", 1)
	reader.finish()
	return def
