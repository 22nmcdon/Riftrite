class_name PhaseDef
extends RefCounted
## One phase of an enemy (usually a boss): entered once, the first time the
## enemy drops below `below_hp_bp` of its max HP while still standing. A
## phase is a list of parts, the same kinds a specialization uses (aura,
## grant, ability, basic_attack, replace_status; see SpecializationDef). A
## part with the same key as an earlier phase's replaces it; a new key adds.
## An ability's on_fight_start effects run when the phase begins.
##   {"name": "Molt", "below_hp_bp": 6000, "parts": [ ... ]}

const PART_KINDS: Array[SpecializationDef.Kind] = [
	SpecializationDef.Kind.AURA, SpecializationDef.Kind.GRANT, SpecializationDef.Kind.ABILITY,
	SpecializationDef.Kind.BASIC_ATTACK, SpecializationDef.Kind.REPLACE_STATUS,
]

var name: String
var below_hp_bp: int
var parts: Array[SpecializationDef.Part] = []


static func read(reader: DataReader, enemy_id: String) -> PhaseDef:
	var def := PhaseDef.new()
	def.name = reader.req_string("name")
	def.below_hp_bp = reader.req_int("below_hp_bp", 1, FixedMath.BP_ONE - 1)
	var keys: Array[String] = []
	for part_reader: DataReader in reader.opt_object_array("parts"):
		var part: SpecializationDef.Part = SpecializationDef.read_part(part_reader, def.name, "%s_%s" % [enemy_id, def.name.to_snake_case()])
		if not PART_KINDS.has(part.kind):
			part_reader.error("a phase can't have a %s part" % SpecializationDef.KIND_NAMES[part.kind])
		if part.when != SpecializationDef.When.FIELDED:
			part_reader.error("phase parts always apply on the field (no \"when\")")
		if keys.has(part.key):
			part_reader.error("key \"%s\" is used twice in this phase" % part.key)
		keys.append(part.key)
		def.parts.append(part)
	if def.parts.is_empty():
		reader.error("a phase needs parts")
	reader.finish()
	return def
