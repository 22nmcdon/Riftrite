# Garrow of the Chains, the anchor

`garrow` · role: tank. Everything the game reads about this hero lives in this folder (`src/sim/content/data_layout.gd` names the files); the code that runs it is the shared sim, not hero-specific.

## Files

| File | What it holds |
| --- | --- |
| `hero.json` | The base kit: stats, the basic attack (Chain Fist), the signature (Haul), passives (Stand Fast, Heavy). |
| `paths.json` | The three paths: each one's vowed taste and cost, its transformation, its deed and threshold, and its two apexes. |
| `upgrades.json` | The after-fight cards: 12 of the hero's own, 6 taste cards, 15 path cards, and 12 apex cards. |
| `statuses.json` | The 7 statuses only this hero's content sets: bulwark_layer, shatter_echo, grinder_feed, undertow_tide, deep_current, thorn_crown, iron_maiden. |

## Paths

| Path | Title | Apexes |
| --- | --- | --- |
| Aegisfang (`aegisfang`) | the shield that bites | Endless Bulwark (`endless_bulwark`), Shatterburst (`shatterburst`) |
| Chainwarden (`chainwarden`) | the one who drags them in | Grinder (`grinder`), Undertow (`undertow`) |
| Spitemail (`spitemail`) | the one who hits back | Thorned King (`thorned_king`), Vengeance (`vengeance`) |

## Duo bonds

- **Dragged to the Snare** (`dragged_to_the_snare`: chainwarden + trapper), whose bond relic is The Snaring Chain (`run/relics/bond.json`).
- **Woven Fang** (`woven_fang`: aegisfang + wardweaver), whose bond relic is The Woven Fang (`run/relics/bond.json`).
- **Iron Hunger** (`iron_hunger`: bloodglut + spitemail), whose bond relic is The Iron Maw (`run/relics/bond.json`).
- **The Firepit** (`the_firepit`: chainwarden + wildfire), whose bond relic is The Firepit (`run/relics/bond.json`).

## Where else to look

- Its tests: `tests/heroes/garrow/`.
- Its figures: `art/figures/heroes/garrow/` (one per form).
- Its design: `docs/plans/design/rebuild-heroes.md`, `upgrade-pools.md`, and `apexes.md`; how it was built and tuned: the phase plan named in `CLAUDE.md`'s table.
