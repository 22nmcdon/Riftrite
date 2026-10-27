# Edric Tithewell's tests

The tests for `edric`'s kit, paths, cards, and apexes, and the sim and run pieces built for them. They read the real content from `data/heroes/edric/` and build small fights with `tests/sim/sim_test_kit.gd` (run tests with `tests/run/run_test_kit.gd`).

| File | What it checks |
| --- | --- |
| `test_edric_apexes.gd` | Edric's six apexes in real fights: each loads on its path's transformed kit with its taste and deed, and what it does at apex: Bastion of Saints' growing Hallow on everyone and Hallowed Ground, Reforged Ward's new Shields, Golden... |
| `test_edric_cards.gd` | Edric's upgrade cards on his real kits: each changes the kit it's offered on, a card on Ward reaches it as his signature or as his habit, Hallow's cards, and his 12 apex cards on their apexes' kits. |
| `test_edric_paths.gd` | Edric's paths in real fights: Aegis's Hallow and Sanctuary, Tithe-Collector's Collection, Psalmist's Offering, Psalm, and Vesper Ward, Ward as each one's habit, and each deed moving only with its taste. |
| `test_edric_pieces.gd` | The fight pieces Edric's paths and apexes added, each in a small fight: the aura stat shield_absorb_bp, trigger_ally on on_ally_shield_broken, lowest_hp_ally's count, a Shield's plus_per_shard_bp, and the effect shards. |

Run one: `godot --headless -s addons/gut/gut_cmdln.gd -gexit -gselect=<file>`.
