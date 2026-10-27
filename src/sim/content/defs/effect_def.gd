class_name EffectDef
extends RefCounted
## One effect entry: WHEN it happens (trigger), WHAT it does (type), and WHO it
## affects (target). This is the shared vocabulary for abilities, relics, and
## duo bonds (CLAUDE.md rule 3). Adding a trigger, type, or target is a code
## change; say so when you make one. The arena sim
## (docs/plans/phases/rebuild-phase1-arena-sim.md) adds spatial targets and the
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
##                 (amount_bp_of_max_hp too, phase 5c step 5b); optional
##                 cap_bp_of_max_hp (phase 8 part 4, Plated Blows): it gives
##                 no more than takes its target's Shield to that share of
##                 its max HP (nothing once it's there); "up_to": true
##                 (phase 8 part 6, Recast the Idol): it fills its target's
##                 Shield to its amount, replacing a smaller Shield (nothing
##                 if it's already that big)
##   damage's amount_bp_of_shield (phase 8 part 4, Bulwark Burst): instead
##                 of amount, that share of the unit's own Shield as it
##                 fires (an area's: as it's cast); a Shield's too (Shared
##                 Ward: a share of what he's about to burst). Damage's
##                 "ignores_def": true (Bitter Blood): its hits ignore the
##                 target's DEF. Damage's "lifesteal_pct" (phase 8 part 5,
##                 Severine's Rend and Drain): its hits heal the unit that
##                 share more, on top of its lifesteal auras. Damage's
##                 "plus_bp_of_max_hp" (Rend's bonus, Gorge): that share of
##                 its unit's own max HP is added to the amount; and
##                 "plus_bp_of_spent" (Exsanguinate): that share of the HP
##                 its unit's signature just spent is added
##   spend_shield: (phase 8 part 4, Bulwark Burst; target "self") the
##                 unit's whole Shield is gone, logged as SHIELD_SPENT with
##                 what it was. After an area that read it, the area keeps
##                 what it read. "keep_bp" (Shatterburst): it keeps that share
##   spend_engorged: (phase 8 part 5, Sanguine Nova; target "self") the max
##                 HP Engorge added to the unit is gone (its HP comes down to
##                 its max HP), logged as MAX_HP_DOWN; damage's
##                 "amount_bp_of_engorged" reads it first, as
##                 amount_bp_of_shield reads the Shield
##   heal's "as_lifesteal": true (phase 8 part 5, The Iron Maw): it lands as
##                 its target's own lifesteal (a LIFESTEAL line, Engorge past
##                 full), never as healing
##   gain_max_hp:  (phase 8 part 5, The Iron Maw) amount or amount_bp_of_damage
##                 of max HP and HP for the fight, logged as MAX_HP_UP
##   shield's "plus_per_shard_bp" (phase 8 part 5, Golden Aegis): that share
##                 of the shards the run holds as the fight starts is added
##                 (FightSetup.shards; Practice's shards setting); damage's
##                 too (phase 8 part 6, Heavy Purse: 20000 is 2 a shard).
##                 Both read CombatSim.shards_held (its shard_worth_bp)
##   shards:       (phase 8 part 5, Collection; target "self") "amount" shards
##                 for the run, logged as SHARDS; RunFlow.record pays them.
##                 "spends": a stacking status on the unit: it pays only
##                 while the unit holds a stack, and spends one (Collection's
##                 window and its cap a cast)
##   raise:        (phase 8 part 5, Gravecaller; no "target" key; on_enemy_fell
##                 or on_kill) the enemy the event names stands again on the
##                 unit's side as its own kit, a summon: "hp_pct" of its max
##                 HP, for "duration_ms", up to "max_standing" raised at once,
##                 each earlier raise by the unit adding "grow_hp_pct" and
##                 "grow_ms". Never a summon, an elite or boss (UnitDef.rank),
##                 or a unit that fell into the void (Summons.raise)
##   release_stored: (phase 8 part 4, Vengeance; target "self") the damage
##                 the unit stored (the aura stat store_bp) is let go, logged
##                 as RELEASED with how much it had grown to; damage's
##                 "amount_bp_of_stored" reads it first, as amount_bp_of_shield
##                 reads the Shield
##   heal's "overheal_status": {"status": "burn", "per": 5} (phase 8 part 6,
##                 Kindred Flame): 1 stack on the enemy nearest the unit
##                 healed for every 5 it would heal past full; and a heal's
##                 "per_damage" (one heal for every that much of the events'
##                 damage, banked)
##   apply_status's "grows_per_stack" (phase 8 part 6): its stacks grow by
##                 that share for each stack of the status on its unit, or
##                 with stacks_of, its share does (Crucible)
##   a zone's "stays_near_hexes" and "radius_per_stack" (phase 8 part 6,
##                 Living Flame; see the fields)
##   heal's "cap": {"pct": 30, "vs": {...UnitCondition...}} (phase 8 part 6,
##                 Lantern Vigil): on a unit that meets "vs", it lifts HP no
##                 higher than that share of max HP; the rest is a Shield
##   damage's "amount_per_stack": {"status": "burn", "per": 5} (phase 8 part
##                 6, Ilse's Immolate): that much more for each stack of the
##                 status on the unit it hits, read as it fires; and an
##                 on_fire apply_status's "stacks_of" reads the ability's
##                 target (Immolate's splash, run before a cleanse);
##                 "status" may list several, their stacks added (Ottilie's
##                 Reaction Flask: Burn and Poison, read, never spent)
##   damage, heal, shield's "grows_per_stack": {"status": "brand", "bp": 500}
##                 (phase 8 part 4, the apexes' snowballs): that much more
##                 power for each stack of the status on the unit (and
##                 gain_mana's: that much more mana; Wellspring)
##   apply_status's "per_damage": 1000 (phase 8 part 4, Thorned King; an
##                 event that names a hit): a stack for every 1,000 of the
##                 hits' damage, banked between events
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
##                 target that stops enemy shots (Walls; phase 4). Phase 8
##                 part 2 (The Unbroken Gate, Warden of Thorns): optional
##                 "blocks_movement" (its enemies can't walk through it),
##                 "hp_bp_of_max_hp" (it has that share of its unit's max HP,
##                 and the shots it stops and the enemies it walls in wear
##                 it down), "until_broken" (no "duration_ms": it stands
##                 until its HP runs out; needs HP), "max_standing" (setting
##                 one more than that takes down the oldest), "at": "target"
##                 (ahead of the target, across its way, rather than ahead
##                 of the unit; a snare's wall: where the snare springs), and
##                 "effects" (each second, on every enemy touching it)
##   gain_mana:    amount (whole mana added to the target's bar, if it has
##                 one; phase 4). Not logged, like every mana gain: the fire
##                 that gave it is
##   knockback:    hexes; pushes the target straight away from the unit.
##                 Phase 8 part 3 (the Cliffmite): "distance_bp" (a share of
##                 the hexes: 5000 is half) and "toward": "edge" (straight
##                 toward the nearest void hex's center or the board's edge,
##                 from the target)
##   pull:         hexes; drags the target straight toward the unit, stopping
##                 when it touches. Phase 8 part 3: "toward": "water" (the
##                 water hex nearest the target, stopping on its center) or
##                 "area" (an area's own pull: its middle); "to": "beside"
##                 (a hook, the Gulf Angler: no "hexes"; the target is
##                 carried all the way to the free spot nearest the unit,
##                 over the void too, and never left over it); phase 8
##                 part 4: "toward": "ally" (toward the unit's nearest
##                 standing ally, else the unit; Tamsin's Drag)
##   sever:        phase 8 part 3 (Islands; the Heart of the Rift; no
##                 "target" key): the fight's next bridge (FightSetup.
##                 bridges, in turn) is warned for "warning_ms", then turns
##                 to void, and comes back after "duration_ms". Logged as
##                 VOID
##   flood:        phase 8 part 3 (Water; no "target" key): "mode" circle
##                 (the hexes within "radius" of the ability's target, or
##                 of the unit with "anchor": "self"; for "duration_ms", or
##                 for good without it), spread (every pool one hex
##                 wider), drain (all the water gone but the hexes within
##                 "radius" of the unit), or all (every hex but the rocks).
##                 Logged as WATER
##   leap:         max_hexes, optional land_ms (tuning's leap_land_ms); the
##                 unit jumps to a free spot touching its target. Phase 8
##                 part 3: "to": "start" (on "self", no max_hexes) leaps it
##                 back to the free spot nearest where it started the fight.
##                 Phase 8 part 4 (Tamsin): "to": "behind" lands on the free
##                 spot past its target, as straight behind it (away from
##                 the unit) as there's room; "to": "step" is a passive's
##                 leap (an event effect, at "enemy_near_named" or
##                 "enemy_near_target", optionally with "only"): the unit
##                 lands beside that enemy and makes it its target;
##                 "resets_attack": true readies its attack after a step.
##                 A passive may leap behind (at "target": its unit's target)
##   charge:       hexes, optional knockback (hexes); the unit runs straight
##                 at its target and knocks back the first enemy it touches.
##                 Phase 8 part 3 (the Avalanche Guardian): "carries": true
##                 knocks every enemy in its line the knockback's distance
##                 along it, farthest first, before it runs
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
##   phase 8 part 3: "placement": "water" (Summons), and "max_standing": no
##   more once that many of its kit stand on its side (dropped, "enough stand")
##   phase 8 part 6: "kit" may name one of its caster's companions (Nest),
##   and "lasts_ms": each goes quietly that long after it joins
##   phase 8 part 6 (Lucan): "copy_of" in place of "kit": a copy of the caster
##   ("self") or of each standing hero on its side ("each_ally"), beside it,
##   at "share_pct" of its HP, ATK, and MGK, with its basic attack only; it
##   needs "lasts_ms", takes no "placement" or "count", and "max_standing"
##   counts every copy standing of the unit copied, whatever made it
##   (Summons.copy_kit)
##     {"type": "summon", "copy_of": "self", "share_pct": 30, "lasts_ms": 6000}
##   with "grows_per_copy_pct": 2 and "share_max_pct": 80 (Thousand Faces:
##   each copy its caster has made this fight adds to the next's share), and
##   "casts": true (True Reflection: each copy keeps a mana signature, starts
##   with a full bar, gains none, so it casts it once)
##     edges:    count (default 1) free spots along the safe ground's edge,
##               nearest first to the unit ("near": "self", the default) or
##               to its target ("near": "target")
##     adjacent: count free spots touching the unit
##     hexes:    one on each [col, row] hex, or the free spot nearest it
## `amount` (or `stacks`) is the base value. An optional "scaling" object adds
## a share of the unit's stats, in basis points of each stat:
##   "scaling": {"atk": 6000, "atsp": 2000}  ->  base + 60% ATK + 20% ATSP
## (Not allowed with amount_bp_of_damage, which scales from the hit instead.)
## With "scaling_of": "owner" (phase 8 part 6, Kestra's companions), the
## stats are its owner's as it lands (Grit's Burn from 20% of her ATK); a unit
## with no owner uses its own.
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
##                         within within_hexes of the unit if given; "count"
##                         (phase 8 part 5): that many, lowest first
##   toughest_enemies      the "count" (1) standing enemies with the most
##                         max HP, fight order on ties ("only": among those
##                         that meet it; phase 8 part 6, Hob's Bounty)
##   most_targeted_ally    the "count" (1) allies (the unit too) the most
##                         enemies are targeting, ties to the lowest share
##                         of HP, then the fight's order (phase 8 part 6,
##                         Shroud)
##   lowest_mana_ally      the "count" (1) other allies with a mana bar
##                         least full, fight order on ties (phase 8 part 4,
##                         Shared Breath)
##   enemies_near_allies   every enemy within reach of each of the unit's
##                         allies (it too) that meet "around"; a knockback
##                         pushes away from that ally (phase 8 part 4, Gale)
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
##   trigger_ally       target: the ally that set off on_ally_below_hp (and,
##                      phase 8 part 6, on_enemy_fell's: the ally that felled
##                      the enemy, Reward Poster)
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
##   on_status        the unit applies a status ("statuses": only those,
##                    but a cleanse's or extend's "statuses" are its own;
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
##                    of the Shield that hit took; phase 8 part 5, Edric:
##                    trigger_ally is the unit whose Shield broke, and its
##                    "vs" and cooldown_per_unit_ms then name that unit)
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
##   on_breaks_shield one of the unit's hits takes the last of an enemy's
##                    Shield (hit_target: that enemy; amount_bp_of_damage:
##                    of the Shield that hit took; phase 8 part 3, the
##                    Hungering Unbinder)
##   on_pull          the unit pulls or hooks an enemy (its PUSH lines noted
##                    "pulled" or "hooked" that moved it; hit_target: that
##                    enemy; "from_ability": only those abilities' pulls;
##                    phase 8 part 4, Garrow's Hard Landing and Heavy Chain)
##   on_shield_spent  the unit spends its Shield (SHIELD_SPENT;
##                    amount_bp_of_damage: of the Shield it spent; phase 8
##                    part 4, The Woven Fang)
##   on_max_hp_up     the unit gains max HP (MAX_HP_UP on it; amount_bp_of_damage:
##                    of what it gained; "from_ability": only what those gave;
##                    phase 8 part 5, The Iron Maw)
##   on_hp_spent      the unit spends HP on its signature (HP_SPENT;
##                    amount_bp_of_damage and per_damage: of the HP spent;
##                    phase 8 part 5, Blood Rite)
##   on_mana_gained   the unit gains mana from an attack, a hit taken, or an
##                    effect (not its regen; Mana.gain raises it at once, not
##                    from the log; amount_bp_of_damage on gain_mana: a share
##                    of what it gained; phase 8 part 4, Chorister)
##   on_ally_hit      another unit of its side lands a basic attack's hit on
##                    an enemy (hit_target: that enemy; "by": {...}: only an
##                    ally that meets it, as {"ranged": true}; phase 8 part
##                    4, Singing Arrows; "spends": a stacking status on that
##                    ally, spent a stack a hit, and nothing without one:
##                    phase 8 part 6, Ilse's Blessing). on_enemy_fell takes "by" too (its
##                    killer) and "by_beyond_hexes" (the killer stood that
##                    far from it or more; Long Wind).
##   on_status_tick   a damage-over-time status ticks on an enemy of the
##                    unit, whoever put it there, a relic too (a STATUS_DAMAGE
##                    line; "statuses": only those; "near_hexes": only on an
##                    enemy that near the unit; hit_target: that enemy;
##                    amount_bp_of_damage: of the tick; phase 8 part 6,
##                    Ilse's Heat: 1 mana a tick)
##   on_zone_enter    an enemy of the unit steps into one of its zones
##                    (hit_target: that enemy; "from_ability": only zones
##                    from those abilities; not from the log: Areas raises it
##                    each tick as a unit comes inside; one already inside as
##                    a zone is cast hasn't stepped in; phase 8 part 6, Ring
##                    of Fire)
##   on_enemy_near    the tuning phase (Snare Wire; not an event: checked
##                    each tick with the timed ones): an enemy first comes
##                    within "near_hexes" of the unit (hit_target: that enemy;
##                    once per enemy for each unit)
## An event effect's "cooldown_per_unit_ms" (step 5d) runs it at most once
## that long for each unit its event names. "once_per_enemy": true (the
## tuning phase; Heavy Pommel, Snare Wire) runs it once for each enemy the
## event names, across every unit holding a passive of the same id. A
## damage effect's "plain": true never crits and never lifesteals (Thorned
## Bandage, Splinter Shot).
## Phase 5c step 5b adds: extend_status ("status", "duration_ms": a timed
## status already on the target lasts that much longer; phase 8 part 4,
## Choke: "statuses": [...] extends each of them it has); the targets
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
## Phase 8 part 4 (habits, Haul's) adds the target farthest_enemies: the
## "count" standing enemies farthest from the unit within "within_hexes" of
## it (farthest first; ties in the fight's order).
## Phase 5c step 6 also adds the target allies_near_self (every ally within
## "within_hexes" of the unit, as it falls too: Last Breath; phase 8 part 6,
## "nearest": only the nearest that many, fight order on ties)
## and cleanse's "statuses" (only those).
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
	ON_BELOW_HP, ON_CHARGED, ON_ENEMY_FELL, ON_ARRIVE, ON_ALLY_SHIELD_BROKEN, ON_WALL_BLOCK, ON_RISE, ON_BREAKS_SHIELD, ON_PULL, ON_SHIELD_SPENT,
	ON_MANA_GAINED, ON_ALLY_HIT, ON_ENEMY_NEAR, ON_HP_SPENT, ON_MAX_HP_UP, ON_STATUS_TICK, ON_ZONE_ENTER, ON_SUMMON_FELL,
	ON_CONTROLLED_FELL, ON_ENEMY_LOST_TARGET,
}
enum Type { DAMAGE, HEAL, SHIELD, APPLY_STATUS, CLEANSE, MANA_DRAIN, KNOCKBACK, PULL, LEAP, CHARGE, AREA, START_COLLAPSE, SUMMON, GAIN_MANA, SNARE, WALL, EXTEND_STATUS, HOP, FLOOD, SEVER, SPEND_SHIELD, RELEASE_STORED,
	SPEND_ENGORGED, RAISE, GAIN_MAX_HP, SHARDS }
