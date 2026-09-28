class_name EffectDef
extends RefCounted
## One effect entry: WHEN it happens (trigger), WHAT it does (type), and WHO it
## affects (target). This is the shared vocabulary for abilities, relics, and
## duo bonds (CLAUDE.md rule 3). Adding a trigger, type, or target is a code
## change; say so when you make one. The arena sim
## (docs/plans/rebuild-phase1-arena-sim.md) adds spatial targets and the
## knockback, pull, leap, charge, area, summon, mana_drain, and
## start_collapse types.
##
## Fields per type:
##   damage:       amount; optional "bonus_per_ally": {"bp": 2500,
##                 "within_hexes": 1, "kit": "rift_pup"} adds bp for each
##                 other standing ally within that many hexes as it fires
##                 (of that kit only, if "kit" is given)
##   heal:         exactly one of amount, amount_bp_of_max_hp (a share of
##                 the healed unit's max HP)
##   shield:       exactly one of amount, amount_bp_of_damage
##   apply_status: status; stacks (damage over time; default 1); optional
##                 duration_ms (a timed status; default: the status's own)
##   cleanse:      amount_bp; strips that share of the target's
##                 damage-over-time stacks (times each status's
##                 cleanse_effectiveness_bp, like heals do)
##   mana_drain:   amount (whole mana taken from the target's bar)
##   knockback:    hexes; pushes the target straight away from the unit
##   pull:         hexes; drags the target straight toward the unit, stopping
##                 when it touches
##   leap:         max_hexes, optional land_ms (tuning's leap_land_ms); the
##                 unit jumps to a free spot touching its target
##   charge:       hexes, optional knockback (hexes); the unit runs straight
##                 at its target and knocks back the first enemy it touches
## (Displacement has the rules. leap and charge move the unit itself, so
## they aim at "target", fire at once, and only signatures have them.)
##   area:         shape (ShapeDef), anchor, optional warning_ms, hits, and
##                 nested effects (no "target" key of its own; Areas has
##                 the rules):
##     {"type": "area", "shape": {"kind": "circle", "radius": 2},
##      "anchor": "target", "warning_ms": 1000, "hits": "enemies",
##      "effects": [{"type": "damage", "amount": 20, "target": "target"}]}
##     anchor: target (centered on the ability's target), self (on the
##             unit), target_direction (a line or cone from the unit aimed
##             at the target); circles and rings take target or self,
##             lines and cones target_direction
##     hits:   enemies, allies, all, or other_allies (allies but the
##             unit itself), by the unit's side
##     Each nested effect aims at "target" (every unit hit), on_fire; no
##     area in an area, and no leap or charge.
##   start_collapse: nothing else, and no "target" key: starts Rift Collapse
##                 now if it hasn't started (Collapse.start_now). Not in an
##                 area.
##   summon:       kit (a kit the fight's setup lists), placement, and no
##                 "target" key; not in an area (Summons has the rules):
##     {"type": "summon", "kit": "rift_pup", "count": 2, "placement": "edges", "near": "target"}
##     {"type": "summon", "kit": "rift_pup", "placement": "adjacent"}
##     {"type": "summon", "kit": "rift_pup", "placement": "hexes", "hexes": [[0, 6], [7, 6]]}
##     edges:    count (default 1) free spots along the safe ground's edge,
##               nearest first to the unit ("near": "self", the default) or
##               to its target ("near": "target")
##     adjacent: count free spots touching the unit
##     hexes:    one on each [col, row] hex, or the free spot nearest it
## `amount` (or `stacks`) is the base value. An optional "scaling" object adds
## a share of the unit's stats, in basis points of each stat:
##   "scaling": {"atk": 6000, "atsp": 2000}  ->  base + 60% ATK + 20% ATSP
## (Not allowed with amount_bp_of_damage, which scales from the hit instead.)
## An optional "window" limits the effect to part of the fight:
##   "window": {"from_ms": 0, "until_ms": 8000}   (either end optional)
##
## "trigger" is optional and defaults to on_fire.
##
## Targets:
##   target       the ability's target (picked by its targeting rule)
##   hit_target   on_hit/on_crit and some events: the unit hit
##   self         the unit itself
##   all_enemies, all_allies   every standing unit of that side, in fight order
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
## Relic numbers are flat: no "scaling". Targets that need a unit on the
## field are rejected.
##
## Event triggers (abilities, not relics): the effect runs when its unit does
## something, read from the combat log each tick:
##   on_ability       another of the unit's abilities fires
##   on_basic_attack  the unit's basic attack fires
##   on_holder_crit   any of the unit's hits crits (hit_target: the unit
##                    hit; amount_bp_of_damage: of that hit)
##   on_shielded      the unit gains Shield (hit_target: the unit)
##   on_hit_taken     an enemy's hit lands on the unit (hit_target: the
##                    attacker; amount_bp_of_damage: of that hit)
##   on_heal          the unit restores HP to an ally (hit_target: them)
##   on_status        the unit applies a status ("statuses": only those;
##                    hit_target: the unit it went on)
##   on_kill          an enemy the unit hit last falls
##   on_hop           the unit hops away (the hop_away trait; added at
##                    playtest gate 1, a code change, for Maren's stealth)
## "every": N runs it on every Nth time. What an event effect does never sets
## off another event effect.
##
## Passive triggers that aren't read from the log (docs/plans/
## rebuild-phase2-heroes-enemies.md, section 4; Passives runs them):
##   on_interval       every "interval_ms" while the unit stands, counted
##                     from when it joined the fight
##   on_ally_below_hp  when an ally (not the unit itself) first drops below
##                     "threshold_bp" of its max HP while standing; once per
##                     ally, or with "once": true only the first
##                     (trigger_ally: that ally)
##   on_fall           as the unit falls, from where it fell: an area
##                     anchored on it, or all_enemies or all_allies
## None of them names a hit, so none can use hit_target or
## amount_bp_of_damage.
## A passive's effects may cast an area on any of these, or on an event
## (never on_hit or on_crit): around the unit (anchor self), or on the unit
## the event names, else the unit's target.

