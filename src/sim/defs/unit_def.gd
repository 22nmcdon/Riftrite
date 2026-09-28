class_name UnitDef
extends RefCounted
## A unit's kit, shared by heroes and enemies (docs/plans/rebuild-phase1-arena-sim.md,
## section 2). HeroDef (paths, phase 4) and EnemyDef (threat line, archetype,
## phases, phase 2) will each wrap one.
##   {"id": "rift_hound", "name": "Rift Hound",
##    "stats": {"hp": 220, "atk": 16, "def": 6, "speed": 2, "range": 1},
##    "targeting": "nearest",
##    "mana": {...a ManaDef...},
##    "basic_attack": {...an AbilityDef...},
##    "signature": {...an AbilityDef with a trigger...},
##    "passives": [...PartDefs...]}
## Only a unit whose signature fires on mana has a mana bar, and it must have
## one. The basic attack, the signature, and the passives each need their own
## id.
##   "traits": ["engage", "flying", "hop_away"]
##       code paths a unit has (sections 4 and 6); hop_away needs
##       "hop_cooldown_ms" too

## A unit's own rule (section 4): Targeting.RULES but self.
const TARGETING_RULES: Array[String] = ["nearest", "weakest_backliner", "largest_group", "farthest", "lowest_hp_ally", "highest_mana"]
const TRAITS: Array[String] = ["engage", "flying", "hop_away"]

var id: String
var name: String
var stats: UnitStats
var targeting: String = "nearest"
## Null: no mana bar.
var mana: ManaDef = null
var basic_attack: AbilityDef
## Null: no signature.
var signature: AbilityDef = null
var passives: Array[PartDef] = []
var traits: Array[String] = []
## hop_away: how long between hops (0 without the trait).
var hop_cooldown_ticks: int = 0


static func read(reader: DataReader) -> UnitDef:
	var def := UnitDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	var stats_reader: DataReader = reader.req_object("stats")
	def.stats = UnitStats.read(stats_reader) if stats_reader != null else UnitStats.make(1)
	def.targeting = reader.opt_string_choice("targeting", "nearest", TARGETING_RULES)
	if reader.has("mana"):
		var mana_reader: DataReader = reader.req_object("mana")
		def.mana = ManaDef.read(mana_reader) if mana_reader != null else null
	var attack_reader: DataReader = reader.req_object("basic_attack")
	def.basic_attack = AbilityDef.read(attack_reader) if attack_reader != null else null
	if reader.has("signature"):
		var signature_reader: DataReader = reader.req_object("signature")
		def.signature = AbilityDef.read_signature(signature_reader) if signature_reader != null else null
	def.traits = reader.opt_choice_array("traits", TRAITS)
	if def.traits.has("hop_away"):
		def.hop_cooldown_ticks = reader.req_ticks("hop_cooldown_ms", FixedMath.MS_PER_TICK)
	elif reader.has("hop_cooldown_ms"):
		reader.error("hop_cooldown_ms: only a unit with the hop_away trait hops")
	for part_reader: DataReader in reader.opt_object_array("passives"):
		def.passives.append(PartDef.read(part_reader))
	var mana_signature: bool = def.signature != null and def.signature.trigger.kind == TriggerDef.Kind.MANA
	if mana_signature and def.mana == null:
		reader.error("a mana signature needs \"mana\"")
	if def.mana != null and not mana_signature:
		reader.error("\"mana\": only a unit whose signature fires on mana has a mana bar")
	var ids: Array[String] = []
	if def.basic_attack != null:
		ids.append(def.basic_attack.id)
	if def.signature != null:
		ids.append(def.signature.id)
	for part: PartDef in def.passives:
		ids.append(part.id)
	for i: int in ids.size():
		if ids.find(ids[i]) < i:
			reader.error("its abilities and passives need different ids (\"%s\" twice)" % ids[i])
	reader.finish()
	return def


## Every status its abilities and passives name (for FightSetup.validate).
func status_ids() -> Array[String]:
	var found: Array[String] = []
	var abilities: Array[AbilityDef] = [basic_attack, signature]
	for part: PartDef in passives:
		abilities.append(part.ability)
		if part.kind == PartDef.Kind.REPLACE_STATUS:
			found.append_array([part.from_status, part.to_status])
	for ability: AbilityDef in abilities:
		if ability == null:
			continue
		var effects: Array[EffectDef] = ability.effects.duplicate()
		for effect: EffectDef in ability.effects:
			effects.append_array(effect.area_effects)
		for effect: EffectDef in effects:
			if effect.type == EffectDef.Type.APPLY_STATUS:
				found.append(effect.status_id)
			found.append_array(effect.statuses)
	return found


func has_trait(trait_name: String) -> bool:
	return traits.has(trait_name)


func has_mana() -> bool:
	return mana != null
