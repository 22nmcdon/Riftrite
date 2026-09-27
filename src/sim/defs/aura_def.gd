class_name AuraDef
extends RefCounted
## A continuous boost while its window is open (the whole fight if it has no
## window):
##   {"target": "holder", "stat": "def_bp", "value": 20000,
##    "window": {"until_ms": 8000}, "label": "Rush"}
##
## Targets (units): holder, all_allies.
## Stats:
##   ability stats (on a unit they boost all its abilities):
##       damage_bp, heal_bp, shield_bp, over_time_bp  multiply (20000 = x2)
##       crit_chance_bp, cooldown_bp                  add (-1500 = 15% faster)
##   unit stats, multiply:
##       atk_bp, mgk_bp, def_bp, atsp_bp, crit_bp
## A unit's aura stops when it falls; a relic's lasts all fight. Adding a
## target or stat is a code change; say so when you make one.
## (The rebuild's gut, phase 0, removed the item targets and filters; the
## arena sim, phase 1, adds what abilities need.)

enum Target { HOLDER, ALL_ALLIES }
enum Stat { DAMAGE_BP, HEAL_BP, SHIELD_BP, OVER_TIME_BP, CRIT_CHANCE_BP, COOLDOWN_BP, ATK_BP, MGK_BP, DEF_BP, ATSP_BP, CRIT_BP }

const TARGET_NAMES: Array[String] = ["holder", "all_allies"]
const TARGET_LABELS: Array[String] = ["its holder", "all allies"]

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
	EffectDef.read_window(reader, def)
	reader.finish()
	return def


func active_at(tick: int) -> bool:
	return tick >= window_from_ticks and (window_until_ticks < 0 or tick < window_until_ticks)


func is_unit_stat() -> bool:
	return UNIT_STAT_FOR.has(stat)


func is_additive() -> bool:
	return stat == Stat.CRIT_CHANCE_BP or stat == Stat.COOLDOWN_BP


## For the log, e.g. "x2 damage for its holder" or "+20% crit chance for all allies".
func describe() -> String:
	var amount: String
	if is_additive():
		amount = "%s%s %s" % ["+" if value >= 0 else "", ValueBreakdown._percent(value), STAT_LABELS[stat]]
	else:
		amount = "x%s %s" % [ValueBreakdown._ratio(value), STAT_LABELS[stat]]
	return "%s for %s" % [amount, TARGET_LABELS[target]]
