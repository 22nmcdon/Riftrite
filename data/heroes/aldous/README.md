# Aldous Vesper, the bell-ringer

`aldous` · role: support. Everything the game reads about this hero lives in this folder (`src/sim/content/data_layout.gd` names the files); the code that runs it is the shared sim, not hero-specific.

## Files

| File | What it holds |
| --- | --- |
| `hero.json` | The base kit: stats, the basic attack (Toll), the signature (Peal), passives (Resonance). |
| `paths.json` | The three paths: each one's vowed taste and cost, its transformation, its deed and threshold, and its two apexes. |
| `upgrades.json` | The after-fight cards: 12 of the hero's own, 6 taste cards, 15 path cards, and 12 apex cards. |
| `statuses.json` | The 12 statuses only this hero's content sets: pealing, cracked, rung, grand_note, wellspring_swell, long_wind_gust, long_wind_gust_more, rising_pitch, great_bell, great_bell_more, deafened, requiem_toll. |

## Paths

| Path | Title | Apexes |
| --- | --- | --- |
| Chorister (`chorister`) | the band's breath | Grand Chorus (`grand_chorus`), Wellspring (`wellspring`) |
| Windcaller (`windcaller`) | the wind at their backs | Long Wind (`long_wind`), Singing Arrows (`singing_arrows`) |
| Bellwarden (`bellwarden`) | the bell that names the dead | The Great Bell (`the_great_bell`), Requiem (`requiem`) |

## Duo bonds

- **The Hunter's Bell** (`the_hunters_bell`: bellwarden + headhunter), whose bond relic is Death's Appointment (`run/relics/bond.json`).
- **Toll and Judgment** (`toll_and_judgment`: bellwarden + vigil_keeper), whose bond relic is The Toll of Dawn (`run/relics/bond.json`).
- **Psalm and Chorus** (`psalm_and_chorus`: psalmist + chorister), whose bond relic is The Psalter (`run/relics/bond.json`).
- **The Bellows** (`the_bellows`: furnace + windcaller), whose bond relic is Bellows of the Wind (`run/relics/bond.json`).
- **Tonic and Hymn** (`tonic_and_hymn`: apothecary + chorister), whose bond relic is The Tonic Choir (`run/relics/bond.json`).

## Where else to look

- Its tests: `tests/heroes/aldous/`.
- Its figures: `art/figures/heroes/aldous/` (one per form).
- Its design: `docs/plans/design/rebuild-heroes.md`, `upgrade-pools.md`, and `apexes.md`; how it was built and tuned: the phase plan named in `CLAUDE.md`'s table.
