# Maren Thistledown, the ranger

`maren` · role: damage. Everything the game reads about this hero lives in this folder (`src/sim/content/data_layout.gd` names the files); the code that runs it is the shared sim, not hero-specific.

## Files

| File | What it holds |
| --- | --- |
| `hero.json` | The base kit: stats, the basic attack (Longshot), the signature (Marking Shot), passives (Slip Away). |
| `paths.json` | The three paths: each one's vowed taste and cost, its transformation, its deed and threshold, and its two apexes. |
| `upgrades.json` | The after-fight cards: 12 of the hero's own, 6 taste cards, 15 path cards, and 12 apex cards. |
| `statuses.json` | The 2 statuses only this hero's content sets: first_blood, hailstorm. |

## Paths

| Path | Title | Apexes |
| --- | --- | --- |
| Deadeye (`deadeye`) | the sniper | Eagle Eye (`eagle_eye`), Stormline (`stormline`) |
| Trapper (`trapper`) | the snarer | Warden of Thorns (`warden_of_thorns`), Huntmaster (`huntmaster`) |
| Volley (`volley`) | the storm of arrows | Hailstorm (`hailstorm`), Windrunner (`windrunner`) |

## Duo bonds

- **Sentry and Sniper** (`sentry_and_sniper`: hearthwall + deadeye), whose bond relic is The Watchtower Stone (`run/relics/bond.json`).
- **Snare and Cleave** (`snare_and_cleave`: ironbrand + trapper), whose bond relic is The Hunter's Anvil (`run/relics/bond.json`).
- **Dragged to the Snare** (`dragged_to_the_snare`: chainwarden + trapper), whose bond relic is The Snaring Chain (`run/relics/bond.json`).
- **Burning Volley** (`burning_volley`: ember_choir + volley), whose bond relic is Fire on the Wind (`run/relics/bond.json`).
- **Hall of Arrows** (`hall_of_arrows`: mirrorwright + volley), whose bond relic is Mirror Step (`run/relics/bond.json`).

## Where else to look

- Its tests: `tests/heroes/maren/`.
- Its figures: `art/figures/heroes/maren/` (one per form).
- Its design: `docs/plans/design/rebuild-heroes.md`, `upgrade-pools.md`, and `apexes.md`; how it was built and tuned: the phase plan named in `CLAUDE.md`'s table.
