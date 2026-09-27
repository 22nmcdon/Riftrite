class_name KeywordDef
extends RefCounted
## A keyword from data/keywords.json (docs/plans/infusion-rework.md). Items
## carry 1-3 of them; a Resonant single essence spills to its holder's other
## items that share one. Later steps build affinities and duo bonds on them.

var id: String
var name: String
## One line for the UI: what kind of item carries it.
var text: String


static func read(reader: DataReader) -> KeywordDef:
	var def := KeywordDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.text = reader.req_string("text")
	reader.finish()
	return def
