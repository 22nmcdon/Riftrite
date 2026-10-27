# Severine Hollowell's tests

The tests for `severine`'s kit, paths, cards, and apexes, and the sim and run pieces built for them. They read the real content from `data/heroes/severine/` and build small fights with `tests/sim/sim_test_kit.gd` (run tests with `tests/run/run_test_kit.gd`).

| File | What it checks |
| --- | --- |
| `test_severine_apex_pieces.gd` | The pieces Severine's apexes added, each in a small fight: an aura that counts per share of max HP Engorge added or per stack of a status on its holder; damage from the max HP Engorge added and giving it up; the trigger on_hp_spent; a... |
| `test_severine_apexes.gd` | Severine's six apexes in real fights: each loads on its path's transformed kit with its taste and deed, and its snowball grows at apex: Leviathan's lifesteal per share of max HP gained, Sanguine Nova's burst of Engorged max HP and... |
| `test_severine_cards.gd` | Severine's upgrade cards on her real kits: each changes the kit it's offered on, a card on Drain reaches it as her signature or as her habit, and the new knobs do what they say; and her 12 apex cards on their apexes' kits. |
| `test_severine_paths.gd` | Severine's paths in real fights: Bloodglut's Engorge and Gorge, Plaguebearer's Blight, Plague Burst, and Plague Feast, Hemomancer's Blood Price and, transformed, the start at half HP, Blood Bolt, and Exsanguinate, Drain as each one's... |
| `test_severine_pieces.gd` | The pieces Severine's kit and paths added, each in a small fight: a damage effect's own lifesteal, added to its unit's lifesteal auras, and the aura stat lifesteal_more_bp, which multiplies the whole share and may be worked out per hit... |

Run one: `godot --headless -s addons/gut/gut_cmdln.gd -gexit -gselect=<file>`.
