class_name EffectDef
extends RefCounted
## One effect entry: WHEN it happens (trigger), WHAT it does (type), and WHO it
## affects (target). This is the shared vocabulary for essences, alloys,
## items, relics, and synergies (CLAUDE.md rule 3). Adding a trigger, type, or
## target is a code change; say so when you make one.
##
## Fields per type:
##   damage:       amount
##   heal:         amount
##   shield:       exactly one of amount, amount_bp_of_damage
##   apply_status: status, stacks
##   cleanse:      amount_bp; strips that share of the target's
##                 damage-over-time stacks (times each status's
##                 cleanse_effectiveness_bp, like heals do)
##   charge:       amount_ms; advances *items'* cooldowns, so its target is
##                 an item target (see ITEM_TARGET_NAMES):
##                 self_item, left_item, right_item, adjacent_items,
##                 row_items (in the holder's row), or partner_items (the
##                 other items of the pair synergy that granted it)
## `amount` (or `stacks`) is the base value. An optional "scaling" object adds
## a share of the holder's stats, in basis points of each stat:
##   "scaling": {"atk": 6000, "atsp": 2000}  ->  base + 60% ATK + 20% ATSP
## (Not allowed with amount_bp_of_damage, which scales from the hit instead.)
## An optional "window" limits the effect to part of the fight:
##   "window": {"from_ms": 0, "until_ms": 8000}   (either end optional)
## Rush and Stall items use windows; outside its window the effect does nothing.
##
## Targets that reach several units (each gets its own hit/heal/...):
##   all_enemies, all_allies (standing units, in resolution order)
##   linked_ally (the ally just left of the holder in its row, else just
##   right), linked_left_ally, linked_right_ally, linked_allies (both),
##   row_allies (every other ally in the holder's row)
##
## Relic effects (read with relic = true) have no holder, so their triggers
## and targets differ:
##   on_fire            on the relic's own cooldown_ms
##   on_fight_start     once, at tick 0, before anything fires
##   at_time            once, at "at_ms"
##   on_ally_below_hp   when an ally first drops below "threshold_bp" of max
##                      HP while still standing; "once": true means only the
##                      first ally in the fight, otherwise once per ally
##   trigger_ally       target: the ally that set off on_ally_below_hp
## Relic numbers are flat: no "scaling" (see AuraDef.covers_everything for
## what can boost them). Targets that need a spot on the field are rejected.
## A specialization's ability (read with ability = true) takes the relic
## triggers too, but it belongs to a hero: its numbers scale from the hero's
## stats, and hero-relative targets work.

enum Trigger { ON_FIRE, ON_HIT, ON_CRIT, ON_FIGHT_START, AT_TIME, ON_ALLY_BELOW_HP }
enum Type { DAMAGE, HEAL, SHIELD, APPLY_STATUS, CHARGE, CLEANSE }
enum ItemTarget { SELF_ITEM, LEFT_ITEM, RIGHT_ITEM, ADJACENT_ITEMS, ROW_ITEMS, PARTNER_ITEMS }
enum Target {
	HIT_TARGET,
	SELF,
	ALLY_LOWEST_HP,
	ENEMY_FRONT,
	ENEMY_BACK,
	ENEMY_RANDOM,
	ENEMY_LOWEST_HP,
	LINKED_ALLY,
	ALL_ENEMIES,
	ALL_ALLIES,
	LINKED_LEFT_ALLY,
	LINKED_RIGHT_ALLY,
	LINKED_ALLIES,
	ROW_ALLIES,
	TRIGGER_ALLY,
}

