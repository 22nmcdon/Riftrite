class_name KitPatch
extends RefCounted
## Changes to a hero's base kit: what a path's vow (its taste and cost) or its
## transformation does to it (docs/plans/rebuild-phase4-paths.md, section 1).
## Every key is optional, but a patch changes something:
##   {"stats_bp": {"atk": 12000, "atsp": 8500},   multiplies HP, ATK, MGK,
##                                                 DEF, or ATSP (basis points)
##    "stats_add": {"crit": 6, "range": 1},        adds to CRIT, speed, or
##                                                 range (may be negative)
##    "basic_attack": {...an AbilityDef...},       replaces it
##    "signature": {...an AbilityDef with a trigger...},   replaces it
##    "mana": {...a ManaDef...},                   replaces the bar; null
##                                                 takes it away
##    "passives": [...PartDefs...],                added; one with a base
##                                                 passive's id replaces it
##    "remove_passives": ["hearthlight"],          base passives it takes away
##    "add_traits": ["fires_moving"],              traits it gains
##    "plant_ms": 1500,                            UnitDef's plant_ms
##    "placed_snares": 2,                          UnitDef's placed_snares
##    "hop_cooldown_ms": 5000,                     a hop_away unit's
##                                                 hop_cooldown_ms (phase 8)
##    "prefer": {"label": "Scent", "vs": {...UnitCondition...},
##               "within_hexes": 4}}               the enemies it picks first
##                                                 (UnitDef.prefer; phase 8
##                                                 part 4, Scent)
## Like a phase (PhaseDef), a new signature that doesn't fire on mana takes
## the bar away too. The patched kit must be sound (UnitDef.problems), with
## HP of at least 1, range of at least 1, and speed and CRIT of at least 0;
## ContentDb checks that against the hero's kit.

const BP_STATS: Array[UnitStats.Stat] = [UnitStats.Stat.HP, UnitStats.Stat.ATK, UnitStats.Stat.MGK, UnitStats.Stat.DEF, UnitStats.Stat.ATSP]
const ADD_STATS: Array[UnitStats.Stat] = [UnitStats.Stat.CRIT, UnitStats.Stat.SPEED, UnitStats.Stat.RANGE]

## Indexed by UnitStats.Stat: a multiplier in basis points (10000: none).
var stats_bp: Array[int] = []
## Indexed by UnitStats.Stat: added after the multipliers (0: none).
var stats_add: Array[int] = []
var basic_attack: AbilityDef = null
var signature: AbilityDef = null
var mana: ManaDef = null
## "mana": null.
var removes_mana: bool = false
var passives: Array[PartDef] = []
var remove_passives: Array[String] = []
var add_traits: Array[String] = []
## -1: unchanged.
var plant_ticks: int = -1
var placed_snares: int = -1
## A hop_away unit's cooldown (-1: unchanged; phase 8 part 2, Windrunner).
var hop_cooldown_ticks: int = -1
## The enemies it picks first (null: unchanged; phase 8 part 4, Scent).
var prefer: UnitCondition = null
var prefer_label: String = ""
var prefer_reach: int = 0


static func make() -> KitPatch:
	var patch := KitPatch.new()
	for i: int in UnitStats.STAT_NAMES.size():
		patch.stats_bp.append(FixedMath.BP_ONE)
		patch.stats_add.append(0)
	return patch


