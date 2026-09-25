class_name ItemDef
extends RefCounted
## An item that sits in a hero's (or enemy's) row and fires on its cooldown.
## Also used for a unit's basic auto-attack, which reads a reduced set of
## fields: it has no size, tags, rarity, or XP, because it takes no slot and
## can't be upgraded (see "Item rules" in CLAUDE.md).

enum Timing { NORMAL, RUSH, STALL }

const TAGS: Array[String] = ["weapon", "tome", "charm", "tool", "food"]
const RARITIES: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]
const TIMING_NAMES: Array[String] = ["normal", "rush", "stall"]
const MAX_SIZE: int = 3
## Rarities whose items may scale their numbers from CRIT and ATSP.
const RATE_SCALING_RARITIES: Array[String] = ["epic", "legendary"]

var id: String
var name: String
## Slots taken: 1 = Small, 2 = Medium, 3 = Large. 0 for a basic auto-attack.
var size: int = 0
var tags: Array[String] = []
var rarity: String = ""
## An auto-attack item replaces its owner's basic auto-attack.
var auto_attack: bool = false
var enemy_only: bool = false
var is_basic_attack: bool = false
var cooldown_ticks: int
var crit_chance_bp: int = 0
var xp_per_fire: int = 0
var timing: Timing = Timing.NORMAL
var effects: Array[EffectDef] = []
## Continuous boosts while their windows are open (not on basic attacks).
var auras: Array[AuraDef] = []


static func read(reader: DataReader) -> ItemDef:
	var def := ItemDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.size = reader.req_int("size", 1, MAX_SIZE)
	def.tags = reader.opt_choice_array("tags", TAGS)
	def.rarity = reader.req_choice("rarity", RARITIES)
	def.auto_attack = reader.opt_bool("auto_attack", false)
	def.enemy_only = reader.opt_bool("enemy_only", false)
	def.xp_per_fire = reader.req_int("xp_per_fire", 0)
	var timing_name: String = reader.opt_string_choice("timing", "normal", TIMING_NAMES)
	def.timing = maxi(TIMING_NAMES.find(timing_name), 0) as Timing
	for aura_reader: DataReader in reader.opt_object_array("auras"):
		def.auras.append(AuraDef.read(aura_reader))
	_read_common(def, reader)
	return def


## Reads a unit's basic auto-attack (no size, tags, rarity, XP, or timing).
static func read_basic_attack(reader: DataReader) -> ItemDef:
	var def := ItemDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.is_basic_attack = true
	_read_common(def, reader)
	return def


static func _read_common(def: ItemDef, reader: DataReader) -> void:
	def.cooldown_ticks = reader.req_ticks("cooldown_ms", FixedMath.MS_PER_TICK)
	def.crit_chance_bp = reader.opt_int("crit_chance_bp", 0, 0, FixedMath.BP_ONE)
	var effect_readers: Array[DataReader] = reader.opt_object_array("effects")
	for effect_reader: DataReader in effect_readers:
		def.effects.append(EffectDef.read(effect_reader))
	if effect_readers.is_empty():
		reader.error("an item needs at least one effect")
	# Common/Uncommon/Rare items and basic auto-attacks treat CRIT and ATSP as
	# rates only (design decision); Epic and Legendary may scale from them.
	if not RATE_SCALING_RARITIES.has(def.rarity):
		for effect: EffectDef in def.effects:
			if effect.scales_from_rate_stats():
				reader.error("only Epic and Legendary items can scale from crit or atsp")
				break
	reader.finish()