const TRIGGER_NAMES: Array[String] = ["on_fire", "on_hit", "on_crit", "on_fight_start", "at_time", "on_ally_below_hp"]
const ITEM_TRIGGERS: Array[Trigger] = [Trigger.ON_FIRE, Trigger.ON_HIT, Trigger.ON_CRIT]
const RELIC_TRIGGERS: Array[Trigger] = [Trigger.ON_FIRE, Trigger.ON_FIGHT_START, Trigger.AT_TIME, Trigger.ON_ALLY_BELOW_HP]
## Targets that need the effect's holder to stand on the field.
const FIELD_ONLY_TARGETS: Array[Target] = [
	Target.HIT_TARGET, Target.SELF, Target.LINKED_ALLY, Target.LINKED_LEFT_ALLY,
	Target.LINKED_RIGHT_ALLY, Target.LINKED_ALLIES, Target.ROW_ALLIES,
]
const TYPE_NAMES: Array[String] = ["damage", "heal", "shield", "apply_status", "charge", "cleanse"]
const ITEM_TARGET_NAMES: Array[String] = ["self_item", "left_item", "right_item", "adjacent_items", "row_items", "partner_items"]
const TARGET_NAMES: Array[String] = [
	"hit_target",
	"self",
	"ally_lowest_hp",
	"enemy_front",
	"enemy_back",
	"enemy_random",
	"enemy_lowest_hp",
	"linked_ally",
	"all_enemies",
	"all_allies",
	"linked_left_ally",
	"linked_right_ally",
	"linked_allies",
	"row_allies",
	"trigger_ally",
]

var trigger: Trigger
var type: Type
var target: Target
## charge: which items it charges.
var item_target: ItemTarget = ItemTarget.SELF_ITEM
## damage/heal/shield: the amount; charge: ticks of cooldown it advances.
var amount: int = 0
var amount_bp_of_damage: int = 0
var status_id: String = ""
var stacks: int = 0
## Basis points of each stat added to the base value, indexed by UnitStats.Stat.
var scaling: Array[int] = [0, 0, 0, 0, 0, 0]
## Fight ticks the effect is active in: [from, until). until = -1: no end.
var window_from_ticks: int = 0
var window_until_ticks: int = -1
## at_time: the tick it fires on.
var at_ticks: int = 0
## on_ally_below_hp: the HP share (basis points of max HP) to drop below.
var threshold_bp: int = 0
## on_ally_below_hp: only the first ally in the fight sets it off.
var once: bool = false


## `relic`: read a relic's effect (relic triggers and targets, flat numbers).
## `ability`: read a specialization ability's effect (relic triggers, hero
## targets, scaled numbers).
static func read(reader: DataReader, relic: bool = false, ability: bool = false) -> EffectDef:
	var def := EffectDef.new()
	var trigger_name: String = reader.req_choice("trigger", TRIGGER_NAMES)
	var type_name: String = reader.req_choice("type", TYPE_NAMES)
	def.trigger = maxi(TRIGGER_NAMES.find(trigger_name), 0) as Trigger
	def.type = maxi(TYPE_NAMES.find(type_name), 0) as Type
	var target_name: String = ""
	if type_name == "charge":
		def.item_target = maxi(ITEM_TARGET_NAMES.find(reader.req_choice("target", ITEM_TARGET_NAMES)), 0) as ItemTarget
		# The unit target is unused; SELF keeps the hit checks below quiet.
		def.target = Target.SELF
		if relic:
			reader.error("a relic holds no item, so its effects can't charge")
	else:
		target_name = reader.req_choice("target", TARGET_NAMES)
		def.target = maxi(TARGET_NAMES.find(target_name), 0) as Target

	if not type_name.is_empty():
		match def.type:
			Type.DAMAGE, Type.HEAL:
				def.amount = reader.req_int("amount", 0)
			Type.SHIELD:
				if reader.has("amount") == reader.has("amount_bp_of_damage"):
					reader.error("shield needs exactly one of \"amount\" or \"amount_bp_of_damage\"")
				def.amount = reader.opt_int("amount", 0, 0)
				def.amount_bp_of_damage = reader.opt_int("amount_bp_of_damage", 0, 0)
			Type.APPLY_STATUS:
				def.status_id = reader.req_string("status")
				def.stacks = reader.req_int("stacks", 1)
			Type.CHARGE:
				def.amount = reader.req_ticks("amount_ms", FixedMath.MS_PER_TICK)
			Type.CLEANSE:
				def.amount = reader.req_int("amount_bp", 1, FixedMath.BP_ONE)
		if reader.has("scaling"):
			if def.amount_bp_of_damage > 0:
				reader.error("\"scaling\" can't be combined with amount_bp_of_damage")
			_read_scaling(def, reader.req_object("scaling"))

	read_window(reader, def)
	if not trigger_name.is_empty():
		_read_trigger_fields(def, reader, relic, ability)

	# "hit_target" and damage-based shields need a hit to refer to.
	var needs_hit: bool = def.target == Target.HIT_TARGET or def.amount_bp_of_damage > 0
	if needs_hit and not trigger_name.is_empty() and not relic and not ability and def.trigger == Trigger.ON_FIRE:
		reader.error("\"%s\" needs a hit, so its trigger must be on_hit or on_crit, not on_fire" % (target_name if def.target == Target.HIT_TARGET else "amount_bp_of_damage"))
	reader.finish()
	return def


