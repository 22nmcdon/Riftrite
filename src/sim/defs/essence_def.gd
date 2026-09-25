class_name EssenceDef
extends RefCounted
## One of the base essences from data/essences.json: what it adds to an item
## when socketed. Spill (at Resonant) reuses these same effects and modifiers,
## scaled by the spill percentage in tuning.

var id: String
var name: String
var effects: Array[EffectDef] = []
var modifiers: Array[ModifierDef] = []


static func read(reader: DataReader) -> EssenceDef:
	var def := EssenceDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	for effect_reader: DataReader in reader.opt_object_array("effects"):
		def.effects.append(EffectDef.read(effect_reader))
	for modifier_reader: DataReader in reader.opt_object_array("modifiers"):
		def.modifiers.append(ModifierDef.read(modifier_reader))
	if def.effects.is_empty() and def.modifiers.is_empty():
		reader.error("an essence needs at least one effect or modifier")
	reader.finish()
	return def
