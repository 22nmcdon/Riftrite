class_name KitMod
extends RefCounted
## A change to a unit's kit, written against its slots rather than an
## ability's name (docs/plans/phases/rebuild-phase5-run.md, section 7): the one shape
## for upgrades, charms, sigils, grafts, relics, duo bonds, and enemy
## upgrades (part 6's "one modifier shape"). Applied at setup, after a path's
## patch, so a fight is still a pure function of its setup; a kit with no
## modifiers is the kit itself. Every key is optional, but a mod changes
## something:
##   {"stats_bp": {"hp": 11000},          multiplies HP, ATK, MGK, DEF, or ATSP
##    "stats_add": {"crit": 5},           adds to CRIT, speed, or range, and
##                                        (phase 5c step 4: growing cards'
##                                        "+1 DEF") HP, ATK, MGK, or DEF
##    "passives": [...PartDefs...],       added (their ids must be new to the kit)
##    "on": [{                            changes to abilities, one entry per slot
##       "slot": "signature",             basic_attack, signature, passive:<id>
##                                        (a path's own passive), or abilities
##                                        (the basic attack, the signature, and
##                                        every passive's ability)
##       "types": ["heal"],               only effects of these types (nested in
##                                        areas and snares too); default all
##       "statuses": ["stealth"],         only apply_status effects of these
##                                        statuses (phase 5c step 5b; Veil of
##                                        the Lost)
##       "amount_bp": 12000,              damage, heals, and Shields: a power
##                                        bonus of this much (+20%) added to
##                                        the effect (EffectDef.power_bp; the
##                                        damage rule, phase 5c); other
##                                        effects' amount, scaling, and share
##                                        of damage, times this (and a
##                                        knockback's or pull's hexes, when
##                                        "types" names it; phase 5c step 7)
##       "duration_bp": 13000,            their durations (a status's, a lasting
##       "duration_add_ms": 2000,         area's, a wall's, a summon's lasts_ms),
##                                        times this, plus this
##       "radius_add": 1,                 their areas' size, in hexes
##       "cooldown_bp": 9000,             the ability's cooldown, times this
##                                        (and, phase 8 part 5, an on_interval
##                                        effect's interval and an event
##                                        effect's cooldowns: Quick Hallow,
##                                        Quick Forge)
##       "add_effects": [...EffectDefs...],   appended to the ability
##       "after_add_ms": -500}],          the passive's aura: how long unmoved
##                                        (or planted) before it holds
## Phase 5c step 7b (the upgrade pools' small knobs) adds, per "on" entry:
##       "at": ["enemy_near_target"],     only effects aimed at these targets
##       "every_add": -1,                 an "every" N effect's N (at least 1)
##       "times_add": 1,                  how many times a "once" effect (or
##                                        on_below_hp's) runs a fight
##       "max_standing_add": 1,           a snare's most standing at once
##       "overheal_shield_add_bp": 2000,  a heal's overheal-to-Shield share
##       "width_add": 1,                  a line's width, in hexes
##       "add_to_areas": [...EffectDefs...],  added inside its areas (on each
##                                        unit an area hits), not after them
##       "value_add": 500,                the named passive's aura's value
##       "guard": {"share_add": 5, "within_add": 1, "covers_all": true}
##                                        the named Guard passive
##       "prefer": {...UnitCondition...}  the signature picks among enemies
##                                        that meet it first
##       "strength_add_bp": 500           (step 7c) a Mark it applies is that
##                                        much stronger
##       "follows": "largest_group",      (step 7d) its zones move toward the
##                                        biggest group ("holder", phase 8
##                                        part 5's Carrier: with its caster);
##       "ricochet_add": 1,               biggest group; its hits ricochet;
##       "reflect_bp": 5000,              its walls send shots back; its
##       "snags": true                    snares catch leaps and charges
## Phase 8 part 2 (the apex cards' knobs), per "on" entry:
##       "per_enemy_add_bp": 500,         an area's per_enemy_bp (Gathering
##                                        Line)
##       (max_standing_add also reaches walls and zones, and width_add a
##       wall's width, in hexes: Thicket, Holy Land, Gatehouse)
##       "overheal_max_hp_add": -5,       a heal's overheal_max_hp_per (at
##                                        least 1; Deep Hearth)
##       "at_stacks_add": -1,             on_status's at_stacks (at least 2;
##                                        Hot Iron)
##       "per_taken_add_bp": 500,         grows_per_damage_taken's bp
##                                        (Bonfire)
##       "grows_add_bp": 1000,            a signature's grows_bp, and
##       "grows_boosts_add_bp": 1000      grows_boosts_bp (Rising Light, War
##                                        Cry)
##       "rise_add_pct": 20,              the named rise passive's HP share
##                                        (Stubborn Flame)
##       "per_shared_bp": 5000            the named link's per_shared, times
##                                        this (Iron Loom)
## Phase 8 part 3 (Act 2's specializations), per "on" entry:
##       "holder": {...UnitCondition...}  its event and timed effects run
##                                        only while their unit meets it (the
##                                        Steaming Ashling's burst, off water)
##       "carries": true                  its charges carry every enemy in
##                                        their line (the Avalanche Guardian)
## Phase 8 part 4 (Garrow's cards), per "on" entry:
##       "ability": "haul",               with "slot": "abilities": only the
##                                        ability or passive with that id, as
##                                        his signature or his habit (an old
##                                        signature kept as a passive)
##       "mana_max_add": -10,             with "ability": what it costs, if it
##                                        is the signature; on a habit, its
##                                        "every" one lower (or higher) instead
##                                        ("costs less mana" fires one attack
##                                        sooner; Swift Haul)
##       "ignores_def": true              its damage ignores DEF (Bitter Blood)
##       "per_twice": {...UnitCondition}  the named per-enemy (or, phase 8 part 6,
##                                        per-allied-unit) aura counts those
##                                        enemies twice (Bloodied Links)
##       "per_stack_add_bp": 500          a grows_per_stack's bp (its apex
##                                        cards: Layered Plate, Echoing Burst)
##       (radius_add also widens a named per-enemy aura's reach, in hexes:
##       Wide Crowd; "prefer" with "ability" reaches a habit's farthest
##       enemies: Back-Line Hook; and added effects go before the ability
##       spends its Shield, so they still read it: Shared Ward)
##       "within_add": 1,                 its near targets' reach ("within_
##                                        hexes"), in hexes, and a named
##                                        allies_near aura's (Aldous's cards:
##                                        Wide Peal, Far Resonance)
##       "count_add": 1                   a lowest_mana_ally's count (Two
##                                        Breaths; at most 5), and a
##                                        most_targeted_ally's (phase 8
##                                        part 6, Shroud Splits)
## Phase 8 part 6 (Ilse's cards), per "on" entry: within_add also reaches
## on_status_tick's near_hexes (Fan the Coals) and count_add an
## allies_near_self's nearest (Shared Blessing); and
##       "share_add_bp": 200,             a stacks_of's share (Deep Stoke),
##                                        and a copy's share of the unit
##                                        it copies (phase 8 part 6,
##                                        Strong Mirror; a growing step's
##                                        adds up: Silvered Glass)
##       "grow_every_add_ms": -500,       a growing zone's step time (Fast
##       "grow_max_add": 1                Spread) and largest radius (Far
##                                        Spread)
##       "heal_cap": {"pct": 30, "vs": {...}}   its heals' cap (EffectDef's
##                                        "cap": The Vigil Lamp)
## Phase 8 part 6 (Ottilie's cards), per "on" entry:
##       "per_stacks_add": -1,            a named per-hit aura's per_stacks (at
##       "cap_add_bp": 200,               least 1) and cap_bp (Sharp Reaction)
##       "per_stack_amount_add": 1        a damage's amount_per_stack (Heavy
##                                        Flask)
## and at the top: "shard_cap_add": 2 (its kit's shard_cap, if it has one:
## Deep Purse).
## Phase 8 part 6 (Hob's cards), per "on" entry:
##       "per_shards_add": -2,            a named per-shards aura's per_shards
##       "per_shards_max_add": 5          (at least 1) and, if it has one, its
##                                        cap (Penny Wise, Deep Pockets)
## and within_add also reaches on_enemy_fell's fell_within_hexes (Wider
## Pickings), and an amount_bp naming "leap" in "types" its hexes (Long
## Grab).
## Phase 8 part 6 (Kestra's cards), at the top:
##    "companions": [{"kit": "grit",      its companions of that kit (or, with
##       "hp_add_pct": 15,                no "kit", all of them): their share
##       "atk_add_pct": 15,               of her max HP and ATK, how long
##       "return_add_ms": -4000,          before one that fell returns (only
##       "mod": {...a KitMod...}}]        one that returns), and a mod on its
##                                        own kit (Big Grit, Quick Return,
##                                        Hot Fangs) Effects a card adds to an ability go before a gain_mana aimed
## at the lowest-mana ally, so they reach the ally the mana does (Fizzing
## Vial, Bracing Vial).
## Phase 8 part 5 (Severine's cards), per "on" entry:
##       "lifesteal_add_bp": 500,         a damage effect's own lifesteal, if it
##                                        has any (Deep Bite: Rend's 15% to 20%)
##       "plus_max_hp_add_bp": 500,       a damage effect's plus_bp_of_max_hp,
##                                        if it has one (Massive)
##       "hp_cost_add_bp": -100           its signature's HP cost, if it has
##                                        one (Thin Blood)
##       "raise_grow_add_pct": 20         a raise's grow_hp_pct (Deep Grave)
## and (step 7d) "places_lantern": true at the top: the player places its
## signature's first area before the fight (UnitSetup.lantern).
## and (phase 8 part 3, the Veil Witch) "drops_passives": ["ward"] at the
## top: those passives go (each must be on the kit); a gambit's "arrive_at":
## "back_line" (it arrives beside the other side's hindmost unit, not where
## it was placed: the Burrowing Pup).
## and (step 8c) "drops_signature": true at the top: the kit's signature and
## its mana bar go (an Oath of Silence, Whispering Stones); a mod that does
## this goes last, after any that change the signature.
## and at the top: "plant_add_ms" (how long it plants after moving),
## "engage": {"break_free_add_ms": 1000} (enemies it engages take that
## much longer to break free; and "reach_add": 1, its Engage reaching that
## many hexes farther: phase 8 part 3, the Warden Sentinel), and "mana": {"taken_bp": 15000} (the mana
## it gains from damage taken, times this).
##    "mana": {"max_add": -15, "start_add": 20, "per_attack_add": 2,
##             "regen_add": 1, "max_bp": 9200},  (regen and max_bp: phase 5c
##                                        step 5a, Rift Candle and Hollow Drum)
##                                        its mana bar, if it has one
##    "also_fires": [{"kind": "ally_falls"}],   its signature also fires on
##                                        these (hp_below or ally_falls), free
##    "echo": {"after_ms": 2000, "share_pct": 50}}  its signature fires again
##                                        that long after each fire, at a
##                                        fresh target, with its numbers and
##                                        durations at that share
## affects() says whether a mod changes anything on a kit (for a slot's "no
## effect on this hero"). The modified kit must be sound (UnitDef.problems).

