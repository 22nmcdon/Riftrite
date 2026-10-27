# Tamsin Gloamstep's tests

The tests for `tamsin`'s kit, paths, cards, and apexes, and the sim and run pieces built for them. They read the real content from `data/heroes/tamsin/` and build small fights with `tests/sim/sim_test_kit.gd` (run tests with `tests/run/run_test_kit.gd`).

| File | What it checks |
| --- | --- |
| `test_tamsin_apexes.gd` | Tamsin's six apexes in real fights: each loads on its path's transformed kit with its taste and deed, and its snowball grows at apex: Phantom's Stealth that attacks don't end, Veilmaster's veiled allies, Executioner's Marked executions,... |
| `test_tamsin_card_pieces.gd` | The pieces Tamsin's cards and her bond relic added, each in a small fight: the aura stat evade_bp, a pull toward the unit's nearest ally, the conditions targets_holder and target, a cleanse on on_status keeping its own statuses, a... |
| `test_tamsin_cards.gd` | Tamsin's upgrade cards and her bond relic on her real kits: each changes the kit it's offered on, a card on Shadowstep reaches it as her signature or as her habit, and Hammer and Wire changes only Garrote. |
| `test_tamsin_paths.gd` | Tamsin's paths in real fights: Nightblade's Fade and Shadow Dance, Headhunter's Scent and Sentence, Garrote's Choke and grip, Shadowstep as each one's habit, and each deed moving. |
| `test_tamsin_pieces.gd` | The pieces Tamsin's kit and paths added, each in a small fight: the targeting rule weakest_within, a preference with a reach, a leap behind the target, a passive's step, a Stealth that ends on its holder's basic attack, extending... |

Run one: `godot --headless -s addons/gut/gut_cmdln.gd -gexit -gselect=<file>`.