enum Trigger {
	ON_FIRE, ON_HIT, ON_CRIT, ON_FIGHT_START, AT_TIME, ON_ALLY_BELOW_HP,
	ON_ABILITY, ON_BASIC_ATTACK, ON_HOLDER_CRIT, ON_SHIELDED, ON_HIT_TAKEN, ON_HEAL, ON_STATUS, ON_KILL,
	ON_INTERVAL, ON_FALL, ON_HOP,
}
enum Type { DAMAGE, HEAL, SHIELD, APPLY_STATUS, CLEANSE, MANA_DRAIN, KNOCKBACK, PULL, LEAP, CHARGE, AREA, START_COLLAPSE, SUMMON }
enum Placement { EDGES, ADJACENT, HEXES }
enum Anchor { TARGET, SELF, TARGET_DIRECTION }
enum Hits { ENEMIES, ALLIES, ALL, OTHER_ALLIES }
enum Target {
	TARGET,
	HIT_TARGET,
	SELF,
	ALL_ENEMIES,
	ALL_ALLIES,
	TRIGGER_ALLY,
}

const TRIGGER_NAMES: Array[String] = [
	"on_fire", "on_hit", "on_crit", "on_fight_start", "at_time", "on_ally_below_hp",
	"on_ability", "on_basic_attack", "on_holder_crit", "on_shielded", "on_hit_taken", "on_heal", "on_status", "on_kill",
	"on_interval", "on_fall", "on_hop",
]
## The unit's events (see the top).
const EVENT_TRIGGERS: Array[Trigger] = [
	Trigger.ON_ABILITY, Trigger.ON_BASIC_ATTACK, Trigger.ON_HOLDER_CRIT, Trigger.ON_SHIELDED,
	Trigger.ON_HIT_TAKEN, Trigger.ON_HEAL, Trigger.ON_STATUS, Trigger.ON_KILL, Trigger.ON_HOP,
]
## Event triggers that name a unit (hit_target) and those that name a hit
## (amount_bp_of_damage).
const EVENT_UNIT_TRIGGERS: Array[Trigger] = [Trigger.ON_HOLDER_CRIT, Trigger.ON_SHIELDED, Trigger.ON_HIT_TAKEN, Trigger.ON_HEAL, Trigger.ON_STATUS]
const EVENT_HIT_TRIGGERS: Array[Trigger] = [Trigger.ON_HOLDER_CRIT, Trigger.ON_HIT_TAKEN]
const ABILITY_TRIGGERS: Array[Trigger] = [
	Trigger.ON_FIRE, Trigger.ON_HIT, Trigger.ON_CRIT,
	Trigger.ON_ABILITY, Trigger.ON_BASIC_ATTACK, Trigger.ON_HOLDER_CRIT, Trigger.ON_SHIELDED,
	Trigger.ON_HIT_TAKEN, Trigger.ON_HEAL, Trigger.ON_STATUS, Trigger.ON_KILL, Trigger.ON_HOP,
	Trigger.ON_ALLY_BELOW_HP, Trigger.ON_INTERVAL, Trigger.ON_FALL,
]
## What a passive's effects may run on (PartDef).
const PASSIVE_TRIGGERS: Array[Trigger] = [
	Trigger.ON_ABILITY, Trigger.ON_BASIC_ATTACK, Trigger.ON_HOLDER_CRIT, Trigger.ON_SHIELDED,
	Trigger.ON_HIT_TAKEN, Trigger.ON_HEAL, Trigger.ON_STATUS, Trigger.ON_KILL, Trigger.ON_HOP,
	Trigger.ON_ALLY_BELOW_HP, Trigger.ON_INTERVAL, Trigger.ON_FALL,
]
## The passive triggers that aren't events (Passives.run_timed, on_fall).
const UNIT_TRIGGERS: Array[Trigger] = [Trigger.ON_ALLY_BELOW_HP, Trigger.ON_INTERVAL, Trigger.ON_FALL]
const RELIC_TRIGGERS: Array[Trigger] = [Trigger.ON_FIRE, Trigger.ON_FIGHT_START, Trigger.AT_TIME, Trigger.ON_ALLY_BELOW_HP]
## Targets that need the effect's unit to stand on the field.
const FIELD_ONLY_TARGETS: Array[Target] = [Target.TARGET, Target.HIT_TARGET, Target.SELF]
const TYPE_NAMES: Array[String] = ["damage", "heal", "shield", "apply_status", "cleanse", "mana_drain", "knockback", "pull", "leap", "charge", "area", "start_collapse", "summon"]
const PLACEMENT_NAMES: Array[String] = ["edges", "adjacent", "hexes"]
const NEAR_NAMES: Array[String] = ["self", "target"]
## The types with no "target" key: they act from the unit itself.
const UNTARGETED: Array[Type] = [Type.START_COLLAPSE, Type.SUMMON]
const ANCHOR_NAMES: Array[String] = ["target", "self", "target_direction"]
const HITS_NAMES: Array[String] = ["enemies", "allies", "all", "other_allies"]
## The types that move the unit itself.
const MOVES_SELF: Array[Type] = [Type.LEAP, Type.CHARGE]
const TARGET_NAMES: Array[String] = [
	"target",
	"hit_target",
	"self",
	"all_enemies",
	"all_allies",
	"trigger_ally",
]

