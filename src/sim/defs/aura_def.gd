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
##                                          long (Steady; a unit starts
##                                          planted). A planted range aura
##                                          also stops the unit walking once
##                                          its target is within the reach
##                                          it'll have planted, so it plants
##                                          there (CombatSim)
##   "while": "below_hp", "below_pct": 30   on while its HP is below that
##                                          share (Last Watch)
##   "while": "ally_standing", "kit": "ash_hound"   on while another of its
##                                          side of that kit stands (phase 5,
##                                          Old Mother Ash's Pack Bond)
##   "per": "fallen_ally"                   counts once for each of its side
##                                          that has fallen (added up, or
##                                          multiplied that many times);
##                                          off while none has
##   "per": "enemy_near", "per_within_hexes": 1   counts once for each
##                                          standing enemy that near it (phase
##                                          8 part 4, Crowd Strength); off
##                                          while none is
##   "while": "state", "state": {...}       on while its holder meets a
##                                          UnitCondition ("Shielded allies
##                                          deal +15%"; phase 5c step 3)
## These are checked every tick (CombatSim.check_conditional_auras).
## Phase 5c step 5b adds stats that add: lifesteal_bp (heals that share of
## the damage its hits deal; LIFESTEAL, not healing), crit_damage_bp (to the
## crit kind of the damage rule), atsp (ATSP points: +30 is +30% attack
## speed), and damage_reduced_bp (takes that much less damage, like Warded);
## and "while": "ally_near", "within_hexes": 1 (on while another standing
## ally is that close). Phase 5c step 5d: "while": "behind_wall",
## "within_hexes": 3 (on while its holder stands behind one of its side's
## walls, within that far of it; Walls.behind).
## Phase 5c step 5c adds stats that add: overheal_shield_bp (what its heals
## would restore past full HP comes back as that share of Shield; Overflow
## Chalice), lifesteal_heals (above 0: its lifesteal is a heal; Blood
## Communion), crit_overflow_bp (a crit's chance past 100% adds this share of
## itself to crit damage; Knife's Edge), def (DEF points), and
## overheal_strike_bp (what its lifesteal would heal past full HP hits its
## target for this share; Shadow Engine), and max_hp_bp (multiplies its max
## HP from the fight's start; HP rises by what max HP gains; The Unbending,
## The Long Watch). And:
##   "step": {"every_ms": 2000, "value": 500}   a planted aura grows by
##                                          `value` for every `every_ms` more
##                                          it stays planted (Stonebound)
##   "per_shield_bp": 5                     its change is the holder's Shield
##                                          times this (no "value"; on while
##                                          it has Shield; Warden's Engine)
##   "per_target_stacks": "marked"          per hit: times the stacks of that
##                                          status on the unit hit (Hunter's
##                                          Engine)
##   "from_basic": true                     per hit: only its basic attack's
##                                          hits (Shadow Engine)
##   "from_signature": true                 per hit: only its signature's
##                                          hits (phase 5c step 6b; Siphon)
## Phase 5c step 6b (the loadout's charms) adds stats that add:
## def_ignore_bp (its hits ignore that share of the target's DEF; Armor
## Breaker), unpushable (above 0: knockbacks and pulls don't move it, logged
## RESISTED; Braced), dodge_every_ms (a hit on it misses, then not again
## until that long has passed; logged DODGED; Sidestep), and halved_hits
## (its first that many hits taken each fight deal half damage; Iron Skin).
## Phase 8 part 3 (the enemy upgrades, docs/plans/rebuild-phase8-act3.md,
## section 2) adds more that add: shield_damage_bp (its hits take that much
## more off a Shield: +10000 is double; Shieldbreaker, the Unbinder),
## sees_stealth (above 0: it can pick and keep a Stealthed or Submerged
## target; Watchful), burn_taken_bp (Burn ticks on it change by that much:
## -5000 is half, noted "cinder-skinned"; Cinder-Skinned), marked_time_bp
## (Marks put on it last that much longer: -5000 is half; Mark-Shy), and
## root_cap_ms (above 0: Roots put on it last at most that long; Anchored);
## and (8c-5c) miss_bp (its basic attack's hits miss that share of the
## time, rolled on the seeded RNG, logged DODGED noted "missed"; the
## Dazzling Moth's dust).
## "vs": {...} (a UnitCondition; damage_bp, crit_chance_bp, and lifesteal_bp;
## phase 5c steps 3 and 5b): the bonus
## counts only on hits against targets that meet it, as power (Decision 12:
## "+25% damage to Rooted enemies"). It isn't folded into the unit's damage
## multiplier; EffectRunner.deal_hit adds it per hit.
## Adding a target, stat, or condition is a code change; say so when you
## make one.
## Phase 8 part 3 (Act 3's enemies, docs/plans/rebuild-phase8-act3.md
## 8c-6a): "only": {...} (a UnitCondition) on an all_allies or allies_near
## aura gives it only to those that meet it now, read against its holder
## (the Spire Chanter: {"same_island": true}); "while": "ally_standing"
## without a "kit" is on while any other unit of its side stands (the Heart
## of the Rift's Ward while its host stands).
## (The rebuild's gut, phase 0, removed the item targets and filters; the
## arena sim, phase 1, adds what abilities need.)

