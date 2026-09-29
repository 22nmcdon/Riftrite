class_name UnitSetup
extends RefCounted
## One unit placed for a fight: its kit, its side, the hex it starts on
## (docs/plans/rebuild-phase1-arena-sim.md, section 1), and a hero's tactic,
## if it took one (docs/plans/rebuild-phase3b-tactics.md, section 3). A hero
## on a path (docs/plans/rebuild-phase4-paths.md, section 2) has that path's
## kit at its stage as `def`, and counts the deeds of `deed_paths`.

var def: UnitDef
## Unique within the fight (FightSetup gives a second copy of a kit "#2").
var id: String
var side: EffectSource.Team
var col: int
var row: int
## Null: no tactic (the fight is exactly as it would be without tactics).
var tactic: TacticDef = null
## Null: no path (the base kit, stage base).
var path: PathDef = null
var stage: PathDef.Stage = PathDef.Stage.BASE
## The paths whose deeds it counts (a hero's three, whatever its stage;
## empty: it counts none).
var deed_paths: Array[PathDef] = []


static func make(unit_def: UnitDef, unit_side: EffectSource.Team, at_col: int, at_row: int, unit_id: String = "") -> UnitSetup:
	var setup := UnitSetup.new()
	setup.def = unit_def
	setup.side = unit_side
	setup.col = at_col
	setup.row = at_row
	setup.id = unit_id if not unit_id.is_empty() else unit_def.id
	return setup
