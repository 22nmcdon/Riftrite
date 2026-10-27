# Lucan Merrow's tests

The tests for `lucan`'s kit, paths, cards, and apexes, and the sim and run pieces built for them. They read the real content from `data/heroes/lucan/` and build small fights with `tests/sim/sim_test_kit.gd` (run tests with `tests/run/run_test_kit.gd`).

| File | What it checks |
| --- | --- |
| `test_lucan_apexes.gd` | Lucan's six apexes in real fights: each loads on its path's transformed kit with its taste and deed, and what it does at apex: Thousand Faces' growing crowd of copies that burst, True Reflection's copies that cast, Unseen Host's sharper... |
| `test_lucan_cards.gd` | Lucan's upgrade cards on his real kits: each changes the kit it's offered on, cards on Mirror reach it as his signature and as his habit, the copy cards reach a copy's share and time, and the growing ones scale. |
| `test_lucan_paths.gd` | Lucan's paths in real fights: Mirrorwright's Reflection and Hall of Mirrors, Veilweaver's Shroud, Veiled Strike, and Vanishing Act, Puppeteer's Strings and Dance of Strings, Mirror as each one's habit, and each deed moving only with its... |
| `test_lucan_pieces.gd` | The fight pieces Lucan's kit added, each in a small fight: copies. |
| `test_lucan_states.gd` | Confused and controlled: a confused enemy attacks the nearest other unit of its own side; a controlled one fights for the side of whoever set it, owned by them, keeping no side up, nobody's fallen ally, and goes back as it ends; an... |

Run one: `godot --headless -s addons/gut/gut_cmdln.gd -gexit -gselect=<file>`.