enum Target { HOLDER, ALL_ALLIES, ALLIES_NEAR }
enum Stat { DAMAGE_BP, HEAL_BP, SHIELD_BP, OVER_TIME_BP, CRIT_CHANCE_BP, COOLDOWN_BP, ATK_BP, MGK_BP, DEF_BP, ATSP_BP, CRIT_BP, RANGE, HEALING_TAKEN_BP,
	LIFESTEAL_BP, CRIT_DAMAGE_BP, ATSP, DAMAGE_REDUCED_BP,
	OVERHEAL_SHIELD_BP, LIFESTEAL_HEALS, CRIT_OVERFLOW_BP, DEF, OVERHEAL_STRIKE_BP, MAX_HP_BP,
	DEF_IGNORE_BP, UNPUSHABLE, DODGE_EVERY_MS, HALVED_HITS,
	SHIELD_DAMAGE_BP, SEES_STEALTH, BURN_TAKEN_BP, MARKED_TIME_BP, ROOT_CAP_MS, MISS_BP }
## What turns an aura on, beyond its window.
enum While { ALWAYS, TAUNTING, PLANTED, BELOW_HP, ALLY_STANDING, STATE, ALLY_NEAR, BEHIND_WALL, MOVED, CROWDED, TACTIC }

const TARGET_NAMES: Array[String] = ["holder", "all_allies", "allies_near"]
const TARGET_LABELS: Array[String] = ["its holder", "all allies", "the allies near it"]

const STAT_NAMES: Array[String] = [
	"damage_bp", "heal_bp", "shield_bp", "over_time_bp", "crit_chance_bp", "cooldown_bp",
	"atk_bp", "mgk_bp", "def_bp", "atsp_bp", "crit_bp", "range", "healing_taken_bp",
	"lifesteal_bp", "crit_damage_bp", "atsp", "damage_reduced_bp",
	"overheal_shield_bp", "lifesteal_heals", "crit_overflow_bp", "def", "overheal_strike_bp", "max_hp_bp",
	"def_ignore_bp", "unpushable", "dodge_every_ms", "halved_hits",
	"shield_damage_bp", "sees_stealth", "burn_taken_bp", "marked_time_bp", "root_cap_ms", "miss_bp",
]
const WHILE_NAMES: Array[String] = ["always", "taunting", "planted", "below_hp", "ally_standing", "state", "ally_near", "behind_wall", "moved", "crowded", "tactic"]
## The stats that add rather than multiply. The rest are factors (x1.1);
## several of one stat add their changes (the damage rule, phase 5c).
const ADDITIVE: Array[Stat] = [Stat.CRIT_CHANCE_BP, Stat.COOLDOWN_BP, Stat.RANGE, Stat.LIFESTEAL_BP, Stat.CRIT_DAMAGE_BP, Stat.ATSP, Stat.DAMAGE_REDUCED_BP,
	Stat.OVERHEAL_SHIELD_BP, Stat.LIFESTEAL_HEALS, Stat.CRIT_OVERFLOW_BP, Stat.DEF, Stat.OVERHEAL_STRIKE_BP,
	Stat.DEF_IGNORE_BP, Stat.UNPUSHABLE, Stat.DODGE_EVERY_MS, Stat.HALVED_HITS,
	Stat.SHIELD_DAMAGE_BP, Stat.SEES_STEALTH, Stat.BURN_TAKEN_BP, Stat.MARKED_TIME_BP, Stat.ROOT_CAP_MS, Stat.MISS_BP]
