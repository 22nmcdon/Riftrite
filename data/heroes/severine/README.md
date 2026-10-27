# Severine Hollowell, the bloodwitch

`severine` · role: damage. Everything the game reads about this hero lives in this folder (`src/sim/content/data_layout.gd` names the files); the code that runs it is the shared sim, not hero-specific.

## Files

| File | What it holds |
| --- | --- |
| `hero.json` | The base kit: stats, the basic attack (Rend), the signature (Drain), passives (Hemophage). |
| `paths.json` | The three paths: each one's vowed taste and cost, its transformation, its deed and threshold, and its two apexes. |
| `upgrades.json` | The after-fight cards: 12 of the hero's own, 6 taste cards, 15 path cards, and 12 apex cards. |
| `statuses.json` | The 10 statuses only this hero's content sets: nova_hunger, gluttony, plague_weak, pestilence, epidemic, wasting, blood_offering, sacred_blood, sacrament, shared_blood. |

## Paths

| Path | Title | Apexes |
| --- | --- | --- |
| Bloodglut (`bloodglut`) | the one who drinks past full | Leviathan (`leviathan`), Sanguine Nova (`sanguine_nova`) |
| Plaguebearer (`plaguebearer`) | the one whose wounds fester | Gravecaller (`gravecaller`), Pestilence (`pestilence`) |
| Hemomancer (`hemomancer`) | the one who bleeds for power | Blood Tide (`blood_tide`), Blood Rite (`blood_rite`) |

## Duo bonds

- **Iron Hunger** (`iron_hunger`: bloodglut + spitemail), whose bond relic is The Iron Maw (`run/relics/bond.json`).
- **Blood and Lamplight** (`blood_and_lamplight`: hemomancer + lanternbearer), whose bond relic is The Lamp of Ichor (`run/relics/bond.json`).
- **Putrefaction** (`putrefaction`: catalyst + plaguebearer), whose bond relic is Plague Alchemy (`run/relics/bond.json`).
- **Nest of Rot** (`nest_of_rot`: plaguebearer + serpent_keeper), whose bond relic is Mother of Serpents (`run/relics/bond.json`).

## Where else to look

- Its tests: `tests/heroes/severine/`.
- Its figures: `art/figures/heroes/severine/` (one per form).
- Its design: `docs/plans/design/rebuild-heroes.md`, `upgrade-pools.md`, and `apexes.md`; how it was built and tuned: the phase plan named in `CLAUDE.md`'s table.
