class_name SpecializationDef
extends RefCounted
## An enemy's specialization (docs/plans/enemy-growth.md, section 2; built in
## phase 8 part 3, docs/plans/rebuild-phase8-act2.md, section 2): a change to
## how the enemy plays, as a kit mod on its kit, with the word put before its
## name and the player's sentence for it. An enemy has at most two.
##   {"id": "gnawing_pup", "name": "Gnawing",
##    "text": "Its bites make you bleed, and the bleeding stacks.",
##    "mod": {...a KitMod...}}

const PER_ENEMY: int = 2

var id: String
## The word before the enemy's name ("Gnawing" makes "Gnawing Rift Pup").
var name: String
var text: String
var mod: KitMod
## The enemy it belongs to.
var enemy: String


static func read(reader: DataReader, enemy_id: String) -> SpecializationDef:
	var def := SpecializationDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.text = reader.req_string("text")
	def.enemy = enemy_id
	var mod_reader: DataReader = reader.req_object("mod")
	def.mod = KitMod.read(mod_reader) if mod_reader != null else null
	reader.finish()
	return def


## `kit` (the enemy's, as the fight has it) specialized: the mod applied and
## the word put before its name.
func apply(kit: UnitDef, problems: Array[String] = []) -> UnitDef:
	var built: UnitDef = mod.apply(kit, problems) if mod != null else kit.copy()
	built.name = "%s %s" % [name, kit.name]
	built.specialization = id
	return built
