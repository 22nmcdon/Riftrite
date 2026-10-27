# tests/sim/pieces/

The sim pieces that cards, items, relics, and apexes added, each tested by the content that uses it: apexes, bonds, engines, the loadout, paths, relics, sigils, the upgrade pools, and the tuning phase's relics.

## Files

| File | What it is |
| --- | --- |
| `test_apex_pieces.gd` | The sim pieces apexes added, each in the fights of the apex that uses it: an execution, on_kill's "executed" and from_ability, a kills deed by an ability, an area's per_enemy_bp, the hop effect, a patch's hop_cooldown_ms, and a deed's within_ms_of_hop. |
| `test_bond_pieces.gd` | The bond relics' pieces, each in a small fight: an aura behind an allied wall, on_knockback, and on_guard with its cooldown for each ally. |
| `test_engine_pieces.gd` | The engines' pieces, each in a small fight: a share of Burn spread, overheal to Shield from an aura, lifesteal as healing, on_lifesteal, stacking boosts, Knife's Edge, planted steps and DEF points, auras per Shield, stacking Marks and crit damage per... |
| `test_loadout_pieces.gd` | The small sim pieces the loadout pool's frame needed, each in a small fight: on_below_hp, the target allies_near_self, and cleanse's "statuses". |
| `test_loadout_tactics.gd` | The loadout's tactics in a fight: each new order, the payoffs, and rank III's twists, in tiny fights, with the tactics as the data has them. |
| `test_path_pieces.gd` | The sim pieces phase 4's paths need, one rule at a time: an ability's own "every", the targets near the target and lowest_hp_ally, gain_mana and far-shot mana, heals and hits worth a share of the hit, overheal that comes back as Shield, per-side effects in... |
| `test_plan_relics.gd` | The tuning phase's relics for sustain, control, and swarms: each one's effect in a small fight, with the sim pieces they brought: plain hits, once_per_enemy, on_enemy_near, above_hp_pct, and the hero rules holds, held_weak, and held_keeps_burn. |
| `test_relic_pieces.gd` | The pieces relics share, each in a small fight: effects at the fight's start, lifesteal, crit bonuses, timed boosts, a status ending, lengthening and extending statuses, the targets around a unit, ally_near, Salt Circle, and overkill. |
| `test_sigil_pieces.gd` | The sim pieces phase 5's sigils and tactics need: a signature's extra triggers, its Echo, and the Plant your feet tactic. |
| `test_upgrade_big_pieces.gd` | The upgrade pools' six big pieces, each on its real card: Chasing Storm, Ricochet, Reflecting Wall, Snag, Guarded Ground, and First Lantern. |
| `test_upgrade_cards.gd` | The upgrade cards phase 5c step 7a writes from built pieces, in small fights on the real kits: the four statuses they add, and a taste card's transformed mod reaching its new piece. |
| `test_upgrade_conditions.gd` | The upgrade pools' new conditions and filters, each on its real card in a small fight: heal and Shield bonuses on some allies, a per-hit reach, auras while moved and crowded or on the allies near, an event's holder condition, on_holder_crit's reach,... |
| `test_upgrade_pieces.gd` | The upgrade pools' small knobs, each on the real card that uses it or in a small fight: every_add and "at", times_add, max_standing_add, value_add, overheal_shield_add_bp, the Guard knobs, add_to_areas, a line's width, plant_add_ms, a signature's prefer,... |
