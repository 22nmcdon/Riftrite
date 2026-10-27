# Kestra Fenn, the beastwarden

`kestra` · role: damage. Everything the game reads about this hero lives in this folder (`src/sim/content/data_layout.gd` names the files); the code that runs it is the shared sim, not hero-specific.

## Files

| File | What it holds |
| --- | --- |
| `hero.json` | The base kit: stats, the basic attack (Spear Jab), the signature (Sic 'Em), passives (Bond), companions (grit). |
| `paths.json` | The three paths: each one's vowed taste and cost, its transformation, its deed and threshold, and its two apexes. |
| `upgrades.json` | The after-fight cards: 12 of the hero's own, 6 taste cards, 15 path cards, and 12 apex cards. |
| `statuses.json` | The 11 statuses only this hero's content sets: pack_fury, howl, numbed, hellhound, inferno_hound, viper_slow, viper_queen, queens_venom, alpha_fury, alpha_blood, pack_blood. |

## Paths

| Path | Title | Apexes |
| --- | --- | --- |
| Cinderhound (`cinderhound`) | the one whose hound runs hot | Hellhound (`hellhound`), Firestarter (`firestarter`) |
| Serpent-Keeper (`serpent_keeper`) | the one the rift's vipers answer to | Brood Mother (`brood_mother`), Viper Queen (`viper_queen`) |
| Packleader (`packleader`) | the one who runs the pack | Alpha (`alpha`), Wild Hunt (`wild_hunt`) |

## Duo bonds

- **Gilded Ash** (`gilded_ash`: transmuter + cinderhound), whose bond relic is The Gilded Hound (`run/relics/bond.json`).
- **Nest of Rot** (`nest_of_rot`: plaguebearer + serpent_keeper), whose bond relic is Mother of Serpents (`run/relics/bond.json`).
- **The Menagerie** (`the_menagerie`: puppeteer + packleader), whose bond relic is The Menagerie (`run/relics/bond.json`).

## Where else to look

- Its tests: `tests/heroes/kestra/`.
- Its figures: `art/figures/heroes/kestra/` (one per form).
- Its design: `docs/plans/design/rebuild-heroes.md`, `upgrade-pools.md`, and `apexes.md`; how it was built and tuned: the phase plan named in `CLAUDE.md`'s table.
