# Edric Tithewell, the tithe-warden

`edric` · role: support. Everything the game reads about this hero lives in this folder (`src/sim/content/data_layout.gd` names the files); the code that runs it is the shared sim, not hero-specific.

## Files

| File | What it holds |
| --- | --- |
| `hero.json` | The base kit: stats, the basic attack (Seal), the signature (Ward), passives (Vigil). |
| `paths.json` | The three paths: each one's vowed taste and cost, its transformation, its deed and threshold, and its two apexes. |
| `upgrades.json` | The after-fight cards: 12 of the hero's own, 6 taste cards, 15 path cards, and 12 apex cards. |
| `statuses.json` | The 6 statuses only this hero's content sets: collection, sanctified, bright_offering, hallowed_ground, bastion, choir. |

## Paths

| Path | Title | Apexes |
| --- | --- | --- |
| Aegis (`aegis`) | the one who wards the weakest | Bastion of Saints (`bastion_of_saints`), Reforged Ward (`reforged_ward`) |
| Tithe-Collector (`tithe_collector`) | the one who takes the rift's toll | Golden Aegis (`golden_aegis`), Collector of Debts (`collector_of_debts`) |
| Psalmist (`psalmist`) | the one who sings over broken wards | Choir of Wards (`choir_of_wards`), Evensong (`evensong`) |

## Duo bonds

- **Watched Over** (`watched_over`: aegis + last_watch), whose bond relic is The Last Ward (`run/relics/bond.json`).
- **Psalm and Chorus** (`psalm_and_chorus`: psalmist + chorister), whose bond relic is The Psalter (`run/relics/bond.json`).
- **Tithe and Hoard** (`tithe_and_hoard`: hoarder + tithe_collector), whose bond relic is The Counting House (`run/relics/bond.json`).

## Where else to look

- Its tests: `tests/heroes/edric/`.
- Its figures: `art/figures/heroes/edric/` (one per form).
- Its design: `docs/plans/design/rebuild-heroes.md`, `upgrade-pools.md`, and `apexes.md`; how it was built and tuned: the phase plan named in `CLAUDE.md`'s table.
