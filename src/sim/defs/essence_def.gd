class_name EssenceDef
extends RefCounted
## One of the base essences from data/essences.json: what it adds to an item
## when socketed. Spill (at Resonant) reuses these same effects and modifiers,
## scaled by the spill percentage in tuning.
##
## An essence can do any of:
##   adds:      an output kind ("damage", "shield", "heal", or a damage-over-
##              time status id). Whenever the item produces output, the
##              essence adds its kind, sized by the conversion rule (see
##              Conversions). "adds_on": "crit" limits this to critical hits.
##   effects:   extra effects on the item (like Frost's Slow on hit)
##   modifiers: changes to the item's stats (like Storm's cooldown)

const DIRECT_KINDS: Array[String] = ["damage", "shield", "heal"]
const ADDS_ON_NAMES: Array[String] = ["any", "crit"]

var id: String
var name: String
## Output kind this essence adds, or "" if none.
var adds: String = ""
var adds_on_crit_only: bool = false
var effects: Array[EffectDef] = []
var modifiers: Array[ModifierDef] = []


static func read(reader: DataReader) -> EssenceDef:
	var def := EssenceDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	if reader.has("adds"):
		def.adds = reader.req_string("adds")
	def.adds_on_crit_only = reader.opt_string_choice("adds_on", "any", ADDS_ON_NAMES) == "crit"
	for effect_reader: DataReader in reader.opt_object_array("effects"):
		def.effects.append(EffectDef.read(effect_reader))
	for modifier_reader: DataReader in reader.opt_object_array("modifiers"):
		def.modifiers.append(ModifierDef.read(modifier_reader))
	if def.adds.is_empty() and def.effects.is_empty() and def.modifiers.is_empty():
		reader.error("an essence needs \"adds\", an effect, or a modifier")
	reader.finish()
	return def
