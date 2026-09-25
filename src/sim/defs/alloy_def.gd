class_name AlloyDef
extends RefCounted
## A named alloy from data/alloys.json: what two essences in one item do on
## top of both essences' normal effects. The recipe is unordered (socket order
## only decides spill direction).
##
## An alloy can:
##   replaces:  {"burn": "golden_flame"} - any of these statuses the item would
##              apply (its own effects or its essences' conversions) is applied
##              as the other status instead. This keeps alloy behavior off
##              other items' plain Burn/Bleed.
##   heal_echo_bp: every heal from the item echoes this share of itself onto
##              a random other ally. Echoes don't echo.
## Alloy specials never spill (design rule).

var id: String
var name: String
## Sorted essence ids.
var recipe: Array[String] = []
## Keyed by the status the item would apply. Looked up, never iterated.
var replaces: Dictionary[String, String] = {}
var heal_echo_bp: int = 0


static func read(reader: DataReader) -> AlloyDef:
	var def := AlloyDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.recipe = reader.req_string_array("recipe")
	if def.recipe.size() != 2:
		reader.error("recipe needs exactly two essences")
	def.recipe.sort()
	if reader.has("replaces"):
		var replaces_reader: DataReader = reader.req_object("replaces")
		if replaces_reader != null:
			for status_id: String in replaces_reader.map_keys():
				def.replaces[status_id] = replaces_reader.req_string(status_id)
			replaces_reader.finish()
	def.heal_echo_bp = reader.opt_int("heal_echo_bp", 0, 0, FixedMath.BP_ONE)
	if def.replaces.is_empty() and def.heal_echo_bp == 0:
		reader.error("an alloy needs \"replaces\" or \"heal_echo_bp\"")
	reader.finish()
	return def


## Key for looking an alloy up by its two essences, in either order.
static func recipe_key(first: String, second: String) -> String:
	return "%s+%s" % [first, second] if first <= second else "%s+%s" % [second, first]
