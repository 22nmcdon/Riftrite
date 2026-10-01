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
##   "traits": ["engage", "flying", "hop_away", "fires_moving", "inert"]
##       code paths a unit has (sections 4 and 6); hop_away needs
##       "hop_cooldown_ms" too; fires_moving (phase 4, Volley): while it
##       walks, its basic attack fires at the nearest enemy in reach;
##       inert (phase 5, the Gloam Totem): it never targets, attacks, or
##       walks, though its signature and passives work (its basic attack
##       is never used)
##   "plant_ms": 1500
##       phase 4 (Deadeye's cost): after it moves, its basic attack waits
##       this long before it can fire
##   "placed_snares": 2
##       phase 4 (Trapper): the player places that many of its snares
##       before the fight (UnitSetup.snares); its kit needs a snare effect
##   "phases": [...PhaseDefs...]
##       changes to the kit as its HP drops (PhaseDef), from the highest
##       threshold down

## A unit's own rule (section 4): Targeting.RULES but self.
const TARGETING_RULES: Array[String] = ["nearest", "weakest_backliner", "largest_group", "farthest", "lowest_hp_ally", "highest_mana"]
const TRAITS: Array[String] = ["engage", "flying", "hop_away", "fires_moving", "inert"]

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
## hop_away: how long between hops (0 without the trait), and how near an
## enemy comes before it hops (plane units; Light Feet adds to it).
var hop_cooldown_ticks: int = 0
var hop_within: int = HexGrid.HEX
## The enemies it picks first, whatever its rule (a kit mod's; phase 5c step
## 6b, Bloodhound; null: none), and the name its picks are logged with.
var prefer: UnitCondition = null
var prefer_label: String = ""
## Its phases, highest threshold first (a phase's own kit has none).
var phases: Array[PhaseDef] = []
## An enemy's archetype (EnemyDef.ARCHETYPE_NAMES; set from its entry, so
## summons have theirs); "" for a hero. Tactics that prefer targets read it.
var archetype: String = ""
## After it moves, how long it needs before its basic attack can fire again
## (phase 4, Deadeye's cost; 0: none).
var plant_ticks: int = 0
## How many snares the player places for it before the fight (phase 4,
## transformed Trapper; 0: none). Its kit needs a snare effect.
var placed_snares: int = 0


## Reads a kit. A hero's or enemy's kit (HeroDef, EnemyDef) takes its id and
## name from the entry around it, so it has neither key.
static func read(reader: DataReader, kit_id: String = "", kit_name: String = "") -> UnitDef:
	var def := UnitDef.new()
	def.id = kit_id if not kit_id.is_empty() else reader.req_string("id")
	def.name = kit_name if not kit_name.is_empty() else reader.req_string("name")
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
	def.plant_ticks = reader.opt_ticks("plant_ms", 0)
	def.placed_snares = reader.opt_int("placed_snares", 0, 0, 4)
	for problem: String in def.problems():
		reader.error(problem)
	var kit: UnitDef = def
	var phase_ids: Array[String] = []
	for phase_reader: DataReader in reader.opt_object_array("phases"):
		var phase: PhaseDef = PhaseDef.read(phase_reader, kit)
		if not def.phases.is_empty() and phase.below_hp_bp >= def.phases.back().below_hp_bp:
			phase_reader.error("phases go from the highest threshold down")
		if phase_ids.has(phase.id):
			phase_reader.error("two phases are called \"%s\"" % phase.id)
		phase_ids.append(phase.id)
		def.phases.append(phase)
		kit = phase.kit
	reader.finish()
	return def


## What's wrong with the kit as a whole (empty when it's sound): a mana bar
## goes with a mana signature, and ids are unique.
func problems() -> Array[String]:
	var found: Array[String] = []
	var mana_signature: bool = signature != null and signature.trigger != null and signature.trigger.kind == TriggerDef.Kind.MANA
	if mana_signature and mana == null:
		found.append("a mana signature needs \"mana\"")
	if mana != null and not mana_signature:
		found.append("\"mana\": only a unit whose signature fires on mana has a mana bar")
	var ids: Array[String] = ability_ids()
	for i: int in ids.size():
		if ids.find(ids[i]) < i:
			found.append("its abilities and passives need different ids (\"%s\" twice)" % ids[i])
	return found


