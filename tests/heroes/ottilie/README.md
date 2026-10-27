# Ottilie Brack's tests

The tests for `ottilie`'s kit, paths, cards, and apexes, and the sim and run pieces built for them. They read the real content from `data/heroes/ottilie/` and build small fights with `tests/sim/sim_test_kit.gd` (run tests with `tests/run/run_test_kit.gd`).

| File | What it checks |
| --- | --- |
| `test_ottilie_apexes.gd` | Ottilie's six apexes in real fights: each loads on its path's transformed kit with its taste and deed, and what it does at apex: Grand Reaction's growing bonus against both, Solvent's evening of Burn and Poison, Midas Touch's shards for... |
| `test_ottilie_cards.gd` | Ottilie's upgrade cards on her real kits: each changes the kit it's offered on, cards on Volatile Flask reach it as her signature and as her habit, the knobs her cards added, the elites-and-bosses condition, and the bond relics built... |
| `test_ottilie_paths.gd` | Ottilie's paths in real fights: Brewing's vials, Catalyst's Reaction and Reaction Flask, Transmuter's Gilded Death and Philosopher's Flask, Apothecary's Tonic and Elixir, Volatile Flask as each one's habit, and each deed moving only... |
| `test_ottilie_pieces.gd` | The fight pieces Ottilie's kit and paths added, each in a small fight: an on_interval's first_ms, on_holder_hit's spends, a per-hit aura's summed stacks with per_stacks and cap_bp, damage's amount_per_stack over several statuses, the... |

Run one: `godot --headless -s addons/gut/gut_cmdln.gd -gexit -gselect=<file>`.
