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
##   damage:       amount (or amount_bp_of_damage: a share of the hit that
##                 set it off, on_hit); optional "bonus_per_ally": {"bp": 2500,
##                 "within_hexes": 1, "kit": "rift_pup"} adds bp for each
##                 other standing ally within that many hexes as it fires
##                 (of that kit only, if "kit" is given)
##   heal:         exactly one of amount, amount_bp_of_max_hp (a share of
##                 the healed unit's max HP), amount_bp_of_damage (a share
##                 of the hit that set it off: lifesteal, on_hit); optional
##                 overheal_shield_bp: what it heals past full HP comes back
##                 as that share of Shield (phase 4)
##   shield:       exactly one of amount, amount_bp_of_damage
##   apply_status: status; stacks (damage over time; default 1); optional
##                 duration_ms (a timed status; default: the status's own)
##   cleanse:      amount_bp; strips that share of the target's
##                 damage-over-time stacks (times each status's
##                 cleanse_effectiveness_bp, like heals do)
##   mana_drain:   amount (whole mana taken from the target's bar)
##   snare:        like an area's, its own "effects" (aiming at "target":
##                 the enemy that springs it), optional "max_standing" (the
##                 oldest goes past that), and no "target" key: it's set in
##                 the path of the ability's target (Snares; phase 4)
##   wall:         "width_hexes", "ahead_hexes", "duration_ms", and no
##                 "target" key: a wall across the way to the ability's
##                 target that stops enemy shots (Walls; phase 4)
##   gain_mana:    amount (whole mana added to the target's bar, if it has
##                 one; phase 4). Not logged, like every mana gain: the fire
##                 that gave it is
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
##     area in an area, and no leap or charge. A nested effect may say which
##     side it's for ("side": "enemies" or "allies"), so one area can harm
##     enemies and help allies (hits "all"; phase 4, Sunfall).
##     A zone (phase 4): an area with "duration_ms" and "every_ms" stays
##     where it was cast that long, landing its effects on whoever is inside
##     every so often, from the moment it's cast (Areas; no warning).
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
## Near the target (phase 4; "within_hexes" limits how far from it, and the
## plural ones need it): the ability's target, or on_hit the unit hit, or
## for an event the unit's target:
##   enemy_near_target     the enemy nearest it, other than it (Split Shot,
##                         Brand, Judgment's smite)
##   enemies_near_target   every enemy within reach of it, other than it
##   ally_near_target      the unit's ally nearest it, other than it (Kindle)
##   allies_near_target    every such ally within reach of it
##   lowest_hp_ally        the unit's ally lowest on HP (a share of max HP),
##                         within within_hexes of the unit if given
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
## Phase 5c step 3 (keywords and triggers; a code change, for the pools):
##   on_holder_hit    one of the unit's hits lands on an enemy (a DAMAGE
##                    entry, not damage over time; hit_target: the enemy;
##                    amount_bp_of_damage: of that hit); "from_ability"
##                    (phase 8 part 2): only hits from those abilities
##   on_shield_broken a hit or damage over time takes the last of the
##                    unit's Shield (hit_target: whoever broke it;
##                    amount_bp_of_damage: of the Shield that hit took). A
##                    Guard's share of a hit doesn't count
##   on_ally_shield_broken (phase 8 part 2, Thornweave): the same, on any
##                    unit of its side (itself too), heard by each of them
##                    (hit_target: whoever broke it; amount_bp_of_damage:
##                    of the Shield that hit took)
##   on_ally_ability  an ally's signature fires (hit_target: that ally)
##   on_status_ended  a status on the unit runs out ("statuses", "keywords":
##                    only those; phase 5c step 5b, "leaving Stealth")
##   on_lifesteal     the unit's lifesteal heals it (phase 5c step 5c;
##                    Sanguine Frenzy)
##   on_knockback     the unit knocks an enemy back (its PUSH lines noted
##                    "knocked back"; hit_target: that enemy; phase 5c step
##                    5d, The Hunter's Anvil)
##   on_guard         the unit's Guard takes a share of a hit on an ally (its
##                    GUARD lines; hit_target: that ally; The Hearth-Woven
##                    Mail)
## An event effect's "cooldown_per_unit_ms" (step 5d) runs it at most once
## that long for each unit its event names.
## Phase 5c step 5b adds: extend_status ("status", "duration_ms": a timed
## status already on the target lasts that much longer); the targets
## enemies_near_self (within_hexes of the unit), enemies_near_named and
## enemy_near_named (around the unit the event names: on_kill's fallen too),
## and, for a relic, nearest_enemies ("count" of the enemies nearest any of
## its side); a Shield's amount_bp_of_max_hp; and apply_status's
## "stacks_of": "burn" (as many stacks as the unit the event names has).
## Phase 5c step 5c adds stacks_of's "stacks_share_bp" (a share of them, at
## least 1) and apply_status's "fresh_only" (nothing if the target has it).
## on_kill names the enemy that fell (for "vs" and an area's anchor; it
## can't be hit_target, since it's gone).
## "every": N runs it on every Nth time; "once": true only the first time.
## "vs": {...} (a UnitCondition; phase 5c step 3) runs it only when the unit
## the event names meets it ("a crit on a Marked enemy", "a Burning enemy
## you felled"), read when the event is. on_status also takes "keywords"
## (only statuses carrying one of them).
## What an event effect does can set off other events (a chain); each log
## entry carries its depth (LogEntry.chain), and one at the fight's
## chain_limit (tuning.json) sets off nothing (Events). An ability's own on_fire effect can have
## "every" too (phase 4): it runs on every Nth time the ability fires
## (Split Shot, Judgment).
##
## Passive triggers that aren't read from the log (docs/plans/
## rebuild-phase2-heroes-enemies.md, section 4; Passives runs them):
##   on_interval       every "interval_ms" while the unit stands, counted
##                     from when it joined the fight ("once": true: only the
##                     first time; phase 4, Snare)
##   on_ally_below_hp  when an ally (not the unit itself) first drops below
##                     "threshold_bp" of its max HP while standing; once per
##                     ally, or with "once": true only the first
##                     (trigger_ally: that ally)
##   on_fall           as the unit falls, from where it fell: an area
##                     anchored on it, or all_enemies or all_allies
##   on_would_fall     once a fight, the first time it would fall: it's
##                     left at 1 HP (SAVED), and the effect runs (phase 4,
##                     Unyielding: a would-fall save that isn't a signature)
## Phase 5c step 6b (the loadout's charms) adds events: on_charged (a charge
## or leap's hit lands on the unit; hit_target: the one that did it; Braced)
## and on_arrive (step 6d: the unit enters the fight late; Late Arrival),
## and on_enemy_fell (an enemy falls, within "fell_within_hexes" of the unit
## if given; it names the fallen; Scavenger); on_kill's "from_signature"
## (only its signature's kills; Execution); an event effect's "cooldown_ms"
## (at most once that long, whoever it names; Spite Brand); on_hit_taken's
## "min_bp_of_max_hp" (only hits that big); apply_status's "marks_stack" (a
## Mark it applies stacks as it refreshes; Hunter's Chalk); and gain_mana's
## "amount_bp_of_max_mana" (a share of the bar).
##   on_fight_start    once, as the fight starts (phase 5c step 6d: a
##                     gambit's; a passive's, like a relic's)
##   on_below_hp       the unit itself drops below "threshold_bp" of its max
##                     HP while standing (each time it drops back below,
##                     up to "times" a fight; default 1; phase 5c step 6,
##                     Warding Thread and Smoke Vial)
## Phase 5c step 6 also adds the target allies_near_self (every ally within
## "within_hexes" of the unit, as it falls too: Last Breath) and cleanse's
## "statuses" (only those).
## None of them names a hit, so none can use hit_target or
## amount_bp_of_damage.
## A passive's effects may cast an area on any of these, or on an event
## (never on_hit or on_crit): around the unit (anchor self), or on the unit
## the event names, else the unit's target.

