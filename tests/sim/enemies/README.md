# tests/sim/enemies/

Every enemy kit in small fights, each act's new enemies, elites' pieces, and enemy growth (specializations and upgrades).

## Files

| File | What it is |
| --- | --- |
| `test_act2_enemies.gd` | Act 2's enemies in data/acts/act<N>/enemies.json: each one's threat happens, and so does each new face's two specializations. |
| `test_act3_enemies.gd` | Act 3's enemies in data/acts/act<N>/enemies.json: each one's threat happens, and so does each new face's two specializations. |
| `test_elite_pieces.gd` | The sim pieces phase 5's elites and boss need: an aura on while an ally of a kit stands, a signature that fires with an ally's, and the inert trait. |
| `test_enemy_growth_pieces.gd` | The sim pieces of Act 3's enemy growth: the upgrades' aura stats and Festering's cut to healing, and Engage reaching farther, each in a small fight, with the real upgrades from data/acts/enemy_upgrades.json. |
| `test_enemy_kits.gd` | The nine Act 1 enemies in data/acts/act<N>/enemies.json: each one's threat happens. |