## The ids of its basic attack, signature, and passives.
func ability_ids() -> Array[String]:
	var ids: Array[String] = []
	if basic_attack != null:
		ids.append(basic_attack.id)
	if signature != null:
		ids.append(signature.id)
	for part: PartDef in passives:
		ids.append(part.id)
	return ids


## A copy to change (PhaseDef, KitPatch): the lists are its own, the parts shared,
## and it has no phases.
func copy() -> UnitDef:
	var other := UnitDef.new()
	other.id = id
	other.name = name
	other.stats = stats
	other.targeting = targeting
	other.mana = mana
	other.basic_attack = basic_attack
	other.signature = signature
	other.passives = passives.duplicate()
	other.traits = traits.duplicate()
	other.hop_cooldown_ticks = hop_cooldown_ticks
	other.hop_within = hop_within
	other.prefer = prefer
	other.prefer_label = prefer_label
	other.archetype = archetype
	other.plant_ticks = plant_ticks
	other.placed_snares = placed_snares
	return other


## Every status its abilities and passives name (for FightSetup.validate).
func status_ids() -> Array[String]:
	var found: Array[String] = []
	var parts: Array[PartDef] = passives.duplicate()
	for phase: PhaseDef in phases:
		parts.append_array(phase.passives)
	for part: PartDef in parts:
		if part.kind == PartDef.Kind.REPLACE_STATUS:
			found.append_array([part.from_status, part.to_status])

	for effect: EffectDef in all_effects():
		if effect.type == EffectDef.Type.APPLY_STATUS or effect.type == EffectDef.Type.EXTEND_STATUS:
			found.append(effect.status_id)
		found.append_array(effect.statuses)
	return found


## Every status its conditions look for (UnitCondition; phase 5c step 3):
## they must exist, but may be any status (an aura "vs" Engaged enemies is
## fine, though only the Engage trait sets it).
func condition_status_ids() -> Array[String]:
	var found: Array[String] = []
	var parts: Array[PartDef] = passives.duplicate()
	for phase: PhaseDef in phases:
		parts.append_array(phase.passives)
	for part: PartDef in parts:
		if part.kind == PartDef.Kind.AURA:
			for condition: UnitCondition in [part.aura.vs, part.aura.state]:
				if condition != null:
					found.append_array(condition.statuses)
	for effect: EffectDef in all_effects():
		if effect.vs != null:
			found.append_array(effect.vs.statuses)
		if not effect.stacks_of.is_empty():
			found.append(effect.stacks_of)
		found.append_array(effect.cleanse_statuses)
	return found


## The effects in its abilities and passives (an area's own effects
## included), and in those its phases bring.
func all_effects() -> Array[EffectDef]:
	var abilities: Array[AbilityDef] = [basic_attack, signature]
	for part: PartDef in passives:
		abilities.append(part.ability)
	for phase: PhaseDef in phases:
		abilities.append_array([phase.basic_attack, phase.signature])
		for part: PartDef in phase.passives:
			abilities.append(part.ability)
	var effects: Array[EffectDef] = []
	for ability: AbilityDef in abilities:
		if ability == null:
			continue
		for effect: EffectDef in ability.effects:
			effects.append(effect)
			effects.append_array(effect.area_effects)
	return effects


## The kits its summon effects name, in order (repeats included).
func summon_ids() -> Array[String]:
	var found: Array[String] = []
	for effect: EffectDef in all_effects():
		if effect.type == EffectDef.Type.SUMMON:
			found.append(effect.summon_kit)
	return found


func has_trait(trait_name: String) -> bool:
	return traits.has(trait_name)


func has_mana() -> bool:
	return mana != null
