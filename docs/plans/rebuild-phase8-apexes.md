# Rebuild phase 8, part 2: apexes

Status: **agreed (2026-10-03, Decisions 1–6); nothing built.** Phase 8's second part, after endless (`rebuild-phase8-endless.md`). The design is `apexes.md` (agreed 2026-09-30); this plan builds it for the three heroes the game has (Maren, Brannoc, Vell: their 18 apexes). The other ten heroes' apexes wait for those heroes. **Numbers are `apexes.md`'s placeholders** until the bots measure them.

## 1. What it builds

- **The apex vow** opens after the Act 1 boss, for each hero who has transformed; a hero who transforms later gets it then. Each transformed path has two apexes. Vowing gives the apex's **taste** at once and starts a second deed bar; the vow can be switched for free until the apex is earned.
- **The apex:** when the apex deed fills, the hero transforms again: its kit is the path's transformed kit with the apex's patch (the full mechanic, a stat change where it fits, and usually one snowball that grows during the fight).
- **Apex upgrades:** each apex adds 2 cards to the hero's pick once earned (`upgrade-pools.md`): the first makes the snowball bigger, the second adds something new.
- **Where it plays today:** Act 2 doesn't exist yet, so apexes live in endless. The vow opens at the choice after the boss shop (going deeper), and the apex lands on the floors.
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
- **`sim_runner.gd --apexes`:** each apex against its path's transformed kit, on the formations the paths report uses: the win rate gained, the target band to tune toward (Question AY).
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
- **8b-4, the cards and the reports:** the 36 apex cards, `--apexes`, the endless report's apex lines, a first tuning pass to Question AY's band, docs, and a playtest build.

## 9. Questions

- **AV. When should an apex land?** The design says Act 2 or early Act 3; for now there are only endless floors. The good bot's runs reach a median floor of 4, so a bar sized for "Act 2" would rarely fill. Size the apex deeds so the apex lands around floor 2–3 (most runs that go deeper see it), or later?
- **AW. A hero who never transforms** in Act 1 never gets an apex vow (they get it when they transform on a floor). Keep it as written, or shrink a late transformer's apex deed?
- **AX. Rain of Ash** overlaps Ilse's Wildfire (both leave burning ground; `apexes.md`'s open question). Ilse isn't built yet: build Rain of Ash as written for now, or give Volley a new apex first?
- **AY. How much stronger should an apex be?** Each transformation is +16 to +21 over all base on the paths report (phase 4's band was 15–25). An apex over its transformed kit: the same band, or smaller?
- **AZ. The vow at the choice:** offer the apex vows on the choice stage (after Go deeper), or only from the hero panel?

## Decisions

The playtester, 2026-10-03:

1. **An apex lands around floor 2–3** (Question AV): the apex deeds are sized so most runs that go deeper earn one; they're resized when Act 2 exists.
2. **An apex is +25 to +35 over its path's transformed kit** (Question AY), on the `--apexes` report, bigger than a transformation's step (+15 to +25): apexes are the long run's big payoff.
3. **Volley gets a new apex in place of Rain of Ash** (Question AX), since Ilse's Wildfire owns burning ground. Its design is in section 10.
4. **A late transformer's apex deed is the same size** (Question AW): a hero who transforms on a floor gets the apex vow then, and simply earns it later.
5. **The vow is offered on the choice stage after Go deeper, and from the hero panel** (Question AZ, not asked; the plan's default, flagged for the playtester).
6. **Hailstorm replaces Rain of Ash** as drafted in section 10 (the playtester approved it, 2026-10-03).

## 10. Volley's new apex: Hailstorm (approved)

Rain of Ash is cut: burning ground is Ilse's (Wildfire). **Hailstorm** keeps Arrow Storm at the center of Volley's second apex (Windrunner is her mobility apex) and makes her a **Root maker**, which the build map lists as a gap (`build-map.md`: Root has one maker, Trapper), so it pairs with Huntmaster and the Root relics.

| Apex | Taste (on vow) | Deed | The apex | Upgrades |
| --- | --- | --- | --- | --- |
| **Hailstorm** (Volley) | Arrow Storm fires 1 more volley | Enemies hit by Arrow Storm | Arrow Storm covers a 3-hex circle, and every 4th shot she fires drops one Arrow Storm volley on her target. **Snowball:** each enemy Arrow Storm hits gives her +1% damage for the rest of the fight, with no cap | **Endless Hail:** +2% per enemy hit. **Pinning Hail:** Arrow Storm Roots each enemy it hits for 0.5s, once per cast |

It's built on pieces that exist (an area's size, an on_fire effect's `every`, stacking boosts for the fight, Root), so it needs no new sim piece.
