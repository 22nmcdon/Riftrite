# Apply order for the plan changes

Written 2026-10-02. There are **21 change files** (`changes-*.md`), plus a few **full files** delivered earlier that go in first. Several change files add to files that earlier ones create, so apply them in this order.

**How to read each step:** "Creates" are new plan files the change file contains in full. "Edits" are existing files it changes. "Needs" are earlier steps it builds on.

**Before you start:** my copy of the repo is behind your branch, so some quoted "Replace" text may already differ on your side. If a quote doesn't match, apply the intent by hand. `CLAUDE.md` is touched by almost every step, and always in the plan table or the heroes bullet.

---

## Step 0: full files delivered earlier (copy in as they are)

| File | What it is |
| --- | --- |
| `docs/plans/relics/` (`README.md` and the five tier files) | The relic pool. These replace the versions on your branch |
| `docs/plans/loadout/` (`README.md`, `tactics.md`, `gambits.md`, `sigils.md`, `charms.md`) | Tactics, gambits, sigils, and charms with ranks |
| `docs/plans/days-and-nodes.md` | The day loop and nodes |
| `docs/plans/events.md` | Events and the Bloodied Oath |

**Ignore `magpie-update.zip`:** it held direct edits made before the change-file rule. Step 1 replaces it.

---

## Part 1: systems

| Step | File | Creates | Edits | Needs |
| --- | --- | --- | --- | --- |
| 1 | `changes-magpie-and-grafts.md` | `magpie.md` | `loadout/charms.md`, `loadout/README.md`, `days-and-nodes.md`, `relics/README.md`, `relics/relics-rare.md`, `rebuild-decisions.md`, `rebuild-content-pool.md`, `rebuild-combos.md`, `CLAUDE.md` | Step 0 |
| 2 | `changes-upgrade-pools.md` | `upgrade-pools.md` | `rebuild-heroes.md`, `rebuild-decisions.md`, `rebuild-content-pool.md`, `CLAUDE.md` | Step 1 (the Bleeding row) |
| 3 | `changes-duo-bonds.md` | `duo-bonds.md` | `rebuild-run.md`, `relics/README.md`, `rebuild-combos.md`, `CLAUDE.md` | Step 0 |
| 4 | `changes-apexes.md` | `apexes.md` | `rebuild-heroes.md`, `upgrade-pools.md`, `rebuild-run.md`, `CLAUDE.md` | Step 2 |
| 5 | `changes-enemy-growth.md` | `enemy-growth.md` | `rebuild-enemies.md`, `days-and-nodes.md`, `CLAUDE.md` | Step 0 |
| 6 | `changes-endless.md` | `endless.md` | `rebuild-combos.md`, `CLAUDE.md` | Step 5 (rift modifiers) |
| 7 | `changes-economy.md` | `economy.md` | `relics/README.md`, `relics/relics-common.md`, `relics/relics-epic.md`, `rebuild-decisions.md`, `rebuild-combos.md`, `days-and-nodes.md`, `CLAUDE.md` | Steps 0, 1 |
| 8 | `changes-ui-new-systems.md` | `ui-new-systems.md` | `rebuild-phase5b-art.md` (on your branch only), `CLAUDE.md` | Steps 1–7 (it describes them) |
| 9 | `changes-asset-contract.md` | `asset-contract.md` | `art-style-guide.md`, `rebuild-build-order.md`, `CLAUDE.md` | None |

## Part 2: heroes and the build map

