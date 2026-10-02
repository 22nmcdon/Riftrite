# Endless mode

Status: **agreed in discussion (2026-09-30); built after Act 1 (on Act 1's fights) in phase 8 part 1** (`rebuild-phase8-endless.md`, whose Decisions win where they differ; apexes, the rift learns, and Acts 2 and 3 come later in phase 8). Fills in part 7, section 8 (`rebuild-combos.md`); where they disagree, this file wins. Uses the day loop (`days-and-nodes.md`), rift modifiers and the rift learns (`enemy-growth.md`), and apexes (`apexes.md`). **Numbers are placeholders.**

## 1. Structure

- **Unlocked after beating Act 3** the first time.
- **After the Act 3 boss, you choose:** end the run as a win, or continue into endless. Continuing keeps your heroes, relics, loadout, and shards.
- **A floor is a day:** fight, after-fight pick, shop, node (the campaign's loop).
- **Every 5th floor is an elite. Every 10th is a boss:** one of the three act bosses, fully specialized. Beating one gives 1 of 3 boss relics; once you own every boss relic, it offers 3 legendaries instead.

## 2. The rift scales

| What grows | How |
| --- | --- |
| **Enemy HP and ATK** | ×1.15 per floor (exponential) |
| **Rift modifiers** | Every 3 floors, one is added for the rest of the run; they stack |
| **The rift learns** | Always on in endless, whatever the difficulty |
| **Rift Collapse** | Starts 1s earlier each floor (down to 10s); crumbled ground's damage grows with the floor |

- **Why the collapse speeds up:** a pure defense build could otherwise stall every fight to 180s, and a tie counts as a win, so it would never lose. The faster collapse makes every fight end.
- **The campaign keeps its own rule:** harder means new problems, not more HP. Exponential numbers are only for endless.

## 3. Your side

- **Permanent scaling keeps counting:** growing upgrades and relics go on growing.
- **Apex snowballs stay per fight.** Only permanent scaling carries across fights.
- **When upgrade pools run dry,** picks offer only stacking upgrades. They never run out, and since each locks in a percentage of the current stat, they grow as you do (`upgrade-pools.md`).
- **Shops:** from floor 10, any shop can show a legendary.
- **No replays:** the first loss ends the run.

## 4. Score

- **The score is the deepest floor reached.** The Codex records your best floor, and your best floor for each apex a run used.
- **Endless unlocks cosmetics only,** never stats (rule 5 of `CLAUDE.md`).
- The sim's integers are 64-bit, so big numbers are safe; the UI shortens them (12.4k, 3.1M).

## Open questions

- **×1.15 per floor** and **a modifier every 3 floors** need a sim pass: at what floor do strong builds usually fall?
- **Income in endless:** does it grow with the floor, or stay flat so prices bite harder?
- **Daily or seeded endless runs** to compare scores: later, if ever.