var trigger: Trigger
var type: Type
var target: Target
## damage/heal/shield: the amount.
var amount: int = 0
var amount_bp_of_damage: int = 0
## heal: a share of the healed unit's max HP (0: `amount` instead).
var amount_bp_of_max_hp: int = 0
## damage: more for each other standing ally near the unit as it fires
## (bp each, within this many plane units, of this kit if not empty).
var bonus_bp_per_ally: int = 0
var bonus_within: int = 0
var bonus_kit: String = ""
## on_interval: how often.
var interval_ticks: int = 0
var status_id: String = ""
var stacks: int = 0
## apply_status: how long a timed status lasts (0: the status's own duration).
var duration_ticks: int = 0
## knockback, pull, charge: how far; leap: how far it can jump (hexes).
var hexes: int = 0
## charge: how far it knocks back the enemy it hits (hexes; 0: not at all).
var knockback_hexes: int = 0
## leap: how long the landing takes (-1: tuning's leap_land_ms).
var land_ticks: int = -1
## area: its shape, where it goes, how long it's warned, whom it hits, and
## what it does to each of them.
var shape: ShapeDef = null
var anchor: Anchor = Anchor.TARGET
var warning_ticks: int = 0
var hits: Hits = Hits.ENEMIES
var area_effects: Array[EffectDef] = []
## summon: the kit, how many, where, and (edges) whether nearest the target.
var summon_kit: String = ""
var count: int = 1
var placement: Placement = Placement.EDGES
var summon_hexes: Array[Vector2i] = []
var near_target: bool = false
## Basis points of each stat added to the base value, indexed by UnitStats.Stat
## (the first SCALING_STATS only).
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
## Event triggers: runs on every Nth event.
var every: int = 1
## on_status: only these statuses (empty = any).
var statuses: Array[String] = []

