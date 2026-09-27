class_name UnitDef
extends RefCounted
## A unit's kit, shared by heroes and enemies (docs/plans/rebuild-phase1-arena-sim.md,
## section 2). HeroDef (paths, phase 4) and EnemyDef (threat line, archetype,
## phases, phase 2) will each wrap one.
##   {"id": "rift_hound", "name": "Rift Hound",
##    "stats": {"hp": 220, "atk": 16, "def": 6, "speed": 2, "range": 1},
##    "targeting": "nearest",
##    "basic_attack": {...an AbilityDef...}}
## Mana, a signature, passives, and traits come with later steps of phase 1;
## until then those keys are unknown and rejected.

## The targeting rules built so far (section 4).
const TARGETING_RULES: Array[String] = ["nearest"]

var id: String
var name: String
var stats: UnitStats
var targeting: String = "nearest"
var basic_attack: AbilityDef


static func read(reader: DataReader) -> UnitDef:
	var def := UnitDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	var stats_reader: DataReader = reader.req_object("stats")
	def.stats = UnitStats.read(stats_reader) if stats_reader != null else UnitStats.make(1)
	def.targeting = reader.opt_string_choice("targeting", "nearest", TARGETING_RULES)
	var attack_reader: DataReader = reader.req_object("basic_attack")
	def.basic_attack = AbilityDef.read(attack_reader) if attack_reader != null else null
	reader.finish()
	return def
