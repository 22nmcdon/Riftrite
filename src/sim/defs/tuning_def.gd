class_name TuningDef
extends RefCounted
## Global tuning values from data/tuning.json. Durations are stored in ticks
## (the file gives milliseconds). Percentages are basis points. The rebuild's
## arena sim (docs/plans/rebuild-phase1-arena-sim.md, section 12) adds the
## grid, movement, and collapse-ring values.

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


## Returns the collapse numbers for an act, or null if that act has none.
func collapse_for_act(act: int) -> CollapseDef:
	return collapse_by_act.get(act, null)
