# Hob Gleaner, the scavenger

`hob` · role: damage. Everything the game reads about this hero lives in this folder (`src/sim/content/data_layout.gd` names the files); the code that runs it is the shared sim, not hero-specific.

## Files

| File | What it holds |
| --- | --- |
| `hero.json` | The base kit: stats, the basic attack (Sling Stone), the signature (Grab), passives (Pickings). |
| `paths.json` | The three paths: each one's vowed taste and cost, its transformation, its deed and threshold, and its two apexes. |
| `upgrades.json` | The after-fight cards: 12 of the hero's own, 6 taste cards, 15 path cards, and 12 apex cards. |
| `statuses.json` | The 11 statuses only this hero's content sets: compounding, cut_purse, slippery_exit, idol_fury, compounding_more, idol_gaze, silver_cut, silver_cut_deep, silver_tongue, bounty_slow, bounty_lesser. |

## Paths

| Path | Title | Apexes |
| --- | --- | --- |
| Hoarder (`hoarder`) | the one whose purse is a weapon | Dragon's Hoard (`dragons_hoard`), Golden Idol (`golden_idol`) |
| Fence (`fence`) | the one who always gets a better price | Black Market (`black_market`), Silver Tongue (`silver_tongue`) |
| Bounty Hunter (`bounty_hunter`) | the one who names the price | Manhunter (`manhunter`), Price on Their Heads (`price_on_their_heads`) |

## Duo bonds

- **Price and Prey** (`price_and_prey`: bounty_hunter + headhunter), whose bond relic is The Contract (`run/relics/bond.json`).
- **Tithe and Hoard** (`tithe_and_hoard`: hoarder + tithe_collector), whose bond relic is The Counting House (`run/relics/bond.json`).
- **Black Market Ledger** (`black_market_ledger`: fence + transmuter), whose bond relic is The Black Market Ledger (`run/relics/bond.json`).

## Where else to look

- Its tests: `tests/heroes/hob/`.
- Its figures: `art/figures/heroes/hob/` (one per form).
- Its design: `docs/plans/design/rebuild-heroes.md`, `upgrade-pools.md`, and `apexes.md`; how it was built and tuned: the phase plan named in `CLAUDE.md`'s table.
