class_name TuningDef
extends RefCounted
## Global tuning values from data/tuning.json. Durations are stored in ticks
## (the file gives milliseconds). Percentages are basis points.

## Item tiers and hero ranks share one ladder: C, B, A, S (index 0-3).
const TIER_NAMES: Array[String] = ["c", "b", "a", "s"]
const TIER_LABELS: Array[String] = ["C", "B", "A", "S"]

var spill_single_bp: int
var spill_alloy_bp: int
var spill_pure_double_bp: int
var xp_to_attuned: int
var xp_to_resonant: int
var xp_per_battle: int
## How strong an infusion is at each level (Base, Attuned, Resonant).
var infusion_level_bp: Array[int] = []
var crit_damage_bp: int
## Item rarities with 2 sockets; every other item has 1, whatever its size.
var two_socket_rarities: Array[String] = []
var rush_end_ticks: int
var stall_start_ticks: int
var collapse_start_ticks: int
var collapse_surge_ticks: int
var tie_ticks: int
## Multiplier on an item's numbers per tier, indexed by tier (0 = C).
var tier_multiplier_bp: Array[int] = []
## Multiplier on a unit's stats per rank, indexed by rank (0 = C).
var rank_multiplier_bp: Array[int] = []
## Crit chance (bp) each CRIT point adds to every item the unit holds.
var crit_bp_per_point: int
## Auto-attack speed (bp) each ATSP point adds.
var atsp_bp_per_point: int
## Hit damage taken is multiplied by C / (C + DEF).
var defense_constant: int
## Essence conversion rule (docs/plans/essence-rework.md): how much of an
## item's output an essence adds as its own kind.
var convert_same_kind_bp: int
var convert_same_family_bp: int
var convert_direct_to_over_time_bp: int
var convert_over_time_to_direct_bp: int
## Share of each damage-over-time status a heal removes from its target.
var heal_cleanse_bp: int
## Heals within this window of each other strip less (see EffectRunner.heal).
var heal_cleanse_window_ticks: int
## Each further heal in the window strips this share of the previous heal's.
var heal_cleanse_falloff_bp: int
## Keyed by act number. Look up with collapse_for_act(); don't iterate.
var collapse_by_act: Dictionary[int, CollapseDef] = {}
## Run layer: stash size (slots, like a hero row), essence pouch cap, and the
## gold a reforge costs.
var stash_slots: int = 6
var pouch_cap: int = 8
var reforge_gold: int = 0


## Sockets an item has: 2 for the two-socket rarities, else 1.
func socket_count(item: ItemDef) -> int:
	return 2 if two_socket_rarities.has(item.rarity) else 1


static func read(reader: DataReader) -> TuningDef:
	var def := TuningDef.new()
	def.spill_single_bp = reader.req_int("spill_single_bp", 0, FixedMath.BP_ONE)
	def.spill_alloy_bp = reader.req_int("spill_alloy_bp", 0, FixedMath.BP_ONE)
	def.spill_pure_double_bp = reader.req_int("spill_pure_double_bp", 0, FixedMath.BP_ONE)
	def.xp_to_attuned = reader.req_int("xp_to_attuned", 1)
	def.xp_to_resonant = reader.req_int("xp_to_resonant", 1)
	def.xp_per_battle = reader.req_int("xp_per_battle", 0)
	var levels: DataReader = reader.req_object("infusion_level_bp")
	def.infusion_level_bp = [FixedMath.BP_ONE, FixedMath.BP_ONE, FixedMath.BP_ONE]
	if levels != null:
		def.infusion_level_bp = [levels.req_int("base", 0), levels.req_int("attuned", 0), levels.req_int("resonant", 0)]
		levels.finish()
	def.crit_damage_bp = reader.req_int("crit_damage_bp", FixedMath.BP_ONE)
	def.two_socket_rarities = reader.opt_choice_array("two_socket_rarities", ItemDef.RARITIES)
	def.tier_multiplier_bp = _read_tier_table(reader, "tier_multiplier_bp")
	def.rank_multiplier_bp = _read_tier_table(reader, "rank_multiplier_bp")
	def.crit_bp_per_point = reader.req_int("crit_bp_per_point", 0)
	def.atsp_bp_per_point = reader.req_int("atsp_bp_per_point", 0)
	def.defense_constant = reader.req_int("defense_constant", 1)
	def.convert_same_kind_bp = reader.req_int("convert_same_kind_bp", 0)
	def.convert_same_family_bp = reader.req_int("convert_same_family_bp", 0)
	def.convert_direct_to_over_time_bp = reader.req_int("convert_direct_to_over_time_bp", 0)
	def.convert_over_time_to_direct_bp = reader.req_int("convert_over_time_to_direct_bp", 0)
	def.heal_cleanse_bp = reader.req_int("heal_cleanse_bp", 0, FixedMath.BP_ONE)
	def.heal_cleanse_window_ticks = reader.req_ticks("heal_cleanse_window_ms")
	def.heal_cleanse_falloff_bp = reader.req_int("heal_cleanse_falloff_bp", 0, FixedMath.BP_ONE)
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

	var run: DataReader = reader.req_object("run")
	if run != null:
		def.stash_slots = run.req_int("stash_slots", 0)
		def.pouch_cap = run.req_int("pouch_cap", 0)
		def.reforge_gold = run.req_int("reforge_gold", 0)
		run.finish()

	if def.xp_to_resonant <= def.xp_to_attuned:
		reader.error("xp_to_resonant (%d) must be greater than xp_to_attuned (%d)" % [def.xp_to_resonant, def.xp_to_attuned])
	if def.collapse_surge_ticks < def.collapse_start_ticks:
		reader.error("collapse_surge_ms must not be earlier than collapse_start_ms")
	if def.tie_ticks <= def.collapse_start_ticks:
		reader.error("tie_ms must be later than collapse_start_ms")
	reader.finish()
	return def


## Reads {"c": .., "b": .., "a": .., "s": ..} into an array indexed by tier.
static func _read_tier_table(reader: DataReader, key: String) -> Array[int]:
	var table: Array[int] = [FixedMath.BP_ONE, FixedMath.BP_ONE, FixedMath.BP_ONE, FixedMath.BP_ONE]
	var tiers: DataReader = reader.req_object(key)
	if tiers == null:
		return table
	for i: int in TIER_NAMES.size():
		table[i] = tiers.req_int(TIER_NAMES[i], 1)
	tiers.finish()
	return table


## Returns the collapse numbers for an act, or null if that act has none.
func collapse_for_act(act: int) -> CollapseDef:
	return collapse_by_act.get(act, null)
