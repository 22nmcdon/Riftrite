# Rebuild phase 8, part 2: apexes

Status: **agreed (2026-10-03, Decisions 1–10; 7–10 replace 1 and 2); 8b-1 (the frame, with Hailstorm) and 8b-2 (Maren's and Vell's apexes) built.** Phase 8's second part, after endless (`rebuild-phase8-endless.md`). The design is `apexes.md` (agreed 2026-09-30); this plan builds it for the three heroes the game has (Maren, Brannoc, Vell: their 18 apexes). The other ten heroes' apexes wait for those heroes. **Numbers are `apexes.md`'s placeholders** until the bots measure them.

## 1. What it builds

- **The apex vow** opens after the Act 1 boss, for each hero who has transformed; a hero who transforms later gets it then. Each transformed path has two apexes. Vowing gives the apex's **taste** at once and starts a second deed bar; the vow can be switched for free until the apex is earned.
- **The apex:** when the apex deed fills, the hero transforms again: its kit is the path's transformed kit with the apex's patch (the full mechanic, a stat change where it fits, and usually one snowball that grows during the fight).
- **Apex upgrades:** each apex adds 2 cards to the hero's pick once earned (`upgrade-pools.md`): the first makes the snowball bigger, the second adds something new.
- **When it lands:** an apex is the team's peak and takes longer than a transformation: the vow opens after the Act 1 boss, and the deed is sized so an average run earns it after the Act 2 boss (Decision 7).
- **Where it plays today:** Act 2 doesn't exist yet, so apexes live in endless. The vow opens at the choice after the boss shop (going deeper), and the apex lands on the floors: until Act 2 exists, the deeds are a shorter stand-in, landing around floor 3–4 (Decision 8).
- **Practice:** a fourth stage on the hero panel's path track (Base, Vowed, Transformed, Apex), with both of the path's apexes to try.

## 2. Data

