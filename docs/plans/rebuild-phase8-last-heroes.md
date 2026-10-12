# Phase 8 part 6: the last five heroes and the roster check

Status: **a build plan, approved** (2026-10-12; Decisions 1–10). The remaining five designed heroes, Ilse Cinderhand, Ottilie Brack, Kestra Fenn, Lucan Merrow, and Hob Gleaner, built from their designs (`rebuild-heroes.md` sections 8b, 8i, 8k, 8j, 8f; `apexes.md`; `upgrade-pools.md`; `duo-bonds.md`) the way phase 8 part 5 built Severine and Edric (`rebuild-phase8-severine-edric.md`), then **the one check and tuning pass over all thirteen** that part 5's Decision 8 moved here. Numbers are the designs' placeholders until each hero's builds report and the final pass. Questions are in section 12, answered in the Decisions.

## 1. What it builds

- **Five heroes,** each whole: the base kit and figure, the sim pieces its kit, paths, apexes, and bond relics need, three paths with habits, 33 cards, six apexes with 12 apex cards, and its paths tuned by build (the builds report, the apex sweep, the apex deed sizes), as each part-5 hero was.
- **Thirteen bond relics:** every bond in `duo-bonds.md` that names one of the five (Price and Prey, Burning Volley, The Bellows, Gilded Ash, Putrefaction, Nest of Rot, The Firepit, Unseen Blade, Tonic and Hymn, The Menagerie, Hall of Arrows, Tithe and Hoard, Black Market Ledger). With them every agreed bond is built but Lantern Vigil (Question LJ).
- **The roster check** (section 9): what part 5's 8e-4 and 8e-5 would have done, once, for thirteen heroes: the paths and deeds reports, the apex sweep, the placement refit, the bots' runs over a sample of the 286 teams, every hero into the band, the acts read, then the docs and a playtest build.

Not in it: unlocks (all thirteen are open from the start), the role layer of upgrades, and new acts or enemies.

## 2. The order, and why

Each hero leans on pieces another needs, so they come in the order that builds each shared piece once, where it's first needed:

1. **Ilse** (8f-1): Burn as mana (Heat), Burn that decays slower, setting off a status's stacks (Immolate), spreading ground fire, and allies' attacks that carry her Burn. Everything after reads Burn.
2. **Ottilie** (8f-2): Burn and Poison together (Catalyst reads both, Transmuter pays for both), a vial on the next attack after a timer, a per-fight cap on a unit's shards, and **bonus damage from a named passive as a deed count** (Catalyst's "extra damage from Reaction"; Hob's, Lucan's, and Kestra's deeds reuse it). Her item transmuting is the first new shop action.
3. **Kestra** (8f-3): **hero-side summons from a hero's own kits** (Grit, the viper, Nest's vipers): a companion that starts beside her, scales from her stats, and returns after falling, commanded by her signature. Lucan's copies reuse the frame.
4. **Lucan** (8f-4): copies of a unit (himself, or every ally) as summons, "allied unit" and "allied summon" counts, the ally most enemies target, and the **confused and controlled states** (Night Veil, Marionette).
5. **Hob** (8f-5): last, since he is mostly run pieces: shards held as fight power (Nest Egg, Heavy Purse), shop rules (rerolls, prices, the black-market slot, sell-back), shards spent as a run count, and the Bounty (the toughest enemy, a feat deed). His Tithe and Hoard bond needs Edric (built).

Then **8f-6, the roster check and tuning** (section 9), and **8f-7, the docs and playtest build** (section 10).

## 3. What's built that they use

