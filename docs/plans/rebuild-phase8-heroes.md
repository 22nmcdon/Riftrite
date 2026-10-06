# Phase 8 part 4: heroes 4 to 6 and the team draft

Status: **a build plan, approved (2026-10-06); section 10's questions answered (Decisions 4–7); 8d-1, the draft frame, built.** It builds Garrow of the Chains, Tamsin Gloamstep, and Aldous Vesper from their designs (`rebuild-heroes.md` sections 8c, 8d, 8e; `apexes.md`; `upgrade-pools.md`; `duo-bonds.md`), and the team draft they bring back: a run picks three of the six. Numbers are the designs' placeholders. **The tuning pass comes after this plan, as its own phase**, with all six heroes in it (Decision 2). Questions are in section 10.

## 1. What it builds

- **The team draft** (section 3): New run picks three heroes of six, then vows them. The run, its save, Practice, the bots, and every report learn that a team is a choice, not `heroes.json`.
- **Three heroes** (sections 4 to 6), each whole: the base kit, three paths (taste, cost, transformation, deed and its threshold), six apexes (taste, deed, snowball), the hero's 12 hero cards, its path cards (taste and path layers), its 12 apex cards, a placeholder figure for the base form and each path, ability texts that name every reach, and the sim pieces they need.
- **Five bond relics** (section 7): every bond in `duo-bonds.md` whose two paths are both among the six heroes'.
- **A first check, not the tuning** (section 8): each new path and apex lands in the bars the built nine and eighteen were tuned to, so the tuning phase starts from heroes that are roughly right.

Not in it: the tuning of the acts to six heroes, the role layer of upgrades (`upgrade-pools.md`; it's phase 8's next piece once heroes share roles), unlocks (all six are open from the start: Question CA), and the other seven designed heroes.

## 2. Why these three, and why now

From the discussion of 2026-10-06 (Decisions 1 to 3):