const SLOT_BASIC: String = "basic_attack"
const SLOT_SIGNATURE: String = "signature"
const SLOT_ABILITIES: String = "abilities"
const PASSIVE_PREFIX: String = "passive:"
## The effects an amount_bp gives a power bonus (phase 5c Decision 6).
const POWER_TYPES: Array[EffectDef.Type] = [EffectDef.Type.DAMAGE, EffectDef.Type.HEAL, EffectDef.Type.SHIELD]
## The stats stats_add can add to (KitPatch's, and flat HP, ATK, MGK, and
## DEF for growing cards, phase 5c step 4).
const ADD_STATS: Array[UnitStats.Stat] = [UnitStats.Stat.HP, UnitStats.Stat.ATK, UnitStats.Stat.MGK, UnitStats.Stat.DEF,
	UnitStats.Stat.ATSP, UnitStats.Stat.CRIT, UnitStats.Stat.SPEED, UnitStats.Stat.RANGE]


## One entry of "companions" (phase 8 part 6): changes to its companions of
## one kit ("": all of them).
class CompanionChange:
	var kit_id: String = ""
	var hp_add_bp: int = 0
	var atk_add_bp: int = 0
	var return_add_ticks: int = 0
	var mod: KitMod = null

	func matches(companion: CompanionDef) -> bool:
		return companion.kit != null and (kit_id.is_empty() or companion.kit.id == kit_id)

	## What it does to `companion` (a copy; the companion is untouched).
	func apply(companion: CompanionDef, problems: Array[String]) -> CompanionDef:
		var changed: CompanionDef = companion.copy()
		changed.hp_bp = maxi(changed.hp_bp + hp_add_bp, 100)
		changed.atk_bp = maxi(changed.atk_bp + atk_add_bp, 100)
		if changed.return_ticks > 0:
			changed.return_ticks = maxi(changed.return_ticks + return_add_ticks, FixedMath.TICKS_PER_SECOND)
		if mod != null:
			var built: UnitDef = mod.apply(changed.kit, problems)
			changed.kit = built
		return changed

	func touches(companion: CompanionDef) -> bool:
		if not matches(companion):
			return false
		return hp_add_bp != 0 or atk_add_bp != 0 or (return_add_ticks != 0 and companion.return_ticks > 0) or (mod != null and mod.affects(companion.kit))


## One entry of "on": changes to the abilities in one slot.
class AbilityChange:
	var slot: String
	## Effect types it touches (empty: all).
	var types: Array[EffectDef.Type] = []
	## Statuses it touches (empty: any; non-empty: only apply_status effects
	## of these).
	var statuses: Array[String] = []
	var amount_bp: int = FixedMath.BP_ONE
	var duration_bp: int = FixedMath.BP_ONE
	var duration_add_ticks: int = 0
	var radius_add: int = 0
	var cooldown_bp: int = FixedMath.BP_ONE
	var add_effects: Array[EffectDef] = []
	var after_add_ticks: int = 0
	## amount_bp is a power bonus on damage, heals, and Shields (false: it
	## scales their numbers, as an echo's share does).
	var as_power: bool = true
	## Phase 5c step 6b (Quickcast, Wide): the ability's cast, times this
	## (0: instant), and how many more units its effects on its target reach
	## (the nearest others to it, of the target's side); `one_of`: not on an
	## ability with an area (its radius_add grows that instead).
	var cast_bp: int = FixedMath.BP_ONE
	var targets_add: int = 0
	var one_of: bool = false
	## Phase 5c step 7b (the upgrade pools' small knobs; see the header).
	var at: Array[EffectDef.Target] = []
	var every_add: int = 0
	var times_add: int = 0
	var max_standing_add: int = 0
	var overheal_add_bp: int = 0
	var width_add: int = 0
	var add_to_areas: Array[EffectDef] = []
	var value_add: int = 0
	var guard_share_add: int = 0
	var guard_within_add: int = 0
	var guard_covers_all: bool = false
	var prefer: UnitCondition = null
	## Phase 5c step 7c: a Mark it applies is this much stronger (Heavy Mark).
	var strength_add_bp: int = 0
	## Phase 5c step 7d: its zones follow the biggest group (Chasing Storm),
	## its near-target hits ricochet this many more times (Ricochet), its
	## walls send stopped shots back at this share (Reflecting Wall), and its
	## snares spring on leaps and charges (Snag).
	var follows: bool = false
	var ricochet_add: int = 0
	var reflect_bp: int = 0
	var snags: bool = false
	## Phase 8 part 2 (the apex cards' knobs; see the header).
	var per_enemy_add_bp: int = 0
	var overheal_max_hp_add: int = 0
	var at_stacks_add: int = 0
	var per_taken_add_bp: int = 0
	var grows_add_bp: int = 0
	var grows_boosts_add_bp: int = 0
	var rise_add_bp: int = 0
	var per_shared_bp: int = FixedMath.BP_ONE
	## Phase 8 part 3: the condition its event and timed effects run under.
	var holder: UnitCondition = null
	var carries: bool = false
	## Phase 8 part 4 (see the header).
	var ability_id: String = ""
	var mana_max_add: int = 0
	var ignores_def: bool = false
	## Phase 8 part 5 (see the header); and its zones follow their caster.
	var lifesteal_add_bp: int = 0
	var plus_max_hp_add_bp: int = 0
	## Phase 8 part 5 (Deep Grave): a raise's grow_hp_pct, in bp.
	var raise_grow_add_bp: int = 0
	var hp_cost_add_bp: int = 0
	var follows_holder: bool = false
	var per_twice: UnitCondition = null
	var per_stack_add_bp: int = 0
	## A signature's reach, in hexes (from the unit's own when it has none;
	## Hammer and Wire), and the targets its grip lands twice as often on.
	var reach_add: int = 0
	var grip_fast_vs: UnitCondition = null
	## Near targets' reach (and a named allies_near aura's), in plane units,
	## and a lowest_mana_ally's count (phase 8 part 4, Aldous's cards).
	var within_add: int = 0
	var count_add: int = 0
	## Phase 8 part 6 (Ilse's cards): a stacks_of's share (Deep Stoke), and a
	## growing zone's step time and largest size (Fast Spread, Far Spread).
	var share_add_bp: int = 0
	## Phase 8 part 6 (Perfect Likeness): a growing copy's share per copy.
	var copy_grow_add_bp: int = 0
	var grow_every_add_ticks: int = 0
	var grow_max_add: int = 0
	## A heal's cap (Lantern Vigil): pct of max HP, and the units it holds on.
	var heal_cap_bp: int = 0
	var heal_cap_vs: UnitCondition = null
	## Phase 8 part 6 (Ottilie's cards): a named per-hit aura's per_stacks and
	## cap (Sharp Reaction), and a damage's amount_per_stack (Heavy Flask).
	var per_stacks_add: int = 0
	var cap_add_bp: int = 0
	var per_stack_amount_add: int = 0
	## Phase 8 part 6 (Hob's cards): a named per-shards aura's step and cap
	## (Penny Wise, Deep Pockets).
	var per_shards_add: int = 0
	var per_shards_max_add: int = 0

	## True if it reaches `ability_id` (every ability when it names none).
	func reaches(id: String) -> bool:
		return ability_id.is_empty() or ability_id == id

	func touches_effects() -> bool:
		return amount_bp != FixedMath.BP_ONE or duration_bp != FixedMath.BP_ONE or duration_add_ticks != 0 or radius_add != 0 \
			or every_add != 0 or times_add != 0 or max_standing_add != 0 or overheal_add_bp != 0 or width_add != 0 or not add_to_areas.is_empty() \
			or strength_add_bp != 0 or follows or ricochet_add != 0 or reflect_bp != 0 or snags \
			or per_enemy_add_bp != 0 or overheal_max_hp_add != 0 or at_stacks_add != 0 or per_taken_add_bp != 0 or holder != null or carries \
			or ignores_def or prefer != null and not ability_id.is_empty() or per_stack_add_bp != 0 or within_add != 0 or count_add != 0 \
			or share_add_bp != 0 or copy_grow_add_bp != 0 or grow_every_add_ticks != 0 or grow_max_add != 0 or heal_cap_bp != 0 or per_stack_amount_add != 0 \
			or lifesteal_add_bp != 0 or plus_max_hp_add_bp != 0 or follows_holder or raise_grow_add_bp != 0 or cooldown_bp != FixedMath.BP_ONE

	func touches(effect: EffectDef) -> bool:
		if not at.is_empty() and not at.has(effect.target):
			return false
		if not statuses.is_empty():
			return effect.type == EffectDef.Type.APPLY_STATUS and statuses.has(effect.status_id)
		return types.is_empty() or types.has(effect.type)

	## True if it changes the named passive itself (its aura or its Guard).
	func changes_part() -> bool:
		return value_add != 0 or guard_share_add != 0 or guard_within_add != 0 or guard_covers_all or rise_add_bp != 0 or per_shared_bp != FixedMath.BP_ONE \
			or per_twice != null or per_stacks_add != 0 or cap_add_bp != 0 or per_shards_add != 0 or per_shards_max_add != 0

	## A knockback's, pull's, or (phase 8 part 6, Long Grab) leap's distance
	## scales with amount_bp only when the change names that type (phase 5c
	## step 7: Crushing Blow), so a mod on every effect never moves a push.
	func moves(effect: EffectDef) -> bool:
		return (effect.type == EffectDef.Type.KNOCKBACK or effect.type == EffectDef.Type.PULL or effect.type == EffectDef.Type.LEAP) and types.has(effect.type)


