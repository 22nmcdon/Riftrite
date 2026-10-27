# Tamsin Gloamstep, the knife

`tamsin` · role: damage. Everything the game reads about this hero lives in this folder (`src/sim/content/data_layout.gd` names the files); the code that runs it is the shared sim, not hero-specific.

## Files

| File | What it holds |
| --- | --- |
| `hero.json` | The base kit: stats, the basic attack (Knife), the signature (Shadowstep), passives (Ambusher, From the Dark). |
| `paths.json` | The three paths: each one's vowed taste and cost, its transformation, its deed and threshold, and its two apexes. |
| `upgrades.json` | The after-fight cards: 12 of the hero's own, 6 taste cards, 15 path cards, and 12 apex cards. |
| `statuses.json` | The 17 statuses only this hero's content sets: assassins_haste, swift_step, death_mark, phantom_edge, phantom_edge_more, veil_haste, veil_haste_more, executioner_rush, executioner_rush_more, on_the_trail, trailing, blood_scent_more, strangle, pinned_light, pinned, pin_rally, pin_rally_more. |

## Paths

| Path | Title | Apexes |
| --- | --- | --- |
| Nightblade (`nightblade`) | the one you never see | Phantom (`phantom`), Veilmaster (`veilmaster`) |
| Headhunter (`headhunter`) | the one with your scent | Executioner (`executioner`), Bloodtrail (`bloodtrail`) |
| Garrote (`garrote`) | the one who holds you still | Strangler (`strangler`), Pinmaster (`pinmaster`) |

## Duo bonds

- **Hold and Break** (`hold_and_break`: garrote + ironbrand), whose bond relic is Hammer and Wire (`run/relics/bond.json`).
- **The Hunter's Bell** (`the_hunters_bell`: bellwarden + headhunter), whose bond relic is Death's Appointment (`run/relics/bond.json`).
- **Unseen Blade** (`unseen_blade`: nightblade + veilweaver), whose bond relic is The Shroud of Knives (`run/relics/bond.json`).
- **Price and Prey** (`price_and_prey`: bounty_hunter + headhunter), whose bond relic is The Contract (`run/relics/bond.json`).

## Where else to look

- Its tests: `tests/heroes/tamsin/`.
- Its figures: `art/figures/heroes/tamsin/` (one per form).
- Its design: `docs/plans/design/rebuild-heroes.md`, `upgrade-pools.md`, and `apexes.md`; how it was built and tuned: the phase plan named in `CLAUDE.md`'s table.
