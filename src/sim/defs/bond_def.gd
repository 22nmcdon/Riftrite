class_name BondDef
extends RefCounted
## A duo bond (data/bonds.json; docs/plans/duo-bonds.md; phase 5c step 5d,
## docs/plans/rebuild-phase5c-combos.md, section 13): two paths of two
## different heroes. It has no boost of its own: it's the key to a bond
## relic. Once both heroes have transformed into its paths it's on, and its
## relic can show up in the shops (Offers.shop_relics). Vowing both shows it
## as "?" (a bond stirs); it's found the first time it's on.
##   {"id": "light_and_iron", "name": "Light and Iron", "text": "...",
##    "paths": ["hearthwall", "wardweaver"], "relic": "the_hearth_woven_mail"}

var id: String
var name: String
var text: String
## The two path ids, in the file's order.
var paths: Array[String] = []
## The bond relic it's the key to (a relic of the bond tier).
var relic: String


static func read(reader: DataReader) -> BondDef:
	var def := BondDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.text = reader.req_string("text")
	def.paths = reader.req_string_array("paths")
	if def.paths.size() != 2:
		reader.error("a bond links exactly two paths")
	def.relic = reader.req_string("relic")
	reader.finish()
	return def


## The other path of the bond.
func partner(path_id: String) -> String:
	return paths[1] if paths[0] == path_id else paths[0]
