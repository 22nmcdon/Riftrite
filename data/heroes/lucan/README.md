# Lucan Merrow, the illusionist

`lucan` · role: damage. Everything the game reads about this hero lives in this folder (`src/sim/content/data_layout.gd` names the files); the code that runs it is the shared sim, not hero-specific.

## Files

| File | What it holds |
| --- | --- |
| `hero.json` | The base kit: stats, the basic attack (Glimmer), the signature (Mirror), passives (Unreal). |
| `paths.json` | The three paths: each one's vowed taste and cost, its transformation, its deed and threshold, and its two apexes. |
| `upgrades.json` | The after-fight cards: 12 of the hero's own, 6 taste cards, 15 path cards, and 12 apex cards. |
| `statuses.json` | The 11 statuses only this hero's content sets: sure_strike, dance, glimmer_dazzle, unseen_host, knife_in_the_dark, veil_confused, grand_dance, puppet_thread, marionette, puppet_cut, puppet_master. |

## Paths

| Path | Title | Apexes |
| --- | --- | --- |
| Mirrorwright (`mirrorwright`) | the one who is never only one | Thousand Faces (`thousand_faces`), True Reflection (`true_reflection`) |
| Veilweaver (`veilweaver`) | the one who hides the threatened | Unseen Host (`unseen_host`), Night Veil (`night_veil`) |
| Puppeteer (`puppeteer`) | the one who holds every string | Grand Puppeteer (`grand_puppeteer`), Marionette (`marionette`) |

## Duo bonds

- **Unseen Blade** (`unseen_blade`: nightblade + veilweaver), whose bond relic is The Shroud of Knives (`run/relics/bond.json`).
- **The Menagerie** (`the_menagerie`: puppeteer + packleader), whose bond relic is The Menagerie (`run/relics/bond.json`).
- **Hall of Arrows** (`hall_of_arrows`: mirrorwright + volley), whose bond relic is Mirror Step (`run/relics/bond.json`).

## Where else to look

- Its tests: `tests/heroes/lucan/`.
- Its figures: `art/figures/heroes/lucan/` (one per form).
- Its design: `docs/plans/design/rebuild-heroes.md`, `upgrade-pools.md`, and `apexes.md`; how it was built and tuned: the phase plan named in `CLAUDE.md`'s table.