## A pull's way (phase 8 part 3): toward the unit, the nearest water, or
## its area's middle; a knockback's: away from the unit, or toward the
## nearest edge.
enum Toward { UNIT, WATER, AREA, EDGE, ALLY }
## A flood's mode (phase 8 part 3; Water).
enum FloodMode { CIRCLE, SPREAD, DRAIN, ALL }
enum Placement { EDGES, ADJACENT, HEXES, WATER }
enum CopyOf { NONE, SELF, EACH_ALLY }
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
	FARTHEST_ENEMIES,
	LOWEST_MANA_ALLY,
	ENEMIES_NEAR_ALLIES,
	MOST_TARGETED_ALLY,
	TOUGHEST_ENEMIES,
}
## A nested area effect's side (phase 4): both, or only one.
enum AreaSide { BOTH, ENEMIES, ALLIES }

const TRIGGER_NAMES: Array[String] = [
	"on_fire", "on_hit", "on_crit", "on_fight_start", "at_time", "on_ally_below_hp",
	"on_ability", "on_basic_attack", "on_holder_crit", "on_shielded", "on_hit_taken", "on_heal", "on_status", "on_kill",
	"on_interval", "on_fall", "on_hop", "on_would_fall",
	"on_holder_hit", "on_shield_broken", "on_ally_ability", "on_status_ended", "on_lifesteal", "on_knockback", "on_guard",
	"on_below_hp", "on_charged", "on_enemy_fell", "on_arrive", "on_ally_shield_broken", "on_wall_block", "on_rise", "on_breaks_shield", "on_pull", "on_shield_spent",
	"on_mana_gained", "on_ally_hit", "on_enemy_near", "on_hp_spent", "on_max_hp_up", "on_status_tick", "on_zone_enter", "on_summon_fell",
	"on_controlled_fell", "on_enemy_lost_target",
]
## The unit's events (see the top).
const EVENT_TRIGGERS: Array[Trigger] = [
	Trigger.ON_ABILITY, Trigger.ON_BASIC_ATTACK, Trigger.ON_HOLDER_CRIT, Trigger.ON_SHIELDED,
	Trigger.ON_HIT_TAKEN, Trigger.ON_HEAL, Trigger.ON_STATUS, Trigger.ON_KILL, Trigger.ON_HOP,
	Trigger.ON_HOLDER_HIT, Trigger.ON_SHIELD_BROKEN, Trigger.ON_ALLY_ABILITY, Trigger.ON_STATUS_ENDED, Trigger.ON_LIFESTEAL, Trigger.ON_KNOCKBACK, Trigger.ON_GUARD,
	Trigger.ON_CHARGED, Trigger.ON_ENEMY_FELL, Trigger.ON_ARRIVE, Trigger.ON_ALLY_SHIELD_BROKEN, Trigger.ON_WALL_BLOCK, Trigger.ON_RISE, Trigger.ON_BREAKS_SHIELD, Trigger.ON_PULL, Trigger.ON_SHIELD_SPENT,
	Trigger.ON_MANA_GAINED, Trigger.ON_ALLY_HIT, Trigger.ON_HP_SPENT, Trigger.ON_MAX_HP_UP, Trigger.ON_STATUS_TICK, Trigger.ON_ZONE_ENTER, Trigger.ON_SUMMON_FELL, Trigger.ON_CONTROLLED_FELL, Trigger.ON_ENEMY_LOST_TARGET,
]
## Event triggers that name a unit (hit_target) and those that name a hit
## (amount_bp_of_damage).
const EVENT_UNIT_TRIGGERS: Array[Trigger] = [Trigger.ON_HOLDER_CRIT, Trigger.ON_SHIELDED, Trigger.ON_HIT_TAKEN, Trigger.ON_HEAL, Trigger.ON_STATUS,
	Trigger.ON_HOLDER_HIT, Trigger.ON_SHIELD_BROKEN, Trigger.ON_ALLY_ABILITY, Trigger.ON_KNOCKBACK, Trigger.ON_GUARD, Trigger.ON_CHARGED,
	Trigger.ON_ALLY_SHIELD_BROKEN, Trigger.ON_WALL_BLOCK, Trigger.ON_BREAKS_SHIELD, Trigger.ON_PULL, Trigger.ON_ALLY_HIT, Trigger.ON_STATUS_TICK, Trigger.ON_ZONE_ENTER, Trigger.ON_SUMMON_FELL, Trigger.ON_CONTROLLED_FELL, Trigger.ON_ENEMY_LOST_TARGET]