enum Trigger {
	ON_FIRE, ON_HIT, ON_CRIT, ON_FIGHT_START, AT_TIME, ON_ALLY_BELOW_HP,
	ON_ABILITY, ON_BASIC_ATTACK, ON_HOLDER_CRIT, ON_SHIELDED, ON_HIT_TAKEN, ON_HEAL, ON_STATUS, ON_KILL,
	ON_INTERVAL, ON_FALL, ON_HOP, ON_WOULD_FALL,
	ON_HOLDER_HIT, ON_SHIELD_BROKEN, ON_ALLY_ABILITY, ON_STATUS_ENDED, ON_LIFESTEAL, ON_KNOCKBACK, ON_GUARD,
	ON_BELOW_HP, ON_CHARGED, ON_ENEMY_FELL, ON_ARRIVE, ON_ALLY_SHIELD_BROKEN,
}
enum Type { DAMAGE, HEAL, SHIELD, APPLY_STATUS, CLEANSE, MANA_DRAIN, KNOCKBACK, PULL, LEAP, CHARGE, AREA, START_COLLAPSE, SUMMON, GAIN_MANA, SNARE, WALL, EXTEND_STATUS, HOP }
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
	ENEMY_NEAR_TARGET,
	ENEMIES_NEAR_TARGET,
	ALLY_NEAR_TARGET,
	ALLIES_NEAR_TARGET,
	LOWEST_HP_ALLY,
	ENEMIES_NEAR_SELF,
	ENEMIES_NEAR_NAMED,
	ENEMY_NEAR_NAMED,
	NEAREST_ENEMIES,
	ALLIES_NEAR_SELF,
}
## A nested area effect's side (phase 4): both, or only one.
enum AreaSide { BOTH, ENEMIES, ALLIES }

