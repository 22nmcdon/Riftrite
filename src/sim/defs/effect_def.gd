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
## `amount` (or `stacks`) is the base value. An optional "scaling" object adds
## a share of the holder's stats, in basis points of each stat:
##   "scaling": {"atk": 6000, "atsp": 2000}  ->  base + 60% ATK + 20% ATSP
## (Not allowed with amount_bp_of_damage, which scales from the hit instead.)

enum Trigger { ON_FIRE, ON_HIT, ON_CRIT }
enum Type { DAMAGE, HEAL, SHIELD, APPLY_STATUS }
enum Target {
	HIT_TARGET,
	SELF,
	ALLY_LOWEST_HP,
	ENEMY_FRONT,
	ENEMY_BACK,
	ENEMY_RANDOM,
	ENEMY_LOWEST_HP,
	LINKED_ALLY,
}

const TRIGGER_NAMES: Array[String] = ["on_fire", "on_hit", "on_crit"]
const TYPE_NAMES: Array[String] = ["damage", "heal", "shield", "apply_status"]
const TARGET_NAMES: Array[String] = [
	"hit_target",
	"self",
	"ally_lowest_hp",
	"enemy_front",
	"enemy_back",
	"enemy_random",
	"enemy_lowest_hp",
	"linked_ally",
]

var trigger: Trigger
var type: Type
var target: Target
var amount: int = 0
var amount_bp_of_damage: int = 0
var status_id: String = ""
var stacks: int = 0
## Basis points of each stat added to the base value, indexed by UnitStats.Stat.
var scaling: Array[int] = [0, 0, 0, 0, 0, 0]


static func read(reader: DataReader) -> EffectDef:
	var def := EffectDef.new()
	var trigger_name: String = reader.req_choice("trigger", TRIGGER_NAMES)
	var type_name: String = reader.req_choice("type", TYPE_NAMES)
	var target_name: String = reader.req_choice("target", TARGET_NAMES)
	def.trigger = maxi(TRIGGER_NAMES.find(trigger_name), 0) as Trigger
	def.type = maxi(TYPE_NAMES.find(type_name), 0) as Type
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
		if reader.has("scaling"):
			if def.amount_bp_of_damage > 0:
				reader.error("\"scaling\" can't be combined with amount_bp_of_damage")
			_read_scaling(def, reader.req_object("scaling"))

	# "hit_target" and damage-based shields need a hit to refer to.
	var needs_hit: bool = def.target == Target.HIT_TARGET or def.amount_bp_of_damage > 0
	if needs_hit and not trigger_name.is_empty() and def.trigger == Trigger.ON_FIRE:
		reader.error("\"%s\" needs a hit, so its trigger must be on_hit or on_crit, not on_fire" % (target_name if def.target == Target.HIT_TARGET else "amount_bp_of_damage"))
	reader.finish()
	return def


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