const EVENT_HIT_TRIGGERS: Array[Trigger] = [Trigger.ON_HOLDER_CRIT, Trigger.ON_HIT_TAKEN, Trigger.ON_HOLDER_HIT, Trigger.ON_SHIELD_BROKEN, Trigger.ON_HEAL,
	Trigger.ON_ALLY_SHIELD_BROKEN, Trigger.ON_GUARD, Trigger.ON_BREAKS_SHIELD, Trigger.ON_SHIELD_SPENT, Trigger.ON_MANA_GAINED, Trigger.ON_ALLY_HIT, Trigger.ON_HP_SPENT, Trigger.ON_MAX_HP_UP, Trigger.ON_STATUS_TICK]
## Event triggers that can take "vs": those that name a unit, and on_kill.
const EVENT_VS_TRIGGERS: Array[Trigger] = [Trigger.ON_HOLDER_CRIT, Trigger.ON_SHIELDED, Trigger.ON_HIT_TAKEN, Trigger.ON_HEAL, Trigger.ON_STATUS,
	Trigger.ON_HOLDER_HIT, Trigger.ON_SHIELD_BROKEN, Trigger.ON_ALLY_ABILITY, Trigger.ON_KILL, Trigger.ON_KNOCKBACK, Trigger.ON_GUARD,
	Trigger.ON_CHARGED, Trigger.ON_ENEMY_FELL, Trigger.ON_ALLY_SHIELD_BROKEN, Trigger.ON_WALL_BLOCK, Trigger.ON_BREAKS_SHIELD, Trigger.ON_PULL, Trigger.ON_ALLY_HIT, Trigger.ON_STATUS_TICK, Trigger.ON_ZONE_ENTER, Trigger.ON_SUMMON_FELL, Trigger.ON_CONTROLLED_FELL, Trigger.ON_ENEMY_LOST_TARGET]