- **`paths.json`:** each path gets `"apexes"`: two entries, each with `id`, `name`, `title`, `fantasy`, `vowed` (the taste: a patch over the transformed kit), `apex` (a patch over the transformed kit), and `deed` (as a path's: `text`, `counts`, its filters, `threshold`). `ContentDb` builds each apex's two kits at load, as it does a path's (`ApexDef`, beside `PathDef`).
- **`upgrades.json`:** the 36 apex cards, `"layer": "apex"`, each naming its apex (`"apex": "eagle_eye"`), offered only once that apex is earned (`RunContent.upgrades_for`).
- **Deeds:** apex deeds are counted like path deeds (every hero counts the deeds of all its apexes, whatever its stage), with the counts the apexes need added to `DeedDef` where they're new (kills by an ability, executions, enemy-seconds inside an area, damage a wall blocked, damage shared through links, healing given to guarded allies).

## 3. The sim pieces

Each piece is skipped by a unit that doesn't use it, like phase 4's, so no built fight changes (the bench's fingerprints and the chaos fight stay the same until a fixture uses them). From `apexes.md`'s 18 apexes:

| Piece | For | What it is |
| --- | --- | --- |
| **Execute** | Eagle Eye, Inquisitor | a damage effect's `execute_below_bp`: a hit that leaves the target below that share of max HP finishes it (logged as an execution: DAMAGE noted "executed") |
| **Kills by an ability** | Eagle Eye, Inquisitor | `on_kill`'s `from_ability` (as `on_heal`'s), so an execution can refund mana or grow a stack |
| **Growth per enemy passed** | Stormline | a piercing shot's `per_pierce_bp`: each enemy it passes through adds to its damage |
| **Walls that block movement, with HP** | Warden of Thorns, The Unbroken Gate | a wall's `blocks_movement` (the nav grid treats it as rock while it stands) and `hp_bp_of_max_hp` (it stands until broken, its hits logged); briars as short walls placed where a snare springs, up to `max_standing` |
| **A snare where an enemy fell** | Huntmaster | `on_enemy_fell` with a filter (rooted) and a `place_snare` effect at the fallen's spot |
| **A trigger on a wall's block** | The Unbroken Gate | `on_wall_block`: a shot a wall stopped (WALL lines noted "blocked") |
| **Effects scaled by a value** | Thornweave, Hearthkeeper, Martyr's Pyre | an effect's `amount_bp_of_event` (a broken Shield's value, the damage Guard took) and `grows_per` a fight tally (Martyr's Pyre: +10% per 1,000 damage taken) |
| **Overheal into max HP** | The Hearthkeeper | an aura stat `overheal_max_hp_per` (+1 max HP per N overheal, for the fight; logged) |
| **Explode at N stacks** | Forgebreaker | `on_status` with `at_stacks`: at 5 brands, the brands are spent and the effect fires (its hits brand, so blasts chain within the chain guard) |
| **Rising after a fall** | Undying Oath | RISE (built for Second Dawn) as a kit's `rises` (count, delay, HP share), with Second Dawn's rise counting toward the 3 |
| **Growth per cast** | The Beacon, Warlord | a signature's `grows_bp` per cast (the next lantern or rally is stronger, for the fight) |
| **Linked Shields** | Loomwarden | every ally with the holder's Shield is linked; damage to one is split evenly between them (logged as SHARED lines, sourced to the link); the deed counts what's shared |
| **Lasting ground** | Sanctifier | a zone whose duration is the fight, up to `max_standing` (zones and `max_standing` exist; the piece is the fight-long duration) |

Most of the rest is data on built pieces: stacking boosts for the fight (Windrunner, Warlord, Inquisitor, Undying Oath, Dawnbringer, Thornweave's next Shields), `vs` auras and `prefer` (Huntmaster), an area's size and every Nth shot (Hailstorm), Bleed, Burn, Slow, Mark, Stealth, taunts, and the hop.

## 4. The run

- **`RunState.Hero`:** `apex` (the vowed apex id, "" before), `apex_earned` (bool), and the apex deeds in `deeds` beside the path deeds. Save version 6 (version 5 still loads, with no apex).
- **`RunFlow`:** `vow_apex(hero, apex_id)` (allowed once the apex vow is open, the hero is transformed, and its apex isn't earned; switching is free), and the apex transformation in `record` when the deed fills (`state.just_transformed` gains the hero, as a path's does).
- **When the vow opens:** at the choice after the act's boss shop (`go_deeper`), and on any later floor a hero transforms. Ending the run there doesn't open it.
- **A fight's kit:** a hero with an apex vow fights with the apex's taste kit; once earned, with the apex kit; mods and wounds go on after, as now.
- **The pick:** an earned apex adds its 2 cards to the hero's offers (a layer after the path's).

## 5. The UI

- **The choice stage** (after the boss shop): Go deeper leads to the apex vows: each transformed hero's two apex cards (taste, deed, the apex), Vow on one, and Skip (a hero can vow later from the hero panel).
- **The hero panel:** the path track gains the Apex stage and the apex deed's bar; the Path tab shows the two apex cards with Vow or Switch.
- **The hero bar:** the apex deed's progress replaces the path deed's once the hero is transformed.
- **Practice:** the Apex stage, with both apexes, free to try.
- **Figures:** the apex form stands as the transformed figure with a mark (the gold ring doubled) until phase 7's art; `asset-contract.md` names the files (`maren_eagle_eye`).
- **Every new log line** (executions, SHARED, wall blocks, rises from a kit) gets its board form and its audit rule.

## 6. The bots and the reports

- **The bots** vow an apex at the choice: the simple bot takes the first; the random bot one at random; the good bot judges each by practice fights, as it judges picks.
- **`sim_runner.gd --apexes`** (Decisions 9 and 10): a sweep over enemy strength (Act 1's encounters with their enemies' HP and ATK ×1.0, ×1.1, ×1.2, and on), on the formations the paths report uses, finding each team's win rate at each step. It compares the all-transformed team with apex teams: the good combinations (a carry apex and its setup), each single apex with the others transformed, and the poor combinations. Per team: where it wins 50%, and for the transformed team where it first wins about 0%; per carry apex, its share of its team's damage. The target is Decision 9's curve.
- **`run_runner.gd --endless`:** when each apex is earned (the floor), and the floors reached with and without one.

## 7. Tests

- `tests/sim/test_apex_pieces.gd`: each new piece, one rule at a time, and that a fight without it is unchanged.
- `tests/sim/test_apex_kits.gd`: each apex's text in a small fight (its taste and the apex), as `test_path_kits.gd` does for paths.
- `tests/run/test_apexes.gd`: the vow opens at the choice (not on ending), only for transformed heroes, later for a late transformer; switching is free until earned; the apex deed fills and transforms; apex cards are offered only once earned; the save round-trips (and a version 5 save loads).
- `tests/ui/`: the apex vow stage, the panel's fourth stage, Practice's Apex stage.
- The chaos fight gains an apex unit so `test_determinism` and the log audit cover the new pieces.

## 8. Parts

- **8b-1, the frame:** `ApexDef`, the data shape, the run's vow and deed and transformation, the save, the bots' answer, the vow screen and the panel's stage, Practice's stage; with Maren's apexes on built pieces where they can be (Windrunner, Hailstorm, Huntmaster's aura half) to prove it.
- **8b-2, the pieces for Maren and Vell:** execute, kills by an ability, growth per enemy passed, growth per cast, lasting ground, effects scaled by a value, linked Shields; the rest of their apexes.
- **8b-3, the pieces for Brannoc:** walls that block movement with HP, the wall's block trigger, explode at N stacks, rising from the kit, overheal into max HP, the snare where an enemy fell; Brannoc's six and Warden of Thorns, Huntmaster's snares.
- **8b-4, the cards and the reports:** the 36 apex cards, `--apexes` (the sweep over enemy strength), the endless report's apex lines, a first tuning pass to Decision 9's curve (the gap it comes to is reported before tuning to it), the stand-in deed sizes (Decision 8), docs, and a playtest build.

