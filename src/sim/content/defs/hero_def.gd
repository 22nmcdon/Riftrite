class_name HeroDef
extends RefCounted
## A hero in data/heroes.json (docs/plans/rebuild-phase2-heroes-enemies.md,
## section 2): who they are, their main role, and their base kit. Their
## paths (phase 4) are in data/paths.json; ContentDb lists them here, in that
## file's order.
##   {"id": "maren", "name": "Maren Thistledown", "title": "the ranger",
##    "role": "damage", "kit": {...a UnitDef, without id or name...}}

enum Role { TANK, DAMAGE, SUPPORT, CONTROL }

const ROLE_NAMES: Array[String] = ["tank", "damage", "support", "control"]

var id: String
var name: String
var title: String
var role: Role
var kit: UnitDef
## Up to three (ContentDb fills it from paths.json).
var paths: Array[PathDef] = []


static func read(reader: DataReader) -> HeroDef:
	var def := HeroDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.title = reader.req_string("title")
	def.role = maxi(ROLE_NAMES.find(reader.req_choice("role", ROLE_NAMES)), 0) as Role
	var kit_reader: DataReader = reader.req_object("kit")
	def.kit = UnitDef.read(kit_reader, def.id, def.name) if kit_reader != null else null
	reader.finish()
	return def


## Its path with this id, or null.
func path(path_id: String) -> PathDef:
	for candidate: PathDef in paths:
		if candidate.id == path_id:
			return candidate
	return null