const ABILITY_TRIGGERS: Array[Trigger] = [
	Trigger.ON_FIRE, Trigger.ON_HIT, Trigger.ON_CRIT,
	Trigger.ON_ABILITY, Trigger.ON_BASIC_ATTACK, Trigger.ON_HOLDER_CRIT, Trigger.ON_SHIELDED,
	Trigger.ON_HIT_TAKEN, Trigger.ON_HEAL, Trigger.ON_STATUS, Trigger.ON_KILL, Trigger.ON_HOP,
	Trigger.ON_ALLY_BELOW_HP, Trigger.ON_INTERVAL, Trigger.ON_FALL, Trigger.ON_WOULD_FALL,
	Trigger.ON_HOLDER_HIT, Trigger.ON_SHIELD_BROKEN, Trigger.ON_ALLY_ABILITY, Trigger.ON_STATUS_ENDED, Trigger.ON_LIFESTEAL, Trigger.ON_KNOCKBACK, Trigger.ON_GUARD,
	Trigger.ON_BELOW_HP, Trigger.ON_CHARGED, Trigger.ON_ENEMY_FELL, Trigger.ON_ARRIVE, Trigger.ON_FIGHT_START, Trigger.ON_ALLY_SHIELD_BROKEN, Trigger.ON_WALL_BLOCK, Trigger.ON_RISE, Trigger.ON_BREAKS_SHIELD, Trigger.ON_PULL, Trigger.ON_SHIELD_SPENT,
	Trigger.ON_MANA_GAINED, Trigger.ON_ALLY_HIT,
	Trigger.ON_ENEMY_NEAR, Trigger.ON_HP_SPENT, Trigger.ON_MAX_HP_UP, Trigger.ON_STATUS_TICK, Trigger.ON_ZONE_ENTER, Trigger.ON_SUMMON_FELL, Trigger.ON_CONTROLLED_FELL, Trigger.ON_ENEMY_LOST_TARGET,
]
## What a passive's effects may run on (PartDef).
const PASSIVE_TRIGGERS: Array[Trigger] = [
	Trigger.ON_ABILITY, Trigger.ON_BASIC_ATTACK, Trigger.ON_HOLDER_CRIT, Trigger.ON_SHIELDED,
	Trigger.ON_HIT_TAKEN, Trigger.ON_HEAL, Trigger.ON_STATUS, Trigger.ON_KILL, Trigger.ON_HOP,
	Trigger.ON_ALLY_BELOW_HP, Trigger.ON_INTERVAL, Trigger.ON_FALL, Trigger.ON_WOULD_FALL,
	Trigger.ON_HOLDER_HIT, Trigger.ON_SHIELD_BROKEN, Trigger.ON_ALLY_ABILITY, Trigger.ON_STATUS_ENDED, Trigger.ON_LIFESTEAL, Trigger.ON_KNOCKBACK, Trigger.ON_GUARD,
	Trigger.ON_BELOW_HP, Trigger.ON_CHARGED, Trigger.ON_ENEMY_FELL, Trigger.ON_ARRIVE, Trigger.ON_FIGHT_START, Trigger.ON_ALLY_SHIELD_BROKEN, Trigger.ON_WALL_BLOCK, Trigger.ON_RISE, Trigger.ON_BREAKS_SHIELD, Trigger.ON_PULL, Trigger.ON_SHIELD_SPENT,
	Trigger.ON_MANA_GAINED, Trigger.ON_ALLY_HIT,
	Trigger.ON_ENEMY_NEAR, Trigger.ON_HP_SPENT, Trigger.ON_MAX_HP_UP, Trigger.ON_STATUS_TICK, Trigger.ON_ZONE_ENTER, Trigger.ON_SUMMON_FELL, Trigger.ON_CONTROLLED_FELL, Trigger.ON_ENEMY_LOST_TARGET,
]
## The passive triggers that aren't events (Passives.run_timed, on_fall,
## would_fall).
const UNIT_TRIGGERS: Array[Trigger] = [Trigger.ON_ALLY_BELOW_HP, Trigger.ON_INTERVAL, Trigger.ON_FALL, Trigger.ON_WOULD_FALL, Trigger.ON_BELOW_HP, Trigger.ON_FIGHT_START]
const RELIC_TRIGGERS: Array[Trigger] = [Trigger.ON_FIRE, Trigger.ON_FIGHT_START, Trigger.AT_TIME, Trigger.ON_ALLY_BELOW_HP]
## Targets that need the effect's unit to stand on the field.
const FIELD_ONLY_TARGETS: Array[Target] = [Target.TARGET, Target.HIT_TARGET, Target.SELF, Target.FARTHEST_ENEMIES,
	Target.ENEMY_NEAR_TARGET, Target.ENEMIES_NEAR_TARGET, Target.ALLY_NEAR_TARGET, Target.ALLIES_NEAR_TARGET, Target.LOWEST_HP_ALLY]