## Indexed by UnitStats.Stat, as in KitPatch.
var stats_bp: Array[int] = []
var stats_add: Array[int] = []
var passives: Array[PartDef] = []
var changes: Array[AbilityChange] = []
var mana_max_add: int = 0
var mana_start_add: int = 0
var mana_per_attack_add: int = 0
var mana_regen_add: int = 0
var mana_max_bp: int = FixedMath.BP_ONE
var also_fires: Array[TriggerDef] = []
var echo_ticks: int = 0
var echo_bp: int = 0
## Phase 5c step 6b: the bar's share it starts each fight with, at least
## (Opener; 0: as it is).
var mana_start_bp: int = 0
## The enemies its targeting picks first (Bloodhound; null: none), and the
## name its picks are logged with.
var prefer: UnitCondition = null
var prefer_label: String = ""
## How near (plane units; 0: anywhere; phase 8 part 4).
var prefer_reach: int = 0
## The hop_away trait: how much nearer an enemy may come before it hops
## (plane units), and its cooldown's change (Light Feet).
var hop_within_add: int = 0
var hop_cooldown_add_ticks: int = 0
## Phase 5c step 7b: how long it plants after moving (Quick Plant), how
## much longer enemies it engages take to break free (Hard to Pass), and
## its mana from damage taken, times this (Grudge).
var plant_add_ticks: int = 0
var break_free_add_ticks: int = 0
## Phase 8 part 3: how much farther its Engage reaches (plane units).
var engage_reach_add: int = 0
## Phase 8 part 6 (Deep Purse): its kit's shard_cap, raised (only a kit
## with one).
var shard_cap_add: int = 0
## Phase 8 part 6 (Kestra): changes to its companions (CompanionChange).
var companion_changes: Array[CompanionChange] = []
var mana_taken_bp: int = FixedMath.BP_ONE
## Phase 5c step 7d: the player places its signature's first area before
## the fight (First Lantern).
var places_lantern: bool = false
var drops_signature: bool = false
var drops_passives: Array[String] = []
## A gambit's rule (phase 5c step 6d; Gambits): its name, where else it may
## start, when it arrives, and when it swaps places (and the Shield then).
var gambit_label: String = ""
var place_rule: String = ""
var arrive_ticks: int = 0
var arrive_at: String = ""
var swap_ticks: int = 0
var swap_shield_bp: int = 0
var swap_choice: bool = false


static func make() -> KitMod:
	var mod := KitMod.new()
	for i: int in UnitStats.STAT_NAMES.size():
		mod.stats_bp.append(FixedMath.BP_ONE)
		mod.stats_add.append(0)
	return mod


static func read(reader: DataReader) -> KitMod:
	var mod: KitMod = make()
	if reader.has("stats_bp"):
		var bp_reader: DataReader = reader.req_object("stats_bp")
		if bp_reader != null:
			for stat: UnitStats.Stat in KitPatch.BP_STATS:
				mod.stats_bp[stat] = bp_reader.opt_int(UnitStats.STAT_NAMES[stat], FixedMath.BP_ONE, 1000, 50000)
			bp_reader.finish()
	if reader.has("stats_add"):
		var add_reader: DataReader = reader.req_object("stats_add")
		if add_reader != null:
			for stat: UnitStats.Stat in ADD_STATS:
				mod.stats_add[stat] = add_reader.opt_int(UnitStats.STAT_NAMES[stat], 0, -100, 1000)
			add_reader.finish()
	for part_reader: DataReader in reader.opt_object_array("passives"):
		mod.passives.append(PartDef.read(part_reader))
	for change_reader: DataReader in reader.opt_object_array("on"):
		mod.changes.append(_read_change(change_reader))
	if reader.has("mana"):
		var mana_reader: DataReader = reader.req_object("mana")
		if mana_reader != null:
			mod.mana_max_add = mana_reader.opt_int("max_add", 0, -100, 100)
			mod.mana_start_add = mana_reader.opt_int("start_add", 0, -100, 100)
			mod.mana_per_attack_add = mana_reader.opt_int("per_attack_add", 0, -20, 20)
			mod.mana_regen_add = mana_reader.opt_int("regen_add", 0, -20, 20)
			mod.mana_max_bp = mana_reader.opt_int("max_bp", FixedMath.BP_ONE, 5000, 20000)
			mod.mana_start_bp = mana_reader.opt_int("start_bp", 0, 0, FixedMath.BP_ONE)
			mod.mana_taken_bp = mana_reader.opt_int("taken_bp", FixedMath.BP_ONE, 1000, 50000)
			mana_reader.finish()
	mod.plant_add_ticks = _signed_ticks(reader, "plant_add_ms")
	mod.shard_cap_add = reader.opt_int("shard_cap_add", 0, -100, 100)
	for companion_reader: DataReader in reader.opt_object_array("companions"):
		var change := CompanionChange.new()
		change.kit_id = companion_reader.opt_string("kit", "")
		change.hp_add_bp = companion_reader.opt_int("hp_add_pct", 0, -100, 100) * 100
		change.atk_add_bp = companion_reader.opt_int("atk_add_pct", 0, -100, 100) * 100
		change.return_add_ticks = _signed_ticks(companion_reader, "return_add_ms")
		if companion_reader.has("mod"):
			var inner: DataReader = companion_reader.req_object("mod")
			change.mod = read(inner) if inner != null else null
		if change.hp_add_bp == 0 and change.atk_add_bp == 0 and change.return_add_ticks == 0 and change.mod == null:
			companion_reader.error("a companion change needs hp_add_pct, atk_add_pct, return_add_ms, or a mod")
		companion_reader.finish()
		mod.companion_changes.append(change)
	mod.places_lantern = reader.opt_bool("places_lantern", false)
	mod.drops_signature = reader.opt_bool("drops_signature", false)
	if reader.has("drops_passives"):
		mod.drops_passives = reader.req_string_array("drops_passives")
	if reader.has("engage"):
		var engage_reader: DataReader = reader.req_object("engage")
		if engage_reader != null:
			mod.break_free_add_ticks = _signed_ticks(engage_reader, "break_free_add_ms")
			mod.engage_reach_add = engage_reader.opt_int("reach_add", 0, 0, 3) * HexGrid.HEX
			engage_reader.finish()
	if reader.has("prefer"):
		var prefer_reader: DataReader = reader.req_object("prefer")
		if prefer_reader != null:
			mod.prefer_label = prefer_reader.req_string("label")
			mod.prefer = UnitCondition.read(prefer_reader.req_object("vs"))
			mod.prefer_reach = prefer_reader.opt_int("within_hexes", 0, 0, 20) * HexGrid.HEX
			prefer_reader.finish()
	if reader.has("gambit"):
		var gambit: DataReader = reader.req_object("gambit")
		if gambit != null:
			mod.gambit_label = gambit.req_string("label")
			mod.place_rule = gambit.opt_string_choice("place", "", Gambits.PLACES)
			mod.arrive_ticks = gambit.opt_ticks("arrive_ms", 0)
			mod.arrive_at = gambit.opt_string_choice("arrive_at", "", Gambits.ARRIVE_AT)
			if not mod.arrive_at.is_empty() and mod.arrive_ticks == 0:
				gambit.error("arrive_at needs arrive_ms")
			mod.swap_ticks = gambit.opt_ticks("swap_ms", 0)
			mod.swap_shield_bp = gambit.opt_int("swap_shield_bp", 0, 0, FixedMath.BP_ONE)
			mod.swap_choice = gambit.opt_bool("swap_choice", false)
			gambit.finish()
	if reader.has("hop"):
		var hop_reader: DataReader = reader.req_object("hop")
		if hop_reader != null:
			mod.hop_within_add = hop_reader.opt_int("within_add", 0, 0, 2 * HexGrid.HEX)
			mod.hop_cooldown_add_ticks = _signed_ticks(hop_reader, "cooldown_add_ms")
			hop_reader.finish()
	for trigger_reader: DataReader in reader.opt_object_array("also_fires"):
		var trigger: TriggerDef = TriggerDef.read(trigger_reader)
		if not TriggerDef.ALSO_KINDS.has(trigger.kind):
			reader.error("also_fires: a signature can also fire on hp_below, ally_falls, or every, not %s" % TriggerDef.KIND_NAMES[trigger.kind])
		mod.also_fires.append(trigger)
	if reader.has("echo"):
		var echo_reader: DataReader = reader.req_object("echo")
		if echo_reader != null:
			mod.echo_ticks = echo_reader.req_ticks("after_ms", FixedMath.MS_PER_TICK)
			mod.echo_bp = echo_reader.req_int("share_pct", 1, 100) * 100
			echo_reader.finish()
	if not mod.changes_anything():
		reader.error("a mod needs stats_bp, stats_add, passives, on, mana, also_fires, or echo")
	reader.finish()
	return mod


