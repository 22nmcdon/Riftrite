class_name HeroDef
extends RefCounted
## A recruitable hero from data/heroes.json: class, stats at rank C, and
## their own basic auto-attack. Item slots come from rank (4 at C, +1 per
## rank), and the loadout comes from the run (or a balance-sim party).

const CLASSES: Array[String] = ["warden", "striker", "arcanist", "mender", "trickster", "ranger"]
const BASE_SLOTS: int = 4

var id: String
var name: String
var hero_class: String
var stats: UnitStats
var basic_attack: ItemDef


static func read(reader: DataReader) -> HeroDef:
	var def := HeroDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.hero_class = reader.req_choice("class", CLASSES)
	var stats_reader: DataReader = reader.req_object("stats")
	def.stats = UnitStats.read(stats_reader) if stats_reader != null else UnitStats.make(1)
	var attack_reader: DataReader = reader.req_object("basic_attack")
	if attack_reader != null:
		def.basic_attack = ItemDef.read_basic_attack(attack_reader)
	reader.finish()
	return def


static func slots_at_rank(rank: int) -> int:
	return BASE_SLOTS + rank
