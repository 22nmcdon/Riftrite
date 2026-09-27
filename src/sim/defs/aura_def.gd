class_name AuraDef
extends RefCounted
## A continuous boost an item gives while its window is open (the whole fight
## if it has no window). Listed under an item's "auras":
##   {"target": "holder_items", "stat": "crit_chance_bp", "value": 1000}
##   {"target": "holder", "stat": "def_bp", "value": 20000,
##    "window": {"until_ms": 8000}, "label": "Rush"}
##
## Targets:
##   self_item: the item itself
##   holder_items: every other item the holder has (their basic attack,
##       abilities, and passives; from a specialization, every item)
##   all_items: every item of every hero on the holder's side. With no
##       filter it boosts *everything* on the side, so it also boosts relic
##       effects and grants (relic numbers are flat; only side-wide boosts
##       change them).
##   matched_items: the items that matched a pair, signature, or
##       transformation synergy (synergies only)
##   units: holder, row_allies (the other allies in the holder's row),
##       all_allies
## An optional "filter" narrows the targets (see AuraFilter):
##   {"target": "all_items", "filter": {"tag": "weapon"}, ...}
## Stats:
##   item stats (any target; on a unit target they boost all its items):
##       damage_bp, heal_bp, shield_bp, over_time_bp  multiply (20000 = x2)
##       crit_chance_bp, cooldown_bp                  add (-1500 = 15% faster)
##   unit stats (unit targets only), multiply:
##       atk_bp, mgk_bp, def_bp, atsp_bp, crit_bp
## An item's aura stops when its holder falls; a relic's lasts all fight.
## Adding a target or stat is a code
## change; say so when you make one.

enum Target {
	SELF_ITEM,
	HOLDER,
	ROW_ALLIES,
	ALL_ALLIES,
	ALL_ITEMS,
	MATCHED_ITEMS,
	HOLDER_ITEMS,
}
enum Stat { DAMAGE_BP, HEAL_BP, SHIELD_BP, OVER_TIME_BP, CRIT_CHANCE_BP, COOLDOWN_BP, ATK_BP, MGK_BP, DEF_BP, ATSP_BP, CRIT_BP }

const TARGET_NAMES: Array[String] = ["self_item", "holder", "row_allies", "all_allies", "all_items", "matched_items", "holder_items"]
const TARGET_LABELS: Array[String] = ["itself", "its holder", "row allies", "all allies", "all items", "matched items", "the holder's other items"]
const STAT_NAMES: Array[String] = [
	"damage_bp", "heal_bp", "shield_bp", "over_time_bp", "crit_chance_bp", "cooldown_bp",
	"atk_bp", "mgk_bp", "def_bp", "atsp_bp", "crit_bp",
]
const STAT_LABELS: Array[String] = [
	"damage", "healing", "shields", "damage over time", "crit chance", "cooldown",
	"ATK", "MGK", "DEF", "ATSP", "CRIT",
]
## Unit stat for each unit-stat aura stat (ATK_BP -> Stat.ATK, ...).
const UNIT_STAT_FOR: Dictionary[int, int] = {
	Stat.ATK_BP: UnitStats.Stat.ATK,
	Stat.MGK_BP: UnitStats.Stat.MGK,
	Stat.DEF_BP: UnitStats.Stat.DEF,
	Stat.ATSP_BP: UnitStats.Stat.ATSP,
	Stat.CRIT_BP: UnitStats.Stat.CRIT,
}

var target: Target
var stat: Stat
var value: int
## Optional name shown with the source, e.g. "Rush" -> "Rush (Dagger)".
var label: String = ""
## Narrows the targets, or null for no filter.
var filter: AuraFilter = null
var window_from_ticks: int = 0
var window_until_ticks: int = -1
## True for an aura from a specialization, innate, or phase part: there is no
## item to leave out, so holder_items reaches every item the holder has.
var from_part: bool = false


static func read(reader: DataReader) -> AuraDef:
	var def := AuraDef.new()
	var target_name: String = reader.req_choice("target", TARGET_NAMES)
	var stat_name: String = reader.req_choice("stat", STAT_NAMES)
	def.target = maxi(TARGET_NAMES.find(target_name), 0) as Target
	def.stat = maxi(STAT_NAMES.find(stat_name), 0) as Stat
	if def.is_additive():
		def.value = reader.req_int("value", -FixedMath.BP_ONE, FixedMath.BP_ONE)
	else:
		def.value = reader.req_int("value", 0)
	if reader.has("label"):
		def.label = reader.req_string("label")
	if reader.has("filter"):
		var filter_reader: DataReader = reader.req_object("filter")
		if filter_reader != null:
			def.filter = AuraFilter.read(filter_reader, def.targets_items())
	EffectDef.read_window(reader, def)
	if not target_name.is_empty() and not stat_name.is_empty() and def.is_unit_stat() and def.targets_items():
		reader.error("\"%s\" boosts a unit, so its target must be a unit, not \"%s\"" % [stat_name, target_name])
	reader.finish()
	return def


func active_at(tick: int) -> bool:
	return tick >= window_from_ticks and (window_until_ticks < 0 or tick < window_until_ticks)


func targets_items() -> bool:
	return target == Target.SELF_ITEM or target == Target.ALL_ITEMS or target == Target.MATCHED_ITEMS or target == Target.HOLDER_ITEMS


## True for an unfiltered all_items aura: it boosts everything on the side,
## relic effects and grants included.
func covers_everything() -> bool:
	return target == Target.ALL_ITEMS and filter == null


func is_unit_stat() -> bool:
	return UNIT_STAT_FOR.has(stat)


func is_additive() -> bool:
	return stat == Stat.CRIT_CHANCE_BP or stat == Stat.COOLDOWN_BP


## For the log, e.g. "x2 damage for the holder's other items" or "+20% crit chance for itself".
func describe() -> String:
	var amount: String
	if is_additive():
		amount = "%s%s %s" % ["+" if value >= 0 else "", ValueBreakdown._percent(value), STAT_LABELS[stat]]
	else:
		amount = "x%s %s" % [ValueBreakdown._ratio(value), STAT_LABELS[stat]]
	var who: String = "the holder's items" if from_part and target == Target.HOLDER_ITEMS else TARGET_LABELS[target]
	return "%s for %s%s" % [amount, who, "" if filter == null else filter.describe()]
