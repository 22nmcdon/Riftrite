class_name PhaseDef
extends RefCounted
## One phase of a unit's kit (docs/plans/rebuild-phase1-arena-sim.md,
## section 3; mostly for bosses): entered once, the first time the unit drops
## below `below_hp_bp` of its max HP while still standing (Phases). It
## changes the kit from then on:
##   {"id": "molt", "name": "Molt", "below_hp_bp": 6000,
##    "signature": {...an AbilityDef with a trigger...},   replaces it
##    "mana": {...a ManaDef...},                            replaces the bar
##    "basic_attack": {...an AbilityDef...},                replaces it
##    "targeting": "largest_group",                         replaces the rule
##    "passives": [...PartDefs...]}                         added; one with an
##                                                          earlier passive's
##                                                          id replaces it
## Each phase needs at least one of these. A kit's phases go from the highest
## threshold down, and each builds on the one before (`kit`), which must be
## a valid kit itself: a mana signature needs a bar, a bar needs a mana
## signature (a new signature that isn't one takes the bar away), and ids
## stay unique. A new signature starts fresh: a fight_start one fires as the
## phase begins.

var id: String
var name: String
var below_hp_bp: int
## What the phase gives (null or empty: unchanged).
var signature: AbilityDef = null
var mana: ManaDef = null
var basic_attack: AbilityDef = null
var targeting: String = ""
var passives: Array[PartDef] = []
## The whole kit once this phase (and every one before it) has begun.
var kit: UnitDef


## Reads a phase that follows `before` (the kit as the previous phase left
## it), and builds its kit.
static func read(reader: DataReader, before: UnitDef) -> PhaseDef:
	var def := PhaseDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.below_hp_bp = reader.req_int("below_hp_bp", 1, FixedMath.BP_ONE - 1)
	if reader.has("signature"):
		var signature_reader: DataReader = reader.req_object("signature")
		def.signature = AbilityDef.read_signature(signature_reader) if signature_reader != null else null
	if reader.has("mana"):
		var mana_reader: DataReader = reader.req_object("mana")
		def.mana = ManaDef.read(mana_reader) if mana_reader != null else null
	if reader.has("basic_attack"):
		var attack_reader: DataReader = reader.req_object("basic_attack")
		def.basic_attack = AbilityDef.read(attack_reader) if attack_reader != null else null
	def.targeting = reader.opt_string_choice("targeting", "", UnitDef.TARGETING_RULES)
	for part_reader: DataReader in reader.opt_object_array("passives"):
		def.passives.append(PartDef.read(part_reader))
	if def.signature == null and def.mana == null and def.basic_attack == null and def.targeting.is_empty() and def.passives.is_empty():
		reader.error("a phase needs a signature, mana, a basic_attack, a targeting rule, or passives")
	def.kit = def._build(before)
	for problem: String in def.kit.problems():
		reader.error(problem)
	reader.finish()
	return def


## `before` with this phase's changes (a new UnitDef; `before` is untouched).
func _build(before: UnitDef) -> UnitDef:
	var built: UnitDef = before.copy()
	if signature != null:
		built.signature = signature
	if basic_attack != null:
		built.basic_attack = basic_attack
	if not targeting.is_empty():
		built.targeting = targeting
	if mana != null:
		built.mana = mana
	elif signature != null and signature.trigger.kind != TriggerDef.Kind.MANA:
		built.mana = null
	for part: PartDef in passives:
		var replaced: bool = false
		for i: int in built.passives.size():
			if built.passives[i].id == part.id:
				built.passives[i] = part
				replaced = true
				break
		if not replaced:
			built.passives.append(part)
	return built