const TRIGGER_NAMES: Array[String] = [
	"on_fire", "on_hit", "on_crit", "on_fight_start", "at_time", "on_ally_below_hp",
	"on_ability", "on_basic_attack", "on_holder_crit", "on_shielded", "on_hit_taken", "on_heal", "on_status", "on_kill",
	"on_interval", "on_fall", "on_hop", "on_would_fall",
	"on_holder_hit", "on_shield_broken", "on_ally_ability", "on_status_ended", "on_lifesteal", "on_knockback", "on_guard",
	"on_below_hp", "on_charged", "on_enemy_fell", "on_arrive", "on_ally_shield_broken",
]
## The unit's events (see the top).
const EVENT_TRIGGERS: Array[Trigger] = [
	Trigger.ON_ABILITY, Trigger.ON_BASIC_ATTACK, Trigger.ON_HOLDER_CRIT, Trigger.ON_SHIELDED,
	Trigger.ON_HIT_TAKEN, Trigger.ON_HEAL, Trigger.ON_STATUS, Trigger.ON_KILL, Trigger.ON_HOP,
	Trigger.ON_HOLDER_HIT, Trigger.ON_SHIELD_BROKEN, Trigger.ON_ALLY_ABILITY, Trigger.ON_STATUS_ENDED, Trigger.ON_LIFESTEAL, Trigger.ON_KNOCKBACK, Trigger.ON_GUARD,
	Trigger.ON_CHARGED, Trigger.ON_ENEMY_FELL, Trigger.ON_ARRIVE, Trigger.ON_ALLY_SHIELD_BROKEN,
]
## Event triggers that name a unit (hit_target) and those that name a hit
## (amount_bp_of_damage).
const EVENT_UNIT_TRIGGERS: Array[Trigger] = [Trigger.ON_HOLDER_CRIT, Trigger.ON_SHIELDED, Trigger.ON_HIT_TAKEN, Trigger.ON_HEAL, Trigger.ON_STATUS,
	Trigger.ON_HOLDER_HIT, Trigger.ON_SHIELD_BROKEN, Trigger.ON_ALLY_ABILITY, Trigger.ON_KNOCKBACK, Trigger.ON_GUARD, Trigger.ON_CHARGED,
	Trigger.ON_ALLY_SHIELD_BROKEN]
const EVENT_HIT_TRIGGERS: Array[Trigger] = [Trigger.ON_HOLDER_CRIT, Trigger.ON_HIT_TAKEN, Trigger.ON_HOLDER_HIT, Trigger.ON_SHIELD_BROKEN,
	Trigger.ON_ALLY_SHIELD_BROKEN]
## Event triggers that can take "vs": those that name a unit, and on_kill.
const EVENT_VS_TRIGGERS: Array[Trigger] = [Trigger.ON_HOLDER_CRIT, Trigger.ON_SHIELDED, Trigger.ON_HIT_TAKEN, Trigger.ON_HEAL, Trigger.ON_STATUS,
	Trigger.ON_HOLDER_HIT, Trigger.ON_SHIELD_BROKEN, Trigger.ON_ALLY_ABILITY, Trigger.ON_KILL, Trigger.ON_KNOCKBACK, Trigger.ON_GUARD,
	Trigger.ON_CHARGED, Trigger.ON_ENEMY_FELL, Trigger.ON_ALLY_SHIELD_BROKEN]