- **Garrow** (tank, the anchor) has the most bonds with the built paths (Dragged to the Snare with Trapper, Woven Fang with Wardweaver), and completes two builds the built heroes only half make: Shield (Wardweaver and Hearthguard make Shields; Aegisfang cashes them) and Clump (Volley, Arrow Storm, Sunfall, and Ironbrand's cleave want enemies bunched; Chainwarden drags them in).
- **Tamsin** (melee damage, the knife) gives Root and Mark their payoffs on a second hero: today Trapper's only Root payoff is her own apex, which breaks `build-map.md`'s rule 5. Garrote pays off Trapper's Roots and Ironbrand's Stuns; Headhunter pays off Maren's Marks.
- **Aldous** (support, the bell-ringer) evens the roster: two tanks (Brannoc, Garrow), two damage (Maren, Tamsin), two supports (Vell, Aldous). Every role is shared, so a draft that drops any hero still has a front, damage, and support. He bonds with Vell (Toll and Judgment) and Tamsin (The Hunter's Bell), and makes Mana and Marks.
- **Three at once, tuned once:** every new hero moves every act's balance, so they come in together and the tuning phase follows. The draft is also thin with four heroes (4 teams); six give 20.

## 3. The team draft

- **The run:** `RunFlow.start(run, seed, vows, errors, testing)` takes its team from `vows`' keys (three hero ids, each with a path), in `heroes.json`'s order; `RunState.heroes` already holds them, so the save holds the team and its format doesn't change (a saved run keeps its three). `start` refuses a team that isn't three different known heroes. Nothing else in the run reads `content.hero_ids` as the team; section 3a lists every place that does and what it reads instead.
- **The start screen** (`RunStartScreen`): six hero cards (name, title, role, the three paths' names); click to pick up to three (a fourth click swaps out the oldest, or the card's Remove); the picked three show their vow rows as today (the paths, their tastes and costs, the bond "?"). Start is greyed until three are picked and vowed. The testing checkbox stays.
- **Practice** (`PracticeSession`, `EncounterListScreen`): the list screen gets a team row: the six heroes as toggles, three on (Brannoc, Maren, and Vell at first), remembered while the game is open. The arena, hero bar, and hero panel show the three chosen. Formations remembered per hero, so switching a hero out and back keeps where it stood.
- **Bonds:** a bond can only stir if both its heroes are on the team; the vow screen's "?" already reads the team's paths.
- **The rift learns and the run's other readers of heroes** read the team (they already read `state.heroes`).

## 3a. Where the code assumes the three (found 2026-10-06)

The sim already fights any set of heroes (`Encounters.setup` builds only those the formation names; `FightSetup.validate` has no team size). The rest reads `content.hero_ids`, or Brannoc, Maren, and Vell by name, as the team:

- **The run:** `RunFlow.start` (a vow for every hero in `heroes.json`; `state.heroes` built from it) takes the team; `RunFlow.fight_setup` refuses a hero who isn't on the team ("%s isn't on the team"). Everything else in the run (offers, oaths, the rift learns, records, events) already reads `state.heroes`.
- **The screens:** `PracticeSession.DEFAULT_FORMATION` (by name) becomes a formation by role for any team; `_build`, `formation_for`, and `tactics_in` read the session's team; `RunSession` reads `state.heroes`. `HeroBar` builds a card per team hero (six cards wouldn't fit, and an undrafted hero's card would crash in a run); `HeroPanel.step` cycles the team. `RunStartScreen` gets the draft (section 3). `FigureArt` finds `<hero id>_<path>.svg` already; the new figures go in `art/figures/heroes/` and `bounds.json`.
- **The tools and bots:** `tools/sim_formations.json` by role (section 8); `tools/run_bot.gd`'s `formation()` by role and `first_vows(content, team)` (Brannoc, Maren, and Vell by default, so the 19 test files that call it keep their runs); `placement_data.gd` and `placement_check.gd` draw a team of three; `sim_report.gd`'s `LATER_ACT_VOWS` stays the gate's team, and its formation draws, tactic variants, and columns read the fight's team; `path_report.gd` fights each path's variants with a team holding its hero (the other two from the built three), and its Guard measure reads the tank, not "brannoc"; `apex_teams.json` gains teams; `run_report.gd`'s `vow_combinations` becomes teams × vows (540), and its picks line reads each run's team; `ui_screenshots.gd` drafts.
- **Tests that name the roster** change on purpose: `test_hero_kits.gd` (the hero list), `test_run_report.gd` (27 combinations), `test_bots.gd` (the vow cycle and the roles), `test_sim_runner.gd` (formation keys), `test_run_flow.gd` (the vow error), `test_relics.gd`'s three-hero loops, `test_placement.gd` (the default formation's keys), and the run screen tests that drive the vow screen. The other fixtures (B, M, and V fights) stay valid, since the three stay in the roster.

## 3b. Habits (part 8d-2h; proposed 2026-10-06, waiting for approval)

The playtester's `changes-habits.md` (2026-10-06, applied to `rebuild-heroes.md` section 3, `upgrade-pools.md`, `ui-new-systems.md`, and `apexes.md`): when a transformation or an apex replaces a hero's signature, the old one stays as a **habit** that fires by itself every few basic attacks. It settles Chainwarden (Haul and Maelstrom both stay) and keeps cards for the base signature alive. Its section 5 (the sim work) is this section.

**What a habit is in the code: a passive on every Nth basic attack**, the piece Vell's three transformed paths already use (Lanternbearer's and Vigil Keeper's Mend, Wardweaver's Weave, each `on_basic_attack` with `"every": 4`). So most of the change doc's rules come for free:

- **Each habit keeps its own count** (each passive effect counts its own events, `Passives`), and fires on the attack that reaches it.
- **It never touches mana and never counts as a signature:** it isn't one, so nothing that listens for a signature (`on_ally_ability`, the `casts` deed, Overcharge, an echo, a sigil on the `signature` slot) hears it. Its effects can still give mana if the path says so (Vell's Mend does).
- **No mana bar needed** (Last Watch): it counts attacks.
- **Logged with the habit as its source:** the passive carries the old signature's id and name ("brannoc · Hold the Line"), so `from_ability` deeds, `on_heal`'s `from_ability`, and cards that name the ability still find it.
- **A Stun holds its count:** a stunned unit doesn't attack.