static func _read_change(reader: DataReader) -> AbilityChange:
	var change := AbilityChange.new()
	change.slot = reader.req_string("slot")
	if not change.slot in [SLOT_BASIC, SLOT_SIGNATURE, SLOT_ABILITIES] and not change.slot.begins_with(PASSIVE_PREFIX):
		reader.error("slot: expected basic_attack, signature, abilities, or passive:<id>, got \"%s\"" % change.slot)
	if reader.has("types"):
		for type_name: String in reader.opt_choice_array("types", EffectDef.TYPE_NAMES):
			change.types.append(EffectDef.TYPE_NAMES.find(type_name) as EffectDef.Type)
	if reader.has("statuses"):
		change.statuses = reader.req_string_array("statuses")
		if change.statuses.is_empty():
			reader.error("statuses: name at least one")
		if not change.types.is_empty():
			reader.error("an \"on\" entry takes types or statuses, not both")
	change.amount_bp = reader.opt_int("amount_bp", FixedMath.BP_ONE, 1000, 50000)
	change.duration_bp = reader.opt_int("duration_bp", FixedMath.BP_ONE, 1000, 50000)
	change.duration_add_ticks = _signed_ticks(reader, "duration_add_ms")
	change.radius_add = reader.opt_int("radius_add", 0, -3, 3)
	change.cooldown_bp = reader.opt_int("cooldown_bp", FixedMath.BP_ONE, 1000, 50000)
	for effect_reader: DataReader in reader.opt_object_array("add_effects"):
		change.add_effects.append(EffectDef.read(effect_reader))
	change.after_add_ticks = _signed_ticks(reader, "after_add_ms")
	change.cast_bp = reader.opt_int("cast_bp", FixedMath.BP_ONE, 0, FixedMath.BP_ONE)
	change.targets_add = reader.opt_int("targets_add", 0, 0, 5)
	change.one_of = reader.opt_bool("one_of", false)
	for target_name: String in reader.opt_choice_array("at", EffectDef.TARGET_NAMES):
		change.at.append(EffectDef.TARGET_NAMES.find(target_name) as EffectDef.Target)
	change.every_add = reader.opt_int("every_add", 0, -10, 10)
	change.times_add = reader.opt_int("times_add", 0, 0, 5)
	change.max_standing_add = reader.opt_int("max_standing_add", 0, 0, 5)
	change.overheal_add_bp = reader.opt_int("overheal_shield_add_bp", 0, 0, FixedMath.BP_ONE)
	change.width_add = reader.opt_int("width_add", 0, 0, 3)
	for effect_reader: DataReader in reader.opt_object_array("add_to_areas"):
		change.add_to_areas.append(EffectDef.read(effect_reader, false, true))
	change.value_add = reader.opt_int("value_add", 0, -100000, 100000)
	change.strength_add_bp = reader.opt_int("strength_add_bp", 0, 0, FixedMath.BP_ONE)
	var follow_rule: String = reader.opt_string_choice("follows", "", ["largest_group", "holder"])
	change.follows = follow_rule == "largest_group"
	change.follows_holder = follow_rule == "holder"
	change.ricochet_add = reader.opt_int("ricochet_add", 0, 0, 5)
	change.reflect_bp = reader.opt_int("reflect_bp", 0, 0, FixedMath.BP_ONE)
	change.snags = reader.opt_bool("snags", false)
	change.per_enemy_add_bp = reader.opt_int("per_enemy_add_bp", 0, -FixedMath.BP_ONE, FixedMath.BP_ONE)
	change.overheal_max_hp_add = reader.opt_int("overheal_max_hp_add", 0, -100, 100)
	change.at_stacks_add = reader.opt_int("at_stacks_add", 0, -10, 10)
	change.per_taken_add_bp = reader.opt_int("per_taken_add_bp", 0, -FixedMath.BP_ONE, FixedMath.BP_ONE)
	change.grows_add_bp = reader.opt_int("grows_add_bp", 0, -FixedMath.BP_ONE, FixedMath.BP_ONE)
	change.grows_boosts_add_bp = reader.opt_int("grows_boosts_add_bp", 0, -FixedMath.BP_ONE, FixedMath.BP_ONE)
	change.rise_add_bp = reader.opt_int("rise_add_pct", 0, -99, 99) * 100
	change.per_shared_bp = reader.opt_int("per_shared_bp", FixedMath.BP_ONE, 1000, 50000)
	if (change.grows_add_bp != 0 or change.grows_boosts_add_bp != 0) and change.slot != SLOT_SIGNATURE:
		reader.error("grows_add_bp and grows_boosts_add_bp change a signature (\"slot\": \"signature\")")
	if reader.has("guard"):
		var guard: DataReader = reader.req_object("guard")
		if guard != null:
			change.guard_share_add = guard.opt_int("share_add", 0, -100, 100) * 100
			change.guard_within_add = guard.opt_int("within_add", 0, -3, 3) * HexGrid.HEX
			change.guard_covers_all = guard.opt_bool("covers_all", false)
			guard.finish()
	if reader.has("prefer"):
		change.prefer = UnitCondition.read(reader.req_object("prefer"))
	if reader.has("holder"):
		change.holder = UnitCondition.read(reader.req_object("holder"))
	change.carries = reader.opt_bool("carries", false)
	change.ability_id = reader.opt_string("ability", "")
	change.mana_max_add = reader.opt_int("mana_max_add", 0, -100, 100)
	change.ignores_def = reader.opt_bool("ignores_def", false)
	change.lifesteal_add_bp = reader.opt_int("lifesteal_add_bp", 0, -FixedMath.BP_ONE, FixedMath.BP_ONE)
	change.plus_max_hp_add_bp = reader.opt_int("plus_max_hp_add_bp", 0, -FixedMath.BP_ONE, FixedMath.BP_ONE)
	change.raise_grow_add_bp = reader.opt_int("raise_grow_add_pct", 0, -100, 100) * 100
	change.hp_cost_add_bp = reader.opt_int("hp_cost_add_bp", 0, -FixedMath.BP_ONE, FixedMath.BP_ONE)
	change.per_stack_add_bp = reader.opt_int("per_stack_add_bp", 0, -FixedMath.BP_ONE, FixedMath.BP_ONE)
	if reader.has("per_twice"):
		change.per_twice = UnitCondition.read(reader.req_object("per_twice"))
	change.reach_add = reader.opt_int("reach_add", 0, -3, 9)
	change.within_add = reader.opt_int("within_add", 0, -3, 3) * HexGrid.HEX
	change.count_add = reader.opt_int("count_add", 0, 0, 4)
	change.share_add_bp = reader.opt_int("share_add_bp", 0, -FixedMath.BP_ONE, FixedMath.BP_ONE)
	change.copy_grow_add_bp = reader.opt_int("per_copy_add_pct", 0, -100, 100) * 100
	change.grow_every_add_ticks = reader.opt_ticks("grow_every_add_ms", 0, -10000)
	change.grow_max_add = reader.opt_int("grow_max_add", 0, -3, 3)
	change.per_stacks_add = reader.opt_int("per_stacks_add", 0, -10, 10)
	change.cap_add_bp = reader.opt_int("cap_add_bp", 0, -FixedMath.BP_ONE, FixedMath.BP_ONE)
	change.per_stack_amount_add = reader.opt_int("per_stack_amount_add", 0, -10, 10)
	change.per_shards_add = reader.opt_int("per_shards_add", 0, -20, 20)
	change.per_shards_max_add = reader.opt_int("per_shards_max_add", 0, -20, 50)
	if reader.has("heal_cap"):
		var cap: DataReader = reader.req_object("heal_cap")
		if cap != null:
			change.heal_cap_bp = cap.req_int("pct", 1, 99) * 100
			if cap.has("vs"):
				change.heal_cap_vs = UnitCondition.read(cap.req_object("vs"))
			cap.finish()
	if reader.has("grip_fast_vs"):
		change.grip_fast_vs = UnitCondition.read(reader.req_object("grip_fast_vs"))
	if (change.reach_add != 0 or change.grip_fast_vs != null) and change.slot != SLOT_SIGNATURE and change.ability_id.is_empty():
		reader.error("reach_add and grip_fast_vs change a signature (\"slot\": \"signature\", or a named \"ability\")")
	if not change.ability_id.is_empty() and change.slot != SLOT_ABILITIES:
		reader.error("\"ability\" names one of its abilities (\"slot\": \"abilities\")")
	if change.mana_max_add != 0 and change.ability_id.is_empty():
		reader.error("mana_max_add changes what a named ability costs (\"ability\")")
	if (change.cast_bp != FixedMath.BP_ONE or change.targets_add > 0) and change.slot != SLOT_SIGNATURE \
			or change.prefer != null and change.slot != SLOT_SIGNATURE and change.ability_id.is_empty():
		reader.error("cast_bp, targets_add, and prefer change a signature (\"slot\": \"signature\"; prefer also a named \"ability\")")
	if (change.changes_part() or change.after_add_ticks != 0) and not change.slot.begins_with(PASSIVE_PREFIX):
		reader.error("after_add_ms, value_add, guard, rise_add_pct, per_shared_bp, per_twice, per_stacks_add, cap_add_bp, per_shards_add, and per_shards_max_add change a named passive (\"slot\": \"passive:<id>\")")
	if not (change.touches_effects() or change.cooldown_bp != FixedMath.BP_ONE or not change.add_effects.is_empty() or change.after_add_ticks != 0
			or change.cast_bp != FixedMath.BP_ONE or change.targets_add > 0 or change.changes_part() or change.prefer != null
			or change.grows_add_bp != 0 or change.grows_boosts_add_bp != 0 or change.mana_max_add != 0 or change.reach_add != 0 or change.grip_fast_vs != null
			or change.hp_cost_add_bp != 0):
		reader.error("an \"on\" entry needs amount_bp, duration_bp, duration_add_ms, radius_add, cooldown_bp, add_effects, after_add_ms, cast_bp, targets_add, or one of step 7b's knobs")
	reader.finish()
	return change


## A signed duration in ms (whole ticks), as ticks.
static func _signed_ticks(reader: DataReader, key: String) -> int:
	var ms: int = reader.opt_int(key, 0, -60000, 60000)
	if ms % FixedMath.MS_PER_TICK != 0:
		reader.error("%s: must be a multiple of %d ms (one tick)" % [key, FixedMath.MS_PER_TICK])
	return FixedMath.ms_to_ticks(ms)


