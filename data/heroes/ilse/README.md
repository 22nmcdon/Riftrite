# Ilse Cinderhand, the fire-speaker

`ilse` · role: damage. Everything the game reads about this hero lives in this folder (`src/sim/content/data_layout.gd` names the files); the code that runs it is the shared sim, not hero-specific.

## Files

| File | What it holds |
| --- | --- |
| `hero.json` | The base kit: stats, the basic attack (Cinder Flick), the signature (Flare), passives (Heat). |
| `paths.json` | The three paths: each one's vowed taste and cost, its transformation, its deed and threshold, and its two apexes. |
| `upgrades.json` | The after-fight cards: 12 of the hero's own, 6 taste cards, 15 path cards, and 12 apex cards. |
| `statuses.json` | The 17 statuses only this hero's content sets: smoldering, blessed, hymn, slow_coals, smoke, fervor, singed, blast_furnace, roaring_bellows, crucible, choking_smoke, ringed, ring_heat, cinder_saint, rising_choir, crowned_in_flame, iron_embers. |

## Paths

| Path | Title | Apexes |
| --- | --- | --- |
| Furnace (`furnace`) | the one who stokes one fire hotter | Blast Furnace (`blast_furnace`), Crucible (`crucible`) |
| Wildfire (`wildfire`) | the one who sets the ground alight | Living Flame (`living_flame`), Ring of Fire (`ring_of_fire`) |
| Ember Choir (`ember_choir`) | the one who sings fire into her allies' weapons | Cinder Saint (`cinder_saint`), Kindred Flame (`kindred_flame`) |

## Duo bonds

- **Burning Volley** (`burning_volley`: ember_choir + volley), whose bond relic is Fire on the Wind (`run/relics/bond.json`).
- **The Bellows** (`the_bellows`: furnace + windcaller), whose bond relic is Bellows of the Wind (`run/relics/bond.json`).
- **The Firepit** (`the_firepit`: chainwarden + wildfire), whose bond relic is The Firepit (`run/relics/bond.json`).

## Where else to look

- Its tests: `tests/heroes/ilse/`.
- Its figures: `art/figures/heroes/ilse/` (one per form).
- Its design: `docs/plans/design/rebuild-heroes.md`, `upgrade-pools.md`, and `apexes.md`; how it was built and tuned: the phase plan named in `CLAUDE.md`'s table.
