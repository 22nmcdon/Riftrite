# Ilse Cinderhand's tests

The tests for `ilse`'s kit, paths, cards, and apexes, and the sim and run pieces built for them. They read the real content from `data/heroes/ilse/` and build small fights with `tests/sim/sim_test_kit.gd` (run tests with `tests/run/run_test_kit.gd`).

| File | What it checks |
| --- | --- |
| `test_ilse_apexes.gd` | Ilse's six apexes in real fights: each loads on its path's transformed kit with its taste and deed, and what it does at apex: Blast Furnace's stokes that speed her up, Crucible's Immolate that keeps the Burn, Living Flame's hunting... |
| `test_ilse_cards.gd` | Ilse's upgrade cards on her real kits: each changes the kit it's offered on, a card on Flare reaches it as her signature or her habit, the knobs her cards added, and the bond relics built with her: Fire on the Wind, Bellows of the Wind,... |
| `test_ilse_paths.gd` | Ilse's paths in real fights: Heat as her only mana, Furnace's Stoke and Immolate, Wildfire's Kindling and Firestorm, Ember Choir's Blessing and Hymn of Cinders, Flare as each one's habit, and each deed moving only with its taste. |
| `test_ilse_pieces.gd` | The fight pieces Ilse's paths added, each in a small fight: the trigger on_status_tick, the aura stat over_time_loss_bp, damage's amount_per_stack and an on_fire stacks_of, a zone that grows, an area at the largest groups, on_ally_hit's... |

Run one: `godot --headless -s addons/gut/gut_cmdln.gd -gexit -gselect=<file>`.