## The stats an aura worked out per hit may hold ("vs", "from_basic",
## "per_target_stacks").
const VS_STATS: Array[Stat] = [Stat.DAMAGE_BP, Stat.CRIT_CHANCE_BP, Stat.LIFESTEAL_BP, Stat.CRIT_DAMAGE_BP, Stat.HEAL_BP, Stat.SHIELD_BP]
const STAT_LABELS: Array[String] = [
	"damage", "healing", "shields", "damage over time", "crit chance", "cooldown",
	"ATK", "MGK", "DEF", "ATSP", "CRIT", "range", "healing taken",
	"lifesteal", "crit damage", "ATSP", "damage taken",
	"of overheal as Shield", "lifesteal heals", "of crit chance past 100% as crit damage", "DEF", "of lifesteal overheal as damage to its target", "max HP",
	"of the target's DEF ignored", "can't be knocked back", "a hit misses every", "hits taken at half damage",
	"damage to Shields", "can target the stealthed", "Burn damage taken", "how long Marks on it last", "Roots on it last at most", "of its attacks missing",
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
## ally_standing: the kit an ally must be.
var ally_kit: String = ""
## Counts once per fallen ally.
var per_fallen_ally: bool = false
## Counts once per standing enemy within this many plane units of its holder
## (phase 8 part 4; 0: not per enemy).
var per_enemy_range: int = 0
## state: the condition its holder must meet.
var state: UnitCondition = null
## damage_bp, crit_chance_bp, lifesteal_bp: the targets it counts against
## (null: every hit).
var vs: UnitCondition = null
## all_allies, allies_near: only those that meet it now, against its holder
## (phase 8 part 3; null: every one).
var only: UnitCondition = null
## ally_near: how close (plane units).
var near_range: int = 0
## planted: every this many ticks more, it grows by step_value (0: never).
var step_ticks: int = 0
var step_value: int = 0
## Its change is the holder's Shield times this (0: its value).
var per_shield_bp: int = 0
## Per hit: times the stacks of this status on the unit hit ("": once).
var per_target_stacks: String = ""
## Per hit: only its holder's basic attack's hits.
var from_basic: bool = false
## Per hit: only its holder's signature's hits (phase 5c step 6b; Siphon,
## Execution).
var from_signature: bool = false
## Phase 5c step 7c (the upgrade pools): per hit, only on targets this near
## its holder (plane units; 0: any; Close Quarters); "moved": how recently
## it moved (Restless); "crowded": how many enemies, within near_range
## (Crowd Sense); the target allies_near's reach (Sanctuary).
var hit_range: int = 0
var moved_ticks: int = 0
var crowd: int = 0
var target_range: int = 0


static func read(reader: DataReader) -> AuraDef:
	var def := AuraDef.new()
	var target_name: String = reader.req_choice("target", TARGET_NAMES)
	var stat_name: String = reader.req_choice("stat", STAT_NAMES)
	def.target = maxi(TARGET_NAMES.find(target_name), 0) as Target
	if def.target == Target.ALLIES_NEAR:
		def.target_range = reader.req_int("target_within_hexes", 1, 8) * HexGrid.HEX
	def.stat = maxi(STAT_NAMES.find(stat_name), 0) as Stat
	if reader.has("per_shield_bp"):
		def.per_shield_bp = reader.req_int("per_shield_bp", 1, FixedMath.BP_ONE)
		if reader.has("value"):
			reader.error("an aura per Shield takes its change from the Shield, so it has no \"value\"")
	elif def.is_additive():
		def.value = reader.req_int("value", -FixedMath.BP_ONE, 10 * FixedMath.BP_ONE)
	else:
		def.value = reader.req_int("value", 0)
	if reader.has("label"):
		def.label = reader.req_string("label")
	if reader.has("while"):
		def.while_kind = maxi(WHILE_NAMES.find(reader.req_choice("while", WHILE_NAMES.slice(1, WHILE_NAMES.size() - 1))), 0) as While
		def.while_taunting = def.while_kind == While.TAUNTING
		match def.while_kind:
			While.PLANTED:
				def.after_ticks = reader.req_ticks("after_ms", 0)
			While.BELOW_HP:
				def.below_bp = reader.req_int("below_pct", 1, 99) * 100
			While.ALLY_STANDING:
				def.ally_kit = reader.opt_string("kit", "")
			While.STATE:
				def.state = UnitCondition.read(reader.req_object("state"))
			While.ALLY_NEAR, While.BEHIND_WALL:
				def.near_range = reader.req_int("within_hexes", 1, 8) * HexGrid.HEX
			While.MOVED:
				def.moved_ticks = reader.req_ticks("within_ms", FixedMath.MS_PER_TICK)
			While.CROWDED:
				def.crowd = reader.req_int("enemies", 1, 30)
				def.near_range = reader.req_int("within_hexes", 1, 8) * HexGrid.HEX
	if reader.has("vs"):
		def.vs = UnitCondition.read(reader.req_object("vs"))
		if not VS_STATS.has(def.stat):
			reader.error("only a damage_bp, crit_chance_bp, lifesteal_bp, crit_damage_bp, heal_bp, or shield_bp aura can be \"vs\" some targets")
	if reader.has("only"):
		def.only = UnitCondition.read(reader.req_object("only"))
		if def.target == Target.HOLDER:
			reader.error("only an aura on allies has \"only\"")
	if reader.has("vs_within_hexes"):
		def.hit_range = reader.req_int("vs_within_hexes", 1, 8) * HexGrid.HEX
		if not VS_STATS.has(def.stat):
			reader.error("only an aura worked out per hit can be \"vs_within_hexes\"")
	if reader.has("per"):
		var per: String = reader.req_choice("per", ["fallen_ally", "enemy_near"])
		def.per_fallen_ally = per == "fallen_ally"
		if per == "enemy_near":
			def.per_enemy_range = reader.req_int("per_within_hexes", 1, 8) * HexGrid.HEX
	if reader.has("per_within_hexes") and def.per_enemy_range == 0:
		reader.error("only an aura \"per\": \"enemy_near\" has \"per_within_hexes\"")
	if reader.has("step"):
		var step: DataReader = reader.req_object("step")
		if step != null:
			def.step_ticks = step.req_ticks("every_ms", FixedMath.MS_PER_TICK)
			def.step_value = step.req_int("value")
			step.finish()
		if def.while_kind != While.PLANTED:
			reader.error("only a planted aura has a \"step\"")
	def.per_target_stacks = reader.opt_string("per_target_stacks", "")
	def.from_basic = reader.opt_bool("from_basic", false)
	def.from_signature = reader.opt_bool("from_signature", false)
	if def.from_basic and def.from_signature:
		reader.error("an aura is from its basic attack or its signature, not both")
	if (def.from_basic or def.from_signature or not def.per_target_stacks.is_empty()) and not VS_STATS.has(def.stat):
		reader.error("only a damage_bp, crit_chance_bp, lifesteal_bp, or crit_damage_bp aura is worked out per hit")
	if def.per_shield_bp > 0 and def.is_per_hit():
		reader.error("an aura per Shield can't also be worked out per hit")
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
	return while_kind == While.PLANTED or while_kind == While.BELOW_HP or while_kind == While.ALLY_STANDING or while_kind == While.STATE \
		or while_kind == While.ALLY_NEAR or while_kind == While.BEHIND_WALL or while_kind == While.TACTIC or per_fallen_ally or per_shield_bp > 0 \
		or per_enemy_range > 0 or while_kind == While.MOVED or while_kind == While.CROWDED or target == Target.ALLIES_NEAR or only != null


## Worked out per hit (EffectRunner), not folded into the unit's stats.
func is_per_hit() -> bool:
	return vs != null or from_basic or from_signature or not per_target_stacks.is_empty() or hit_range > 0


## For the log, e.g. "x2 damage for its holder" or "+20% crit chance for all allies".
func describe() -> String:
	var amount: String
	if per_shield_bp > 0:
		amount = "+%s %s per point of Shield" % [ValueBreakdown._percent(per_shield_bp), STAT_LABELS[stat]]
	elif stat == Stat.RANGE or stat == Stat.ATSP or stat == Stat.DEF:
		amount = "%s%d %s" % ["+" if value >= 0 else "", value, STAT_LABELS[stat]]
	elif stat == Stat.UNPUSHABLE:
		amount = STAT_LABELS[stat]
	elif stat == Stat.DODGE_EVERY_MS:
		amount = "a hit misses every %s" % _seconds_ms(value)
	elif stat == Stat.HALVED_HITS:
		amount = "its first %d hits taken at half damage" % value
	elif stat == Stat.SEES_STEALTH:
		amount = STAT_LABELS[stat]
	elif stat == Stat.DAMAGE_REDUCED_BP:
		# Less damage taken reads as a minus (phase 8 part 3, the Heart's Ward).
		amount = "%s%s %s" % ["-" if value >= 0 else "+", ValueBreakdown._percent(absi(value)), STAT_LABELS[stat]]
	elif stat == Stat.ROOT_CAP_MS:
		amount = "Roots on it last at most %s" % _seconds_ms(value)
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
			if step_ticks > 0:
				condition += ", %s%d more every %s" % ["+" if step_value >= 0 else "", step_value, _seconds(step_ticks)]
		While.BELOW_HP:
			condition = " while below %s HP" % ValueBreakdown._percent(below_bp)
		While.ALLY_STANDING:
			condition = " while a %s stands" % ally_kit.replace("_", " ") if not ally_kit.is_empty() else " while another of its side stands"
		While.STATE:
			condition = " while %s" % state.describe()
		While.ALLY_NEAR:
			@warning_ignore("integer_division")
			condition = " while an ally is within %d hex%s" % [near_range / HexGrid.HEX, "" if near_range == HexGrid.HEX else "es"]
		While.TACTIC:
			condition = " while it follows its tactic"
		While.BEHIND_WALL:
			@warning_ignore("integer_division")
			condition = " while behind an allied wall (within %d hex%s)" % [near_range / HexGrid.HEX, "" if near_range == HexGrid.HEX else "es"]
	if vs != null:
		condition = " against %s%s" % [vs.describe(), condition]
	if only != null:
		condition += " (only those %s)" % only.describe()
	if per_fallen_ally:
		condition += " for each fallen ally"
	if per_enemy_range > 0:
		@warning_ignore("integer_division")
		condition += " for each enemy within %d hex%s" % [per_enemy_range / HexGrid.HEX, "" if per_enemy_range == HexGrid.HEX else "es"]
	if not per_target_stacks.is_empty():
		condition += " per %s stack on the unit hit" % per_target_stacks.replace("_", " ")
	if from_basic:
		condition += " on its basic attack's hits"
	return "%s for %s%s" % [amount, TARGET_LABELS[target], condition]


static func _seconds_ms(ms: int) -> String:
	@warning_ignore("integer_division")
	return _seconds(ms / FixedMath.MS_PER_TICK)


static func _seconds(ticks: int) -> String:
	var ms: int = ticks * FixedMath.MS_PER_TICK
	@warning_ignore("integer_division")
	return "%ds" % (ms / 1000) if ms % 1000 == 0 else "%d.%ds" % [ms / 1000, (ms % 1000) / 100]
