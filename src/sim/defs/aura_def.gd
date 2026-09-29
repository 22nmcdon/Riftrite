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
##   range: adds hexes to its reach (phase 4, Steady)
##   healing_taken_bp: multiplies the healing it gets (phase 4, Last Watch's
##       cost; 7000 = 30% less)
## A unit's aura stops when it falls; a relic's lasts all fight.
## "while": "taunting" keeps a unit's aura on only while at least one
## standing enemy's Taunt in effect is its own (Brannoc's Hold the Line;
## docs/plans/rebuild-phase2-heroes-enemies.md, section 4). Phase 4 adds:
##   "while": "planted", "after_ms": 2000   on once it hasn't moved for that
##                                          long (Steady)
##   "while": "below_hp", "below_pct": 30   on while its HP is below that
##                                          share (Last Watch)
##   "per": "fallen_ally"                   counts once for each of its side
##                                          that has fallen (added up, or
##                                          multiplied that many times);
##                                          off while none has
## These are checked every tick (CombatSim.check_conditional_auras).
## Adding a target, stat, or condition is a code change; say so when you
## make one.
## (The rebuild's gut, phase 0, removed the item targets and filters; the
## arena sim, phase 1, adds what abilities need.)

enum Target { HOLDER, ALL_ALLIES }
enum Stat { DAMAGE_BP, HEAL_BP, SHIELD_BP, OVER_TIME_BP, CRIT_CHANCE_BP, COOLDOWN_BP, ATK_BP, MGK_BP, DEF_BP, ATSP_BP, CRIT_BP, RANGE, HEALING_TAKEN_BP }
## What turns an aura on, beyond its window.
enum While { ALWAYS, TAUNTING, PLANTED, BELOW_HP }

const TARGET_NAMES: Array[String] = ["holder", "all_allies"]
const TARGET_LABELS: Array[String] = ["its holder", "all allies"]

const STAT_NAMES: Array[String] = [
	"damage_bp", "heal_bp", "shield_bp", "over_time_bp", "crit_chance_bp", "cooldown_bp",
	"atk_bp", "mgk_bp", "def_bp", "atsp_bp", "crit_bp", "range", "healing_taken_bp",
]
const WHILE_NAMES: Array[String] = ["always", "taunting", "planted", "below_hp"]
## The stats that add rather than multiply.
const ADDITIVE: Array[Stat] = [Stat.CRIT_CHANCE_BP, Stat.COOLDOWN_BP, Stat.RANGE]
const STAT_LABELS: Array[String] = [
	"damage", "healing", "shields", "damage over time", "crit chance", "cooldown",
	"ATK", "MGK", "DEF", "ATSP", "CRIT", "range", "healing taken",
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
## On only while its holder is taunting someone.
var while_taunting: bool = false
var while_kind: While = While.ALWAYS
## planted: how long without moving.
var after_ticks: int = 0
## below_hp: the HP share (basis points) to be below.
var below_bp: int = 0
## Counts once per fallen ally.
var per_fallen_ally: bool = false


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
	if reader.has("while"):
		def.while_kind = maxi(WHILE_NAMES.find(reader.req_choice("while", WHILE_NAMES.slice(1))), 0) as While
		def.while_taunting = def.while_kind == While.TAUNTING
		match def.while_kind:
			While.PLANTED:
				def.after_ticks = reader.req_ticks("after_ms", 0)
			While.BELOW_HP:
				def.below_bp = reader.req_int("below_pct", 1, 99) * 100
	if reader.has("per"):
		def.per_fallen_ally = reader.req_choice("per", ["fallen_ally"]) == "fallen_ally"
	EffectDef.read_window(reader, def)
	reader.finish()
	return def


func active_at(tick: int) -> bool:
	return tick >= window_from_ticks and (window_until_ticks < 0 or tick < window_until_ticks)


func is_unit_stat() -> bool:
	return UNIT_STAT_FOR.has(stat)


func is_additive() -> bool:
	return ADDITIVE.has(stat)


## Checked each tick, not just when a window opens or closes.
func is_conditional() -> bool:
	return while_kind == While.PLANTED or while_kind == While.BELOW_HP or per_fallen_ally


## For the log, e.g. "x2 damage for its holder" or "+20% crit chance for all allies".
func describe() -> String:
	var amount: String
	if stat == Stat.RANGE:
		amount = "%s%d %s" % ["+" if value >= 0 else "", value, STAT_LABELS[stat]]
	elif is_additive():
		amount = "%s%s %s" % ["+" if value >= 0 else "", ValueBreakdown._percent(value), STAT_LABELS[stat]]
	else:
		amount = "x%s %s" % [ValueBreakdown._ratio(value), STAT_LABELS[stat]]
	var condition: String = ""
	match while_kind:
		While.TAUNTING:
			condition = " while taunting"
		While.PLANTED:
			condition = " once it hasn't moved for %s" % _seconds(after_ticks)
		While.BELOW_HP:
			condition = " while below %s HP" % ValueBreakdown._percent(below_bp)
	if per_fallen_ally:
		condition += " for each fallen ally"
	return "%s for %s%s" % [amount, TARGET_LABELS[target], condition]


static func _seconds(ticks: int) -> String:
	var ms: int = ticks * FixedMath.MS_PER_TICK
	@warning_ignore("integer_division")
	return "%ds" % (ms / 1000) if ms % 1000 == 0 else "%d.%ds" % [ms / 1000, (ms % 1000) / 100]
