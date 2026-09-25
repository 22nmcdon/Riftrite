class_name EnemyDef
extends RefCounted
## An enemy from data/enemies.json: stats, a set tier (rank), its own basic
## auto-attack, and a hand-made, fixed item layout (with infusions).

const DEFAULT_SLOTS: int = 7

var id: String
var name: String
var stats: UnitStats
var rank: int = 0
var slots: int = DEFAULT_SLOTS
var basic_attack: ItemDef
var items: Array[LoadoutEntry] = []


static func read(reader: DataReader) -> EnemyDef:
	var def := EnemyDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	var stats_reader: DataReader = reader.req_object("stats")
	def.stats = UnitStats.read(stats_reader) if stats_reader != null else UnitStats.make(1)
	def.rank = maxi(TuningDef.TIER_NAMES.find(reader.opt_string_choice("tier", "c", TuningDef.TIER_NAMES)), 0)
	def.slots = reader.opt_int("slots", DEFAULT_SLOTS, 0)
	var attack_reader: DataReader = reader.req_object("basic_attack")
	if attack_reader != null:
		def.basic_attack = ItemDef.read_basic_attack(attack_reader)
	def.items = LoadoutEntry.read_list(reader, "items")
	reader.finish()
	return def
