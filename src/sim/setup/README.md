# src/sim/setup/

What a fight starts from: `FightSetup` and `UnitSetup` (units on hexes, rocks, water, void, the seed), `HeroExtras` (a run's mods and wounds), and `Encounters.setup`, which builds a setup from content.

## Files

| File | What it is |
| --- | --- |
| `encounters.gd` | Builds a fight from content: the heroes on a formation's hexes, and an encounter's enemies and rocks. |
| `fight_setup.gd` | Everything a fight starts from: both sides placed on the board, the rocks, the seed, and the act. |
| `hero_extras.gd` | What a hero brings into a fight beyond its path and tactic: kit modifiers, applied in this order after the path's patch, and its wounds. |
| `unit_setup.gd` | One unit placed for a fight: its kit, its side, the hex it starts on, and a hero's tactic, if it took one. |
