# Ottilie Brack, the alchemist

`ottilie` · role: damage. Everything the game reads about this hero lives in this folder (`src/sim/content/data_layout.gd` names the files); the code that runs it is the shared sim, not hero-specific.

## Files

| File | What it holds |
| --- | --- |
| `hero.json` | The base kit: stats, the basic attack (Toss), the signature (Volatile Flask), passives (Brewing). |
| `paths.json` | The three paths: each one's vowed taste and cost, its transformation, its deed and threshold, and its two apexes. |
| `upgrades.json` | The after-fight cards: 12 of the hero's own, 6 taste cards, 15 path cards, and 12 apex cards. |
| `statuses.json` | The 15 statuses only this hero's content sets: fire_vial, venom_vial, tonic_rush, elixir, sticky, fumes, corroded, fizz, bracing, grand_reaction, dissolved, potent_draught, potent_more, mana_flood, potent_elixir. |

## Paths

| Path | Title | Apexes |
| --- | --- | --- |
| Catalyst (`catalyst`) | the one who knows how much worse two poisons are | Grand Reaction (`grand_reaction`), Solvent (`solvent`) |
| Transmuter (`transmuter`) | the one who turns lead to gold, and the dead to coin | Midas Touch (`midas_touch`), Grand Transmutation (`grand_transmutation`) |
| Apothecary (`apothecary`) | the one with a vial for the foe and a tonic for the friend | Panacea (`panacea`), Mana Flood (`mana_flood`) |

## Duo bonds

- **Putrefaction** (`putrefaction`: catalyst + plaguebearer), whose bond relic is Plague Alchemy (`run/relics/bond.json`).
- **Tonic and Hymn** (`tonic_and_hymn`: apothecary + chorister), whose bond relic is The Tonic Choir (`run/relics/bond.json`).
- **Gilded Ash** (`gilded_ash`: transmuter + cinderhound), whose bond relic is The Gilded Hound (`run/relics/bond.json`).
- **Black Market Ledger** (`black_market_ledger`: fence + transmuter), whose bond relic is The Black Market Ledger (`run/relics/bond.json`).

## Where else to look

- Its tests: `tests/heroes/ottilie/`.
- Its figures: `art/figures/heroes/ottilie/` (one per form).
- Its design: `docs/plans/design/rebuild-heroes.md`, `upgrade-pools.md`, and `apexes.md`; how it was built and tuned: the phase plan named in `CLAUDE.md`'s table.