static func read(reader: DataReader) -> KitPatch:
	var patch: KitPatch = make()
	if reader.has("stats_bp"):
		var bp_reader: DataReader = reader.req_object("stats_bp")
		if bp_reader != null:
			for stat: UnitStats.Stat in BP_STATS:
				patch.stats_bp[stat] = bp_reader.opt_int(UnitStats.STAT_NAMES[stat], FixedMath.BP_ONE, 1000, 50000)
			bp_reader.finish()
	if reader.has("stats_add"):
		var add_reader: DataReader = reader.req_object("stats_add")
		if add_reader != null:
			for stat: UnitStats.Stat in ADD_STATS:
				patch.stats_add[stat] = add_reader.opt_int(UnitStats.STAT_NAMES[stat], 0, -10, 100)
			add_reader.finish()
	if reader.has("basic_attack"):
		var attack_reader: DataReader = reader.req_object("basic_attack")
		patch.basic_attack = AbilityDef.read(attack_reader) if attack_reader != null else null
	if reader.has("signature"):
		var signature_reader: DataReader = reader.req_object("signature")
		patch.signature = AbilityDef.read_signature(signature_reader) if signature_reader != null else null
	if reader.is_null("mana"):
		patch.removes_mana = true
	elif reader.has("mana"):
		var mana_reader: DataReader = reader.req_object("mana")
		patch.mana = ManaDef.read(mana_reader) if mana_reader != null else null
	for part_reader: DataReader in reader.opt_object_array("passives"):
		patch.passives.append(PartDef.read(part_reader))
	if reader.has("remove_passives"):
		patch.remove_passives = reader.req_string_array("remove_passives")
	if reader.has("add_traits"):
		patch.add_traits = reader.opt_choice_array("add_traits", ["engage", "flying", "fires_moving"])
	if reader.has("plant_ms"):
		patch.plant_ticks = reader.req_ticks("plant_ms", 0)
	if reader.has("placed_snares"):
		patch.placed_snares = reader.req_int("placed_snares", 0, 4)
	if reader.has("hop_cooldown_ms"):
		patch.hop_cooldown_ticks = reader.req_ticks("hop_cooldown_ms", FixedMath.MS_PER_TICK)
	if reader.has("prefer"):
		var prefer_reader: DataReader = reader.req_object("prefer")
		if prefer_reader != null:
			patch.prefer_label = prefer_reader.req_string("label")
			patch.prefer = UnitCondition.read(prefer_reader.req_object("vs"))
			patch.prefer_reach = prefer_reader.opt_int("within_hexes", 0, 0, 20) * HexGrid.HEX
			prefer_reader.finish()
	if not patch.changes_anything():
		reader.error("a patch needs stats_bp, stats_add, a basic_attack, a signature, mana, passives, remove_passives, add_traits, or plant_ms")
	reader.finish()
	return patch


func changes_anything() -> bool:
	for stat: int in stats_bp.size():
		if stats_bp[stat] != FixedMath.BP_ONE or stats_add[stat] != 0:
			return true
	return basic_attack != null or signature != null or mana != null or removes_mana or not passives.is_empty() or not remove_passives.is_empty() \
		or not add_traits.is_empty() or plant_ticks >= 0 or placed_snares >= 0 or hop_cooldown_ticks >= 0 or prefer != null


## `base` with the patch applied (a new UnitDef; `base` is untouched), and
## what's wrong with it in `problems`: passives to remove that it doesn't
## have, stats out of bounds, and UnitDef.problems.
func apply(base: UnitDef, problems: Array[String] = []) -> UnitDef:
	var built: UnitDef = base.copy()
	built.stats = base.stats.copy()
	for stat: int in built.stats.values.size():
		built.stats.values[stat] = FixedMath.apply_bp(built.stats.values[stat], stats_bp[stat]) + stats_add[stat]
	if built.stats.values[UnitStats.Stat.HP] < 1:
		problems.append("its HP would drop below 1")
	if built.stats.values[UnitStats.Stat.RANGE] < 1:
		problems.append("its range would drop below 1")
	for stat: UnitStats.Stat in [UnitStats.Stat.CRIT, UnitStats.Stat.SPEED]:
		if built.stats.values[stat] < 0:
			problems.append("its %s would drop below 0" % UnitStats.LABELS[stat])
	if basic_attack != null:
		built.basic_attack = basic_attack
	if signature != null:
		built.signature = signature
	if removes_mana:
		built.mana = null
	elif mana != null:
		built.mana = mana
	elif signature != null and signature.trigger.kind != TriggerDef.Kind.MANA:
		built.mana = null
	for part_id: String in remove_passives:
		var at: int = -1
		for i: int in built.passives.size():
			if built.passives[i].id == part_id:
				at = i
		if at < 0:
			problems.append("it has no passive \"%s\" to remove" % part_id)
		else:
			built.passives.remove_at(at)
	for trait_name: String in add_traits:
		if built.traits.has(trait_name):
			problems.append("it already has the trait %s" % trait_name)
		else:
			built.traits.append(trait_name)
	if plant_ticks >= 0:
		built.plant_ticks = plant_ticks
	if placed_snares >= 0:
		built.placed_snares = placed_snares
	if hop_cooldown_ticks >= 0:
		if built.hop_cooldown_ticks <= 0:
			problems.append("only a unit that hops away has a hop cooldown")
		else:
			built.hop_cooldown_ticks = hop_cooldown_ticks
	if prefer != null:
		built.prefer = prefer
		built.prefer_label = prefer_label
		built.prefer_reach = prefer_reach
	if built.placed_snares > 0 and Snares.placed_effect(built) == null:
		problems.append("it places snares, so its kit needs a snare effect")
	for part: PartDef in passives:
		var replaced: bool = false
		for i: int in built.passives.size():
			if built.passives[i].id == part.id:
				built.passives[i] = part
				replaced = true
				break
		if not replaced:
			built.passives.append(part)
	problems.append_array(built.problems())
	return built
