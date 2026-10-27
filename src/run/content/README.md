# src/run/content/

The run's content: `RunContent` reads the run's half of `data/` (acts, upgrades, items, relics, bonds, camp, events, the rift learns) and answers what a hero's kit, cards, Tithe, and shop rules are now.

## Files

| File | What it is |
| --- | --- |
| `act_def.gd` | An act's shape: its days, the shards a won fight pays by its tier, the shards a run starts with, how many losses end it, and each hero's loadout slots, the after-fight pick's shards and wild cards, and the shops' prices and sizes. |
| `camps_def.gd` | Camp's data: the options' names and lines, the places and their menus, and camp's numbers; and the day's nodes: their names, lines, and icons, and when the Magpie comes. |
| `event_def.gd` | The Event node's data: the scenes, each with its choices and their results, and the Bloodied Oath's oaths. |
| `rift_learns_def.gd` | The rift learns' data: how many fights it reads, and the habits it answers, each with what a fight counts toward it, how much a fight of it is a habit, and the upgrades and specializations that answer it. |
| `run_content.gd` | The run's data, apart from the sim's: the acts, the upgrades, the items, camp, the relics, and the duo bonds. |