const ABILITY_TRIGGERS: Array[Trigger] = [
	Trigger.ON_FIRE, Trigger.ON_HIT, Trigger.ON_CRIT,
	Trigger.ON_ABILITY, Trigger.ON_BASIC_ATTACK, Trigger.ON_HOLDER_CRIT, Trigger.ON_SHIELDED,
	Trigger.ON_HIT_TAKEN, Trigger.ON_HEAL, Trigger.ON_STATUS, Trigger.ON_KILL, Trigger.ON_HOP,
	Trigger.ON_ALLY_BELOW_HP, Trigger.ON_INTERVAL, Trigger.ON_FALL, Trigger.ON_WOULD_FALL,
	Trigger.ON_HOLDER_HIT, Trigger.ON_SHIELD_BROKEN, Trigger.ON_ALLY_ABILITY, Trigger.ON_STATUS_ENDED, Trigger.ON_LIFESTEAL, Trigger.ON_KNOCKBACK, Trigger.ON_GUARD,
	Trigger.ON_BELOW_HP, Trigger.ON_CHARGED, Trigger.ON_ENEMY_FELL, Trigger.ON_ARRIVE, Trigger.ON_FIGHT_START, Trigger.ON_ALLY_SHIELD_BROKEN,
]
## What a passive's effects may run on (PartDef).
const PASSIVE_TRIGGERS: Array[Trigger] = [
	Trigger.ON_ABILITY, Trigger.ON_BASIC_ATTACK, Trigger.ON_HOLDER_CRIT, Trigger.ON_SHIELDED,
	Trigger.ON_HIT_TAKEN, Trigger.ON_HEAL, Trigger.ON_STATUS, Trigger.ON_KILL, Trigger.ON_HOP,
	Trigger.ON_ALLY_BELOW_HP, Trigger.ON_INTERVAL, Trigger.ON_FALL, Trigger.ON_WOULD_FALL,
	Trigger.ON_HOLDER_HIT, Trigger.ON_SHIELD_BROKEN, Trigger.ON_ALLY_ABILITY, Trigger.ON_STATUS_ENDED, Trigger.ON_LIFESTEAL, Trigger.ON_KNOCKBACK, Trigger.ON_GUARD,
	Trigger.ON_BELOW_HP, Trigger.ON_CHARGED, Trigger.ON_ENEMY_FELL, Trigger.ON_ARRIVE, Trigger.ON_FIGHT_START, Trigger.ON_ALLY_SHIELD_BROKEN,
]
## The passive triggers that aren't events (Passives.run_timed, on_fall,
## would_fall).
const UNIT_TRIGGERS: Array[Trigger] = [Trigger.ON_ALLY_BELOW_HP, Trigger.ON_INTERVAL, Trigger.ON_FALL, Trigger.ON_WOULD_FALL, Trigger.ON_BELOW_HP, Trigger.ON_FIGHT_START]
const RELIC_TRIGGERS: Array[Trigger] = [Trigger.ON_FIRE, Trigger.ON_FIGHT_START, Trigger.AT_TIME, Trigger.ON_ALLY_BELOW_HP]
## Targets that need the effect's unit to stand on the field.
const FIELD_ONLY_TARGETS: Array[Target] = [Target.TARGET, Target.HIT_TARGET, Target.SELF,
	Target.ENEMY_NEAR_TARGET, Target.ENEMIES_NEAR_TARGET, Target.ALLY_NEAR_TARGET, Target.ALLIES_NEAR_TARGET, Target.LOWEST_HP_ALLY]
## Targets near the ability's target (phase 4), and those that need a reach.
const NEAR_TARGETS: Array[Target] = [Target.ENEMY_NEAR_TARGET, Target.ENEMIES_NEAR_TARGET, Target.ALLY_NEAR_TARGET, Target.ALLIES_NEAR_TARGET,
	Target.ENEMIES_NEAR_SELF, Target.ENEMIES_NEAR_NAMED, Target.ENEMY_NEAR_NAMED, Target.ALLIES_NEAR_SELF]
const REACH_TARGETS: Array[Target] = [Target.ENEMIES_NEAR_TARGET, Target.ALLIES_NEAR_TARGET, Target.ENEMIES_NEAR_SELF, Target.ENEMIES_NEAR_NAMED,
	Target.ALLIES_NEAR_SELF]
## The targets around the unit an event names (they need one).
const NAMED_TARGETS: Array[Target] = [Target.ENEMIES_NEAR_NAMED, Target.ENEMY_NEAR_NAMED]
const SIDE_NAMES: Array[String] = ["both", "enemies", "allies"]
const TYPE_NAMES: Array[String] = ["damage", "heal", "shield", "apply_status", "cleanse", "mana_drain", "knockback", "pull", "leap", "charge", "area", "start_collapse", "summon", "gain_mana", "snare", "wall", "extend_status", "hop"]
## The types placed at the ability's target without a "target" key of their
## own (an area, a snare, a wall).
const PLACED: Array[Type] = [Type.AREA, Type.SNARE, Type.WALL]
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
	"enemy_near_target",
	"enemies_near_target",
	"ally_near_target",
	"allies_near_target",
	"lowest_hp_ally",
	"enemies_near_self",
	"enemies_near_named",
	"enemy_near_named",
	"nearest_enemies",
	"allies_near_self",
]