## 9. Questions

- **AV. When should an apex land?** *(Answered: Decision 1, then Decisions 7 and 8.)* The design says Act 2 or early Act 3; for now there are only endless floors. The good bot's runs reach a median floor of 4, so a bar sized for "Act 2" would rarely fill. Size the apex deeds so the apex lands around floor 2–3 (most runs that go deeper see it), or later?
- **AW. A hero who never transforms** in Act 1 never gets an apex vow (they get it when they transform on a floor). Keep it as written, or shrink a late transformer's apex deed?
- **AX. Rain of Ash** overlaps Ilse's Wildfire (both leave burning ground; `apexes.md`'s open question). Ilse isn't built yet: build Rain of Ash as written for now, or give Volley a new apex first?
- **AY. How much stronger should an apex be?** *(Answered: Decision 2, then Decisions 9 and 10.)* Each transformation is +16 to +21 over all base on the paths report (phase 4's band was 15–25). An apex over its transformed kit: the same band, or smaller?
- **AZ. The vow at the choice:** offer the apex vows on the choice stage (after Go deeper), or only from the hero panel?

## Decisions

The playtester, 2026-10-03:

1. *(Replaced by Decisions 7 and 8.)* **An apex lands around floor 2–3** (Question AV): the apex deeds are sized so most runs that go deeper earn one; they're resized when Act 2 exists.
2. *(Replaced by Decisions 9 and 10.)* **An apex is +25 to +35 over its path's transformed kit** (Question AY), on the `--apexes` report, bigger than a transformation's step (+15 to +25): apexes are the long run's big payoff.
3. **Volley gets a new apex in place of Rain of Ash** (Question AX), since Ilse's Wildfire owns burning ground. Its design is in section 10.
4. **A late transformer's apex deed is the same size** (Question AW): a hero who transforms on a floor gets the apex vow then, and simply earns it later.
5. **The vow is offered on the choice stage after Go deeper, and from the hero panel** (Question AZ, not asked; the plan's default, flagged for the playtester).
6. **Hailstorm replaces Rain of Ash** as drafted in section 10 (the playtester approved it, 2026-10-03).

The playtester, 2026-10-03, after 8b-2 (these replace Decisions 1 and 2):

7. **An apex lands after the Act 2 boss on an average run** (replaces Decision 1). Apexes are the team's peak and take longer than the first transformations (day 3–4 of Act 1): the vow still opens after the Act 1 boss, and the deed is sized to fill over about an act, so Act 2's boss is fought on tastes and Act 3 is the apex act.
8. **Until Act 2 exists, a stand-in deed size** (option b, to help with testing): the apex deeds are sized so a run that goes deeper earns its apex around floor 3–4 (the good bot's median deep run reaches floor 4), and marked as temporary. They're resized to Decision 7 when Act 2 is built.
9. **How strong: a shift in the difficulty a team can beat** (replaces Decision 2's +25 to +35). Measured as enemy strength (Act 1's encounters with their HP and ATK scaled up step by step, as endless floors scale them): a fight the all-transformed team wins about 50% of, the apex team wins about 100%; and at the first strength where the transformed team wins about 0%, the apex team wins about 50%. Measured against today's unscaled encounters there'd be no room (a transformed team already wins about 70%), so the report sweeps. What that gap comes to (in enemy strength, or endless floors at ×1.15 each) is reported before tuning to it. Apexes that grow without a cap grow more in harder, longer fights; that's the snowball, and the sweep measures it where it shows.
10. **Apexes have roles; every hero has 1–2 that can carry** (Question 3 of 2026-10-03). Some apexes carry, some support, some tank, some control; each hero has at least one or two that can be the team's carry with the right setup. Decision 9's curve is for a **good combination**: all three heroes at apex, with a carry apex and apexes that fit it (the bonded paths of `test-teams.md` first). A carry apex, in its best team, deals the biggest share of that team's damage; a support, tank, or control apex is judged by how much it lifts a carry's team over the same team with that hero only transformed. **Poor combinations have no target:** they should still beat the transformed team, by less, and the report lists them so it shows whether the combination matters. No single apex reaches the whole curve alone (The Beacon's first read nearly did). The roles, first draft: **Maren:** Eagle Eye, Stormline, Hailstorm, Windrunner carry; Warden of Thorns control; Huntmaster support. **Brannoc:** Forgebreaker carry, Undying Oath carry (a bruiser who grows with each rise); The Unbroken Gate and The Hearthkeeper tank; Warlord and Martyr's Pyre support. **Vell:** Inquisitor and Sanctifier carry; Loomwarden tank; The Beacon control; Dawnbringer and Thornweave support.

## 10. Volley's new apex: Hailstorm (approved)

Rain of Ash is cut: burning ground is Ilse's (Wildfire). **Hailstorm** keeps Arrow Storm at the center of Volley's second apex (Windrunner is her mobility apex) and makes her a **Root maker**, which the build map lists as a gap (`build-map.md`: Root has one maker, Trapper), so it pairs with Huntmaster and the Root relics.

| Apex | Taste (on vow) | Deed | The apex | Upgrades |
| --- | --- | --- | --- | --- |
| **Hailstorm** (Volley) | Arrow Storm fires 1 more volley | Enemies hit by Arrow Storm | Arrow Storm covers a 3-hex circle, and every 4th shot she fires drops one Arrow Storm volley on her target. **Snowball:** each enemy Arrow Storm hits gives her +1% damage for the rest of the fight, with no cap | **Endless Hail:** +2% per enemy hit. **Pinning Hail:** Arrow Storm Roots each enemy it hits for 0.5s, once per cast |

It's built on pieces that exist (an area's size, an on_fire effect's `every`, stacking boosts for the fight, Root), so it needs no new sim piece.

## Built in 8b-1: the frame (2026-10-03)

- **Data:** a path's `"apexes"` (`ApexDef`: id, name, title, fantasy, the taste's text and patch, the apex's text and patch, a deed); both patches go on the path's transformed kit, and ContentDb builds and checks the two kits (`_check_apex`), keeps `apexes` and `apex_ids` (their ids may not be a path's: a hero's deeds are keyed by both), and allows two per path (`PathDef.APEXES_PER_PATH`). `PathDef.Stage` gains `APEX_VOWED` and `APEX` (`is_apex`, `apex_kits`; `kit(stage, base, apex_id)`).
- **The sim:** `Encounters.setup` takes `apex_vows` and `apexed` (a transformed hero only, its own path's apex), sets `UnitSetup.apex` and the stage, and gives a transformed hero its path's apexes' deeds (`deed_apexes`, counted by `Deeds.make_counter` after the paths'); `FightSetup.validate` refuses an apex stage without its path's apex and an apex off its stage. No built fight changed (the bench's fingerprints match the commit before).
- **The run:** `RunState` (save version 6; a 5 or 4 still loads, with no apex): `Hero.apex`, `apex_earned`, `apex_open`, `just_apexed`. Going deeper opens the apex vow (`_open_apex`: a transformed hero's path's apexes' deeds start counting; a hero who transforms later gets them then; ending the run opens nothing). `apex_waiting()`, `vow_apex()` (free to switch until earned), the apex earned in `record` when the vowed apex's deed fills, `RunContent.hero_kit` the apex's kit, and `fight_setup` passes the vow. Hero, path, and taste cards, relics, items, and camp's and events' mods are checked against apex kits too.
- **The bots:** `Bot.apex` (the first; the random bot one at random; the good bot by practice fights), answered by `RunPlayer` and the simple bot as soon as a hero waits.
- **The screens:** the day's "The apex vow is open" section (each waiting hero's apexes, Vow to one) and "<hero> reaches the apex" after the fight; the hero panel's apex cards (Practice: Vow apex, Reach apex; a run: Vow apex or Switch apex, `apex_editable` while the vow is open), its track's apex step, the apex form's name, and No apex; the hero bar's apex deed and name; the board's tag ("Volley (Hailstorm vow)", "Hailstorm"). An apex stands as its path's figure until phase 7's art (the plan's doubled ring wasn't needed: the tag names it).
- **Hailstorm** (section 10), on two small pieces: `on_holder_hit`'s `"from_ability"` (the hit's ability rides along with the event, as `on_heal`'s does) and the deed count `hits` (its hits on enemies, one each). Its numbers are placeholders: a transformed Volley puts 30 to 130 Arrow Storm hits a fight into its deed (more with the taste in 19 of 20 encounters), against a threshold of 120 (two fights or so, floor 2–3; Decision 1), to tune in 8b-4.
- **Tests:** `tests/sim/test_apex_kits.gd` (the kits, the setup and its refusals, Hailstorm in a fight, the taste, the hits count), `tests/run/test_apexes.gd` (the vow's opening, switching, earning, a late transformer, the save), apexes in `test_paths_ui.gd` (Practice and the panel), `test_run_screens.gd` (the vow after going deeper, the apex reached), `test_bots.gd` (the bot vows), and `test_path_kits.gd` (apex kits' texts name their reaches).

## Built in 8b-2: Maren's and Vell's apexes (2026-10-03)

- **The pieces** (each skipped by a unit that doesn't use it; the bench's fingerprints match the commit before):
  - an **execution**: a damage effect's `execute_below_pct` finishes a target the hit leaves below that share (DAMAGE noted "executed"); `on_kill`'s `executed` and `from_ability`, and a `kills` deed by `from_ability`;
  - an area's **`per_enemy_bp`**: each enemy a line passes, nearest first, makes it hit the next one harder (Stormline);
  - the **hop** as an effect (a new effect type: only the `hop_away` trait could hop), a patch's `hop_cooldown_ms`, and a deed's `within_ms_of_hop` (read from the log's hops in order, so a hop in the same tick as a hit counts as the log has them);
  - **`on_ally_shield_broken`** (a new trigger: any ally's Shield broken by a hit or damage over time; the breaker is the event's unit);
  - a zone's **`max_standing`**: once that many of a unit's zones from the ability stand, a new cast lays no more ground (it doesn't replace the oldest; a small call, to revisit if Sanctifier plays badly);
  - a signature's **`grows_bp`**: each cast is that much stronger than the last, for the fight (as power on its effects);
  - an `applied` deed's **`statuses`** filter (statuses on allies count too, so Dawnbringer counts its hastes), and the deed count **`shared`**;
  - **links** (`PartDef.Kind.LINK`, `Links`, a new log kind SHARED sourced to the link): every ally holding a Shield the holder gave (`UnitState.woven_by`) is linked; a hit on one gives `share_pct` of it, split evenly and rounded up, to the others (each part no more than an even split of the hit), as SHARED lines; every `per_shared` shared gives each linked ally a stack of the link's status.
- **The apexes** (numbers and thresholds are placeholders, to tune in 8b-4): Eagle Eye, Stormline, Windrunner (Maren); The Beacon, Dawnbringer, Loomwarden, Thornweave, Inquisitor, Sanctifier (Vell). Calls made while building: Inquisitor's +30% against Marked is on all her damage, not only smites (a `damage_bp` aura with `vs`); Eagle Eye's mana refill comes only from executions; Dawnbringer's and The Beacon's deeds count the statuses they apply. A first look on bare heroes: The Beacon is far too strong (17 of 18 test fights won against 8), Inquisitor's deed fills slowly (0.2 smite kills a fight), and several apexes add little; 8b-4 tunes all of them to Decision 9's curve.
- **Tests:** `tests/sim/test_apex_pieces.gd` (each piece in a fight), the new statuses in `test_content_db.gd` and `test_determinism.gd`'s apex statuses, SHARED in `test_arena_log.gd`'s audit and `test_every_encounter_plays.gd`'s table, and `test_tallies.gd` (a kills count may name its ability now).

## Built in 8b-3: Brannoc's apexes, and the Trapper's (2026-10-03)

- **The pieces** (each skipped by a unit that doesn't use it; the bench's fingerprints match the commit before):
  - **Walls that block movement, with HP** (`Walls`): a wall's `blocks_movement` is a row of barrier circles its enemies treat as rocks (walking, sliding, landing, pushes, and being walled off; circles that would overlap one of them as it rises are left out, so no one is trapped inside); `hp_bp_of_max_hp` (of its unit's max HP), worn down by the shots it stops (their damage) and by enemies with no way round that have it in reach (they strike it with their basic attack instead of waiting); `until_broken`; `max_standing` (a newer wall takes down the oldest); `at: "target"` (ahead of the target, across its way: a snare's wall rises where the snare springs); and its own effects, each second, on enemies touching it. A new log kind, WALL_HIT ("shot", "struck", ", broken", or "gone"), and a stopped shot's SHOT_FIZZLED names the wall's unit (`wall_of`).
  - **The trigger `on_wall_block`** (a shot its wall stops or a strike it takes) and the deed count **`blocked`** (shots its walls stop).
  - **Spent at so many stacks** (`on_status`'s `at_stacks`): once the unit it went on has that many, they're spent (the status ends) and the effect runs. Events are read after the units act, so a unit can gather a stack or two past the count in one tick; all of them are spent.
  - **Boosts that grow with each cast**: a signature's growth now also strengthens the boosts it gives (`StatusState.boost_strength_bp`), and `grows_boosts_bp` grows only those (Warlord's rally; the slam's own damage stays). The Beacon's Dazzled grows with its lanterns too.
  - **Rising from a kit** (a new passive kind, `rise`: times, after_ms, hp_pct, and a stacking boost kept through its rises). A unit with one never takes Second Dawn's rise (that counts toward its own), and while its rise is due its side isn't down (Second Dawn's rise doesn't hold the fight, as before).
  - **Power that grows with damage taken** (`grows_per_damage_taken`, from `UnitState.taken_total`), **overheal into max HP** (a heal's `overheal_max_hp_per`; a new log kind, MAX_HP_UP), and `on_guard` carrying the share taken (for `amount_bp_of_damage`).
  - **A snare where the named unit stands** (`"at": "named"`, on an event that names one: Huntmaster's, where a Rooted enemy fell), and the damage deed's filters **`vs_keywords`** and **`by_allies`** (its allies' hits count too).
- **The apexes** (all 18 are now data; numbers and thresholds are placeholders for 8b-4): The Unbroken Gate, The Hearthkeeper, Forgebreaker, Warlord, Undying Oath, Martyr's Pyre (Brannoc); Warden of Thorns, Huntmaster (Maren). Calls made while building:
  - The Unbroken Gate keeps the taste's extra hex (4 wide), so earning it is never a step back; a new wall replaces the old; he holds still for 4s after raising it, not while it stands. Enemies don't attack a wall unless they have no way round it.
  - Warden of Thorns' briars rise 1 hex ahead of the snared enemy, across its way; touching one tears (Briar-Torn, a Bleed-like status of its own, so the deed can count it).
  - Undying Oath's taste rises once at 5% HP and fights (the design's "can't attack, but still engages and taunts" needs a piece of its own; not built).
  - Huntmaster's "and target them first" isn't built (a side-wide targeting preference is a new piece); its deed counts the whole team's hits on Rooted enemies.
  - Warlord's rally grows a quarter of itself each slam (+5 points on +20%, as designed), and the slam's damage doesn't grow.
  - The Hearthkeeper's overheal almost never happens in a plain fight (a guarded ally has just been hit, so a quarter of Brannoc's share rarely overfills them); it needs Shields that take whole hits, or healthy allies. A tuning question for 8b-4.
- **Tests:** `tests/sim/test_apex_pieces.gd` (the walls, the Gate's toughening and deed, briars, brands and chained blasts, the growing rally, rises with Second Dawn on, the growing burst, Hearthkeeper's heals and max HP, Huntmaster's snares and team deed), the new statuses in `test_content_db.gd` and `test_determinism.gd`, WALL_HIT and MAX_HP_UP in `test_arena_log.gd`'s audit and `test_every_encounter_plays.gd`'s table.
