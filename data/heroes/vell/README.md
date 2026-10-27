# Sister Vell, the mender

`vell` · role: support. Everything the game reads about this hero lives in this folder (`src/sim/content/data_layout.gd` names the files); the code that runs it is the shared sim, not hero-specific.

## Files

| File | What it holds |
| --- | --- |
| `hero.json` | The base kit: stats, the basic attack (Lantern Glow), the signature (Mend), passives (Hearthlight). |
| `paths.json` | The three paths: each one's vowed taste and cost, its transformation, its deed and threshold, and its two apexes. |
| `upgrades.json` | The after-fight cards: 12 of the hero's own, 6 taste cards, 15 path cards, and 12 apex cards. |
| `statuses.json` | The 9 statuses only this hero's content sets: zeal, morning_haste, dawnlight, first_light, glare, woven_thorns, first_light_more, zeal_more, dawn_ward. |

## Paths

| Path | Title | Apexes |
| --- | --- | --- |
| Lanternbearer (`lanternbearer`) | the warm light | The Beacon (`the_beacon`), Dawnbringer (`dawnbringer`) |
| Wardweaver (`wardweaver`) | the shielder | Loomwarden (`loomwarden`), Thornweave (`thornweave`) |
| Vigil Keeper (`vigil_keeper`) | the battle cleric | Inquisitor (`inquisitor`), Sanctifier (`sanctifier`) |

## Duo bonds

- **Light and Iron** (`light_and_iron`: wardweaver + hearthwall), whose bond relic is The Hearth-Woven Mail (`run/relics/bond.json`).
- **Woven Fang** (`woven_fang`: aegisfang + wardweaver), whose bond relic is The Woven Fang (`run/relics/bond.json`).
- **Toll and Judgment** (`toll_and_judgment`: bellwarden + vigil_keeper), whose bond relic is The Toll of Dawn (`run/relics/bond.json`).
- **Blood and Lamplight** (`blood_and_lamplight`: hemomancer + lanternbearer), whose bond relic is The Lamp of Ichor (`run/relics/bond.json`).
- **Lantern Vigil** (`lantern_vigil`: last_watch + lanternbearer), whose bond relic is The Vigil Lamp (`run/relics/bond.json`).

## Where else to look

- Its tests: `tests/heroes/vell/`.
- Its figures: `art/figures/heroes/vell/` (one per form).
- Its design: `docs/plans/design/rebuild-heroes.md`, `upgrade-pools.md`, and `apexes.md`; how it was built and tuned: the phase plan named in `CLAUDE.md`'s table.
