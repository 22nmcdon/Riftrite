class_name UnitSetup
extends RefCounted
## One unit placed for a fight: its kit, its side, and the hex it starts on
## (docs/plans/rebuild-phase1-arena-sim.md, section 1).

var def: UnitDef
## Unique within the fight (FightSetup gives a second copy of a kit "#2").
var id: String
var side: EffectSource.Team
var col: int
var row: int


static func make(unit_def: UnitDef, unit_side: EffectSource.Team, at_col: int, at_row: int, unit_id: String = "") -> UnitSetup:
	var setup := UnitSetup.new()
	setup.def = unit_def
	setup.side = unit_side
	setup.col = at_col
	setup.row = at_row
	setup.id = unit_id if not unit_id.is_empty() else unit_def.id
	return setup