## Checks the trigger is allowed here and reads its extra fields.
static func _read_trigger_fields(def: EffectDef, reader: DataReader, relic: bool, ability: bool) -> void:
	var allowed: Array[Trigger] = RELIC_TRIGGERS if relic or ability else ITEM_TRIGGERS
	if not allowed.has(def.trigger):
		reader.error("%s effects can't use the trigger \"%s\"" % ["relic" if relic else ("ability" if ability else "item"), TRIGGER_NAMES[def.trigger]])
	match def.trigger:
		Trigger.AT_TIME:
			def.at_ticks = reader.req_ticks("at_ms", FixedMath.MS_PER_TICK)
		Trigger.ON_ALLY_BELOW_HP:
			def.threshold_bp = reader.req_int("threshold_bp", 1, FixedMath.BP_ONE - 1)
			def.once = reader.opt_bool("once", false)
	if def.target == Target.TRIGGER_ALLY and def.trigger != Trigger.ON_ALLY_BELOW_HP:
		reader.error("\"trigger_ally\" only works with the on_ally_below_hp trigger")
	if ability and def.target == Target.HIT_TARGET:
		reader.error("an ability has no hit, so it can't use hit_target")
	if not relic:
		return
	if FIELD_ONLY_TARGETS.has(def.target):
		reader.error("\"%s\" needs a spot on the field, so a relic can't use it" % TARGET_NAMES[def.target])
	if def.amount_bp_of_damage > 0:
		reader.error("a relic has no hit, so it can't use amount_bp_of_damage")
	if def.scaling.any(func(ratio: int) -> bool: return ratio != 0):
		reader.error("relic numbers are flat, so relic effects can't have \"scaling\"")


## Reads an optional "window" object into `holder` (an EffectDef or AuraDef,
## anything with window_from_ticks / window_until_ticks).
static func read_window(reader: DataReader, holder: Object) -> void:
	if not reader.has("window"):
		return
	var window: DataReader = reader.req_object("window")
	if window == null:
		return
	var from_ticks: int = window.opt_ticks("from_ms", 0)
	var until_ticks: int = -1
	if window.has("until_ms"):
		until_ticks = window.req_ticks("until_ms", FixedMath.MS_PER_TICK)
		if until_ticks <= from_ticks:
			window.error("until_ms must be later than from_ms")
	window.finish()
	holder.set("window_from_ticks", from_ticks)
	holder.set("window_until_ticks", until_ticks)


## True if the effect is active at this tick of the fight.
func active_at(tick: int) -> bool:
	return tick >= window_from_ticks and (window_until_ticks < 0 or tick < window_until_ticks)


static func _read_scaling(def: EffectDef, reader: DataReader) -> void:
	if reader == null:
		return
	for key: String in reader.map_keys():
		var stat: int = UnitStats.STAT_NAMES.find(key)
		if stat < 0:
			reader.error("unknown stat \"%s\" (expected one of: %s)" % [key, ", ".join(UnitStats.STAT_NAMES)])
			continue
		def.scaling[stat] = reader.req_int(key, 0)
	reader.finish()


## The base value this effect scales (amount, or stacks for apply_status).
func base_value() -> int:
	return stacks if type == Type.APPLY_STATUS else amount


func scales_from_rate_stats() -> bool:
	for stat: UnitStats.Stat in UnitStats.RATE_STATS:
		if scaling[stat] != 0:
			return true
	return false
