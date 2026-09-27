class_name UnitDef
extends RefCounted
## A unit's kit, shared by heroes and enemies (docs/plans/rebuild-phase1-arena-sim.md,
## section 2). HeroDef (paths, phase 4) and EnemyDef (threat line, archetype,
## phases, phase 2) will each wrap one.
##   {"id": "rift_hound", "name": "Rift Hound",
##    "stats": {"hp": 220, "atk": 16, "def": 6, "speed": 2, "range": 1},
##    "targeting": "nearest",
##    "mana": {...a ManaDef...},
##    "basic_attack": {...an AbilityDef...},
##    "signature": {...an AbilityDef with a trigger...}}
## Only a unit whose signature fires on mana has a mana bar, and it must have
## one. Passives come with step 4's second half, traits with later steps;
## until then those keys are unknown and rejected.

## The targeting rules built so far (section 4).
const TARGETING_RULES: Array[String] = ["nearest"]

var id: String
var name: String
var stats: UnitStats
var targeting: String = "nearest"
## Null: no mana bar.
var mana: ManaDef = null
var basic_attack: AbilityDef
## Null: no signature.
var signature: AbilityDef = null


static func read(reader: DataReader) -> UnitDef:
	var def := UnitDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	var stats_reader: DataReader = reader.req_object("stats")
	def.stats = UnitStats.read(stats_reader) if stats_reader != null else UnitStats.make(1)
	def.targeting = reader.opt_string_choice("targeting", "nearest", TARGETING_RULES)
	if reader.has("mana"):
		var mana_reader: DataReader = reader.req_object("mana")
		def.mana = ManaDef.read(mana_reader) if mana_reader != null else null
	var attack_reader: DataReader = reader.req_object("basic_attack")
	def.basic_attack = AbilityDef.read(attack_reader) if attack_reader != null else null
	if reader.has("signature"):
		var signature_reader: DataReader = reader.req_object("signature")
		def.signature = AbilityDef.read_signature(signature_reader) if signature_reader != null else null
	var mana_signature: bool = def.signature != null and def.signature.trigger.kind == TriggerDef.Kind.MANA
	if mana_signature and def.mana == null:
		reader.error("a mana signature needs \"mana\"")
	if def.mana != null and not mana_signature:
		reader.error("\"mana\": only a unit whose signature fires on mana has a mana bar")
	if def.signature != null and def.basic_attack != null and def.signature.id == def.basic_attack.id:
		reader.error("the signature and the basic attack need different ids (\"%s\")" % def.signature.id)
	reader.finish()
	return def


func has_mana() -> bool:
	return mana != null