## Why this mod can't be a growing card's step ("" if it can): a step may
## only multiply or add stats, change abilities' amount_bp, or add auras,
## since those are what scale cleanly (phase 5c step 4, section 9.3), or (phase
## 8 part 6, Midas Touch) raise the shard cap.
func step_problem() -> String:
	if _changes_mana() or not also_fires.is_empty() or echo_ticks > 0 or prefer != null or hop_within_add != 0 or hop_cooldown_add_ticks != 0 \
			or not gambit_label.is_empty() or plant_add_ticks != 0 or break_free_add_ticks != 0 or engage_reach_add != 0 or places_lantern or drops_signature \
			or not drops_passives.is_empty():
		return "a growing card's step can't change mana, add triggers, echo, targeting, or hops"
	for part: PartDef in passives:
		if part.kind != PartDef.Kind.AURA:
			return "a growing card's step can only add auras (\"%s\" isn't one)" % part.id
	for change: AbilityChange in changes:
		if change.duration_bp != FixedMath.BP_ONE or change.duration_add_ticks != 0 or change.radius_add != 0 \
				or change.cooldown_bp != FixedMath.BP_ONE or not change.add_effects.is_empty() or change.after_add_ticks != 0 \
				or change.cast_bp != FixedMath.BP_ONE or change.targets_add > 0 or change.every_add != 0 or change.times_add != 0 \
				or change.max_standing_add != 0 or change.overheal_add_bp != 0 or change.width_add != 0 or not change.add_to_areas.is_empty() \
				or change.changes_part() or change.prefer != null or not change.at.is_empty() or change.strength_add_bp != 0 \
				or change.follows or change.ricochet_add != 0 or change.reflect_bp != 0 or change.snags \
				or change.per_enemy_add_bp != 0 or change.overheal_max_hp_add != 0 or change.at_stacks_add != 0 or change.per_taken_add_bp != 0 \
				or change.grows_add_bp != 0 or change.grows_boosts_add_bp != 0 or change.holder != null or change.carries \
				or change.mana_max_add != 0 or change.ignores_def or change.per_twice != null or change.per_stack_add_bp != 0 \
				or change.reach_add != 0 or change.grip_fast_vs != null or change.lifesteal_add_bp != 0 or change.plus_max_hp_add_bp != 0 \
				or change.hp_cost_add_bp != 0 or change.follows_holder or change.raise_grow_add_bp != 0:
			return "a growing card's step can only change an ability's amount_bp (or a share)"
	return ""


## This mod `steps` times over (phase 5c step 4: a growing card's bonus): each
## change n times, added (by the damage rule, ten +1% steps are +10%). Only
## for a mod with no step_problem(). Null for 0 steps.
func times(steps: int) -> KitMod:
	if steps <= 0:
		return null
	var scaled: KitMod = make()
	for stat: int in stats_bp.size():
		scaled.stats_bp[stat] = FixedMath.BP_ONE + steps * (stats_bp[stat] - FixedMath.BP_ONE)
		scaled.stats_add[stat] = steps * stats_add[stat]
	for part: PartDef in passives:
		var copy: PartDef = DefCopy.shallow(part) as PartDef
		var aura: AuraDef = DefCopy.shallow(part.aura) as AuraDef
		aura.value = steps * aura.value if aura.is_additive() else FixedMath.BP_ONE + steps * (aura.value - FixedMath.BP_ONE)
		copy.aura = aura
		scaled.passives.append(copy)
	# A shard cap's step adds up (phase 8 part 6, Midas Touch).
	scaled.shard_cap_add = steps * shard_cap_add
	# So do a companion's shares and its own kit's (phase 8 part 6, Old Leash).
	for change: CompanionChange in companion_changes:
		var each := CompanionChange.new()
		each.kit_id = change.kit_id
		each.hp_add_bp = steps * change.hp_add_bp
		each.atk_add_bp = steps * change.atk_add_bp
		each.return_add_ticks = steps * change.return_add_ticks
		each.mod = change.mod.times(steps) if change.mod != null else null
		scaled.companion_changes.append(each)
	for change: AbilityChange in changes:
		var copy := AbilityChange.new()
		copy.slot = change.slot
		# The ability it names, if any (phase 8 part 6, Silvered Glass: Mirror,
		# a signature or a habit).
		copy.ability_id = change.ability_id
		copy.types = change.types.duplicate()
		copy.statuses = change.statuses.duplicate()
		copy.as_power = change.as_power
		copy.amount_bp = FixedMath.BP_ONE + steps * (change.amount_bp - FixedMath.BP_ONE)
		# A share's step adds up (phase 8 part 6, Silvered Glass).
		copy.share_add_bp = steps * change.share_add_bp
		scaled.changes.append(copy)
	return scaled


func changes_anything() -> bool:
	for stat: int in stats_bp.size():
		if stats_bp[stat] != FixedMath.BP_ONE or stats_add[stat] != 0:
			return true
	return not passives.is_empty() or not changes.is_empty() or _changes_mana() or not also_fires.is_empty() or echo_ticks > 0 \
		or prefer != null or hop_within_add != 0 or hop_cooldown_add_ticks != 0 or not gambit_label.is_empty() or plant_add_ticks != 0 or shard_cap_add != 0 \
		or break_free_add_ticks != 0 or engage_reach_add != 0 or places_lantern or drops_signature or not drops_passives.is_empty() \
		or not companion_changes.is_empty()


func _changes_mana() -> bool:
	return mana_max_add != 0 or mana_start_add != 0 or mana_per_attack_add != 0 or mana_regen_add != 0 or mana_max_bp != FixedMath.BP_ONE \
		or mana_start_bp > 0 or mana_taken_bp != FixedMath.BP_ONE


## True if the mod changes anything on `kit` (stats and passives always do;
## a change to abilities only if the slot is there and has effects of its
## types; mana only on a kit with a mana bar).
func affects(kit: UnitDef) -> bool:
	return not passives.is_empty() or affects_besides_passives(kit)


## affects() without its added passives (whether those can ever fire is the
## caller's to judge: the upgrade pools' "changes nothing", phase 5c step 7).
func affects_besides_passives(kit: UnitDef) -> bool:
	for stat: int in stats_bp.size():
		if stats_bp[stat] != FixedMath.BP_ONE or stats_add[stat] != 0:
			return true
	if kit.mana != null and _changes_mana():
		return true
	if kit.signature != null and (not also_fires.is_empty() or echo_ticks > 0):
		return true
	if prefer != null or (kit.hop_cooldown_ticks > 0 and (hop_within_add != 0 or hop_cooldown_add_ticks != 0)) or not gambit_label.is_empty():
		return true
	if plant_add_ticks != 0 and kit.plant_ticks > 0 or (break_free_add_ticks != 0 or engage_reach_add != 0) and kit.has_trait("engage"):
		return true
	if shard_cap_add != 0 and kit.shard_cap > 0:
		return true
	for change: CompanionChange in companion_changes:
		if kit.companions.any(func(companion: CompanionDef) -> bool: return change.touches(companion)):
			return true
	if places_lantern and lantern_area(kit) != null or drops_signature and kit.signature != null:
		return true
	if drops_passives.any(func(part_id: String) -> bool: return _passive_index(kit, PASSIVE_PREFIX + part_id) >= 0):
		return true
	for change: AbilityChange in changes:
		if change.mana_max_add != 0:
			# A named ability's cost: its signature's bar, or its habit's every.
			if kit.signature != null and kit.signature.id == change.ability_id and kit.mana != null:
				return true
			var habit: int = _passive_index(kit, PASSIVE_PREFIX + change.ability_id)
			if habit >= 0 and kit.passives[habit].ability != null and kit.passives[habit].ability.effects.any(func(effect: EffectDef) -> bool: return effect.every > 1):
				return true
		if (change.radius_add != 0 or change.per_twice != null) and _per_enemy_aura(kit, change.slot) != null:
			return true
		if change.per_twice != null and _slot_aura(kit, change.slot) != null and _slot_aura(kit, change.slot).per_allied_unit:
			# Who counts twice for a per-allied-unit aura (phase 8 part 6, Lead Puppet).
			return true
		if change.within_add != 0 and _near_aura(kit, change.slot) != null:
			return true
		if change.changes_part():
			var at: int = _passive_index(kit, change.slot)
			if at >= 0 and (change.value_add != 0 and kit.passives[at].aura != null
					or (change.per_stacks_add != 0 or change.cap_add_bp != 0) and kit.passives[at].aura != null and not kit.passives[at].aura.per_target_stacks.is_empty()
					or kit.passives[at].aura != null and kit.passives[at].aura.per_shards > 0
						and (change.per_shards_add != 0 or change.per_shards_max_add != 0 and kit.passives[at].aura.per_shards_max > 0)
					or kit.passives[at].kind == PartDef.Kind.GUARD and
					(change.guard_share_add != 0 or change.guard_within_add != 0 or change.guard_covers_all and kit.passives[at].behind_only)
					or change.rise_add_bp != 0 and kit.passives[at].kind == PartDef.Kind.RISE
					or change.per_shared_bp != FixedMath.BP_ONE and kit.passives[at].kind == PartDef.Kind.LINK and kit.passives[at].per_shared > 0):
				return true
		for ability: AbilityDef in _slot_abilities(kit, change.slot, change.ability_id):
			if not change.add_effects.is_empty() or change.cooldown_bp != FixedMath.BP_ONE or change.prefer != null:
				return true
			if change.grows_add_bp != 0 and ability.grows_bp > 0 or change.grows_boosts_add_bp != 0 and ability.grows_boosts_bp > 0:
				return true
			if change.cast_bp != FixedMath.BP_ONE and ability.cast_ticks > 0:
				return true
			if change.hp_cost_add_bp != 0 and ability.hp_cost_bp > 0:
				return true
			if change.reach_add != 0 and ability.is_signature() or change.grip_fast_vs != null and not ability.grip_status.is_empty():
				return true
			if change.targets_add > 0 and not _extra_targets(ability, change).is_empty():
				return true
			if change.touches_effects() and (_any_effect(ability.effects, change) or _any_effect(ability.grip_effects, change)):
				return true
		if change.after_add_ticks != 0 and _slot_aura(kit, change.slot) != null:
			return true
	return false


