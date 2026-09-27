class_name ItemDef
extends RefCounted
## An item in a hero's (or enemy's) loadout (docs/plans/fun-redesign.md,
## section 2). Its "slot" says where it goes:
##   basic_attack  the hero's weapon: replaces their built-in basic attack
##                 (at most one); ATSP speeds it up
##   ability       fires on its own cooldown
##   passive       gives auras (and later, reacts to events); never fires
## Also used for a unit's built-in basic auto-attack, which reads a reduced
## set of fields: no slot, tags, keywords, rarity, or XP, because it can't be
## upgraded (see "Item rules" in CLAUDE.md).

enum Timing { NORMAL, RUSH, STALL }

## Item tags and class-fit tags (docs/design.md); items can carry several.
const TAGS: Array[String] = ["weapon", "tome", "charm", "tool", "food", "melee", "ranged", "magic", "healing", "defense"]
const RARITIES: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]
## How many keywords an item carries (docs/plans/infusion-rework.md).
const MAX_KEYWORDS: int = 3
const TIMING_NAMES: Array[String] = ["normal", "rush", "stall"]
enum Slot { BASIC_ATTACK, ABILITY, PASSIVE }
const SLOT_NAMES: Array[String] = ["basic_attack", "ability", "passive"]
const SLOT_LABELS: Array[String] = ["Basic attack", "Ability", "Passive"]
const SLOT_PLURALS: Array[String] = ["Basic attacks", "Abilities", "Passives"]
## Rarities whose items may scale their numbers from CRIT and ATSP.
const RATE_SCALING_RARITIES: Array[String] = ["epic", "legendary"]

var id: String
var name: String
## Which loadout slot it goes in (items only; see the top).
var slot: Slot = Slot.ABILITY
var tags: Array[String] = []
## Keyword ids (data/keywords.json; ContentDb checks them). A Resonant single
## spills to its holder's other items that share one. Empty for built-in
## basic attacks and slotless abilities.
var keywords: Array[String] = []
var rarity: String = ""
## A basic-attack item (slot basic_attack): it replaces its owner's built-in
## basic auto-attack.
var auto_attack: bool = false
var enemy_only: bool = false
var is_basic_attack: bool = false
## A specialization's ability: slotless, fires from the hero (see
## SpecializationDef).
var is_ability: bool = false
## An ability with only triggered effects (no on_fire): it never fires on a
## cooldown.
var triggered_only: bool = false
var cooldown_ticks: int
var crit_chance_bp: int = 0
var xp_per_fire: int = 0
var timing: Timing = Timing.NORMAL
var effects: Array[EffectDef] = []
## Continuous boosts while their windows are open (not on basic attacks).
var auras: Array[AuraDef] = []
## A Legendary's upgrade path (every Legendary has one; nothing else does).
var legendary: LegendaryDef = null


static func read(reader: DataReader) -> ItemDef:
	var def := ItemDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	var slot_name: String = reader.req_choice("slot", SLOT_NAMES)
	def.slot = maxi(SLOT_NAMES.find(slot_name), 0) as Slot
	def.tags = reader.opt_choice_array("tags", TAGS)
	def.keywords = reader.req_string_array("keywords")
	if def.keywords.is_empty() or def.keywords.size() > MAX_KEYWORDS:
		reader.error("an item needs 1 to %d keywords" % MAX_KEYWORDS)
	for i: int in def.keywords.size():
		if def.keywords.find(def.keywords[i]) < i:
			reader.error("keyword \"%s\" is listed twice" % def.keywords[i])
	def.rarity = reader.req_choice("rarity", RARITIES)
	def.auto_attack = def.slot == Slot.BASIC_ATTACK
	def.enemy_only = reader.opt_bool("enemy_only", false)
	def.xp_per_fire = reader.req_int("xp_per_fire", 0)
	var timing_name: String = reader.opt_string_choice("timing", "normal", TIMING_NAMES)
	def.timing = maxi(TIMING_NAMES.find(timing_name), 0) as Timing
	for aura_reader: DataReader in reader.opt_object_array("auras"):
		def.auras.append(AuraDef.read(aura_reader))
	if reader.has("legendary"):
		var path_reader: DataReader = reader.req_object("legendary")
		if path_reader != null:
			def.legendary = LegendaryDef.read(path_reader)
	_read_common(def, reader, true)
	if slot_name.is_empty():
		pass
	elif def.slot == Slot.PASSIVE:
		if not def.effects.is_empty():
			reader.error("a passive doesn't fire, so it has auras but no effects")
		if def.auras.is_empty():
			reader.error("a passive needs auras")
	elif def.effects.is_empty():
		reader.error("%s needs effects (it fires on its cooldown)" % ("a basic attack" if def.auto_attack else "an ability"))
	if def.rarity == "legendary" and def.legendary == null and not reader.has("legendary"):
		reader.error("Legendary items need an upgrade path (\"legendary\")")
	if def.rarity != "legendary" and reader.has("legendary"):
		reader.error("only Legendary items have an upgrade path")
	return def


## Reads a unit's basic auto-attack (no size, tags, rarity, XP, or timing).
static func read_basic_attack(reader: DataReader) -> ItemDef:
	var def := ItemDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.is_basic_attack = true
	_read_common(def, reader, false)
	return def


## `effects_optional`: items may have no effects of their own (passives);
## basic attacks must have some.
static func _read_common(def: ItemDef, reader: DataReader, effects_optional: bool) -> void:
	def.crit_chance_bp = reader.opt_int("crit_chance_bp", 0, 0, FixedMath.BP_ONE)
	var effect_readers: Array[DataReader] = reader.opt_object_array("effects")
	for effect_reader: DataReader in effect_readers:
		def.effects.append(EffectDef.read(effect_reader))
	if effect_readers.is_empty() and not effects_optional:
		reader.error("an item needs at least one effect")
	# Cooldown only matters for items that fire.
	if def.effects.is_empty():
		def.cooldown_ticks = maxi(reader.opt_ticks("cooldown_ms", 0), 1)
	else:
		def.cooldown_ticks = reader.req_ticks("cooldown_ms", FixedMath.MS_PER_TICK)
	# Common/Uncommon/Rare items and basic auto-attacks treat CRIT and ATSP as
	# rates only (design decision); Epic and Legendary may scale from them.
	if not RATE_SCALING_RARITIES.has(def.rarity):
		for effect: EffectDef in def.effects:
			if effect.scales_from_rate_stats():
				reader.error("only Epic and Legendary items can scale from crit or atsp")
				break
	reader.finish()
