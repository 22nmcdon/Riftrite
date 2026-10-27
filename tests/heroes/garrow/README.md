# Garrow of the Chains's tests

The tests for `garrow`'s kit, paths, cards, and apexes, and the sim and run pieces built for them. They read the real content from `data/heroes/garrow/` and build small fights with `tests/sim/sim_test_kit.gd` (run tests with `tests/run/run_test_kit.gd`).

| File | What it checks |
| --- | --- |
| `test_garrow_apex_pieces.gd` | The pieces Garrow's apexes added, each in a small fight: power that grows per stack of a status, a spend that keeps a share of the Shield, a stack per so much damage, damage stored and released, the Shield deed past a share of max HP,... |
| `test_garrow_apexes.gd` | Garrow's six apexes in real fights: each loads on its path's transformed kit, its taste and deed, and its snowball growing at apex: Endless Bulwark's layers, Shatterburst's echoes and kept Shield, Grinder's feed, Undertow's tide,... |
| `test_garrow_cards.gd` | Garrow's upgrade cards on his real kits: each changes the kit it's offered on, a card on Haul reaches it as his signature or as his habit, and the knobs they added. |
| `test_garrow_paths.gd` | Garrow's paths in real fights: Aegisfang's capped Shield and its Burst, Chainwarden's Bleeding chains and Maelstrom, Spitemail's Spikes and Iron Maiden, Haul as each one's habit, and each deed moving. |
| `test_garrow_pieces.gd` | Garrow's paths' pieces, each in a small fight: a Shield with a cap, damage worked out from the unit's own Shield and the Shield spent, a signature that readies the basic attack, an aura per enemy near, and the enemies farthest from it. |

Run one: `godot --headless -s addons/gut/gut_cmdln.gd -gexit -gselect=<file>`.
