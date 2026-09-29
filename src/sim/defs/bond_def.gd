class_name BondDef
extends RefCounted
## A duo bond (data/bonds.json; docs/plans/rebuild-phase5-run.md, section 8;
## Decision 4): two paths of two different heroes. Once both heroes have
## transformed into them, each gets its path's mod (after relics). Vowing
## both shows it as "?" (a bond stirs); it's found the first time it's on.
##   {"id": "light_and_iron", "name": "Light and Iron", "text": "...",
##    "paths": {"wardweaver": {"text": "...", "mod": {...KitMod...}},
##              "hearthwall": {"text": "...", "mod": {...}}}}

var id: String
var name: String
var text: String
## The two path ids, in the file's order.
var paths: Array[String] = []
## Path id -> what that path's hero gets, and the player's line for it.
var mods: Dictionary[String, KitMod] = {}
var texts: Dictionary[String, String] = {}


static func read(reader: DataReader) -> BondDef:
	var def := BondDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.text = reader.req_string("text")
	var paths_reader: DataReader = reader.req_object("paths")
	if paths_reader != null:
		for path_id: String in paths_reader.map_keys():
			var side: DataReader = paths_reader.req_object(path_id)
			if side == null:
				continue
			def.paths.append(path_id)
			def.texts[path_id] = side.req_string("text")
			var mod_reader: DataReader = side.req_object("mod")
			if mod_reader != null:
				def.mods[path_id] = KitMod.read(mod_reader)
			side.finish()
		if def.paths.size() != 2:
			paths_reader.error("a bond links exactly two paths")
		paths_reader.finish()
	reader.finish()
	return def


## The other path of the bond.
func partner(path_id: String) -> String:
	return paths[1] if paths[0] == path_id else paths[0]