## Targets near the ability's target (phase 4), and those that need a reach.
const NEAR_TARGETS: Array[Target] = [Target.ENEMY_NEAR_TARGET, Target.ENEMIES_NEAR_TARGET, Target.ALLY_NEAR_TARGET, Target.ALLIES_NEAR_TARGET,
	Target.ENEMIES_NEAR_SELF, Target.ENEMIES_NEAR_NAMED, Target.ENEMY_NEAR_NAMED, Target.ALLIES_NEAR_SELF, Target.FARTHEST_ENEMIES, Target.ENEMIES_NEAR_ALLIES]
const REACH_TARGETS: Array[Target] = [Target.ENEMIES_NEAR_TARGET, Target.ALLIES_NEAR_TARGET, Target.ENEMIES_NEAR_SELF, Target.ENEMIES_NEAR_NAMED,
	Target.ALLIES_NEAR_SELF, Target.FARTHEST_ENEMIES, Target.ENEMIES_NEAR_ALLIES]
## The targets around the unit an event names (they need one).
const NAMED_TARGETS: Array[Target] = [Target.ENEMIES_NEAR_NAMED, Target.ENEMY_NEAR_NAMED]
const SIDE_NAMES: Array[String] = ["both", "enemies", "allies"]
const TYPE_NAMES: Array[String] = ["damage", "heal", "shield", "apply_status", "cleanse", "mana_drain", "knockback", "pull", "leap", "charge", "area", "start_collapse", "summon", "gain_mana", "snare", "wall", "extend_status", "hop", "flood", "sever", "spend_shield", "release_stored", "spend_engorged", "raise", "gain_max_hp", "shards"]
const TOWARD_NAMES: Array[String] = ["unit", "water", "area", "edge", "ally"]
const FLOOD_MODE_NAMES: Array[String] = ["circle", "spread", "drain", "all"]
## The types placed at the ability's target without a "target" key of their
## own (an area, a snare, a wall).
const PLACED: Array[Type] = [Type.AREA, Type.SNARE, Type.WALL, Type.FLOOD]
const PLACEMENT_NAMES: Array[String] = ["edges", "adjacent", "hexes", "water"]
const COPY_OF_NAMES: Array[String] = ["", "self", "each_ally"]
const NEAR_NAMES: Array[String] = ["self", "target"]
## The types with no "target" key: they act from the unit itself.
const UNTARGETED: Array[Type] = [Type.START_COLLAPSE, Type.SUMMON, Type.SEVER, Type.RAISE]
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
	"farthest_enemies",
	"lowest_mana_ally",
	"enemies_near_allies",
	"most_targeted_ally",
	"toughest_enemies",
]

