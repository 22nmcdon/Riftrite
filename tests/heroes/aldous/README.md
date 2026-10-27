# Aldous Vesper's tests

The tests for `aldous`'s kit, paths, cards, and apexes, and the sim and run pieces built for them. They read the real content from `data/heroes/aldous/` and build small fights with `tests/sim/sim_test_kit.gd` (run tests with `tests/run/run_test_kit.gd`).

| File | What it checks |
| --- | --- |
| `test_aldous_apex_pieces.gd` | The pieces Aldous's apexes added, each in a small fight: the aura stats mana_gain_bp, mana_store_bp, and overflow_power_bp, the condition fired_over_full, a boost's signature_power_bp, an aura's per_hex, the trigger on_ally_hit and the... |
| `test_aldous_apexes.gd` | Aldous's six apexes in real fights: each loads on its path's transformed kit with its taste and deed, and its snowball grows at apex: Grand Chorus's stronger next signatures and mana for every signature, Wellspring's bars past full,... |
| `test_aldous_cards.gd` | Aldous's upgrade cards and his bond relics on his real kits: each changes the kit it's offered on, a card on Peal reaches it as his signature or as his habit, and the new knobs do what they say. |
| `test_aldous_paths.gd` | Aldous's paths in real fights: Chorister's Shared Breath, Chorus, and Crescendo, Windcaller's Tailwind, High Wind, and Gale, Bellwarden's Toll the Hour and Death Knell, Peal as each one's habit, and each deed moving only with its taste. |
| `test_aldous_pieces.gd` | The pieces Aldous's paths added, each in a small fight: the target lowest_mana_ally, the trigger on_mana_gained with gain_mana by a share of it, mana given to another unit and the deed count mana_given, the conditions ranged and... |

Run one: `godot --headless -s addons/gut/gut_cmdln.gd -gexit -gselect=<file>`.