Much of what the five need is already in the sim from earlier heroes and relics: Burn and Poison (damage over time with stacks and decay), `stacks_of` with `stacks_share_bp` (Stoke: a share of the target's Burn), per-hit auras with `per_target_stacks`, zones that last, that follow the biggest group or the nearest enemy, warned rings, `on_enemy_fell` with `vs` statuses, `once_per_enemy`, the effect `shards` and its SHARDS log kind with a board form (Edric), `FightSetup.shards` and Practice's shards setting (Edric), the run's own counts and team growths (Edric), `lowest_mana_ally` with `count`, MANA_GIVEN, mana-gain auras, a boost spent by the holder's next attack (`until_attack`) or next signature (`signature_power_bp`), Stealth and its payoffs (Tamsin), defender-side evasion (`evade_bp`), summons with `max_standing` and a lifetime (Gravecaller's `expires_at`), `UnitCondition.raised` and `kits`, auras `"while": "ally_near"` and `ally_standing`, and execute below a share of HP.

## 4. Ilse Cinderhand (part 8f-1)

The design: `rebuild-heroes.md` 8b, `apexes.md` Ilse, `upgrade-pools.md` Ilse, the bonds Burning Volley, The Bellows, and The Firepit.

- **Base kit:** HP 260, ATK 6, MGK 22, DEF 8, CRIT 5, speed 2, range 3. Cinder Flick (MGK, plus Burn of 10% of her MGK; **gives no mana**); Flare (60 mana: a 1-hex burst of Burn equal to 60% of her MGK); Heat (each Burn tick on any enemy within 3 hexes gives her 1 mana: her only mana).
- **Paths:** Furnace (Stoke, Immolate), Wildfire (Kindling, Firestorm), Ember Choir (Blessing, Hymn of Cinders). Flare is each one's habit.
- **Apexes:** Blast Furnace, Crucible, Living Flame, Ring of Fire, Cinder Saint, Kindred Flame.

| Piece | Built already | New |
| --- | --- | --- |
| Heat | Burn ticks are STATUS_DAMAGE lines | **a trigger on any status tick near the unit** (`on_status_tick` with `statuses` and `within_hexes`; one firing a tick, so 1 mana per tick per enemy) |
| Stoke | `every`, `stacks_of` with a share | none expected |
| Furnace's slower decay | | **a decay aura on the burning unit** (the stat `over_time_loss_bp`, put on enemies she hit by a short status) |
| Immolate | cleanse of a status | **damage from a status's stacks** (damage's `"amount_per_stack"`: N times the target's stacks, read before a cleanse in the same ability) and the half spread to enemies within 1 hex (`stacks_of` share on near targets, run first) |
| Kindling, Wildfire | zones, `follows` | **a zone that grows** (`"grows_hexes"`, `"grow_every_ms"`, `"max_hexes"`) and **Firestorm's 3 largest groups** (the target `largest_groups` with `count`) |
| Blessing, Ember Choir, Hymn | boosts, `until_attack` | **an on-hit effect given to allies** (a new aura kind, `"grants_on_hit"`: an effect that rides on each receiver's basic attack, scaled by the giver's stat as it lands; with `charges` for Blessing's 3 attacks) |
| Living Flame, Ring of Fire | `follows: nearest`, rings | a zone that **stays while an enemy is within 1 hex**, grows per kill, and starts a new one (`on_enemy_fell` inside a zone); **entering a ring** as an event (`on_zone_enter`) for Ring of Fire's crossing |
| Cinder Saint | per-hit `vs` auras | an MGK step from each ally basic attack (`on_ally_hit` with `"by"`, a stacking boost on her) |
| Kindred Flame | heals | **a heal on every hero from any Burn tick**, as a share of it, and its overheal to Burn on the nearest enemy |

**The rift learns:** her Burn counts toward the Burn habit as Maren's Ember relics' does.

### Built in 8f-1

- **Her base kit** (`data/heroes.json`, the ninth hero): the design's stats, Cinder Flick (MGK, Burn of 10% of her MGK, no mana), Flare (60 mana: Burn of 60% of her MGK on every enemy within 1 hex of its target), and Heat (her only mana: each Burn tick on an enemy within 3 hexes, whoever's Burn, Decision 1). Measured against the base-kit band (enemies x0.75, as 8e-1's check): at the design's 1 mana a tick she cast Flare 0–1 times a fight, so Heat gives **3 a tick**, and Cinder Flick is **1.2s** to keep her team in the band: **+9** (78% against the old three's 69%; Heat 3 at 1.0s was +16, Heat 2 at 1.1s +9 with fewer casts). Her figures (`tools/art/hero_kit.py`).
- **Her pieces** (each skipped by a fight that doesn't use it; `tests/sim/test_ilse_pieces.gd`): `on_status_tick` (Heat), the aura stat `over_time_loss_bp` (Furnace's Smoldering; the part of a stack it puts off is carried, so it halves the fade at any stack count), damage's `amount_per_stack` and an on_fire `stacks_of` reading the ability's target (Immolate; the splash runs first, then the hit, then the cleanse), zones that `grow` (Wildfire), areas `at_largest_groups` (Firestorm), on_ally_hit's `spends` (Blessing's charges: a stack of `blessed` spent per hit), allies_near_self's `nearest`, and the deed filter `by_stacks` (her three deeds count Burn stacks). **Not built as the table proposed:** Ember Choir needed no `grants_on_hit`: its Burn on allies' attacks is an on_ally_hit passive on Ilse, so it is hers, reads her MGK as each hit lands, and rides summons' and copies' basic attacks too (Decision 2).
- **Her paths** (`data/paths.json`; she can be drafted, so a run drafts three of nine): **Furnace** (vowed: Stoke, every 4th Cinder Flick adds 5% of its target's Burn, -10% MGK; transformed: every 3rd adds 8%, Burn on enemies she hit in the last 3s fades half as fast, Immolate 8 a stack and half its Burn to enemies within 1 hex, +20% attack speed), **Wildfire** (vowed: Kindling, Flare leaves 3s of burning ground; transformed: the ground spreads 1 hex every 2s up to 3 and lasts 6s, Burn of 15% of her MGK a second, Firestorm under the 3 largest groups, Cinder Flick sets no Burn, +10% MGK and HP), and **Ember Choir** (vowed: Blessing every 8s on the nearest ally within 8 hexes, 3 attacks of 1 Burn, -1 range; transformed: every ally's basic attack sets Burn of 5% of her MGK, Hymn of Cinders gives every ally +15% attack speed and 15% more for 5s, her own Burn 30% weaker). Flare is each one's habit, every 8th Cinder Flick (Wildfire's every 6th, with Kindling's ground). First thresholds, about four fights' worth: Furnace 14, Wildfire 56, Ember Choir 18.
- **Tuned by build** (`tools/build_teams.json`: Furnace, Wildfire Pit, Pyre): floors **Furnace +5** (engine, +5 to +15; it was +3 before Immolate's 5 a stack became 8 and the attack-speed lift; more speed didn't move it), **Wildfire +30** (self-sufficient; +18 before the MGK and HP lift and the hotter ground), **Ember Choir +21** (enabler, +10 to +20, one over) with **lift +16** against Wildfire. The ceilings read low (their build teams win 75–97% with her on base), as earlier heroes' did.
- **Her 33 cards** (`data/upgrades.json`; `tests/sim/test_ilse_cards.gd`) and their knobs: `share_add_bp` (Deep Stoke), `grow_every_add_ms` and `grow_max_add` (Fast and Far Spread), `within_add` reaching Heat (Fan the Coals), `count_add` reaching Blessing (Shared Blessing). **Calls made while building:** Wildfire's vowed cost is Flare's Burn 25% weaker, not a smaller circle (a 1-hex circle can't shrink); Kindled Start is her first Cinder Flick's great Burn (the nearest enemy, at the start, has no target to name); Heat Shimmer is 15% evasion on any basic attack (evasion can't filter by distance); Tinder Box and Scorched Earth grow with the Burn stacks set (enemy-seconds and Burn damage near her aren't counted); Ember Ward weakens the enemies her allies set Burning (damage taken can't ask who hit); Rekindle is any Burning enemy falling.
- **Bond relics** (`data/relics.json`, `data/bonds.json`; 115 relics, 16 bonds): **Fire on the Wind** (Burning Volley: Maren's basic attacks, split arrows too, carry Burn of 20% of Ilse's MGK; Arrow Storm's area sets Burn from Maren's ATK, her MGK being nothing), **Bellows of the Wind** (The Bellows: Ilse attacks faster and harder as if from far off; every enemy Gale knocks back gains a quarter more Burn), **The Firepit** (`"mod_for": "garrow"`: Maelstrom sets spreading burning ground from his ATK, and Crowd Strength counts Burning enemies twice), and **The Vigil Lamp** (Lantern Vigil, Decision 10; `"mod_for": "vell"`: her heals on Brannoc below 30% stop at 30%, the rest a Shield, and Night Lantern goes to him first; the lantern lands on him rather than following him, a call). The relic check now meets a hero's own kits for `mod_for` a hero, and a bond relic's only its bond path's.
- **Her apexes** (`tests/sim/test_ilse_apexes.gd`) and their pieces: **Blast Furnace** (every 2nd Cinder Flick stokes; each Stoke +2% attack speed and +1% MGK), **Crucible** (Immolate keeps the Burn; each Immolate makes Stoke add 1% more: `grows_per_stack` on a stacks_of share), **Living Flame** (her fires creep toward the nearest enemy, stay while one is within 1 hex, 20% of her MGK a second; each kill by them makes every fire 1 hex wider and 25% hotter and starts a new one where it fell: a zone's `stays_near_hexes` and `radius_per_stack`), **Ring of Fire** (each Firestorm also draws a 2-hex ring round the largest group, lasting the fight, up to 3; crossing one burns for 80% of her MGK and Slows, and makes every ring 10% hotter: `on_zone_enter`; first built as Firestorm's replacement, it lost Wildfire's fires and did nothing on the sweep), **Cinder Saint** (allies +20% damage to Burning enemies, their Burn rises to 10%, each ally basic attack +1% MGK), and **Kindred Flame** (every hero heals 1% of all Burn damage, 1 HP for every 100 banked: a heal's `per_damage`; overheal sets Burn on the enemy nearest, 1 for every 5: `overheal_status`). Their 12 cards. Apex teams (`tools/apex_teams.json`): Blast Furnace, Crucible, Living Flame, Ring of Fire, Cinder Saint, Kindred Flame.
- **The sweep** (apex half point over the transformed half point; the Gallery's 1.44, the built spread 1.26–2.07): Blast Furnace 1.33, Crucible 1.79, Living Flame 1.37, Ring of Fire 1.29, Cinder Saint 1.44, Kindred Flame 1.35. **Apex deed sizes** (about 13 fights' worth with the taste, as Hailstorm's, Undertow's, and Eagle Eye's): Blast Furnace 95, Crucible 5500, Living Flame 12, Ring of Fire 40, Cinder Saint 9500, Kindred Flame 16.
- **Not changed:** no fight without these pieces; the bench's fingerprints are unchanged. Changed on purpose: nine heroes in `test_hero_kits.gd` (with Cinder Flick and Flare tests), `test_hero_team.gd`, `test_path_kits.gd`, `test_path_report.gd` (61 variants), `test_unit_info.gd` (48 kits, 53 reaches), `test_content_db.gd` (the statuses), and `test_relics.gd` (16 bond relics).

## 5. Ottilie Brack (part 8f-2)

The design: `rebuild-heroes.md` 8i, `apexes.md` Ottilie, `upgrade-pools.md` Ottilie, the bonds Gilded Ash, Putrefaction, Tonic and Hymn, and Black Market Ledger.

- **Base kit:** HP 280, ATK 8, MGK 18, DEF 10, speed 2, range 3. Toss (MGK); Volatile Flask (60 mana: a 1-hex burst, 120% MGK and Burn and Poison of 20% MGK each); Brewing (every 4s her next Toss is a fire or a venom vial, in turn).
- **Paths:** Catalyst (Reaction, Reaction Flask), Transmuter (Gilded Death, Philosopher's Flask, item transmuting), Apothecary (Tonic, Elixir). Volatile Flask is each one's habit.
- **Apexes:** Grand Reaction, Solvent, Midas Touch, Grand Transmutation, Panacea, Mana Flood.

| Piece | Built already | New |
| --- | --- | --- |
| Brewing, Tonic | a boost spent by the next attack | **a timer that loads the next basic attack** (a passive `"loads_next_attack"`: every N ms a status that the next basic attack spends, adding its effects; Brewing's two vials take turns) |
| Reaction | per-hit auras with `per_target_stacks` | per-hit stacks of **two statuses summed**, with a cap (`per_target_stacks` taking a list, `"cap"`) |
| Reaction Flask | | damage's `amount_per_stack` over two statuses (8f-1's piece), reading without spending |
| Catalyst's deed | | **bonus damage from a named passive** (the deed count `bonus_damage` with `"from_part"`: the share of each hit the named aura's power added, worked out where the damage rule adds power; Hob's Nest Egg, Lucan's Strings, and Kestra's Pack Call count the same way) |
| Gilded Death | `on_enemy_fell` with `vs`, `shards` | `vs` both statuses (a condition's `statuses` that must all hold: `"all_statuses"`), and **a unit's shard cap for the fight** (`UnitDef.shard_cap`; SHARDS past it are logged as "capped" and paid nothing; apexes and cards raise it) |
| Transmuting | the Pedlar's buy-back | **a shop action** (`RunFlow.transmute(item)`: an item's full price as shards, once a shop, while she's transformed on Transmuter), and Grand Transmutation's item for a random one of its kind at rank II |
| Elixir, Mana Flood | `gain_mana`, boosts | **signatures costing less while a status lasts** (the aura stat `signature_cost_bp`), and the window lasting longer per ally signature (`extend_status` on `on_ally_ability`) |
| Solvent | `stacks_of` | the smaller of two statuses raised by a share of the larger (apply_status's `"to_smaller_of"`) |

**The rift learns:** Poison gets its habit once she and Kestra are in (part 5's Decision 7), sized from runs in 8f-6.

## 6. Kestra Fenn (part 8f-3)

The design: `rebuild-heroes.md` 8k, `apexes.md` Kestra, `upgrade-pools.md` Kestra, the bonds Gilded Ash, Nest of Rot, and The Menagerie.

- **Base kit:** HP 300, ATK 18, DEF 12, CRIT 8, speed 2, range 2. Spear Jab; Sic 'Em (50 mana: Grit leaps to her target and bites for 200% of his ATK); Bond (+10% attack speed for both while Grit is up). **Grit:** a rift-hound beside her from the fight's start, 40% of her max HP, 60% of her ATK, fast melee; he returns 10s after falling.
- **Paths:** Cinderhound (Smoldering Fangs, Firebrand Pounce), Serpent-Keeper (Venomed Jab; the viper in Grit's place; Nest), Packleader (Pack Call; two hounds; Howl). Sic 'Em is each one's habit.
- **Apexes:** Hellhound, Firestarter, Brood Mother, Viper Queen, Alpha, Wild Hunt.

| Piece | Built already | New |
| --- | --- | --- |
| Grit, the viper | summons, lifetimes | **companions:** a hero kit's `"companions"` (kits in `heroes.json` beside the hero's, never draftable), placed beside her at the start, their HP and ATK a share of hers at setup (after her upgrades and loadout), logged as SUMMON sourced to her, returning after `return_ms` (a new SUMMON noted "returns"); allied summons for every count |
| Sic 'Em, Firebrand Pounce | leaps | **an effect done by a companion** (`"by": "companion"`: the companion leaps to her target and does the effects, its own ATK) |
| Bond, Pack Call | `ally_standing`, per-unit auras | `"per": "allied_summon"` (and Lucan's `"allied_unit"`) |
| Smoldering Fangs, Cinderhound's burning coat | `every`, `on_hit_taken` | a companion's effects scaled by **her** stats (an effect's `"scaling_of": "owner"`) |
| Nest, Brood Mother | summons with `max_standing` | summons of a hero's own companion kits (the summon effect naming a companion kit) |
| Pack Fury, Alpha | `on_ally_falls`-like events | **an allied summon falling** as a trigger (`on_summon_fell`) |
| Howl, Wild Hunt | boosts, Shields | the target `allied_summons` |

## 7. Lucan Merrow (part 8f-4)

The design: `rebuild-heroes.md` 8j, `apexes.md` Lucan, `upgrade-pools.md` Lucan, the bonds Unseen Blade, The Menagerie, and Hall of Arrows.

- **Base kit:** HP 270, ATK 8, MGK 18, DEF 8, speed 2, range 3. Glimmer (MGK); Mirror (60 mana: a copy of himself beside him for 6s, at 30% of his stats, basic attack only); Unreal (enemies attacking him miss 15%).
- **Paths:** Mirrorwright (Reflection, Hall of Mirrors), Veilweaver (Shroud, Vanishing Act), Puppeteer (Strings, Dance of Strings). Mirror is each one's habit.
- **Apexes:** Thousand Faces, True Reflection, Unseen Host, Night Veil, Grand Puppeteer, Marionette.

| Piece | Built already | New |
| --- | --- | --- |
| Mirror, Reflection, Thousand Faces | 8f-3's companions, `max_standing`, lifetimes | **a copy of a unit** (the summon `"copy_of": "self"`: its kit as it stands, stats at a share, basic attack only, carrying its basic-attack mods), bursting when it falls (on_fall) |
| Hall of Mirrors, True Reflection | | `"copy_of": "each_ally"` (each hero, at a share of its stats; True Reflection's copies cast their signature once) |
| Unreal | `evade_bp` | none expected |
| Shroud | Stealth on `lowest_hp_ally` | the target **the ally most enemies target** (`most_targeted_ally`) |
| First strike from Stealth, Vanishing Act | Tamsin's from-Stealth pieces, crit boosts | none expected beyond a guaranteed crit on the next attack (a boost's `"crit_next"`) |
| Strings, Puppeteer | per-unit auras | `"per": "allied_unit"`; an aura `"only"` on summons (`UnitCondition`'s `"summoned"`) |
| Dance of Strings | | **summons attack his target** (a status on summons that sets their target to his: `"focus_of"`) |
| Night Veil, Marionette | | **confused** (attacks the nearest other enemy) and **controlled** (fights for the heroes, counts as an allied unit; never elites or bosses, who take +25% damage instead): two new targeting states, set and ended with log lines sourced to Lucan (new log kinds with audit rules and board forms) |

## 8. Hob Gleaner (part 8f-5)

The design: `rebuild-heroes.md` 8f, `apexes.md` Hob, `upgrade-pools.md` Hob, the bonds Price and Prey, Tithe and Hoard, and Black Market Ledger. **Deliberately weaker in a fight;** his worth is the run.

- **Base kit:** HP 300, ATK 16, DEF 12, CRIT 10, speed 3, range 2. Sling Stone; Grab (50 mana: darts to the lowest-HP enemy within 3 hexes, 150% ATK); Pickings (an enemy dying within 2 hexes of him: +1 shard). **Shard cap:** 8 a fight, from his whole kit (8f-2's `shard_cap`).
- **Paths:** Hoarder (Nest Egg, Heavy Purse), Fence (Haggle, Cut Purse, shop rules), Bounty Hunter (Bounty, Collect). Grab is each one's habit.
- **Apexes:** Dragon's Hoard, Golden Idol, Black Market, Silver Tongue, Manhunter, Price on Their Heads.

| Piece | Built already | New |
| --- | --- | --- |
| Nest Egg, Dragon's Hoard | `FightSetup.shards`, team auras | **an aura per shards held** (`"per_shards": N`, with a cap), to allies at a share |
| Heavy Purse, Golden Idol | a Shield's `plus_per_shard_bp` | the same on damage; a Shield of N a shard at the start; the held shards counting more per cast (a stacking boost read by `per_shards`) |
| Fence, Black Market | run rules on relics (prices, rerolls) | **run rules on a path's stage** (a `"shop"` block beside `"tithe"`: rerolls free or cheaper, sell-back share, the black-market relic slot one tier up) and **shards spent in shops** as a run count for a team growth (Fence's +0.1% a shard) and a deed (Haggle's shards saved) |
| Cut Purse, Silver Tongue | `once_per_enemy`, `shards` | none expected |
| Bounty, Manhunter, Price on Their Heads | Marks, execute | **the toughest enemy** (the target `toughest_enemy`, most max HP, then the fight's order), a Bounty status that passes to the next toughest when its holder dies, and the deed count `kills` with `vs` a status (the feat deed: 1) |
| Run snowballs | Edric's team growths and run counts | the counts "won_holding" (a fight won holding 30+ shards: Dragon's Hoard), "relics_bought" (Black Market), "bounties" (Manhunter, Price on Their Heads) |

## 9. The roster check and tuning (part 8f-6)

Part 5's section 8, for thirteen heroes, once:

- **The reports:** `tools/build_teams.json` a build team for each new path; `tools/apex_teams.json` a team for each new carry apex and bond; `tools/test_teams.json` the synergy teams `test-teams.md` names for the five (Venom, Burning Volley, Full Greed, and the rest).
- **The check:** each vow within 5 points of base on the paths report, each transformation at its type's floor on the builds report, each vowed deed sized to about 4 fights, each apex's half point within the built spread on the apex sweep, every bond relic firing in its team's fights.
- **The placement refit:** once, with teams drawn from the thirteen (Act 1, water, and void sets), checked with `placement_check.gd`.
- **The runs:** 286 teams are too many to cover each (Question LH); the good bot's runs over a sample that holds every hero about equally, then **every hero into the band** (±8 points of the mean runs won), lifting or trimming the hero, never the acts first; then the acts read against their targets (Act 1 43%, Act 2 34%, Act 3 33% of the runs reaching them) and retuned only if Act 1 leaves 40–49%.
- **The rift learns:** the Poison habit (part 5's Decision 7) sized from the runs.

## 10. The docs and the build (part 8f-7)

HOW-TO-PLAY (the thirteen, their bonds, what we want to know), screenshots (the draft, a fight with each new hero), `docs/design.md`, `CLAUDE.md`, and a playtest build.

## 11. Parts

- **8f-1, Ilse:** her pieces (section 4), paths and habits, figures, cards, apexes, Burning Volley, The Bellows, and The Firepit, her paths tuned by build, and her docs.
- **8f-2, Ottilie:** her pieces (section 5, the bonus-damage deed and the shard cap among them), her shop action, paths, figures, cards, apexes, Putrefaction and Tonic and Hymn, tuned by build.
- **8f-3, Kestra:** companions and her pieces, paths, figures, cards, apexes, Gilded Ash and Nest of Rot, tuned by build.
- **8f-4, Lucan:** copies, the confused and controlled states, his pieces, paths, figures, cards, apexes, Unseen Blade, The Menagerie, and Hall of Arrows, tuned by build.
- **8f-5, Hob:** his fight and run pieces, paths, figures, cards, apexes, Price and Prey, Tithe and Hoard, and Black Market Ledger, tuned by build.
- **8f-6, the roster check and tuning** (section 9).
- **8f-7, the docs and the build** (section 10).

A bond relic is built with the later of its two heroes. Every new piece is skipped by a fight that doesn't use it, so the bench's fingerprints stay as they are; each gets a small-fight test, an audit rule and a board form if it adds a log kind, a place in the chaos fight or a named test, and a mutation check. Each part commits on its own with the full suite green.

## 12. Questions

- **LA. Heat's mana:** "each Burn tick on any enemy within 3 hexes gives her 1 mana." Proposed: every enemy's tick counts (five Burning enemies near her is 10 mana a second), whoever's Burn it is (allies' and relics' Burn is her fuel), and her own Silence stops it as it stops all mana.
- **LB. Ember Choir's Burn on allies' attacks:** "Burn equal to 5% of her MGK." Proposed: read her MGK as each hit lands (so Cinder Saint's growing MGK feeds it), and it rides on basic attacks only, summons' and copies' included (they're allies), as the design's "plays off" says.
- **LC. "Allied unit" and "allied summon":** proposed: an allied unit is any unit standing on the heroes' side (heroes, copies, companions, vipers, thralls, controlled enemies); an allied summon is any of those that isn't a hero or a controlled enemy, Severine's thralls included (Firestarter names them). Grit counts as an allied summon (the design says so) and for Puppeteer.
- **LD. Companions' stats:** proposed: Grit and the viper take their share of Kestra's HP and ATK as each fight is set up, after her upgrades, loadout, and relics (not her in-fight auras); relics that change every hero don't touch them, and their wounds are hers (they start at her max HP's share after wounds).
- **LE. Shard caps:** proposed: one cap a unit a fight (Hob 8, Ottilie's Gilded Death 3 vowed, 8 transformed), counted in the sim so the log shows each capped shard; shards from a lost fight are paid as Collection's are (any fight).
- **LF. Which shops Hob's and Ottilie's shop rules reach:** proposed: the Pedlar and the boss shop; the Magpie keeps his own rules (he buys no items, so no transmuting or sell-back there), and Black Market's slot shows only at the Pedlar and the boss shop. Fence's "shards spent in a shop" counts items, relics, rerolls, and treated wounds there and at the Magpie, never the Shrine.
- **LG. Controlled and confused enemies:** proposed: a controlled enemy keeps its kit and HP, fights for the heroes for the time, counts as an allied unit (not a summon), and its kills are Lucan's; confused attacks the nearest other enemy and its hits count as the enemies' (no deeds for the heroes); elites and bosses take +25% damage for the time instead; neither state survives a Taunt (Taunt wins).
- **LH. The runs over 286 teams:** proposed: 300 runs for the band (each hero in about 70), drawn so every hero appears about equally, with 10 runs each for the synergy teams `test-teams.md` names; about 7 hours with 4 jobs. Or fewer runs per hero (200 runs, about 46 a hero) at more noise?
- **LI. The order:** proposed as section 2 (Ilse, Ottilie, Kestra, Lucan, Hob). Or Hob earlier, since his run pieces are the most different and might want a look before the rest?
- **LJ. Lantern Vigil:** the one agreed bond among built heroes not built (Last Watch + Lanternbearer: The Vigil Lamp needs heals capped below 30% with the rest as Shield). Proposed: build it in 8f-1 alongside Ilse's bonds, so the check sees every bond.

## Decisions

The playtester approved the plan with every proposed answer (2026-10-12):

1. **Heat (LA):** every enemy's Burn tick within 3 hexes counts, whoever's Burn it is (allies' and relics' too); her own Silence stops it as it stops all mana.
2. **Ember Choir's Burn on allies' attacks (LB):** her MGK is read as each hit lands (Cinder Saint's growing MGK feeds it); it rides on basic attacks only, summons' and copies' included.
3. **Allied units and summons (LC):** an allied unit is any unit standing on the heroes' side (heroes, copies, companions, vipers, thralls, controlled enemies); an allied summon is any of those that isn't a hero or a controlled enemy, thralls included. Grit counts as an allied summon and for Puppeteer.
4. **Companions' stats (LD):** set as each fight is set up, from Kestra's HP and ATK after her upgrades, loadout, and relics (not her in-fight auras); relics that change every hero don't touch them; her wounds are theirs.
5. **Shard caps (LE):** one cap a unit a fight (Hob 8; Gilded Death 3 vowed, 8 transformed), counted in the sim so the log shows each capped shard; shards from any fight are paid, won or lost.
6. **Shop rules (LF):** Hob's and Ottilie's reach the Pedlar and the boss shop; the Magpie keeps his own; Black Market's slot shows only at those two. Fence counts shards spent on items, relics, rerolls, and treated wounds there and at the Magpie, never the Shrine.
7. **Controlled and confused (LG):** controlled keeps its kit and HP, fights for the heroes for the time, counts as an allied unit (not a summon), its kills Lucan's; confused attacks the nearest other enemy and its hits count as the enemies' (no deeds for the heroes); elites and bosses take +25% damage for the time instead; Taunt wins over both.
8. **The runs (LH):** 300 runs for the band, drawn so every hero appears about equally (about 70 each), plus 10 runs for each synergy team `test-teams.md` names.
9. **The order (LI):** as section 2: Ilse, Ottilie, Kestra, Lucan, Hob.
10. **Lantern Vigil (LJ):** built in 8f-1 with Ilse's bonds, so the check sees every bond.
