# data/acts/

The rift: one folder per act (its shape, the enemies it brings in, and its fights), and what makes enemies grow across acts: `enemy_upgrades.json` (the upgrades elites carry from Act 3) and `rift_learns.json` (the habits the rift learns to answer on a boss's adds). An enemy is listed in the act that brings it in, though later acts reuse it, specialized.

## Folders

| Folder | What it holds |
| --- | --- |
| `act1/` | Act 1: `act.json`, `enemies.json`, and `encounters.json`. |
| `act2/` | Act 2, the Glassmere: shallow water, its fifteen new enemies, and its fights, specialized from day 1. |
| `act3/` | Act 3, the Shattered Crown: islands over the void, its ten new enemies, its fights, elites with upgrades, the rift learning, and the real endless after it. |

## Files

| File | What it is |
| --- | --- |
| `enemy_upgrades.json` | 12 entries |
| `rift_learns.json` | The rift learns. |
