class_name EnemyUpgradeDef
extends RefCounted
## An enemy upgrade (docs/plans/enemy-growth.md, section 3; built in phase 8
## part 3, docs/plans/rebuild-phase8-act3.md, section 2): a small change an
## elite fight's enemies carry, one or two at a time, as a kit mod on the
## enemy's kit, with its word put before the enemy's name and the player's
## sentence for it. Any enemy can carry any upgrade, so they live in their
## own file (data/enemy_upgrades.json, Decision 3), not on the enemies.
##   {"id": "frenzied", "name": "Frenzied",
##    "text": "It attacks faster once it's below half its HP.",
##    "mod": {...a KitMod...}}

## The most one enemy carries.
const PER_ENEMY: int = 2

var id: String
## The word before the enemy's name ("Frenzied" makes "Frenzied Rift Hound").
var name: String
var text: String
var mod: KitMod


static func read(reader: DataReader) -> EnemyUpgradeDef:
	var def := EnemyUpgradeDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.text = reader.req_string("text")
	var mod_reader: DataReader = reader.req_object("mod")
	def.mod = KitMod.read(mod_reader) if mod_reader != null else null
	reader.finish()
	return def


## `kit` (the enemy's, as the fight has it) upgraded: the mod applied, the
## word put before its name, and the upgrade noted on it.
func apply(kit: UnitDef, problems: Array[String] = []) -> UnitDef:
	var built: UnitDef = mod.apply(kit, problems) if mod != null else kit.copy()
	built.name = "%s %s" % [name, kit.name]
	built.upgrades = kit.upgrades.duplicate()
	built.upgrades.append(id)
	return built


## Whether the mod changes anything on `kit` (an upgrade that wouldn't, such
## as Rift-Touched on an enemy without a mana bar, is never drawn for it).
func changes(kit: UnitDef) -> bool:
	return mod != null and mod.affects(kit)
