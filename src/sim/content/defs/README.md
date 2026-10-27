# src/sim/content/defs/

The definitions content is read into: kits (`UnitDef`), abilities, effects, auras, triggers, statuses, paths and apexes, deeds, encounters, kit mods (the one shape for upgrades, items, relics, bonds, and enemy upgrades), and the rest. Each file's header comment has its JSON shape.

## Files

| File | What it is |
| --- | --- |
| `ability_def.gd` | One of a unit's abilities: its basic attack, or its signature. |
| `apex_def.gd` | One of a path's two apexes, in its entry in data/heroes/<hero>/paths.json: the path's final form. |
| `aura_def.gd` | A continuous boost while its window is open. |
| `bond_def.gd` | A duo bond: two paths of two different heroes. |
| `collapse_def.gd` | Rift Collapse numbers for one act. |
| `companion_def.gd` | A hero's companion: a kit of its own that fights beside the hero, written in the hero's kit. |
| `deed_def.gd` | A path's deed: one thing its hero does in fights, counted in every fight whatever path the hero is on. |
| `def_copy.gd` | Copies of content definitions, for changing one without touching the shared one the content loaded. |
| `effect_def.gd` | One effect entry: WHEN it happens, WHAT it does, and WHO it affects. |
| `encounter_def.gd` | A hand-placed fight in data/acts/act<N>/encounters.json: the enemies on their hexes, the rocks, and when it can come. |
| `enemy_def.gd` | An enemy in data/acts/act<N>/enemies.json: its archetype and the one-line threat the fight card shows, and its kit. |
| `enemy_upgrade_def.gd` | An enemy upgrade: a small change an elite fight's enemies carry, one or two at a time, as a kit mod on the enemy's kit, with its word put before the enemy's name and the player's sentence for it. |
| `growth_def.gd` | How a card grows for the rest of the run: it counts something its holder does, the way a deed does, and every `per` of it is a step; the next fight gets the step's mod that many times over. |
| `hero_def.gd` | A hero in data/heroes/<hero>/hero.json: who they are, their main role, and their base kit. |
| `item_def.gd` | A thing for a hero's loadout slots. |
| `kit_mod.gd` | A change to a unit's kit, written against its slots rather than an ability's name: the one shape for upgrades, charms, sigils, gambits, relics, camp's modifiers, and enemy upgrades. |
| `kit_patch.gd` | Changes to a hero's base kit: what a path's vow or its transformation does to it. |
| `mana_def.gd` | A unit's mana bar. |
| `part_def.gd` | A passive: always on, part of a unit's kit. |
| `path_def.gd` | One of a hero's three paths, in data/heroes/<hero>/paths.json: what vowing to it does, what transforming into it does, and its deed. |
| `phase_def.gd` | One phase of a unit's kit: entered once, the first time the unit drops below `below_hp_bp` of its max HP while still standing. |
| `relic_def.gd` | A relic: team-wide, kept for the run, with no downsides. |
| `shape_def.gd` | An area's shape, measured in hexes. |
| `shop_rules_def.gd` | Shop rules: how the Pedlar and the boss shop price things for the team. |
| `side_rules.gd` | Rules of the fight one side plays by: the heroes' relics rewrite them. |
| `specialization_def.gd` | An enemy's specialization: a change to how the enemy plays, as a kit mod on its kit, with the word put before its name and the player's sentence for it. |
| `status_def.gd` | A status effect from data/core/statuses.json. |
| `tactic_def.gd` | A tactic in data/core/tactics.json: a change to how a hero behaves in a fight, never to what they can do. |
| `tithe_def.gd` | Tithe: shards the run pays after a won day fight, worked out from what the fight reports. |
| `transmute_def.gd` | Transmuting: turning an item the run owns into shards at the Pedlar or the boss shop, at its full price where selling pays half. |
| `trigger_def.gd` | What fires a signature. |
| `tuning_def.gd` | Global tuning values from data/core/tuning.json. |
| `unit_condition.gd` | "A unit that is ...": the one shape cards use to look at a unit's state. |
| `unit_def.gd` | A unit's kit, shared by heroes and enemies. |
| `unit_stats.gd` | A unit's six stats. |
| `upgrade_def.gd` | One upgrade from the after-fight pick: permanent, and a kit modifier written against the hero's slots, so it survives a transformation. |
