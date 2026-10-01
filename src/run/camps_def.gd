class_name CampsDef
extends RefCounted
## Camp's data (data/camps.json; docs/plans/rebuild-phase5-run.md, section 9,
## Decisions 8, 9, 13): the options' names and lines, the places and their
## menus, and camp's numbers; and the day's nodes (phase 5c step 8,
## docs/plans/days-and-nodes.md): their names, lines, and icons, and when
## the Magpie comes. What each option and node does is RunFlow's (one job
## each), so an id must be one of OPTIONS or NODES.

const OPTIONS: Array[String] = ["train", "hunt", "rest", "scout", "map_the_rift", "fortify", "dig_in", "shrine"]
const NODES: Array[String] = ["camp", "rift_tear", "magpie"]


class Option:
	var id: String
	var name: String
	## Its icon: a file under art/ui/ (phase 5b; RunContent checks it).
	var icon: String
	var text: String


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
	reader.finish()
	return def
