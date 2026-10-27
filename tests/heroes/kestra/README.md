# Kestra Fenn's tests

The tests for `kestra`'s kit, paths, cards, and apexes, and the sim and run pieces built for them. They read the real content from `data/heroes/kestra/` and build small fights with `tests/sim/sim_test_kit.gd` (run tests with `tests/run/run_test_kit.gd`).

| File | What it checks |
| --- | --- |
| `test_kestra_apexes.gd` | Kestra's six apexes in real fights: each loads on its path's transformed kit with its taste and deed, and what it does at apex: Hellhound's fire round Grit, Firestarter's Burn on every summon's attacks, Brood Mother's nest that stays,... |
| `test_kestra_cards.gd` | Kestra's upgrade cards on her real kits: each changes the kit it's offered on, cards on Sic 'Em reach it as her signature and as her habit, cards on her companions reach their kits, and the bond relics built with her: The Gilded Hound... |
| `test_kestra_paths.gd` | Kestra's paths in real fights: Cinderhound's Smoldering Fangs, ember coat, and Firebrand Pounce, Serpent-Keeper's Venomed Jab, viper, and Nest, Packleader's Pack Call, two hounds, Pack Fury, and Howl, Sic 'Em as each one's habit, and... |
| `test_kestra_pieces.gd` | The fight pieces Kestra's kit and paths added, each in a small fight: companions, an ability done by a companion, a companion's effect scaled by its owner, an aura "per": "allied_summon" and the condition "summon", the trigger... |

Run one: `godot --headless -s addons/gut/gut_cmdln.gd -gexit -gselect=<file>`.