var trigger: Trigger
var type: Type
var target: Target
## damage/heal/shield: the amount.
var amount: int = 0
var amount_bp_of_damage: int = 0
## heal: a share of the healed unit's max HP (0: `amount` instead).
var amount_bp_of_max_hp: int = 0
## damage (phase 8 part 4): a share of the unit's own Shield (0: `amount`).
var amount_bp_of_shield: int = 0
## damage (phase 8 part 4, Bitter Blood): its hits ignore the target's DEF.
var ignores_def: bool = false
## damage (phase 8 part 5, Severine): its own lifesteal share (bp), added to
## the unit's for its hits.
var lifesteal_bp: int = 0
## damage (phase 8 part 5): added to the amount, a share of its unit's own
## max HP, and of the HP its signature's fire just spent (UnitState.
## last_hp_spent).
var plus_bp_of_max_hp: int = 0
var plus_bp_of_spent: int = 0
## damage (phase 8 part 4, Vengeance): a share of the unit's stored damage.
var amount_bp_of_stored: int = 0
## spend_shield (Shatterburst): the share of the Shield it keeps.
var keep_bp: int = 0
## shield (phase 8 part 5, Golden Aegis): that share (bp) of the shards the
## run holds is added (FightSetup.shards; 0: none).
var plus_per_shard_bp: int = 0
## shards (phase 8 part 5, Collection): a stack of this status on the unit
## is spent for each, and none pays without one ("": always pays).
var spends: String = ""
## heal (phase 8 part 5, The Iron Maw): it lands as its target's own
## lifesteal (EffectRunner.steal), not as healing.
var as_lifesteal: bool = false
## damage (phase 8 part 5, Sanguine Nova): a share of the max HP Engorge has
## added to its unit (UnitState.engorged; 0: `amount`).
var amount_bp_of_engorged: int = 0
## raise (phase 8 part 5, Gravecaller): the risen's share of its max HP, how
## long it stands, and how much more of each the unit's every earlier raise
## adds (UnitState.raises). max_standing caps those standing.
var raise_hp_bp: int = 0
var raise_ticks: int = 0
var raise_grow_hp_bp: int = 0
var raise_grow_ticks: int = 0
## damage, heal, shield (the apexes' snowballs): this much more power for
## each stack of this status on its unit ("": none).
var grows_status: String = ""
var grows_stack_bp: int = 0
## damage (phase 8 part 6, Ilse's Immolate): this much more for each stack
## of this status on the unit it hits, read as it fires ("": none).
var per_stack_status: String = ""
## amount_per_stack: these statuses' stacks too (phase 8 part 6, Reaction
## Flask).
var per_stack_more: Array[String] = []
var amount_per_stack: int = 0
## heal (phase 8 part 6, Lantern Vigil): on a unit that meets heal_cap_vs (any,
## if null), it lifts HP no higher than this share of max HP, and the rest
## of it is a Shield instead ("cap": {"pct": 30, "vs": {...}}; 0: none).
var heal_cap_bp: int = 0
var heal_cap_vs: UnitCondition = null
## apply_status on an event naming a hit: a stack per this much damage (0:
## once a run of the event).
var per_damage: int = 0
## farthest_enemies (phase 8 part 4, Back-Line Hook): the enemies that meet
## this are picked first, farthest first, then the rest. Not read from the
## data: a kit mod's "prefer" sets it on a habit.
var prefer: UnitCondition = null
## shield (phase 8 part 4): it fills its target's Shield to at most this
## share of its max HP (0: no cap).
var cap_bp_of_max_hp: int = 0
## shield (phase 8 part 6): it fills its target's Shield up to its amount.
var shield_up_to: bool = false
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
## on_interval: when it first runs (phase 8 part 6, Ottilie's Brewing: two
## vials taking turns; 0: after one interval), then every interval_ticks.
var first_ticks: int = 0
var status_id: String = ""
## apply_status (phase 8 part 6, Solvent): the one of these the unit has
## fewest of, and a share of the most it has of them as its stacks (0: its
## own stacks).
var smaller_of: Array[String] = []
var larger_share_bp: int = 0
## extend_status (phase 8 part 4, Choke): each of these it has (empty: just
## status_id).
var extend_statuses: Array[String] = []
var stacks: int = 0
## apply_status: how long a timed status lasts (0: the status's own duration).
var duration_ticks: int = 0
## knockback, pull, charge: how far; leap: how far it can jump (hexes).
var hexes: int = 0
## charge: how far it knocks back the enemy it hits (hexes; 0: not at all).
var knockback_hexes: int = 0
## charge (phase 8 part 3): it carries every enemy in its line.
var carries: bool = false
## pull (phase 8 part 3): which way.
var toward: Toward = Toward.UNIT
## knockback (phase 8 part 3): the share of `hexes` it goes (basis points).
var distance_bp: int = FixedMath.BP_ONE
## pull (phase 8 part 3): a hook, carried to the free spot beside the unit.
var hook: bool = false
## Any effect (phase 8 part 3, the Cliffmite): it lands only while at least
## this many standing units of the unit's side (itself among them) have its
## target as theirs (0: always).
var when_attackers: int = 0
## when_attackers counts only units of these kits (empty: any of its side;
## phase 8 part 3, 8c-6c: the Cliffmite's crowd is Cliffmites).
var when_attackers_kits: Array[String] = []
## An event effect (phase 8 part 3, the Gloam Hound): it runs this long
## after its event (ticks; 0: at once), if its unit still stands.
var delay_ticks: int = 0
## leap (phase 8 part 3, the Gloam Hound): back to where the unit started
## the fight (its target is "self"), the free spot nearest it.
var leap_home: bool = false
## leap (phase 8 part 4, Shadowstep): to the free spot past its target.
var leap_behind: bool = false
## leap (phase 8 part 4, Scent): a passive's step beside the enemy its
## target names, which becomes the unit's target; resets_attack readies its
## attack after.
var leap_step: bool = false
var resets_attack: bool = false
## flood (phase 8 part 3): its mode and radius (hexes); how long a circle
## lasts is zone_ticks (0: for good); anchor (target or self).
var flood_mode: FloodMode = FloodMode.CIRCLE
var flood_radius: int = 0
## all_enemies and all_allies (phase 8 part 3, Undertow): only the units
## that meet it (null: all).
var only: UnitCondition = null
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
## A summon's lifetime (phase 8 part 6; 0: the whole fight).
var lasts_ticks: int = 0
## A copy (phase 8 part 6, Lucan): of whom, and its share of their HP, ATK,
## and MGK (basis points).
var copy_of: CopyOf = CopyOf.NONE
var copy_share_bp: int = 0
## A copy's share grows by this much for each copy its caster has made this
## fight, up to copy_share_max_bp (phase 8 part 6, Thousand Faces).
var copy_grows_bp: int = 0
var copy_share_max_bp: int = FixedMath.BP_ONE
## Each copy keeps the copied unit's mana signature and casts it once
## (phase 8 part 6, True Reflection).
var copy_casts: bool = false
var count: int = 1
var placement: Placement = Placement.EDGES
var summon_hexes: Array[Vector2i] = []
var near_target: bool = false
## Basis points of each stat added to the base value, indexed by UnitStats.Stat
## (the first SCALING_STATS only).
var scaling: Array[int] = [0, 0, 0, 0, 0, 0]
## Its scaling reads its unit's owner's stats (phase 8 part 6).
var scaling_of_owner: bool = false
## Fight ticks the effect is active in: [from, until). until = -1: no end.
var window_from_ticks: int = 0
var window_until_ticks: int = -1
## at_time: the tick it fires on.
var at_ticks: int = 0
## on_ally_below_hp: the HP share (basis points of max HP) to drop below.
var threshold_bp: int = 0
## on_ally_below_hp: only the first ally in the fight sets it off.
var once: bool = false
## on_ally_below_hp with "enemies": true (phase 8 part 6, Puppet Thread):
## it watches the enemies instead, the one that drops named (trigger_ally).
var below_hp_enemies: bool = false
## A plain hit (damage; the tuning phase, T-1): no crit, no lifesteal.
var plain: bool = false
## Runs only once for each enemy its event names, across every unit with a
## passive of the same id (the tuning phase: Heavy Pommel, Snare Wire;
## CombatSim.once_marks).
var once_per_enemy: bool = false
## on_enemy_near: how close an enemy comes (plane units).
var near_trigger_range: int = 0
## Event triggers: runs on every Nth event.
var every: int = 1
## on_status: only these statuses (empty = any), and only statuses carrying
## one of these keywords (empty = any).
var statuses: Array[String] = []
var keywords: Array[String] = []
## on_status (phase 8 part 2, Forgebreaker): only once the unit it went on
## has this many stacks of it; they're spent (the status ends) first.
var at_stacks: int = 0
## Event triggers: only when the unit the event names meets it (null: any).
var vs: UnitCondition = null
## Near-target targets and lowest_hp_ally: how far (plane units; 0: any).
var near_range: int = 0
## enemies_near_allies (phase 8 part 4, Gale): the allies (the unit too) it
## reaches round; null: every one.
var around: UnitCondition = null
## heal: the share of what it heals past full HP that comes back as Shield.
var overheal_shield_bp: int = 0
## heal (phase 8 part 2, The Hearthkeeper): every so much it heals past full
## HP gives its unit +1 max HP for the fight ("overheal_max_hp_per"; 0: none).
var overheal_max_hp_per: int = 0
## damage, heal, shield (phase 8 part 2, Martyr's Pyre): this much more
## power for every `taken_per` damage its unit has taken this fight
## ("grows_per_damage_taken": {"per": 1000, "bp": 1000}; 0: none).
var power_per_taken_bp: int = 0
var taken_per: int = 0
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
## on_ally_hit: the ally that hit; on_enemy_fell: its killer (the last to
## hit it), and how far that killer stood from it, at least (phase 8 part 4,
## Singing Arrows and Long Wind; null and 0: any).
var by: UnitCondition = null
var by_range: int = 0
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
## (8c-5c, the Drifting Moth) it follows the enemy nearest it instead.
var follows_nearest: bool = false
## (phase 8 part 5, Carrier) it moves with its caster instead: centered on it
## before each pulse while it stands.
var follows_holder: bool = false
## A circle or ring zone that grows (phase 8 part 6, Wildfire): 1 hex wider
## every grow_ticks after it's cast, up to grow_max hexes ("grows":
## {"every_ms": 2000, "max_radius": 3}; 0: it doesn't).
var grow_ticks: int = 0
var grow_max: int = 0
## An area cast once on each of the unit's largest groups of enemies, up to
## this many (phase 8 part 6, Firestorm: Targeting.largest_groups; 0: on its
## anchor as usual). Its anchor is "target".
var at_groups: int = 0
## A zone (phase 8 part 6, Living Flame): it stays past its end while an
## enemy of its caster stands within this far of its edge ("stays_near_hexes";
## plane units, 0: it ends on time), and it's 1 hex wider for each stack of
## this status on its caster ("radius_per_stack": "living_flame"; "": none).
var stays_near: int = 0
var radius_per_stack: String = ""
## heal (phase 8 part 6, Kindred Flame): what it would heal past full HP is
## that many stacks of this status for every `overheal_per`, on the enemy
## nearest the unit healed ("overheal_status": {"status": "burn", "per": 5}).
var overheal_status: String = ""
var overheal_per: int = 0
## allies_near_self: only the nearest this many (phase 8 part 6, Blessing;
## 0: every ally within reach).
var nearest: int = 0
## An area (phase 8 part 2, Stormline): each enemy it hits after the first,
## nearest its origin first, deals this much more damage than the one
## before ("per_enemy_bp": +10% a step is 1000). 0: none.
var per_enemy_bp: int = 0
var ricochet: int = 0
## Damage (phase 8 part 2, Eagle Eye and Inquisitor): a hit that leaves its
## target alive below this share of max HP finishes it ("execute_below_pct";
## a DAMAGE line noted "executed"). 0: none.
var execute_below_bp: int = 0
## Damage (phase 8 part 4, Executioner): the execution finishes only a
## target that meets this ("execute_vs"; null: any).
var execute_vs: UnitCondition = null
## on_kill (phase 8 part 2): only a kill an execution made ("executed").
var executed: bool = false
var reflect_bp: int = 0
var snags: bool = false
var under_front: bool = false
## A snare set where the unit an event names stands ("at": "named"; phase 8
## part 2, Huntmaster: where a Rooted enemy fell), not in a target's path.
var snare_at_named: bool = false
## wall: how wide, and how far ahead of the unit its middle is (plane units).
var width_range: int = 0
var ahead_range: int = 0
## wall (phase 8 part 2; Walls): its enemies can't walk through it; its HP
## as a share of its unit's max HP (0: none, it can't be worn down); it
## stands until broken (zone_ticks 0); it's raised ahead of the target
## rather than the unit. Its own effects land on enemies touching it.
var blocks_movement: bool = false
var wall_hp_bp: int = 0
var until_broken: bool = false
var at_target: bool = false
var pulse_ticks: int = 0