## `kit` with the mod applied (a new UnitDef; `kit` and the content it shares
## are untouched), and what's wrong in `problems`.
func apply(kit: UnitDef, problems: Array[String] = []) -> UnitDef:
	var built: UnitDef = kit.copy()
	built.phases = kit.phases
	built.stats = kit.stats.copy()
	for stat: int in built.stats.values.size():
		built.stats.values[stat] = FixedMath.apply_bp(built.stats.values[stat], stats_bp[stat]) + stats_add[stat]
	if built.stats.values[UnitStats.Stat.HP] < 1:
		problems.append("its HP would drop below 1")
	if built.stats.values[UnitStats.Stat.RANGE] < 1:
		problems.append("its range would drop below 1")
	for part_id: String in drops_passives:
		if not built.passives.any(func(other: PartDef) -> bool: return other.id == part_id):
			problems.append("it has no passive \"%s\" to drop" % part_id)
		built.passives = built.passives.filter(func(other: PartDef) -> bool: return other.id != part_id)
	for part: PartDef in passives:
		if built.passives.any(func(other: PartDef) -> bool: return other.id == part.id):
			problems.append("it already has a passive \"%s\"" % part.id)
		built.passives.append(part)
	if built.mana != null and _changes_mana():
		var mana: ManaDef = DefCopy.shallow(built.mana) as ManaDef
		mana.max = maxi(FixedMath.apply_bp(mana.max, mana_max_bp) + mana_max_add, 1)
		mana.regen_per_s = maxi(mana.regen_per_s + mana_regen_add, 0)
		mana.start = clampi(mana.start + mana_start_add, 0, mana.max)
		if mana_start_bp > 0:
			mana.start = maxi(mana.start, FixedMath.apply_bp(mana.max, mana_start_bp))
		mana.per_attack = maxi(mana.per_attack + mana_per_attack_add, 0)
		mana.taken_bp = FixedMath.apply_bp(mana.taken_bp, mana_taken_bp)
		built.mana = mana
	if built.plant_ticks > 0:
		built.plant_ticks = maxi(built.plant_ticks + plant_add_ticks, 0)
	if built.shard_cap > 0:
		built.shard_cap = maxi(built.shard_cap + shard_cap_add, 1)
	for change: CompanionChange in companion_changes:
		for i: int in built.companions.size():
			if change.matches(built.companions[i]):
				built.companions[i] = change.apply(built.companions[i], problems)
	if built.has_trait("engage"):
		built.break_free_add_ticks += break_free_add_ticks
		built.engage_reach_add += engage_reach_add
	if places_lantern and lantern_area(built) != null:
		built.placed_lantern = true
	for change: AbilityChange in changes:
		_apply_change(built, change, problems)
	if prefer != null:
		built.prefer = prefer
		built.prefer_label = prefer_label
		built.prefer_reach = prefer_reach
	if not gambit_label.is_empty():
		built.gambit_label = gambit_label
		built.place_rule = place_rule
		built.arrive_ticks = arrive_ticks
		built.arrive_at = arrive_at
		built.swap_ticks = swap_ticks
		built.swap_shield_bp = swap_shield_bp
		built.swap_choice = swap_choice
	if built.hop_cooldown_ticks > 0:
		built.hop_within += hop_within_add
		built.hop_cooldown_ticks = maxi(built.hop_cooldown_ticks + hop_cooldown_add_ticks, 1)
	if built.signature != null and (not also_fires.is_empty() or echo_ticks > 0):
		var signature: AbilityDef = DefCopy.shallow(built.signature) as AbilityDef
		signature.also.append_array(also_fires)
		if echo_ticks > 0:
			signature.echo_ticks = echo_ticks
			signature.echo = make_echo(signature, echo_bp)
		built.signature = signature
	if drops_signature:
		built.signature = null
		built.mana = null
	problems.append_array(built.problems())
	return built


## The area a placed lantern lights (phase 5c step 7d): its signature's
## first zone, or null.
static func lantern_area(kit: UnitDef) -> EffectDef:
	if kit.signature == null:
		return null
	for effect: EffectDef in kit.signature.effects:
		if effect.type == EffectDef.Type.AREA and effect.zone_ticks > 0:
			return effect
	return null


## A signature's echo: a copy without a trigger, "<id>_echo" and
## "<name> (Echo)", its numbers and durations at `share_bp`.
static func make_echo(signature: AbilityDef, share_bp: int) -> AbilityDef:
	var echo: AbilityDef = DefCopy.shallow(signature) as AbilityDef
	echo.id = signature.id + "_echo"
	echo.name = signature.name + " (Echo)"
	echo.trigger = null
	echo.also = []
	echo.echo = null
	echo.echo_ticks = 0
	echo.cast_ticks = 0
	var change := AbilityChange.new()
	change.amount_bp = share_bp
	change.as_power = false
	change.duration_bp = share_bp
	echo.effects = _changed_effects(signature.effects, change)
	return echo


func _apply_change(built: UnitDef, change: AbilityChange, problems: Array[String]) -> void:
	if change.slot.begins_with(PASSIVE_PREFIX) and _passive_index(built, change.slot) < 0:
		problems.append("it has no passive \"%s\"" % change.slot.trim_prefix(PASSIVE_PREFIX))
		return
	if change.slot in [SLOT_BASIC, SLOT_ABILITIES] and change.reaches(built.basic_attack.id):
		built.basic_attack = _changed_ability(built.basic_attack, change)
	if change.slot in [SLOT_SIGNATURE, SLOT_ABILITIES] and built.signature != null and change.reaches(built.signature.id):
		built.signature = _changed_ability(built.signature, change)
		if change.mana_max_add != 0 and built.mana != null:
			# What the named signature costs (phase 8 part 4, Swift Haul).
			var mana: ManaDef = DefCopy.shallow(built.mana) as ManaDef
			mana.max = maxi(mana.max + change.mana_max_add, 1)
			mana.start = mini(mana.start, mana.max)
			built.mana = mana
	for i: int in built.passives.size():
		var part: PartDef = built.passives[i]
		var named: bool = change.slot == PASSIVE_PREFIX + part.id
		if not named and change.slot != SLOT_ABILITIES or not change.reaches(part.id):
			continue
		if change.mana_max_add != 0 and part.ability != null:
			# On a habit, a cost change moves its every by one (phase 8 part
			# 4: "costs less mana" fires one attack sooner).
			var habit: AbilityChange = _as_habit(change)
			var habit_copy: PartDef = DefCopy.shallow(part) as PartDef
			habit_copy.ability = _changed_ability(part.ability, habit)
			built.passives[i] = habit_copy
			continue
		if part.ability == null and not (named and (change.after_add_ticks != 0 or change.changes_part() or change.radius_add != 0 or change.within_add != 0)):
			continue
		var copy: PartDef = DefCopy.shallow(part) as PartDef
		if part.ability != null:
			copy.ability = _changed_ability(part.ability, change)
		if named and (change.after_add_ticks != 0 or change.value_add != 0 or change.per_stacks_add != 0 or change.cap_add_bp != 0
				or change.per_shards_add != 0 or change.per_shards_max_add != 0) and part.aura != null:
			copy.aura = DefCopy.shallow(part.aura) as AuraDef
			copy.aura.after_ticks = maxi(copy.aura.after_ticks + change.after_add_ticks, 0)
			copy.aura.value += change.value_add
			if not part.aura.per_target_stacks.is_empty():
				# Reaction's count and cap (phase 8 part 6, Sharp Reaction).
				copy.aura.per_stacks = maxi(part.aura.per_stacks + change.per_stacks_add, 1)
				if part.aura.cap_bp > 0:
					copy.aura.cap_bp = maxi(part.aura.cap_bp + change.cap_add_bp, 1)
			if part.aura.per_shards > 0:
				# Nest Egg's step and cap (phase 8 part 6, Penny Wise, Deep Pockets).
				copy.aura.per_shards = maxi(part.aura.per_shards + change.per_shards_add, 1)
				if part.aura.per_shards_max > 0:
					copy.aura.per_shards_max = maxi(part.aura.per_shards_max + change.per_shards_max_add, 1)
		if named and part.kind == PartDef.Kind.RISE and change.rise_add_bp != 0:
			copy.rise_hp_bp = clampi(copy.rise_hp_bp + change.rise_add_bp, 100, FixedMath.BP_ONE)
		if named and part.kind == PartDef.Kind.LINK and change.per_shared_bp != FixedMath.BP_ONE and part.per_shared > 0:
			copy.per_shared = maxi(FixedMath.apply_bp(part.per_shared, change.per_shared_bp), 1)
		if named and part.aura != null and part.aura.per_enemy_range > 0 and (change.radius_add != 0 or change.per_twice != null):
			# A per-enemy aura's reach and who counts twice (phase 8 part 4).
			copy.aura = DefCopy.shallow(copy.aura if copy.aura != null else part.aura) as AuraDef
			copy.aura.per_enemy_range = maxi(copy.aura.per_enemy_range + change.radius_add * HexGrid.HEX, HexGrid.HEX)
			if change.per_twice != null:
				copy.aura.per_twice = change.per_twice
		if named and part.aura != null and part.aura.per_allied_unit and change.per_twice != null:
			# Who counts twice for a per-allied-unit aura (phase 8 part 6, Lead
			# Puppet); one who already counts twice still does (The Menagerie).
			copy.aura = DefCopy.shallow(copy.aura if copy.aura != null else part.aura) as AuraDef
			copy.aura.per_twice = change.per_twice if copy.aura.per_twice == null else UnitCondition.either(copy.aura.per_twice, change.per_twice)
		if named and part.aura != null and part.aura.target == AuraDef.Target.ALLIES_NEAR and change.within_add != 0:
			# An allies_near aura's reach (phase 8 part 4, Far Resonance).
			copy.aura = DefCopy.shallow(copy.aura if copy.aura != null else part.aura) as AuraDef
			copy.aura.target_range = maxi(copy.aura.target_range + change.within_add, HexGrid.HEX)
		if named and part.kind == PartDef.Kind.GUARD:
			copy.share_bp = clampi(copy.share_bp + change.guard_share_add, 100, FixedMath.BP_ONE)
			copy.guard_range = maxi(copy.guard_range + change.guard_within_add, HexGrid.HEX)
			copy.behind_only = copy.behind_only and not change.guard_covers_all
		built.passives[i] = copy


