class_name AuraDef
extends RefCounted
## A continuous boost an item gives while its window is open (the whole fight
## if it has no window). Listed under an item's "auras":
##   {"target": "adjacent_items", "stat": "crit_chance_bp", "value": 2000}
##   {"target": "holder", "stat": "def_bp", "value": 20000,
##    "window": {"until_ms": 8000}, "label": "Rush"}
##
## Targets:
##   items in the holder's row: self_item, left_item, right_item,
##       adjacent_items, row_items (every other item in the row)
##   all_items: every item of every hero on the holder's side, backup
##       heroes' included. With no filter it boosts *everything* on the
##       side, so it also boosts relic effects and grants (relic numbers
##       are flat; only side-wide boosts change them).
##   units: holder, linked_ally, linked_left_ally, linked_right_ally,
##       linked_allies, row_allies, all_allies (see Targeting.linked)
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
	LEFT_ITEM,
	RIGHT_ITEM,
	ADJACENT_ITEMS,
	ROW_ITEMS,
	HOLDER,
	LINKED_ALLY,
	LINKED_LEFT_ALLY,
	LINKED_RIGHT_ALLY,
	LINKED_ALLIES,
	ROW_ALLIES,
	ALL_ALLIES,
	ALL_ITEMS,
}
enum Stat { DAMAGE_BP, HEAL_BP, SHIELD_BP, OVER_TIME_BP, CRIT_CHANCE_BP, COOLDOWN_BP, ATK_BP, MGK_BP, DEF_BP, ATSP_BP, CRIT_BP }

const TARGET_NAMES: Array[String] = [
	"self_item", "left_item", "right_item", "adjacent_items", "row_items",
	"holder", "linked_ally", "linked_left_ally", "linked_right_ally", "linked_allies", "row_allies", "all_allies", "all_items",
]
const TARGET_LABELS: Array[String] = [
	"itself", "the item to its left", "the item to its right", "adjacent items", "the rest of the row",
	"its holder", "a linked ally", "the linked ally on the left", "the linked ally on the right", "linked allies", "row allies", "all allies", "all items",
]
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
	return target <= Target.ROW_ITEMS or target == Target.ALL_ITEMS


## True for an unfiltered all_items aura: it boosts everything on the side,
## relic effects and grants included.
func covers_everything() -> bool:
	return target == Target.ALL_ITEMS and filter == null


func is_unit_stat() -> bool:
	return UNIT_STAT_FOR.has(stat)


func is_additive() -> bool:
	return stat == Stat.CRIT_CHANCE_BP or stat == Stat.COOLDOWN_BP


## For the log, e.g. "x2 damage for adjacent items" or "+20% crit chance for itself".
func describe() -> String:
	var amount: String
	if is_additive():
		amount = "%s%s %s" % ["+" if value >= 0 else "", ValueBreakdown._percent(value), STAT_LABELS[stat]]
	else:
		amount = "x%s %s" % [ValueBreakdown._ratio(value), STAT_LABELS[stat]]
	return "%s for %s%s" % [amount, TARGET_LABELS[target], "" if filter == null else filter.describe()]
