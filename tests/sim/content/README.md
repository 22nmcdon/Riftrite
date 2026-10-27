# tests/sim/content/

Loading and checking content: `ContentDb` (and that every file in `data/` is read), effect and tactic definitions, kits and their text, paths and apexes as kits, and kit mods.

## Files

| File | What it is |
| --- | --- |
| `test_apex_kits.gd` | Apexes in the sim: a path's apexes load and build their kits on the transformed kit, a hero takes one through Encounters.setup at the apex vowed or apex stage, the setup's checks, a transformed hero counts its path's apexes' deeds, and Hailstorm's pieces... |
| `test_content_db.gd` | ContentDb loading and validation of tuning and statuses. |
| `test_effect_defs.gd` | The effect vocabulary that survived the rebuild's gut: EffectDef and AuraDef read from data. |
| `test_hero_kits.gd` | The base kits in data/heroes/<hero>/hero.json do what their text says. |
| `test_kit_mods.gd` | Kit modifiers and wounds: each change on each slot, what a mod affects, that the content it reads is never changed, and that a fight takes them through Encounters.setup. |
| `test_path_kits.gd` | The nine paths as data: each hero's three, in the design's order; every ability's sentence names its reaches and has a numbers line; each path's kits carry what its texts say; and each taste fills its deed where the base kit barely does. |
| `test_paths.gd` | Paths and stages: reading a path, building its vowed and transformed kits from the hero's base kit, the checks across files, and a fight's setup taking a hero's vow and stage. |
| `test_tactic_defs.gd` | data/core/tactics.json and tactics in a fight's setup: reading each kind, the checks across files, enemies' archetypes on their kits, and Encounters and FightSetup taking a hero's tactic. |
| `test_units_content.gd` | heroes.json, enemies.json, and encounters.json: reading them, and the checks across files. |