static func _changed_ability(ability: AbilityDef, change: AbilityChange) -> AbilityDef:
	var copy: AbilityDef = DefCopy.shallow(ability) as AbilityDef
	if change.cooldown_bp != FixedMath.BP_ONE:
		copy.cooldown_ticks = maxi(FixedMath.apply_bp(copy.cooldown_ticks, change.cooldown_bp), 1)
	if change.cast_bp != FixedMath.BP_ONE:
		copy.cast_ticks = FixedMath.apply_bp(copy.cast_ticks, change.cast_bp)
	if change.prefer != null:
		copy.prefer = change.prefer
	if change.reach_add != 0 and ability.is_signature():
		# From the unit's own reach when it has none (a melee unit's: 1).
		copy.max_range = maxi((copy.max_range if copy.max_range > 0 else 1) + change.reach_add, 1)
	if change.grip_fast_vs != null and not ability.grip_status.is_empty():
		copy.grip_fast_vs = change.grip_fast_vs
	if change.grows_add_bp != 0 and ability.grows_bp > 0:
		copy.grows_bp = maxi(ability.grows_bp + change.grows_add_bp, 0)
	if change.grows_boosts_add_bp != 0 and ability.grows_boosts_bp > 0:
		copy.grows_boosts_bp = maxi(ability.grows_boosts_bp + change.grows_boosts_add_bp, 0)
	if change.hp_cost_add_bp != 0 and ability.hp_cost_bp > 0:
		copy.hp_cost_bp = clampi(ability.hp_cost_bp + change.hp_cost_add_bp, 1, 9000)
	if change.touches_effects():
		copy.effects = _changed_effects(ability.effects, change)
		# A grip's effects too (phase 8 part 4, Tightening Cord).
		if not ability.grip_effects.is_empty():
			copy.grip_effects = _changed_effects(ability.grip_effects, change)
	else:
		copy.effects = copy.effects.duplicate()
	if change.targets_add > 0:
		copy.effects.append_array(_extra_targets(ability, change))
	# Added effects go before the ability spends its Shield, so they still
	# read it (phase 8 part 4, Shared Ward).
	var spends: int = -1
	for i: int in copy.effects.size():
		if copy.effects[i].type == EffectDef.Type.SPEND_SHIELD:
			spends = i
			break
		# And before mana to the lowest-mana ally, so they reach the ally the
		# mana does (phase 8 part 6, Fizzing Vial).
		if copy.effects[i].type == EffectDef.Type.GAIN_MANA and copy.effects[i].target == EffectDef.Target.LOWEST_MANA_ALLY:
			spends = i
			break
	if spends < 0 or change.add_effects.is_empty():
		copy.effects.append_array(change.add_effects)
	else:
		var before: Array[EffectDef] = copy.effects.slice(0, spends)
		before.append_array(change.add_effects)
		before.append_array(copy.effects.slice(spends))
		copy.effects = before
	for effect: EffectDef in change.add_effects:
		copy.has_hit_effects = copy.has_hit_effects or effect.trigger != EffectDef.Trigger.ON_FIRE
	return copy


## Wide's extra targets (phase 5c step 6b): a copy of each of `ability`'s
## effects on its target, reaching the `targets_add` units nearest that
## target of its side (an ally for a signature that picks allies). None for
## one aimed at itself, or (`one_of`) one with an area.
static func _extra_targets(ability: AbilityDef, change: AbilityChange) -> Array[EffectDef]:
	var extra: Array[EffectDef] = []
	if ability.targeting == "self" or (change.one_of and ability.effects.any(func(effect: EffectDef) -> bool: return effect.type == EffectDef.Type.AREA)):
		return extra
	for effect: EffectDef in ability.effects:
		if effect.trigger != EffectDef.Trigger.ON_FIRE or effect.target != EffectDef.Target.TARGET or not COPIED_TYPES.has(effect.type):
			continue
		var copy: EffectDef = DefCopy.shallow(effect) as EffectDef
		copy.target = EffectDef.Target.ALLY_NEAR_TARGET if ability.targeting == "lowest_hp_ally" else EffectDef.Target.ENEMY_NEAR_TARGET
		copy.count = change.targets_add
		copy.near_range = 0
		extra.append(copy)
	return extra


## The effects Wide copies onto more targets.
const COPIED_TYPES: Array[EffectDef.Type] = [EffectDef.Type.DAMAGE, EffectDef.Type.HEAL, EffectDef.Type.SHIELD, EffectDef.Type.APPLY_STATUS,
	EffectDef.Type.CLEANSE, EffectDef.Type.MANA_DRAIN, EffectDef.Type.KNOCKBACK, EffectDef.Type.PULL, EffectDef.Type.EXTEND_STATUS]


static func _changed_effects(effects: Array[EffectDef], change: AbilityChange) -> Array[EffectDef]:
	var result: Array[EffectDef] = []
	for effect: EffectDef in effects:
		var copy: EffectDef = DefCopy.shallow(effect) as EffectDef
		if change.touches(effect) and change.amount_bp != FixedMath.BP_ONE and change.as_power and POWER_TYPES.has(effect.type):
			copy.power_bp += change.amount_bp - FixedMath.BP_ONE
		elif change.touches(effect):
			copy.amount = FixedMath.apply_bp(copy.amount, change.amount_bp)
			if change.moves(effect):
				copy.hexes = FixedMath.apply_bp(copy.hexes, change.amount_bp)
			copy.amount_bp_of_damage = FixedMath.apply_bp(copy.amount_bp_of_damage, change.amount_bp)
			for stat: int in copy.scaling.size():
				copy.scaling[stat] = FixedMath.apply_bp(copy.scaling[stat], change.amount_bp)
		if change.touches(effect):
			if change.cooldown_bp != FixedMath.BP_ONE:
				if copy.interval_ticks > 0:
					copy.interval_ticks = maxi(FixedMath.apply_bp(copy.interval_ticks, change.cooldown_bp), 1)
					if copy.first_ticks > 0:
						copy.first_ticks = maxi(FixedMath.apply_bp(copy.first_ticks, change.cooldown_bp), 1)
				if copy.cooldown_ticks > 0:
					copy.cooldown_ticks = maxi(FixedMath.apply_bp(copy.cooldown_ticks, change.cooldown_bp), 1)
				if copy.cooldown_per_unit_ticks > 0:
					copy.cooldown_per_unit_ticks = maxi(FixedMath.apply_bp(copy.cooldown_per_unit_ticks, change.cooldown_bp), 1)
			if copy.duration_ticks > 0:
				copy.duration_ticks = maxi(FixedMath.apply_bp(copy.duration_ticks, change.duration_bp) + change.duration_add_ticks, 1)
			if copy.zone_ticks > 0:
				copy.zone_ticks = maxi(FixedMath.apply_bp(copy.zone_ticks, change.duration_bp) + change.duration_add_ticks, 1)
			if copy.lasts_ticks > 0:
				# A summon's lifetime too (phase 8 part 6, Long Nest).
				copy.lasts_ticks = maxi(FixedMath.apply_bp(copy.lasts_ticks, change.duration_bp) + change.duration_add_ticks, 1)
			if copy.shape != null and change.radius_add != 0:
				copy.shape = DefCopy.shallow(copy.shape) as ShapeDef
				copy.shape.size = maxi(copy.shape.size + change.radius_add, 1)
			# Phase 8 part 4's: near targets' reach, and a lowest_mana_ally's count.
			if change.within_add != 0 and effect.near_range > 0:
				copy.near_range = maxi(effect.near_range + change.within_add, HexGrid.HEX)
			if change.count_add != 0 and (effect.target == EffectDef.Target.LOWEST_MANA_ALLY or effect.target == EffectDef.Target.MOST_TARGETED_ALLY):
				copy.count = mini(effect.count + change.count_add, 5)
			# Phase 8 part 6 (Ilse's cards): on_status_tick's reach (Fan the
			# Coals), allies_near_self's nearest (Shared Blessing), a stacks_of
			# share (Deep Stoke), and a growing zone (Fast and Far Spread).
			if change.within_add != 0 and effect.trigger == EffectDef.Trigger.ON_STATUS_TICK and effect.near_trigger_range > 0:
				copy.near_trigger_range = maxi(effect.near_trigger_range + change.within_add, HexGrid.HEX)
			if change.within_add != 0 and effect.fell_range > 0:
				# on_enemy_fell's reach (phase 8 part 6, Wider Pickings).
				copy.fell_range = maxi(effect.fell_range + change.within_add, HexGrid.HEX)
			if change.count_add != 0 and effect.nearest > 0:
				copy.nearest = mini(effect.nearest + change.count_add, 5)
			if change.share_add_bp != 0 and effect.stacks_share_bp > 0:
				copy.stacks_share_bp = clampi(effect.stacks_share_bp + change.share_add_bp, 1, FixedMath.BP_ONE)
			if change.share_add_bp != 0 and effect.copy_of != EffectDef.CopyOf.NONE:
				copy.copy_share_bp = clampi(effect.copy_share_bp + change.share_add_bp, 100, FixedMath.BP_ONE)
			if change.copy_grow_add_bp != 0 and effect.copy_grows_bp > 0:
				copy.copy_grows_bp = maxi(effect.copy_grows_bp + change.copy_grow_add_bp, 0)
			if change.grow_every_add_ticks != 0 and effect.grow_ticks > 0:
				copy.grow_ticks = maxi(effect.grow_ticks + change.grow_every_add_ticks, 1)
			if change.grow_max_add != 0 and effect.grow_ticks > 0:
				copy.grow_max = maxi(effect.grow_max + change.grow_max_add, effect.shape.size + 1)
			if change.heal_cap_bp != 0 and effect.type == EffectDef.Type.HEAL:
				copy.heal_cap_bp = change.heal_cap_bp
				copy.heal_cap_vs = change.heal_cap_vs
			# Phase 8 part 6 (Heavy Flask): more for each stack.
			if change.per_stack_amount_add != 0 and effect.amount_per_stack > 0:
				copy.amount_per_stack = maxi(effect.amount_per_stack + change.per_stack_amount_add, 1)
			# Step 7b's knobs.
			if change.every_add != 0 and effect.every > 1:
				copy.every = maxi(effect.every + change.every_add, 1)
			if change.times_add != 0 and _runs_times(effect):
				copy.times = effect.times + change.times_add
			if change.max_standing_add != 0 and effect.max_standing > 0:
				copy.max_standing = effect.max_standing + change.max_standing_add
			# The apex cards' knobs (phase 8 part 2).
			if change.width_add != 0 and effect.type == EffectDef.Type.WALL:
				copy.width_range = effect.width_range + change.width_add * HexGrid.HEX
			if change.per_enemy_add_bp != 0 and effect.per_enemy_bp > 0:
				copy.per_enemy_bp = maxi(effect.per_enemy_bp + change.per_enemy_add_bp, 0)
			if change.overheal_max_hp_add != 0 and effect.overheal_max_hp_per > 0:
				copy.overheal_max_hp_per = maxi(effect.overheal_max_hp_per + change.overheal_max_hp_add, 1)
			if change.at_stacks_add != 0 and effect.at_stacks > 0:
				copy.at_stacks = maxi(effect.at_stacks + change.at_stacks_add, 2)
			if change.per_taken_add_bp != 0 and effect.power_per_taken_bp > 0:
				copy.power_per_taken_bp = maxi(effect.power_per_taken_bp + change.per_taken_add_bp, 0)
			if change.overheal_add_bp != 0 and effect.overheal_shield_bp > 0:
				copy.overheal_shield_bp = effect.overheal_shield_bp + change.overheal_add_bp
			if change.strength_add_bp != 0 and effect.type == EffectDef.Type.APPLY_STATUS:
				copy.strength_add_bp = effect.strength_add_bp + change.strength_add_bp
			if change.follows and effect.zone_ticks > 0:
				copy.follows = true
			if change.ricochet_add != 0 and effect.type == EffectDef.Type.DAMAGE:
				copy.ricochet = effect.ricochet + change.ricochet_add
			if change.reflect_bp != 0 and effect.type == EffectDef.Type.WALL:
				copy.reflect_bp = effect.reflect_bp + change.reflect_bp
			if change.snags and effect.type == EffectDef.Type.SNARE:
				copy.snags = true
			if change.holder != null and _takes_holder(effect):
				copy.holder = change.holder
			if change.carries and effect.type == EffectDef.Type.CHARGE and effect.knockback_hexes > 0:
				copy.carries = true
			if change.ignores_def and effect.type == EffectDef.Type.DAMAGE:
				copy.ignores_def = true
			if change.lifesteal_add_bp != 0 and effect.lifesteal_bp > 0:
				copy.lifesteal_bp = maxi(effect.lifesteal_bp + change.lifesteal_add_bp, 0)
			if change.plus_max_hp_add_bp != 0 and effect.plus_bp_of_max_hp > 0:
				copy.plus_bp_of_max_hp = maxi(effect.plus_bp_of_max_hp + change.plus_max_hp_add_bp, 0)
			if change.raise_grow_add_bp != 0 and effect.type == EffectDef.Type.RAISE:
				copy.raise_grow_hp_bp = maxi(effect.raise_grow_hp_bp + change.raise_grow_add_bp, 0)
			if change.follows_holder and effect.zone_ticks > 0:
				copy.follows = true
				copy.follows_nearest = false
				copy.follows_holder = true
			if change.per_stack_add_bp != 0 and not effect.grows_status.is_empty():
				copy.grows_stack_bp = maxi(effect.grows_stack_bp + change.per_stack_add_bp, 0)
			if change.prefer != null and (effect.target == EffectDef.Target.FARTHEST_ENEMIES or effect.target == EffectDef.Target.LOWEST_HP_ALLY):
				copy.prefer = change.prefer
			if change.width_add != 0 and copy.shape != null and copy.shape.kind == ShapeDef.Kind.LINE:
				copy.shape = DefCopy.shallow(copy.shape) as ShapeDef
				copy.shape.width += change.width_add
		if not effect.area_effects.is_empty():
			copy.area_effects = _changed_effects(effect.area_effects, change)
		if not change.add_to_areas.is_empty() and effect.type == EffectDef.Type.AREA and change.touches(effect):
			copy.area_effects = copy.area_effects.duplicate()
			copy.area_effects.append_array(change.add_to_areas)
		result.append(copy)
	return result