## The effect `reader` holds, checked (EffectReader). `relic`: a relic's effect
## (relic triggers and targets, flat numbers). `in_area`: one of an area's own
## effects (it may have a "side").
static func read(reader: DataReader, relic: bool = false, in_area: bool = false) -> EffectDef:
	return EffectReader.read(reader, relic, in_area)


## Reads an optional "window" object into `holder` (an EffectDef or AuraDef,
## anything with window_from_ticks / window_until_ticks; EffectReader).
static func read_window(reader: DataReader, holder: Object) -> void:
	EffectReader.read_window(reader, holder)


## The event triggers' names, in order.
static func event_trigger_names() -> Array[String]:
	var names: Array[String] = []
	for trigger: Trigger in EVENT_TRIGGERS:
		names.append(TRIGGER_NAMES[trigger])
	return names


## True if the effect is active at this tick of the fight.
func active_at(tick: int) -> bool:
	return tick >= window_from_ticks and (window_until_ticks < 0 or tick < window_until_ticks)


## The base value this effect scales (amount, or stacks for apply_status).
func base_value() -> int:
	return stacks if type == Type.APPLY_STATUS else amount


## It lands on one unit by itself (no area, move, or placement): what a grip
## may do each time (phase 8 part 4, Grips).
func is_landed() -> bool:
	return type == Type.DAMAGE or type == Type.HEAL or type == Type.SHIELD or type == Type.APPLY_STATUS or type == Type.EXTEND_STATUS
