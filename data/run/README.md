# data/run/

What the run offers between fights: relics (by tier), loadout items (by kind), duo bonds, camp and the day's nodes (`camps.json`: options, places, Rift Tear's depths and modifiers), and the Event node's scenes and oaths (`events.json`). Read by `RunContent`.

## Folders

| Folder | What it holds |
| --- | --- |
| `items/` | The loadout pool, one file per kind: charms, tactics, sigils, and gambits, each with three ranks. |
| `relics/` | The relic pool, one file per tier. |

## Files

| File | What it is |
| --- | --- |
| `bonds.json` | Duo bonds: two paths of two heroes, with no boost of their own. (26 entries) |
| `camps.json` | Camp and the day's nodes: each option has one job, and what it does is code; this file names them, says which places offer which, and gives their numbers. |
| `events.json` | The Event node's scenes and the Bloodied Oath. |
