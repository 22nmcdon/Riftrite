class_name TuningDef
extends RefCounted
## Global tuning values from data/tuning.json. Durations are stored in ticks
## (the file gives milliseconds). Percentages are basis points.

var spill_single_bp: int
var spill_alloy_bp: int
var spill_pure_double_bp: int
var xp_to_attuned: int
var xp_to_resonant: int
var xp_per_battle: int
var crit_damage_bp: int
var rush_end_ticks: int
var stall_start_ticks: int
var collapse_start_ticks: int
var collapse_surge_ticks: int
var tie_ticks: int
## Keyed by act number. Look up with collapse_for_act(); don't iterate.
var collapse_by_act: Dictionary[int, CollapseDef] = {}


static func read(reader: DataReader) -> TuningDef:
	var def := TuningDef.new()
	def.spill_single_bp = reader.req_int("spill_single_bp", 0, FixedMath.BP_ONE)
	def.spill_alloy_bp = reader.req_int("spill_alloy_bp", 0, FixedMath.BP_ONE)
	def.spill_pure_double_bp = reader.req_int("spill_pure_double_bp", 0, FixedMath.BP_ONE)
	def.xp_to_attuned = reader.req_int("xp_to_attuned", 1)
	def.xp_to_resonant = reader.req_int("xp_to_resonant", 1)
	def.xp_per_battle = reader.req_int("xp_per_battle", 0)
	def.crit_damage_bp = reader.req_int("crit_damage_bp", FixedMath.BP_ONE)
	def.rush_end_ticks = reader.req_ticks("rush_end_ms")
	def.stall_start_ticks = reader.req_ticks("stall_start_ms")
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

	if def.xp_to_resonant <= def.xp_to_attuned:
		reader.error("xp_to_resonant (%d) must be greater than xp_to_attuned (%d)" % [def.xp_to_resonant, def.xp_to_attuned])
	if def.collapse_surge_ticks < def.collapse_start_ticks:
		reader.error("collapse_surge_ms must not be earlier than collapse_start_ms")
	if def.tie_ticks <= def.collapse_start_ticks:
		reader.error("tie_ms must be later than collapse_start_ms")
	reader.finish()
	return def


## Returns the collapse numbers for an act, or null if that act has none.
func collapse_for_act(act: int) -> CollapseDef:
	return collapse_by_act.get(act, null)
