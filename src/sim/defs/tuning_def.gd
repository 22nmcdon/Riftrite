class_name TuningDef
extends RefCounted
## Global tuning values from data/tuning.json. Durations are stored in ticks
## (the file gives milliseconds). Percentages are basis points. The rebuild's
## arena sim (docs/plans/rebuild-phase1-arena-sim.md, section 12) adds the
## grid, movement, and collapse-ring values.

## The placement board (HexGrid).
var grid_width: int = 8
var grid_height: int = 7
var zone_rows: int = 3
## Circles on the plane (1 hex = 1000), and the pathfinding cell size.
var unit_radius: int = 400
var rock_radius: int = 500
var nav_cell: int = 125
## A walker looks for a new route this often, and gives up on a target it
## can't reach for this long.
## Engage: how close an enemy must be to be next to an engager, and how long
## it takes to break free.
var engage_reach: int = 1000
var break_free_ticks: int = 20
var repath_ticks: int
var repath_give_up_ticks: int
## Standing units per side, summons included.
var max_units_per_side: int = 30
var crit_damage_bp: int
var collapse_start_ticks: int
var collapse_surge_ticks: int
var tie_ticks: int
## Crit chance (bp) each CRIT point adds to every ability the unit has.
var crit_bp_per_point: int
## Attack speed (bp) each ATSP point adds.
var atsp_bp_per_point: int
## Hit damage taken is multiplied by C / (C + DEF).
var defense_constant: int
## Share of each damage-over-time status a heal removes from its target.
var heal_cleanse_bp: int
## Heals within this window of each other strip less.
var heal_cleanse_window_ticks: int
## Each further heal in the window strips this share of the previous heal's.
var heal_cleanse_falloff_bp: int
## Keyed by act number. Look up with collapse_for_act(); don't iterate.
var collapse_by_act: Dictionary[int, CollapseDef] = {}


static func read(reader: DataReader) -> TuningDef:
	var def := TuningDef.new()
	var grid: DataReader = reader.req_object("grid")
	if grid != null:
		def.grid_width = grid.req_int("width", 1, 64)
		def.grid_height = grid.req_int("height", 3, 64)
		def.zone_rows = grid.req_int("zone_rows", 1, 32)
		if def.grid_height <= 2 * def.zone_rows:
			grid.error("height must leave a neutral row between the two zones")
		grid.finish()
	def.unit_radius = reader.req_int("unit_radius", 1, 1000)
	def.rock_radius = reader.req_int("rock_radius", 1, 1000)
	def.nav_cell = reader.req_int("nav_cell", 25, 1000)
	def.engage_reach = reader.req_int("engage_reach", 1)
	def.break_free_ticks = reader.req_ticks("break_free_ms", FixedMath.MS_PER_TICK)
	def.repath_ticks = reader.req_ticks("repath_ms", FixedMath.MS_PER_TICK)
	def.repath_give_up_ticks = reader.req_ticks("repath_give_up_ms", FixedMath.MS_PER_TICK)
	def.max_units_per_side = reader.req_int("max_units_per_side", 1)
	def.crit_damage_bp = reader.req_int("crit_damage_bp", FixedMath.BP_ONE)
	def.crit_bp_per_point = reader.req_int("crit_bp_per_point", 0)
	def.atsp_bp_per_point = reader.req_int("atsp_bp_per_point", 0)
	def.defense_constant = reader.req_int("defense_constant", 1)
	def.heal_cleanse_bp = reader.req_int("heal_cleanse_bp", 0, FixedMath.BP_ONE)
	def.heal_cleanse_window_ticks = reader.req_ticks("heal_cleanse_window_ms")
	def.heal_cleanse_falloff_bp = reader.req_int("heal_cleanse_falloff_bp", 0, FixedMath.BP_ONE)
	def.collapse_start_ticks = reader.req_ticks("collapse_start_ms")
	def.collapse_surge_ticks = reader.req_ticks("collapse_surge_ms")
	def.tie_ticks = reader.req_ticks("tie_ms", 1)

	var acts: DataReader = reader.req_object("collapse_by_act")
	if acts != null:
		for key: String in acts.map_keys():
			if not key.is_valid_int() or key.to_int() < 1:
				acts.error("act \"%s\" must be a whole number, 1 or higher" % key)
				continue
			var act_reader: DataReader = acts.req_object(key)
			if act_reader != null:
				def.collapse_by_act[key.to_int()] = CollapseDef.read(act_reader, key.to_int())
		if not def.collapse_by_act.has(1):
			acts.error("must define act \"1\"")
		acts.finish()

	if def.collapse_surge_ticks < def.collapse_start_ticks:
		reader.error("collapse_surge_ms must not be earlier than collapse_start_ms")
	if def.tie_ticks <= def.collapse_start_ticks:
		reader.error("tie_ms must be later than collapse_start_ms")
	reader.finish()
	return def


## The placement board these values describe.
func make_grid() -> HexGrid:
	return HexGrid.make(grid_width, grid_height, zone_rows)


## Returns the collapse numbers for an act, or null if that act has none.
func collapse_for_act(act: int) -> CollapseDef:
	return collapse_by_act.get(act, null)