## `relic`: read a relic's effect (relic triggers and targets, flat numbers).
static func read(reader: DataReader, relic: bool = false) -> EffectDef:
	var def := EffectDef.new()
	var trigger_name: String = reader.opt_string_choice("trigger", "on_fire", TRIGGER_NAMES)
	var type_name: String = reader.req_choice("type", TYPE_NAMES)
	def.trigger = maxi(TRIGGER_NAMES.find(trigger_name), 0) as Trigger
	def.type = maxi(TYPE_NAMES.find(type_name), 0) as Type
	# An area has an anchor instead of a target; start_collapse and summon
	# need none.
	var target_name: String = "target"
	if UNTARGETED.has(def.type) and not type_name.is_empty():
		target_name = "self"
	elif type_name != "area":
		target_name = reader.req_choice("target", TARGET_NAMES)
	def.target = maxi(TARGET_NAMES.find(target_name), 0) as Target

	if not type_name.is_empty():
		match def.type:
			Type.DAMAGE:
				def.amount = reader.req_int("amount", 0)
				if reader.has("bonus_per_ally"):
					_read_bonus(def, reader.req_object("bonus_per_ally"))
			Type.HEAL:
				if reader.has("amount") == reader.has("amount_bp_of_max_hp"):
					reader.error("heal needs exactly one of \"amount\" or \"amount_bp_of_max_hp\"")
				def.amount = reader.opt_int("amount", 0, 0)
				def.amount_bp_of_max_hp = reader.opt_int("amount_bp_of_max_hp", 0, 0, FixedMath.BP_ONE)
			Type.MANA_DRAIN:
				def.amount = reader.req_int("amount", 1)
			Type.KNOCKBACK, Type.PULL:
				def.hexes = reader.req_int("hexes", 1)
			Type.LEAP:
				def.hexes = reader.req_int("max_hexes", 1)
				if reader.has("land_ms"):
					def.land_ticks = reader.req_ticks("land_ms")
			Type.CHARGE:
				def.hexes = reader.req_int("hexes", 1)
				def.knockback_hexes = reader.opt_int("knockback", 0, 0)
			Type.AREA:
				_read_area(def, reader)
			Type.SUMMON:
				_read_summon(def, reader)
			Type.SHIELD:
				if reader.has("amount") == reader.has("amount_bp_of_damage"):
					reader.error("shield needs exactly one of \"amount\" or \"amount_bp_of_damage\"")
				def.amount = reader.opt_int("amount", 0, 0)
				def.amount_bp_of_damage = reader.opt_int("amount_bp_of_damage", 0, 0)
			Type.APPLY_STATUS:
				def.status_id = reader.req_string("status")
				def.stacks = reader.opt_int("stacks", 1, 1)
				def.duration_ticks = reader.opt_ticks("duration_ms", 0)
			Type.CLEANSE:
				def.amount = reader.req_int("amount_bp", 1, FixedMath.BP_ONE)
		if reader.has("scaling"):
			if def.amount_bp_of_damage > 0 or def.amount_bp_of_max_hp > 0:
				reader.error("\"scaling\" can't be combined with %s" % ("amount_bp_of_damage" if def.amount_bp_of_damage > 0 else "amount_bp_of_max_hp"))
			_read_scaling(def, reader.req_object("scaling"))

	read_window(reader, def)
	if not trigger_name.is_empty():
		_read_trigger_fields(def, reader, relic)
	if def.type == Type.AREA and (def.trigger == Trigger.ON_HIT or def.trigger == Trigger.ON_CRIT):
		reader.error("an area is cast as its ability fires or on a passive's trigger, never on_hit or on_crit")
	if MOVES_SELF.has(def.type) and not type_name.is_empty() and not target_name.is_empty():
		if def.target != Target.TARGET or def.trigger != Trigger.ON_FIRE:
			reader.error("%s moves the unit itself to its target, so it needs \"target\": \"target\" and the on_fire trigger" % type_name)

	# "hit_target" and damage-based shields need a hit to refer to.
	var needs_hit: bool = def.target == Target.HIT_TARGET or def.amount_bp_of_damage > 0
	if needs_hit and not trigger_name.is_empty() and not relic and def.trigger == Trigger.ON_FIRE:
		reader.error("\"%s\" needs a hit, so its trigger must be on_hit or on_crit, not on_fire" % (target_name if def.target == Target.HIT_TARGET else "amount_bp_of_damage"))
	if not trigger_name.is_empty() and (EVENT_TRIGGERS.has(def.trigger) or UNIT_TRIGGERS.has(def.trigger)):
		if def.target == Target.HIT_TARGET and not EVENT_UNIT_TRIGGERS.has(def.trigger):
			reader.error("%s names no unit, so it can't use hit_target" % trigger_name)
		if def.amount_bp_of_damage > 0 and not EVENT_HIT_TRIGGERS.has(def.trigger):
			reader.error("%s names no hit, so it can't use amount_bp_of_damage" % trigger_name)
	if def.trigger == Trigger.ON_FALL and not type_name.is_empty():
		if def.type == Type.AREA and def.anchor != Anchor.SELF:
			reader.error("on_fall runs once the unit has fallen, so its area is anchored on it (\"anchor\": \"self\")")
		elif def.type != Type.AREA and FIELD_ONLY_TARGETS.has(def.target) and not UNTARGETED.has(def.type):
			reader.error("on_fall runs once the unit has fallen, so it can't aim at \"%s\"" % TARGET_NAMES[def.target])
	reader.finish()
	return def