| Step | File | Creates | Edits | Needs |
| --- | --- | --- | --- | --- |
| 10 | `changes-ilse.md` | none | `rebuild-heroes.md` (section 8b), `rebuild-combos.md` (lifesteal), `upgrade-pools.md`, `apexes.md`, `rebuild-content-pool.md`, `CLAUDE.md` | Steps 2, 4 |
| 11 | `changes-build-map.md` | `build-map.md` | `rebuild-heroes.md`, `CLAUDE.md` | None (but apply before step 12) |
| 12 | `changes-tamsin.md` | none | `rebuild-heroes.md` (8c), `apexes.md` (rarity rule, Inquisitor buff), `upgrade-pools.md`, `build-map.md`, `CLAUDE.md` | Steps 10, 11 |
| 13 | `changes-garrow.md` | none | `rebuild-heroes.md` (8d; damage-over-time rule), `apexes.md`, `upgrade-pools.md`, `build-map.md`, `CLAUDE.md` | Step 12 |
| 14 | `changes-aldous.md` | none | `rebuild-heroes.md` (8e), `apexes.md`, `upgrade-pools.md`, `build-map.md`, `CLAUDE.md` | Step 13 |
| 15 | `changes-hob.md` | none | `rebuild-heroes.md` (8f; feat deeds), `apexes.md` (run-long snowballs), `upgrade-pools.md`, `economy.md`, `build-map.md`, `CLAUDE.md` | Steps 7, 14 |
| 16 | `changes-severine.md` | none | `rebuild-heroes.md` (8g), `apexes.md`, `upgrade-pools.md`, `build-map.md` (Poison and Summons rows), `CLAUDE.md` | Step 15 |
| 17 | `changes-edric.md` | none | `rebuild-heroes.md` (8h; Shield rule), `apexes.md` (snowballs optional), `upgrade-pools.md` (Wardweaver fix), `economy.md`, `build-map.md` (rule 5), `CLAUDE.md` | Step 16 |
| 18 | `changes-ottilie.md` | none | `rebuild-heroes.md` (8i), `apexes.md`, `upgrade-pools.md`, `economy.md`, `build-map.md` (rule 6), `CLAUDE.md` | Step 17 |
| 19 | `changes-lucan.md` | none | `rebuild-heroes.md` (8j), `apexes.md`, `upgrade-pools.md`, `build-map.md`, `CLAUDE.md` | Step 18 |
| 20 | `changes-kestra.md` | none | `rebuild-heroes.md` (8k), `apexes.md`, `upgrade-pools.md`, `build-map.md`, `CLAUDE.md` | Step 19 |
| 21 | `changes-bonds-full.md` | none | `duo-bonds.md` (all 24 bonds and relics), `relics/README.md`, `test-teams.md`, `CLAUDE.md` | Steps 3, 20, and `test-teams.md` added to `docs/plans/` |

**Why the heroes go in this order:** each hero file replaces text the previous one set: the `CLAUDE.md` heroes bullet, the build map's "Open questions" line, and the "after X's section" insertion point in `rebuild-heroes.md`, `apexes.md`, and `upgrade-pools.md`.

---

## Rules that came out of these changes

When you're done, these rules should be in the plans. They're easy to miss because they're spread across files:

| Rule | Where it lands |
| --- | --- |
| Damage over time (Burn, Bleed, Poison) and Shields have no owner; nothing may depend on who applied or gave them | `rebuild-heroes.md`, section 5 (steps 10, 13, 17) |
| Burn and other damage over time never count toward lifesteal | `rebuild-combos.md`, section 2b (step 10) |
| Stacking upgrades lock in a percentage of the stat when picked | `upgrade-pools.md` (step 2) |
| The rarer a snowball's trigger, the bigger its payoff; not every apex needs one; long-game heroes can have run-long snowballs | `apexes.md` (steps 12, 15, 17) |
| A deed can be a single planned feat | `rebuild-heroes.md`, section 2 (step 15) |
| Every new hero's three paths touch three different builds; no build may depend on one hero; Economy and Mana need three | `rebuild-heroes.md` section 3 and `build-map.md` (steps 11, 17, 18) |

## Sim work these changes ask for

Collected here so it isn't lost in the plans:

- **Hero-side summons** (Severine's Gravecaller, Lucan's copies, Kestra's Grit and vipers), including a permanent summon that returns after falling.
- **Confused and controlled enemies** (Lucan's Night Veil and Marionette): a new targeting state, like Taunt.
- **Shard log entries** (Hob, Edric, Ottilie): shards earned in a fight are logged with their source, and need an audit rule and a form on the board.
