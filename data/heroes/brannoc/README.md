# Brannoc of the Hearthwatch, the warden

`brannoc` · role: tank. Everything the game reads about this hero lives in this folder (`src/sim/content/data_layout.gd` names the files); the code that runs it is the shared sim, not hero-specific.

## Files

| File | What it holds |
| --- | --- |
| `hero.json` | The base kit: stats, the basic attack (Shield Bash), the signature (Hold the Line), passives (Hold the Line, Hearthguard). |
| `paths.json` | The three paths: each one's vowed taste and cost, its transformation, its deed and threshold, and its two apexes. |
| `upgrades.json` | The after-fight cards: 12 of the hero's own, 6 taste cards, 15 path cards, and 12 apex cards. |
| `statuses.json` | The 5 statuses only this hero's content sets: scarred, gatekeeper, war_call, rally, shield_wall. |

## Paths

| Path | Title | Apexes |
| --- | --- | --- |
| Hearthwall (`hearthwall`) | the protector | The Unbroken Gate (`unbroken_gate`), The Hearthkeeper (`hearthkeeper`) |
| Ironbrand (`ironbrand`) | the bruiser | Forgebreaker (`forgebreaker`), Warlord (`warlord`) |
| Last Watch (`last_watch`) | the martyr | Undying Oath (`undying_oath`), Martyr's Pyre (`martyrs_pyre`) |

## Duo bonds

- **Sentry and Sniper** (`sentry_and_sniper`: hearthwall + deadeye), whose bond relic is The Watchtower Stone (`run/relics/bond.json`).
- **Snare and Cleave** (`snare_and_cleave`: ironbrand + trapper), whose bond relic is The Hunter's Anvil (`run/relics/bond.json`).
- **Light and Iron** (`light_and_iron`: wardweaver + hearthwall), whose bond relic is The Hearth-Woven Mail (`run/relics/bond.json`).
- **Hold and Break** (`hold_and_break`: garrote + ironbrand), whose bond relic is Hammer and Wire (`run/relics/bond.json`).
- **Watched Over** (`watched_over`: aegis + last_watch), whose bond relic is The Last Ward (`run/relics/bond.json`).
- **Lantern Vigil** (`lantern_vigil`: last_watch + lanternbearer), whose bond relic is The Vigil Lamp (`run/relics/bond.json`).

## Where else to look

- Its tests: `tests/heroes/brannoc/`.
- Its figures: `art/figures/heroes/brannoc/` (one per form).
- Its design: `docs/plans/design/rebuild-heroes.md`, `upgrade-pools.md`, and `apexes.md`; how it was built and tuned: the phase plan named in `CLAUDE.md`'s table.