static func _read_area(def: EffectDef, reader: DataReader) -> void:
	var shape_reader: DataReader = reader.req_object("shape")
	def.shape = ShapeDef.read(shape_reader) if shape_reader != null else ShapeDef.new()
	var anchor_name: String = reader.req_choice("anchor", ANCHOR_NAMES)
	def.anchor = maxi(ANCHOR_NAMES.find(anchor_name), 0) as Anchor
	def.warning_ticks = reader.opt_ticks("warning_ms", 0)
	def.hits = maxi(HITS_NAMES.find(reader.req_choice("hits", HITS_NAMES)), 0) as Hits
	if not anchor_name.is_empty() and def.shape.is_aimed() != (def.anchor == Anchor.TARGET_DIRECTION):
		reader.error("anchor: a %s takes %s" % [ShapeDef.KIND_NAMES[def.shape.kind], "target_direction" if def.shape.is_aimed() else "target or self"])
	var effect_readers: Array[DataReader] = reader.opt_object_array("effects")
	if effect_readers.is_empty():
		reader.error("an area needs effects")
	for effect_reader: DataReader in effect_readers:
		var effect: EffectDef = EffectDef.read(effect_reader)
		if effect.type == Type.AREA or MOVES_SELF.has(effect.type):
			effect_reader.error("an area's effects can't be an area, a leap, or a charge")
		elif effect.target != Target.TARGET or effect.trigger != Trigger.ON_FIRE:
			effect_reader.error("an area's effects aim at \"target\" (each unit hit), on_fire")
		def.area_effects.append(effect)