**In the data:** each path whose transformed patch (or an apex patch) replaces the signature carries the habit as a passive, written out, like Vell's. `ContentDb` refuses a kit that replaced a signature without a passive of the old one's id, so a new path can't forget it.

**One new target:** `farthest_enemies` (`"count"`, `"within_hexes"`): the standing enemies farthest from the unit within that reach. Haul's habit needs it, since a passive can't use the signature's `farthest` targeting rule.

**The habits this builds** (numbers from `rebuild-heroes.md`'s "Habits by hero"; placeholders):

| Hero | Paths | Habit |
| --- | --- | --- |
| Maren | Deadeye, Trapper, Volley | Marking Shot: every 8th Longshot, Marks her target for 4s |
| Brannoc | Hearthwall, Last Watch | Hold the Line: every 8th Shield Bash, taunts every enemy within 2 hexes for 3s |
| Brannoc | Ironbrand | the same, within 1 hex (adjacent, as its cost says) |
| Vell | all three | already built (Mend, Weave, the smaller Mend); unchanged |
| Garrow | Aegisfang, Spitemail | Haul: every 8th Chain Fist, pulls the farthest enemy within 4 hexes beside him |
| Garrow | Chainwarden | Haul: every 6th Chain Fist, pulls the 3 farthest enemies within 4 hexes beside him and Bleeds each (Barbed Chain's 20% of ATK) |

**Cards for an old signature** (`upgrade-pools.md`): the built heroes' cards already name statuses on every ability (Deep Mark, Long Hold) or a passive (`passive:mend`), so they reach the habit as they are. Garrow's (Swift Haul, Hard Landing, Long Barbs, Heavy Chain, Back-Line Hook) need one more knob: an "on" entry's `"ability": "haul"` applies only to the ability or passive with that id, signature or habit; and a mana cost change on it becomes the habit's `every` one lower ("costs less mana" fires one attack sooner).

**The screens:** a habit is a passive, so the Kit tab, the hero popup, and `UnitInfo` list it with its sentence ("Every 8th Shield Bash, he taunts every enemy within 2 hexes."). The pips beside the signature (`ui-new-systems.md`) wait for the UI redesign.

**What it changes:** every transformed Maren and Brannoc gains a habit, so the paths report's band (+16 to +21), the acts' tuning, and the good bot's placement fits drift up. Proposed: no retune now (Decision 2: the tuning phase tunes all six), and 8d-5's first check re-measures the band with habits in. The bench's fingerprints move if its fights use transformed kits; that's checked and recorded.

**Questions:**
- **HA. Retune:** leave the drift for the tuning phase (proposed), or bring the built six transformations back into the band now?
- **HB. Maren's habit target:** her current target (proposed; a passive's "target"), or the nearest enemy within 4 hexes like Marking Shot?
- **HC. Chainwarden's three:** the 3 farthest within 4 hexes (proposed), or the farthest and the 2 enemies nearest it?
- **HD. A bug found on the way:** Wide's extra targets (`targets_add`) reach only one enemy even at rank III (`targets_add: 2`), against its own description. Fix it now (runs with Wide at rank III change), or leave it for the tuning phase?

## 4. Garrow of the Chains (part 8d-2)

The design: `rebuild-heroes.md` 8d, `apexes.md` Garrow, `upgrade-pools.md` Garrow, the bonds Dragged to the Snare, Woven Fang (and The Firepit and Iron Hunger, waiting for Ilse and Severine).

- **Base kit:** Chain Fist; Haul (70 mana: the farthest enemy within 4 hexes, pulled beside him); Stand Fast (the first drop below 50%: a Shield of 15% of max HP); Heavy (no knockback or pull moves him).
- **Paths:** Aegisfang (Plated Blows, Bulwark Burst), Chainwarden (Barbed Chain, Crowd Strength, Maelstrom), Spitemail (Spikes, Iron Maiden).
- **Apexes:** Endless Bulwark, Shatterburst, Grinder, Undertow, Thorned King, Vengeance.

| Piece | Built already | New |
| --- | --- | --- |
| Haul | the farthest-target rule; a pull `"to": "beside"` (the Gulf Angler's hook) | none expected |
| Heavy | the aura stat `unpushable` (RESISTED; knockbacks and pulls don't move him) | none |
| Stand Fast | `on_below_hp` with `once`, a Shield of max HP | none |
| Plated Blows | `on_holder_hit` Shield on self | **a Shield cap** (Shield from this effect stops at a share of max HP: `cap_bp_of_max_hp`) |
| Bulwark Burst | areas, damage | **spend the Shield as damage**: a damage amount from the unit's own Shield (`amount_bp_of_shield`), the Shield then removed (logged as SHIELD_SPENT or the Shield's line, sourced to the ability) |
| Barbed Chain, Maelstrom | Bleed; pulls; targets_add | **pull every enemy within N** to beside him (a pull on `enemies_near_self`), and an attack reset (`reset_attack`) |
| Crowd Strength | auras `"per": "fallen_ally"` (Grief) | **an aura per enemy near** (`"per": "enemy_near"`, with a reach in hexes) |
| Spikes, Iron Maiden, Thorned King | taunt; a wall's `reflect_bp` (DAMAGE noted "reflected") | **thorns on a unit**: a share of each hit taken sent back to the attacker (an aura stat `thorns_bp`; DAMAGE noted "thorns", sourced to the passive), with "heals for half" as lifesteal on it, and a splash to enemies within 1 hex for Thorned King |
| Grinder | `on_interval`, `enemies_near_self` | none expected |
| Undertow | pulls | **a pull by a distance** (1 hex toward him, not beside) |
| Vengeance | `UnitState.taken_total` (8b-3c's grows-per-damage) | **stored damage**: a share of each hit stored instead of taken, growing a share a second, released as an area when Iron Maiden ends or he falls |

## 5. Tamsin Gloamstep (part 8d-3)

The design: `rebuild-heroes.md` 8c, `apexes.md` Tamsin, `upgrade-pools.md` Tamsin, the bonds Hold and Break (with Ironbrand) and The Hunter's Bell (with Aldous's Bellwarden); Price and Prey and Unseen Blade wait for Hob and Lucan.

- **Base kit:** Knife (fast); Shadowstep (50 mana: hidden 2s, slips behind her target); Ambusher (hidden for 2s at the start; attacks from Stealth always crit); targeting the lowest-HP enemy within 3 hexes, else the nearest.
- **Paths:** Nightblade (Fade, Shadow Dance), Headhunter (Scent, Sentence), Garrote (Choke, the Garrote hold).
- **Apexes:** Phantom, Veilmaster, Executioner, Bloodtrail, Strangler, Pinmaster.

| Piece | Built already | New |
| --- | --- | --- |
| Targeting | `nearest`, `weakest_backliner`, `prefer` | **`weakest_within`**: the lowest-HP (by %) enemy within N hexes, else the nearest |
| Shadowstep | Stealth (`until_attack` exists for Shadow Step the charm); leaps | **a leap behind the target** (`"to": "behind"`: the free spot past it, away from her) |
| Ambusher | `on_fight_start` statuses; crit chance auras; `"while": "state"` (Stealthed) | none expected (an aura of +100% crit chance while Stealthed) |
| Fade, Nightblade | `on_kill` apply Stealth to self; mana on kill; `until_attack` (boosts only today: the built Stealth doesn't end when its holder attacks) | **her Stealth ends when she attacks** (a Stealth status of her own with `until_attack`), **except for a number of attacks** (Shadow Dance's next 3; Phantom's always: `until_attack` after N) |
| Scent, Headhunter | `prefer` Marked; `extend_status` on hit | **a step to the next Marked enemy after a kill**, with an attack reset (a leap on `on_kill` to `enemy_near_named` Marked, `reset_attack` from Garrow's part) |
| Sentence | conditional damage, executes (`execute_below_pct`) | **fires again once if it kills** (a signature's `again_on_kill`) |
| Choke | `on_holder_crit` `vs` Rooted/Stunned, `extend_status` | none expected |
| Garrote | Root, damage over time, Stealth | **a hold**: she Roots her target, can't move, stays hidden, and hits it every 0.5s until it ends (a channelled signature: `holds_ms`, with ticks; logged as the ability's hits) |
| Bloodtrail, Veilmaster, Pinmaster | Marks, statuses on allies near, `vs` auras | none expected beyond the above |

## 6. Aldous Vesper (part 8d-4)

The design: `rebuild-heroes.md` 8e, `apexes.md` Aldous, `upgrade-pools.md` Aldous, the bonds Toll and Judgment (with Vigil Keeper) and The Hunter's Bell; Psalm and Chorus, Tonic and Hymn, and The Bellows wait for Edric, Ottilie, and Ilse.

- **Base kit:** Toll (MGK, his mana); Peal (60 mana: allies within 3 hexes +15% attack speed for 4s); Resonance (allies within 2 hexes +5% attack speed).
- **Paths:** Chorister (Shared Breath, Crescendo), Windcaller (Tailwind, Gale), Bellwarden (Toll the Hour, Death Knell).
- **Apexes:** Grand Chorus, Wellspring, Long Wind, Singing Arrows, The Great Bell, Requiem.

| Piece | Built already | New |
| --- | --- | --- |
| Peal, Resonance | timed boosts; `allies_near` auras | none |
| Shared Breath, Crescendo | `gain_mana` on allies near | **the ally with the least mana** as a target (`lowest_mana_ally`) |
| Chorister | | **a trigger on gaining mana** (`on_mana_gained`, carrying the amount, so allies near gain half) |
| Tailwind, Windcaller, Long Wind | `damage_bp` auras with `vs` | **a bonus by the attacker's distance to its target** (an aura's `"from_hexes"`; Long Wind's per-hex step) and **shot speed** (a stat for how fast a unit's shots fly) |
| Gale | knockbacks, areas | **an area round each ranged ally** (an area anchored on `allies_near_self` that are ranged) |
| Toll the Hour, Death Knell | `every` on on_fire; Marks; areas at the target | none expected |
| Wellspring | mana | **mana past full** (a holder's mana cap raised or lifted; a signature stronger per mana over full) |
| Grand Chorus, Singing Arrows, Requiem | `on_ally_ability`; `on_enemy_fell` with `vs` Marked; growing auras | **an ally's shot carrying an effect of his** (Singing Arrows: an `on_ally_hit` trigger for ranged allies' shots) |

**Across the three:** the Mirrorwight copies a hero signature only if its effects are all of the kinds it can turn (`Copies.COPYABLE`: damage, heals, Shields, statuses, areas of those), so the new signatures fall under that rule as they are: Peal (a boost), Death Knell (Marks), and Sentence (damage) would be copied; anything that gives mana, moves, hides, or holds (Crescendo, Haul, Maelstrom, Shadowstep, Garrote) wouldn't. Each part lists which. The rift learns' habits already count what the three do (Stealth, Marks, Roots, Shields, signatures).

Every new piece is skipped by a fight that doesn't use it, so the bench's fingerprints stay as they are; each gets a small-fight test, an audit rule and a board form if it adds a log kind, and a mutation check.

## 7. The bond relics

Five, from `duo-bonds.md`, as relics of tier `bond` (the built three's frame: a bond on once both paths transform, its relic 20% of the shops' draws): **Dragged to the Snare** (Chainwarden + Trapper: The Snaring Chain), **Woven Fang** (Aegisfang + Wardweaver: The Woven Fang), **Hold and Break** (Garrote + Ironbrand: Hammer and Wire), **The Hunter's Bell** (Bellwarden + Headhunter: Death's Appointment), **Toll and Judgment** (Bellwarden + Vigil Keeper: The Toll of Dawn). The built three stay. A bond whose second path belongs to a hero not yet built (The Firepit, Iron Hunger, and the rest) waits for that hero.

## 8. Tools, bots, and the first check

- **Formations:** the sim runner's named formations (`tools/sim_formations.json`) are written by role (tank, far, mid), filled from the team by `Placement.roles_of`, so any team can be fought; the gate keeps its teams (Brannoc, Maren, Vell for Act 1; the Gallery transformed for Acts 2 and 3) so its read doesn't move.
- **The reports:** `--paths`, `--deeds`, and `--apexes` cover every hero; `tools/apex_teams.json` gains teams with the new heroes (one per new bond, and one for each new hero's carry apex); the run report cycles teams and vows by seed (20 teams × 27 vow combinations; a run's team and vows are its seed's) and adds **By hero** (runs with each hero, won, its paths' transformations and apexes).
- **The bots:** `Bot.team` picks a team (the base and simple bots: Brannoc, Maren, Vell; the random bot at random; the good bot by practice fights over its candidates, as it judges other choices); `--team=a,b,c` fixes it for a report. The good bot's placement roles come from the kits, so they hold; its weights are refitted once with teams drawn from the six (Act 1, water, and void sets), and checked with `placement_check.gd`.
- **The first check** (not the tuning): on the paths report each new transformation lands in the built ones' band over all base (+16 to +21 points), each vowed taste fills its deed in about the built ones' number of fights (the deeds report, thresholds set as phase 5c's were), and each new apex's half point on the apex sweep sits within the built eighteen's spread. What doesn't is noted for the tuning phase; the acts aren't retuned here.

## 9. Parts

- **8d-1, the draft frame:** the run's team (start, the fight's team check), the start screen's draft, Practice's team row, every tool and report reading a team (section 3a's list), role formations, `--team`, and the tests; Garrow's base kit as the fourth hero, so the frame is tested on a real roster.
- **8d-2, Garrow:** his pieces (8d-2a, built), habits (8d-2h, section 3b; for every hero), then his paths, apexes, cards, figures, his two bond relics.
- **8d-3, Tamsin:** the same, and Hold and Break.
- **8d-4, Aldous:** the same, The Hunter's Bell and Toll and Judgment.
- **8d-5, the check and the docs:** the first check (section 8), the placement refit, the run report By hero, HOW-TO-PLAY, screenshots (the draft, a fight of each new hero), the design doc, and a playtest build.

### Built in 8d-1

- **Garrow's base kit** (`data/heroes.json`, the fourth hero; section 4's base): Chain Fist, Haul (the farthest enemy within 4 hexes dragged beside him, a pull `"to": "beside"` with signature `"targeting": "farthest"` and `"max_range"`), Stand Fast (a Shield of 15% of max HP the first time he drops below half: `on_below_hp`), and Heavy (`unpushable`: knockbacks and pulls are RESISTED). No new sim piece was needed. His placeholder figure (`tools/art/hero_kit.py`, `garrow_base.svg`). He has no paths yet, so he can't be drafted (`HeroTeam.ready`); Practice fields him at base.
- **`HeroTeam`** (`src/run/hero_team.gd`): `SIZE`, `DEFAULT` (Brannoc, Maren, Vell), `ready` and `draftable` (a hero with all three paths), `problem` (three different known heroes, ready unless `drafted` is false for Practice), `ordered` (heroes.json's order), `roles` (tank: the highest HP x (100 + DEF); far: the longer range of the other two; mid: the last; ties by heroes.json's order), `place` (a role formation for a team), and `GUARDED` (the tank in front of the other two). (Named `HeroTeam` since `EffectSource.Team` is the sides.)
- **The run:** `RunFlow.start` takes its team from the vows' keys and refuses a team `HeroTeam.problem` refuses (before the vows are checked); `state.heroes` is the team in heroes.json's order, so the save is unchanged. `fight_setup` refuses a hero who isn't on the team ("%s isn't on the team").
- **The screens:** `RunStartScreen` drafts on cards (name, title, role, the paths; Draft/Drafted; greyed with "Paths aren't built yet." for a hero who can't be drafted; a fourth draft sends back the first drafted; a hero drafted again keeps its last vow; Into the rift is greyed until three are drafted), and the vow rows are the drafted three's. `EncounterListScreen` has the team row (a toggle a hero, gold when on, three on; the place buttons greyed until three; a note names who fights at base). `PracticeSession.team` and `set_team` (the formation remembers every hero's last hex, so one back on the team stands where it stood; a hero with no hex yet starts on its role's), `RunSession` takes the run's team, and `HeroBar` and `HeroPanel.step` show and cycle the team. The hero panel says when a hero's paths aren't built.
- **The tools:** `tools/sim_formations.json` is by role (`tank`, `far`, `mid`), filled from a team by `SimReport.for_team`; `drawn_formations`, the tactics report, and the columns read the team (the gate's is still the old three). `run_bot.gd`'s `formation(name, team, content)` places by role, `team_of(flow)` reads the run's, and `first_vows(content, team)`. `run_report.gd`'s `vow_combinations` is every team of three draftable heroes times their vows (27 while three can be drafted, in the old order, so runs are unchanged); `play`/`play_many` take a `team`, and the picks line averages over the runs that had each hero. `run_runner.gd --team=a,b,c` fixes the team (passed to `--jobs` children with `--endless`). `placement_data.gd` and `placement_check.gd` draw a team (`Placement.draw_team`, only once more than three can be drafted, so the fits don't move now). `path_report.gd`'s deeds read the draftable heroes.
- **A call made while building:** the bots don't choose a team yet (section 8's `Bot.team`); a report's runs get theirs from the seed, as vows are, and `--team` fixes one. The good bot choosing by practice fights comes with 8d-5, once there are teams to choose between.
- **Tests:** `tests/run/test_hero_team.gd` (ready, problems, roles, the run's team and the outsider check, Practice's team and remembered hexes), `test_hero_kits.gd`'s Garrow tests, the draft (`test_run_screens.gd`) and the team row (`test_practice_flow.gd`); the vow error in `test_run_flow.gd` is now the team's. The bench's fingerprints are unchanged.

### Built in 8d-2a (Garrow's path pieces)

- A Shield's `cap_bp_of_max_hp` (it fills its target's Shield to at most that share of max HP; Plated Blows). With the cap on the effect, Vell's Weave already ignores it, so The Woven Fang's first line holds by itself (a call, flagged for 8d-2d).
- A damage effect's `amount_bp_of_shield` (a share of the unit's own Shield as it fires or casts) and the effect `spend_shield` (`"target": "self"`; a new effect type, since nothing else removes a Shield): Bulwark Burst. A new log kind, **SHIELD_SPENT** (source: the ability; target: the unit; amount: the Shield), with its audit rule and a board popup ("Spends N Shield").
- A signature's `resets_attack` (its FIRE line noted "and readies its attack"; the basic attack is ready at once): Maelstrom.
- An aura's `"per": "enemy_near"` with `"per_within_hexes"` (once per standing enemy that near; off while none is): Crowd Strength.
- Not needed after all: thorns are an `on_hit_taken` damage back at `hit_target` (Spikes), and Iron Maiden's 100% an `on_hit_taken` effect with a `"holder"` condition on its status, so no thorns stat.
- Tests: `tests/sim/test_garrow_pieces.gd`. The bench's fingerprints are unchanged.

Each part is tested as before: every piece in a small fight (`tests/sim/`), every kit's texts in small fights (`test_hero_kits.gd`), each card and relic changing what it says, the chaos fight using the new pieces, the save across versions, a run with each new hero, and mutation checks on each new rule.

## 10. Questions

- **CA. Unlocks:** *(Answered: Decision 4.)* are all six heroes open from the start? Proposed: yes for now; unlocking heroes (meta progression adds variety only: rule 5) comes with the Codex.
- **CB. The draft screen:** *(Answered: Decision 5.)* pick three on the vow screen itself (six cards, then the three vow rows), as proposed, or a separate screen before the vows?
- **CC. Practice:** *(Answered: Decision 6.)* a team row on the fight list (three of six), as proposed, or any number of heroes on the board?
- **CD. The first check:** *(Answered: Decision 7.)* bring each new path and apex into the built ones' bars now (section 8), so the tuning phase starts level, or leave all numbers to the tuning phase?

## Decisions

The playtester, 2026-10-06:

1. **Heroes 4 to 6 are Garrow, Tamsin, and Aldous**, in that order of building.
2. **They come in together, before the tuning phase**, which then tunes all six (and the acts) at once. This overrides `rebuild-heroes.md`'s "get the first three right before adding more".
3. **The team draft comes back with them:** a run picks three of the six.
4. **All six heroes are open from the start** (Question CA); unlocks come with the Codex.
5. **The draft is on the vow screen** (Question CB): six hero cards, pick three, then their vow rows.
6. **Practice picks three of six** on a team row on the fight list (Question CC).
7. **The first check is in this phase** (Question CD): each new path and apex is brought into the built ones' bars, so the tuning phase starts level.