var trigger: Trigger
var type: Type
var target: Target
## damage/heal/shield: the amount.
var amount: int = 0
var amount_bp_of_damage: int = 0
## heal: a share of the healed unit's max HP (0: `amount` instead).
var amount_bp_of_max_hp: int = 0
## damage/heal/shield: a power bonus (bp, added to the unit's other power
## bonuses by the damage rule, DamageRule). Not read from the data: kit mods
## set it ("amount_bp" on an ability, phase 5c Decision 6).
var power_bp: int = 0
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
## on_status: only these statuses (empty = any), and only statuses carrying
## one of these keywords (empty = any).
var statuses: Array[String] = []
var keywords: Array[String] = []
## Event triggers: only when the unit the event names meets it (null: any).
var vs: UnitCondition = null
## Near-target targets and lowest_hp_ally: how far (plane units; 0: any).
var near_range: int = 0
## heal: the share of what it heals past full HP that comes back as Shield.
var overheal_shield_bp: int = 0
## apply_status: as many stacks as the unit the event names has of this
## status ("": stacks as given).
var stacks_of: String = ""
## stacks_of: only this share of them, at least 1 (0: all; Ashen Engine).
var stacks_share_bp: int = 0
## apply_status: nothing if the target already has the status (Snaring
## Shot: never stacked or extended).
var fresh_only: bool = false
## An event effect: at most once this many ticks for each unit its event
## names (0: no limit; phase 5c step 5d).
var cooldown_per_unit_ticks: int = 0
## on_below_hp: how many times a fight it may run (phase 5c step 6); and a
## "once" effect's (phase 5c step 7b: a kit mod's times_add, Second Snare).
var times: int = 1
## Phase 5c step 6b. apply_status: a Mark it applies stacks as it refreshes
## (Hunter's Chalk). An event effect: at most once this long, whoever it
## names (Spite Brand). on_hit_taken: only a hit of at least this share of
## the unit's max HP. on_enemy_fell: how near the unit the enemy fell (0:
## anywhere). on_kill: only a kill by its signature (Execution). gain_mana:
## this share of its bar instead of a flat amount.
var marks_stack: bool = false
## apply_status (phase 5c step 6d, Rear Guard): it ends once an enemy stands
## this near its holder (plane units; 0: as it is).
var until_near: int = 0
var cooldown_ticks: int = 0
var min_hit_bp: int = 0
var fell_range: int = 0
var from_signature: bool = false
var mana_bp: int = 0
## cleanse: only these statuses (empty: all damage over time; phase 5c step
## 6, Purifying Light).
var cleanse_statuses: Array[String] = []
## Phase 5c step 7c (the upgrade pools). cleanse: removes this many harmful
## statuses, the newest first (0: by amount_bp; Cleansing Touch).
## apply_status: a Mark it applies is this much stronger (Heavy Mark). An
## event or timed effect: only while its holder meets `holder` (Scar Tissue,
## Bloody Kills). on_holder_crit: only on a unit farther than beyond_range
## (Bleeding Shot). on_kill: only one off its target by its basic attack (a
## split arrow's; Glutton's Quiver). on_heal: only from these abilities, and
## only on an ally that was below was_below_bp before it (Cleansing Touch,
## Last-Minute Mercy).
var cleanse_count: int = 0
var strength_add_bp: int = 0
var holder: UnitCondition = null
var beyond_range: int = 0
var off_target: bool = false
var from_abilities: Array[String] = []
var was_below_bp: int = 0
## In an area: which side it's for.
var side: AreaSide = AreaSide.BOTH
## A zone: how long it stays and how often it lands (0: an ordinary area).
## A wall: how long it stands.
var zone_ticks: int = 0
## snare: how many of its kind the unit may have set at once (0: any).
var max_standing: int = 0
## Phase 5c step 7d (the upgrade pools' big pieces): a zone that moves
## toward the biggest group of enemies before each pulse (Chasing Storm); a
## near-target hit that hits again that many times, each at the enemy
## nearest the last one hit (Ricochet); a wall that sends a stopped shot
## back at its shooter at this share (Reflecting Wall); a snare a leap or
## charge over it springs (Snag); and a snare set under its side's
## front-most unit, of the kit's placed snares' kind (Guarded Ground).
var follows: bool = false
## An area (phase 8 part 2, Stormline): each enemy it hits after the first,
## nearest its origin first, deals this much more damage than the one
## before ("per_enemy_bp": +10% a step is 1000). 0: none.
var per_enemy_bp: int = 0
var ricochet: int = 0
## Damage (phase 8 part 2, Eagle Eye and Inquisitor): a hit that leaves its
## target alive below this share of max HP finishes it ("execute_below_pct";
## a DAMAGE line noted "executed"). 0: none.
var execute_below_bp: int = 0
## on_kill (phase 8 part 2): only a kill an execution made ("executed").
var executed: bool = false
var reflect_bp: int = 0
var snags: bool = false
var under_front: bool = false
## wall: how wide, and how far ahead of the unit its middle is (plane units).
var width_range: int = 0
var ahead_range: int = 0
var pulse_ticks: int = 0

