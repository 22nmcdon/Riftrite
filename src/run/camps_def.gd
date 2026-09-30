class_name CampsDef
extends RefCounted
## Camp's data (data/camps.json; docs/plans/rebuild-phase5-run.md, section 9,
## Decisions 8, 9, 13): the options' names and lines, the places and their
## menus, and camp's numbers. What each option does is RunFlow's (one job
## each), so an option's id must be one of OPTIONS.

const OPTIONS: Array[String] = ["train", "hunt", "pedlar", "rest", "scout", "map_the_rift", "fortify", "dig_in", "rift_tear", "shrine", "magpie"]


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
## The days the Magpie may come on (one of them, drawn at the run's start).
var magpie_days: Array[int] = []
## How often (percent) the Pedlar also carries a relic.
var pedlar_relic_pct: int = 0
var options: Dictionary[String, Option] = {}
var places: Array[Place] = []
## Fortify's Shield on each hero, and a Rift Tear's upgrade on each enemy.
var fortify_mod: KitMod = null
var rift_tear_mod: KitMod = null


static func read(reader: DataReader) -> CampsDef:
	var def := CampsDef.new()
	def.shown = reader.req_int("shown", 1, 6)
	def.magpie_days = reader.req_int_array("magpie_days")
	def.pedlar_relic_pct = reader.req_int("pedlar_relic_pct", 0, 100)
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
			if not OPTIONS.has(id) or id == "magpie":
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