## An effect that can take a holder condition: an event's or a timed one.
static func _takes_holder(effect: EffectDef) -> bool:
	return EffectDef.EVENT_TRIGGERS.has(effect.trigger) or EffectDef.UNIT_TRIGGERS.has(effect.trigger)


## A "once" effect, or on_below_hp's: it runs `times` a fight (times_add).
static func _runs_times(effect: EffectDef) -> bool:
	return effect.once or effect.trigger == EffectDef.Trigger.ON_BELOW_HP


static func _any_effect(effects: Array[EffectDef], change: AbilityChange) -> bool:
	for effect: EffectDef in effects:
		if change.touches(effect) and (change.every_add != 0 and effect.every > 1 or change.times_add != 0 and _runs_times(effect)
				or change.within_add != 0 and effect.near_range > 0 or change.count_add != 0 and (effect.target == EffectDef.Target.LOWEST_MANA_ALLY or effect.target == EffectDef.Target.MOST_TARGETED_ALLY)
				or change.within_add != 0 and effect.trigger == EffectDef.Trigger.ON_STATUS_TICK and effect.near_trigger_range > 0
				or change.within_add != 0 and effect.fell_range > 0
				or change.count_add != 0 and effect.nearest > 0 or change.share_add_bp != 0 and (effect.stacks_share_bp > 0 or effect.copy_of != EffectDef.CopyOf.NONE)
				or change.copy_grow_add_bp != 0 and effect.copy_grows_bp > 0
				or (change.grow_every_add_ticks != 0 or change.grow_max_add != 0) and effect.grow_ticks > 0
				or change.heal_cap_bp != 0 and effect.type == EffectDef.Type.HEAL
				or change.per_stack_amount_add != 0 and effect.amount_per_stack > 0
				or change.max_standing_add != 0 and effect.max_standing > 0
				or change.overheal_add_bp != 0 and effect.overheal_shield_bp > 0
				or change.width_add != 0 and effect.type == EffectDef.Type.WALL
				or change.per_enemy_add_bp != 0 and effect.per_enemy_bp > 0
				or change.overheal_max_hp_add != 0 and effect.overheal_max_hp_per > 0
				or change.at_stacks_add != 0 and effect.at_stacks > 0
				or change.per_taken_add_bp != 0 and effect.power_per_taken_bp > 0
				or change.width_add != 0 and effect.shape != null and effect.shape.kind == ShapeDef.Kind.LINE
				or not change.add_to_areas.is_empty() and effect.type == EffectDef.Type.AREA
				or change.strength_add_bp != 0 and effect.type == EffectDef.Type.APPLY_STATUS
				or change.follows and effect.zone_ticks > 0 or change.ricochet_add != 0 and effect.type == EffectDef.Type.DAMAGE
				or change.reflect_bp != 0 and effect.type == EffectDef.Type.WALL or change.snags and effect.type == EffectDef.Type.SNARE
				or change.holder != null and _takes_holder(effect)
				or change.carries and effect.type == EffectDef.Type.CHARGE and effect.knockback_hexes > 0 and not effect.carries
				or change.ignores_def and effect.type == EffectDef.Type.DAMAGE and not effect.ignores_def
				or change.lifesteal_add_bp != 0 and effect.lifesteal_bp > 0
				or change.plus_max_hp_add_bp != 0 and effect.plus_bp_of_max_hp > 0
				or change.raise_grow_add_bp != 0 and effect.type == EffectDef.Type.RAISE
				or change.follows_holder and effect.zone_ticks > 0 and not effect.follows_holder
				or change.per_stack_add_bp != 0 and not effect.grows_status.is_empty()
				or change.prefer != null and (effect.target == EffectDef.Target.FARTHEST_ENEMIES or effect.target == EffectDef.Target.LOWEST_HP_ALLY)):
			return true
		if change.touches(effect) and (change.amount_bp != FixedMath.BP_ONE and (effect.amount != 0 or effect.amount_bp_of_damage != 0 or effect.scaling.any(func(value: int) -> bool: return value != 0) or effect.amount_bp_of_max_hp != 0 or change.moves(effect))
				or (change.duration_bp != FixedMath.BP_ONE or change.duration_add_ticks != 0) and (effect.duration_ticks > 0 or effect.zone_ticks > 0 or effect.lasts_ticks > 0)
				or change.radius_add != 0 and effect.shape != null):
			return true
		if _any_effect(effect.area_effects, change):
			return true
	return false


static func _slot_abilities(kit: UnitDef, slot: String, ability_id: String = "") -> Array[AbilityDef]:
	var found: Array[AbilityDef] = []
	if slot in [SLOT_BASIC, SLOT_ABILITIES] and kit.basic_attack != null and (ability_id.is_empty() or kit.basic_attack.id == ability_id):
		found.append(kit.basic_attack)
	if slot in [SLOT_SIGNATURE, SLOT_ABILITIES] and kit.signature != null and (ability_id.is_empty() or kit.signature.id == ability_id):
		found.append(kit.signature)
	for part: PartDef in kit.passives:
		if part.ability != null and (slot == SLOT_ABILITIES or slot == PASSIVE_PREFIX + part.id) and (ability_id.is_empty() or part.id == ability_id):
			found.append(part.ability)
	return found


## The named passive's aura, if it counts enemies near (phase 8 part 4).
static func _per_enemy_aura(kit: UnitDef, slot: String) -> AuraDef:
	var aura: AuraDef = _slot_aura(kit, slot)
	return aura if aura != null and aura.per_enemy_range > 0 else null


## The named passive's aura, if it reaches the allies near its holder.
static func _near_aura(kit: UnitDef, slot: String) -> AuraDef:
	var aura: AuraDef = _slot_aura(kit, slot)
	return aura if aura != null and aura.target == AuraDef.Target.ALLIES_NEAR else null


## `change` as it reaches a habit: its cost change becomes its every one
## lower (or higher), the rest as it is.
static func _as_habit(change: AbilityChange) -> AbilityChange:
	var habit: AbilityChange = DefCopy.shallow(change) as AbilityChange
	habit.every_add = change.every_add + signi(change.mana_max_add)
	return habit


static func _slot_aura(kit: UnitDef, slot: String) -> AuraDef:
	var at: int = _passive_index(kit, slot)
	return kit.passives[at].aura if at >= 0 else null


static func _passive_index(kit: UnitDef, slot: String) -> int:
	for i: int in kit.passives.size():
		if slot == PASSIVE_PREFIX + kit.passives[i].id:
			return i
	return -1
