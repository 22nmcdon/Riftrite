class_name CampsDef
extends RefCounted
## Camp's data (data/camps.json; docs/plans/rebuild-phase5-run.md, section 9,
## Decisions 8, 9, 13): the options' names and lines, the places and their
## menus, and camp's numbers; and the day's nodes (phase 5c step 8,
## docs/plans/days-and-nodes.md): their names, lines, and icons, and when
## the Magpie comes. What each option and node does is RunFlow's (one job
## each), so an id must be one of OPTIONS or NODES. A Rift Tear's depths
## and the rift modifiers (phase 5c step 8b) are data here too.

const OPTIONS: Array[String] = ["train", "hunt", "rest", "scout", "map_the_rift", "fortify", "dig_in", "shrine"]
const NODES: Array[String] = ["camp", "rift_tear", "magpie"]


class Option:
	var id: String
	var name: String
	## Its icon: a file under art/ui/ (phase 5b; RunContent checks it).
	var icon: String
	var text: String


## A Rift Tear's depth (phase 5c step 8b): how many rift modifiers its
## fight takes, and the tiers of the relics a win offers (one each).
class Depth:
	var id: String
	var name: String
	var text: String
	var modifiers: int = 0
	var relics: Array[String] = []


## A rift modifier: a kit mod on every enemy and summon kit, one on the
## heroes, an early start for Rift Collapse, or Reinforcements.
class Modifier:
	var id: String
	var name: String
	var text: String
	var mod: KitMod = null
	var hero_mod: KitMod = null
	var collapse_from_ticks: int = 0
	var reinforce_ticks: int = 0
	var reinforce_count: int = 0


class Place:
	var id: String
	var name: String
	## Its node on the act map and at camp: a file under art/ui/.
	var icon: String
	var text: String
	var options: Array[String] = []


## How many options a camp shows.
var shown: int = 3
## The Magpie's node: from this day, at most this many times an act.
var magpie_from_day: int = 3
var magpie_per_act: int = 2
var options: Dictionary[String, Option] = {}
## The nodes' cards (an Option each: id, name, icon, line).
var nodes: Dictionary[String, Option] = {}
var places: Array[Place] = []
## Fortify's Shield on each hero, and a Rift Tear's upgrade on each enemy.
var fortify_mod: KitMod = null
var rift_tear_mod: KitMod = null
var depths: Array[Depth] = []
var modifiers: Dictionary[String, Modifier] = {}
var modifier_ids: Array[String] = []


func depth(depth_id: String) -> Depth:
	for found: Depth in depths:
		if found.id == depth_id:
			return found
	return null


static func read(reader: DataReader) -> CampsDef:
	var def := CampsDef.new()
	def.shown = reader.req_int("shown", 1, 6)
	def.magpie_from_day = reader.req_int("magpie_from_day", 1)
	def.magpie_per_act = reader.req_int("magpie_per_act", 0)
	for node_reader: DataReader in reader.opt_object_array("nodes"):
		var node := Option.new()
		node.id = node_reader.req_choice("id", NODES)
		node.name = node_reader.req_string("name")
		node.icon = node_reader.req_string("icon")
		node.text = node_reader.req_string("text")
		node_reader.finish()
		def.nodes[node.id] = node
	for id: String in NODES:
		if not def.nodes.has(id):
			reader.error("nodes: \"%s\" needs a name and a line" % id)
	for option_reader: DataReader in reader.opt_object_array("options"):
		var option := Option.new()
		option.id = option_reader.req_choice("id", OPTIONS)
		option.name = option_reader.req_string("name")
		option.icon = option_reader.req_string("icon")
		option.text = option_reader.req_string("text")
		option_reader.finish()
		if def.options.has(option.id):
			option_reader.error("duplicate option \"%s\"" % option.id)
		def.options[option.id] = option
	for id: String in OPTIONS:
		if not def.options.has(id):
			reader.error("options: \"%s\" needs a name and a line" % id)
	for place_reader: DataReader in reader.opt_object_array("places"):
		var place := Place.new()
		place.id = place_reader.req_string("id")
		place.name = place_reader.req_string("name")
		place.icon = place_reader.req_string("icon")
		place.text = place_reader.req_string("text")
		place.options = place_reader.req_string_array("options")
		for id: String in place.options:
			if not OPTIONS.has(id):
				place_reader.error("options: \"%s\" isn't a camp option a place can offer" % id)
		if place.options.size() < def.shown:
			place_reader.error("a place needs at least %d options" % def.shown)
		place_reader.finish()
		def.places.append(place)
	if def.places.is_empty():
		reader.error("camp needs places")
	for key: String in ["fortify_mod", "rift_tear_mod"]:
		var mod_reader: DataReader = reader.req_object(key)
		if mod_reader != null:
			def.set(key, KitMod.read(mod_reader))
	for depth_reader: DataReader in reader.opt_object_array("rift_depths"):
		var depth := Depth.new()
		depth.id = depth_reader.req_string("id")
		depth.name = depth_reader.req_string("name")
		depth.text = depth_reader.req_string("text")
		depth.modifiers = depth_reader.req_int("modifiers", 0, 3)
		depth.relics = depth_reader.req_string_array("relics")
		for tier: String in depth.relics:
			if not RelicDef.TIER_NAMES.has(tier) or tier == "boss" or tier == "bond":
				depth_reader.error("relics: \"%s\" isn't a tier a Rift Tear offers" % tier)
		depth_reader.finish()
		def.depths.append(depth)
	if def.depths.is_empty():
		reader.error("a Rift Tear needs its depths (rift_depths)")
	for modifier_reader: DataReader in reader.opt_object_array("rift_modifiers"):
		var modifier := Modifier.new()
		modifier.id = modifier_reader.req_string("id")
		modifier.name = modifier_reader.req_string("name")
		modifier.text = modifier_reader.req_string("text")
		if modifier_reader.has("mod"):
			modifier.mod = KitMod.read(modifier_reader.req_object("mod"))
		if modifier_reader.has("hero_mod"):
			modifier.hero_mod = KitMod.read(modifier_reader.req_object("hero_mod"))
		if modifier_reader.has("collapse_from_ms"):
			modifier.collapse_from_ticks = FixedMath.ms_to_ticks(modifier_reader.req_int("collapse_from_ms", 1000))
		if modifier_reader.has("reinforcements"):
			var reinforce_reader: DataReader = modifier_reader.req_object("reinforcements")
			modifier.reinforce_ticks = FixedMath.ms_to_ticks(reinforce_reader.req_int("at_ms", 50))
			modifier.reinforce_count = reinforce_reader.req_int("count", 1, 6)
			reinforce_reader.finish()
		var kinds: int = int(modifier.mod != null) + int(modifier.hero_mod != null) + int(modifier.collapse_from_ticks > 0) + int(modifier.reinforce_count > 0)
		if kinds != 1:
			modifier_reader.error("a rift modifier is one of mod, hero_mod, collapse_from_ms, or reinforcements")
		modifier_reader.finish()
		if def.modifiers.has(modifier.id):
			modifier_reader.error("duplicate rift modifier \"%s\"" % modifier.id)
		def.modifiers[modifier.id] = modifier
		def.modifier_ids.append(modifier.id)
	for depth: Depth in def.depths:
		if depth.modifiers > def.modifier_ids.size():
			reader.error("rift_depths: %s takes more modifiers than there are" % depth.id)
	reader.finish()
	return def