## `relic`: read a relic's effect (relic triggers and targets, flat numbers).
## `in_area`: one of an area's own effects (it may have a "side").
static func read(reader: DataReader, relic: bool = false, in_area: bool = false) -> EffectDef:
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
	elif type_name != "area" and type_name != "snare" and type_name != "wall":
		target_name = reader.req_choice("target", TARGET_NAMES)
	def.target = maxi(TARGET_NAMES.find(target_name), 0) as Target

	if not type_name.is_empty():
		match def.type:
			Type.DAMAGE:
				if reader.has("amount") == reader.has("amount_bp_of_damage"):
					reader.error("damage needs exactly one of \"amount\" or \"amount_bp_of_damage\"")
				def.amount = reader.opt_int("amount", 0, 0)
				def.amount_bp_of_damage = reader.opt_int("amount_bp_of_damage", 0, 0)
				if reader.has("bonus_per_ally"):
					_read_bonus(def, reader.req_object("bonus_per_ally"))
				def.ricochet = reader.opt_int("ricochet", 0, 0, 5)
				def.execute_below_bp = reader.opt_int("execute_below_pct", 0, 0, 50) * 100
			Type.HEAL:
				var kinds: int = int(reader.has("amount")) + int(reader.has("amount_bp_of_max_hp")) + int(reader.has("amount_bp_of_damage"))
				if kinds != 1:
					reader.error("heal needs exactly one of \"amount\", \"amount_bp_of_max_hp\", or \"amount_bp_of_damage\"")
				def.amount = reader.opt_int("amount", 0, 0)
				def.amount_bp_of_max_hp = reader.opt_int("amount_bp_of_max_hp", 0, 0, FixedMath.BP_ONE)
				def.amount_bp_of_damage = reader.opt_int("amount_bp_of_damage", 0, 0)
				def.overheal_shield_bp = reader.opt_int("overheal_shield_bp", 0, 0, 5 * FixedMath.BP_ONE)
			Type.MANA_DRAIN:
				def.amount = reader.req_int("amount", 1)
			Type.GAIN_MANA:
				if reader.has("amount_bp_of_max_mana"):
					def.mana_bp = reader.req_int("amount_bp_of_max_mana", 1, FixedMath.BP_ONE)
				else:
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
			Type.SNARE:
				def.max_standing = reader.opt_int("max_standing", 0, 0)
				def.snags = reader.opt_bool("snags", false)
				def.under_front = reader.opt_string_choice("under", "", ["front_ally"]) == "front_ally"
				if not def.under_front:
					_read_nested(def, reader, "a snare")
			Type.WALL:
				def.width_range = reader.req_int("width_hexes", 1, 8) * HexGrid.HEX
				def.ahead_range = reader.req_int("ahead_hexes", 0, 4) * HexGrid.HEX
				def.zone_ticks = reader.req_ticks("duration_ms", FixedMath.MS_PER_TICK)
				def.reflect_bp = reader.opt_int("reflect_bp", 0, 0, FixedMath.BP_ONE)
			Type.SHIELD:
				if int(reader.has("amount")) + int(reader.has("amount_bp_of_damage")) + int(reader.has("amount_bp_of_max_hp")) != 1:
					reader.error("shield needs exactly one of \"amount\", \"amount_bp_of_damage\", or \"amount_bp_of_max_hp\"")
				def.amount = reader.opt_int("amount", 0, 0)
				def.amount_bp_of_damage = reader.opt_int("amount_bp_of_damage", 0, 0)
				def.amount_bp_of_max_hp = reader.opt_int("amount_bp_of_max_hp", 0, 0, FixedMath.BP_ONE)
			Type.APPLY_STATUS:
				def.status_id = reader.req_string("status")
				def.stacks = reader.opt_int("stacks", 1, 1)
				def.duration_ticks = reader.opt_ticks("duration_ms", 0)
				def.stacks_of = reader.opt_string("stacks_of", "")
				def.stacks_share_bp = reader.opt_int("stacks_share_bp", 0, 1, FixedMath.BP_ONE)
				if def.stacks_share_bp > 0 and def.stacks_of.is_empty():
					reader.error("stacks_share_bp is a share of stacks_of")
				def.fresh_only = reader.opt_bool("fresh_only", false)
				def.marks_stack = reader.opt_bool("marks_stack", false)
				if reader.has("until_enemy_within_hexes"):
					def.until_near = reader.req_int("until_enemy_within_hexes", 1, 10) * HexGrid.HEX
				def.strength_add_bp = reader.opt_int("strength_add_bp", 0, 0, FixedMath.BP_ONE)
			Type.EXTEND_STATUS:
				def.status_id = reader.req_string("status")
				def.duration_ticks = reader.req_ticks("duration_ms", FixedMath.MS_PER_TICK)
			Type.CLEANSE:
				if reader.has("count"):
					def.cleanse_count = reader.req_int("count", 1, 10)
				else:
					def.amount = reader.req_int("amount_bp", 1, FixedMath.BP_ONE)
				if reader.has("statuses"):
					def.cleanse_statuses = reader.req_string_array("statuses")
		if reader.has("scaling"):
			if def.amount_bp_of_damage > 0 or def.amount_bp_of_max_hp > 0:
				reader.error("\"scaling\" can't be combined with %s" % ("amount_bp_of_damage" if def.amount_bp_of_damage > 0 else "amount_bp_of_max_hp"))
			_read_scaling(def, reader.req_object("scaling"))

	if def.target == Target.NEAREST_ENEMIES:
		def.count = reader.req_int("count", 1, 30)
		if not relic:
			reader.error("nearest_enemies is a relic's target (nearest any of its side)")
	if NEAR_TARGETS.has(def.target) or def.target == Target.LOWEST_HP_ALLY:
		if REACH_TARGETS.has(def.target) or reader.has("within_hexes"):
			def.near_range = reader.req_int("within_hexes", 1, 20) * HexGrid.HEX
	elif reader.has("within_hexes"):
		reader.req_int("within_hexes")
		reader.error("within_hexes is only for the targets near the target and lowest_hp_ally")
	if reader.has("side"):
		var side_name: String = reader.req_choice("side", ["enemies", "allies"])
		def.side = maxi(SIDE_NAMES.find(side_name), 0) as AreaSide
		if not in_area:
			reader.error("only an area's own effects have a \"side\"")
	read_window(reader, def)
	if not trigger_name.is_empty():
		_read_trigger_fields(def, reader, relic, in_area)
	if PLACED.has(def.type) and (def.trigger == Trigger.ON_HIT or def.trigger == Trigger.ON_CRIT):
		reader.error("%s is %s as its ability fires or on a passive's trigger, never on_hit or on_crit" % ["an area" if def.type == Type.AREA else "a " + type_name, "cast" if def.type == Type.AREA else "placed"])
	# A hop (phase 8 part 2, Windrunner): the unit hops a hex away from its
	# nearest enemy, as the hop_away trait does; it aims at the unit itself.
	if def.type == Type.HOP and not target_name.is_empty() and def.target != Target.SELF:
		reader.error("a hop moves the unit itself, so it needs \"target\": \"self\"")
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
	if NAMED_TARGETS.has(def.target) and not EVENT_VS_TRIGGERS.has(def.trigger):
		reader.error("%s needs an event that names a unit" % TARGET_NAMES[def.target])
	if not def.stacks_of.is_empty() and not EVENT_VS_TRIGGERS.has(def.trigger):
		reader.error("stacks_of needs an event that names a unit")
	if def.trigger == Trigger.ON_FALL and not type_name.is_empty():
		if def.type == Type.AREA and def.anchor != Anchor.SELF:
			reader.error("on_fall runs once the unit has fallen, so its area is anchored on it (\"anchor\": \"self\")")
		elif def.type != Type.AREA and FIELD_ONLY_TARGETS.has(def.target) and not UNTARGETED.has(def.type):
			reader.error("on_fall runs once the unit has fallen, so it can't aim at \"%s\"" % TARGET_NAMES[def.target])
	reader.finish()
	return def