static func _read_summon(def: EffectDef, reader: DataReader) -> void:
	def.summon_kit = reader.req_string("kit")
	var placement_name: String = reader.req_choice("placement", PLACEMENT_NAMES)
	def.placement = maxi(PLACEMENT_NAMES.find(placement_name), 0) as Placement
	if def.placement == Placement.HEXES:
		def.summon_hexes = reader.req_hex_array("hexes")
		def.count = def.summon_hexes.size()
		if reader.has("count"):
			reader.opt_int("count", 0)
			reader.error("summon on hexes makes one on each hex, so it takes no \"count\"")
	else:
		def.count = reader.opt_int("count", 1, 1)
	if def.placement == Placement.EDGES:
		def.near_target = reader.opt_string_choice("near", "self", NEAR_NAMES) == "target"


## Checks the trigger is allowed here and reads its extra fields.
static func _read_trigger_fields(def: EffectDef, reader: DataReader, relic: bool) -> void:
	var allowed: Array[Trigger] = RELIC_TRIGGERS if relic else ABILITY_TRIGGERS
	if not allowed.has(def.trigger):
		reader.error("%s effects can't use the trigger \"%s\"" % ["relic" if relic else "ability", TRIGGER_NAMES[def.trigger]])
	match def.trigger:
		Trigger.AT_TIME:
			def.at_ticks = reader.req_ticks("at_ms", FixedMath.MS_PER_TICK)
		Trigger.ON_ALLY_BELOW_HP:
			def.threshold_bp = reader.req_int("threshold_bp", 1, FixedMath.BP_ONE - 1)
			def.once = reader.opt_bool("once", false)
		Trigger.ON_INTERVAL:
			def.interval_ticks = reader.req_ticks("interval_ms", FixedMath.MS_PER_TICK)
		Trigger.ON_STATUS:
			if reader.has("statuses"):
				def.statuses = reader.req_string_array("statuses")
	if EVENT_TRIGGERS.has(def.trigger):
		def.every = reader.opt_int("every", 1, 1)
	if def.target == Target.TRIGGER_ALLY and def.trigger != Trigger.ON_ALLY_BELOW_HP:
		reader.error("\"trigger_ally\" only works with the on_ally_below_hp trigger")
	if not relic:
		return
	if FIELD_ONLY_TARGETS.has(def.target):
		reader.error("\"%s\" needs a unit on the field, so a relic can't use it" % TARGET_NAMES[def.target])
	if def.amount_bp_of_damage > 0:
		reader.error("a relic has no hit, so it can't use amount_bp_of_damage")
	if def.scaling.any(func(ratio: int) -> bool: return ratio != 0):
		reader.error("relic numbers are flat, so relic effects can't have \"scaling\"")


static func _read_bonus(def: EffectDef, reader: DataReader) -> void:
	if reader == null:
		return
	def.bonus_bp_per_ally = reader.req_int("bp", 1)
	def.bonus_within = reader.req_int("within_hexes", 1) * HexGrid.HEX
	def.bonus_kit = reader.opt_string("kit", "")
	reader.finish()


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


## The event triggers' names, in order.
static func event_trigger_names() -> Array[String]:
	var names: Array[String] = []
	for trigger: Trigger in EVENT_TRIGGERS:
		names.append(TRIGGER_NAMES[trigger])
	return names


## True if the effect is active at this tick of the fight.
func active_at(tick: int) -> bool:
	return tick >= window_from_ticks and (window_until_ticks < 0 or tick < window_until_ticks)


static func _read_scaling(def: EffectDef, reader: DataReader) -> void:
	if reader == null:
		return
	for key: String in reader.map_keys():
		var stat: int = UnitStats.STAT_NAMES.find(key)
		if stat < 0 or stat >= UnitStats.SCALING_STATS:
			reader.error("can't scale from \"%s\" (expected one of: %s)" % [key, ", ".join(UnitStats.STAT_NAMES.slice(0, UnitStats.SCALING_STATS))])
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
