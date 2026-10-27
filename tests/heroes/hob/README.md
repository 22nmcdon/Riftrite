# Hob Gleaner's tests

The tests for `hob`'s kit, paths, cards, and apexes, and the sim and run pieces built for them. They read the real content from `data/heroes/hob/` and build small fights with `tests/sim/sim_test_kit.gd` (run tests with `tests/run/run_test_kit.gd`).

| File | What it checks |
| --- | --- |
| `test_hob_apexes.gd` | Hob's six apexes in real fights: each loads on its path's transformed kit with its taste and deed, and what it does at apex: Dragon's Hoard's Nest Egg for every hero, Golden Idol's purse of a Shield and Recast, Silver Tongue's wide cut... |
| `test_hob_cards.gd` | Hob's upgrade cards and bond relics on his real kits: each changes the kit it's offered on, cards on Grab reach it as his signature and as his habit, the knobs they added, and The Contract and The Counting House in fights. |
| `test_hob_paths.gd` | Hob's paths in real fights: the Hoarder's Nest Egg and Heavy Purse, the Fence's Cut Purse, the Bounty Hunter's Bounty and Collect, Grab as each one's habit, and each fight deed moving only with its taste. |
| `test_hob_pieces.gd` | The fight pieces Hob's kit added, each in a small fight: shards held as power, the toughest enemies, a Bounty that passes to the next toughest, and a kills deed counting a side's kills of a Bounty. |
| `test_hob_shop.gd` | Hob's run pieces: shop rules on a path's stage and on cards, at the Pedlar and the boss shop only; the shards they save as Haggle's deed; shards spent in shops as transformed Fence's team snowball; and the run counts his cards grow... |

Run one: `godot --headless -s addons/gut/gut_cmdln.gd -gexit -gselect=<file>`.