static func _read_area(def: EffectDef, reader: DataReader) -> void:
	if reader.has("duration_ms") or reader.has("every_ms"):
		def.zone_ticks = reader.req_ticks("duration_ms", FixedMath.MS_PER_TICK)
		def.pulse_ticks = reader.req_ticks("every_ms", FixedMath.MS_PER_TICK)
		if def.pulse_ticks > def.zone_ticks:
			reader.error("a zone lands every_ms, which can't be longer than its duration_ms")
	var shape_reader: DataReader = reader.req_object("shape")
	def.shape = ShapeDef.read(shape_reader) if shape_reader != null else ShapeDef.new()
	var anchor_name: String = reader.req_choice("anchor", ANCHOR_NAMES)
	def.anchor = maxi(ANCHOR_NAMES.find(anchor_name), 0) as Anchor
	def.warning_ticks = reader.opt_ticks("warning_ms", 0)
	if def.zone_ticks > 0 and def.warning_ticks > 0:
		reader.error("a zone lands from the moment it's cast, so it takes no warning_ms")
	def.follows = reader.opt_string_choice("follows", "", ["largest_group"]) == "largest_group"
	if def.follows and def.zone_ticks == 0:
		reader.error("only a zone (an area with a duration) follows")
	def.hits = maxi(HITS_NAMES.find(reader.req_choice("hits", HITS_NAMES)), 0) as Hits
	def.per_enemy_bp = reader.opt_int("per_enemy_bp", 0, 0, FixedMath.BP_ONE)
	# A zone that may stand only so many at once from its ability (phase 8
	# part 2, Sanctifier): once that many stand, a new cast lays no more.
	def.max_standing = reader.opt_int("max_standing", 0, 0)
	if def.max_standing > 0 and def.zone_ticks == 0:
		reader.error("only a zone (an area with a duration) has max_standing")
	if not anchor_name.is_empty() and def.shape.is_aimed() != (def.anchor == Anchor.TARGET_DIRECTION):
		reader.error("anchor: a %s takes %s" % [ShapeDef.KIND_NAMES[def.shape.kind], "target_direction" if def.shape.is_aimed() else "target or self"])
	_read_nested(def, reader, "an area")


## An area's or a snare's own effects: each aims at "target" (every unit it
## lands on), on_fire; no placed thing, leap, or charge among them.
static func _read_nested(def: EffectDef, reader: DataReader, what: String) -> void:
	var effect_readers: Array[DataReader] = reader.opt_object_array("effects")
	if effect_readers.is_empty():
		reader.error("%s needs effects" % what)
	for effect_reader: DataReader in effect_readers:
		var effect: EffectDef = EffectDef.read(effect_reader, false, def.type == Type.AREA)
		if PLACED.has(effect.type) or MOVES_SELF.has(effect.type) or UNTARGETED.has(effect.type):
			effect_reader.error("%s's effects can't be an area, a leap, or a charge (nor a snare, a wall, a summon, or start_collapse)" % what)
		elif effect.target != Target.TARGET or effect.trigger != Trigger.ON_FIRE:
			effect_reader.error("%s's effects aim at \"target\" (%s), on_fire" % [what, "each unit hit" if def.type == Type.AREA else "the enemy that springs it"])
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
static func _read_trigger_fields(def: EffectDef, reader: DataReader, relic: bool, in_area: bool = false) -> void:
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
			def.once = reader.opt_bool("once", false)
		Trigger.ON_BELOW_HP:
			def.threshold_bp = reader.req_int("threshold_bp", 1, FixedMath.BP_ONE - 1)
			def.times = reader.opt_int("times", 1, 1, 10)
		Trigger.ON_HIT_TAKEN:
			def.min_hit_bp = reader.opt_int("min_bp_of_max_hp", 0, 0, FixedMath.BP_ONE)
		Trigger.ON_ENEMY_FELL:
			if reader.has("fell_within_hexes"):
				def.fell_range = reader.req_int("fell_within_hexes", 1, 20) * HexGrid.HEX
		Trigger.ON_KILL:
			def.from_signature = reader.opt_bool("from_signature", false)
			def.off_target = reader.opt_bool("off_target", false)
			def.executed = reader.opt_bool("executed", false)
			if reader.has("from_ability"):
				def.from_abilities = reader.req_string_array("from_ability")
		Trigger.ON_HOLDER_CRIT:
			if reader.has("beyond_hexes"):
				def.beyond_range = reader.req_int("beyond_hexes", 1, 10) * HexGrid.HEX
		Trigger.ON_HEAL, Trigger.ON_HOLDER_HIT:
			if reader.has("from_ability"):
				def.from_abilities = reader.req_string_array("from_ability")
			if def.trigger == Trigger.ON_HEAL and reader.has("was_below_pct"):
				def.was_below_bp = reader.req_int("was_below_pct", 1, 99) * 100
		Trigger.ON_STATUS, Trigger.ON_STATUS_ENDED:
			if reader.has("statuses"):
				def.statuses = reader.req_string_array("statuses")
			def.keywords = reader.opt_choice_array("keywords", Keywords.NAMES)
			if def.keywords.has(Keywords.SHIELDED):
				reader.error("Shielded isn't a status; on_shielded is when a unit gains Shield")
	if EVENT_TRIGGERS.has(def.trigger) or (def.trigger == Trigger.ON_FIRE and not relic and not in_area):
		def.every = reader.opt_int("every", 1, 1)
	if EVENT_TRIGGERS.has(def.trigger):
		def.once = reader.opt_bool("once", false)
		def.cooldown_per_unit_ticks = reader.opt_ticks("cooldown_per_unit_ms", 0, FixedMath.MS_PER_TICK)
		def.cooldown_ticks = reader.opt_ticks("cooldown_ms", 0, FixedMath.MS_PER_TICK)
		if def.cooldown_per_unit_ticks > 0 and not EVENT_VS_TRIGGERS.has(def.trigger):
			reader.error("%s names no unit, so it can't take cooldown_per_unit_ms" % TRIGGER_NAMES[def.trigger])
		if reader.has("vs"):
			def.vs = UnitCondition.read(reader.req_object("vs"))
			if not EVENT_VS_TRIGGERS.has(def.trigger):
				reader.error("%s names no unit, so it can't take \"vs\"" % TRIGGER_NAMES[def.trigger])
	if reader.has("holder"):
		def.holder = UnitCondition.read(reader.req_object("holder"))
		if not (EVENT_TRIGGERS.has(def.trigger) or UNIT_TRIGGERS.has(def.trigger)):
			reader.error("only an event's or a timed effect can take \"holder\"")
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
