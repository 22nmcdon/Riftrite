class_name UpgradeDef
extends RefCounted
## One upgrade from the after-fight pick (data/upgrades.json;
## docs/plans/rebuild-phase5-run.md, section 5): permanent, and a kit
## modifier written against the hero's slots, so it survives a
## transformation. Either a hero's (any path) or a path's:
##   {"id": "keen_eye", "name": "Keen Eye", "hero": "maren",
##    "text": "She crits a little more often.", "mod": {...KitMod...}}
##   {"id": "quick_footing", "name": "Quick Footing", "path": "deadeye",
##    "vow": true, "text": "...", "mod": {...}, "transformed_mod": {...}}
## A path's upgrade is offered once its hero has transformed, or from the vow
## on if it's a vow pick ("vow": true). A vow pick may give the mod its
## transformed kit takes ("transformed_mod"), since the taste's piece and the
## transformation's are different parts. A path's upgrade only counts while
## its hero is on that path. RunContent checks every mod against every kit it
## can meet.

enum Layer { HERO, PATH }

var id: String
var name: String
## The player's sentence.
var text: String
var layer: Layer
## The hero it's for (a path's upgrade: the path's hero, set by RunContent).
var hero: String = ""
## A path's upgrade: the path's id.
var path: String = ""
var vow: bool = false
var mod: KitMod
## A vow pick's mod once transformed (null: `mod`).
var transformed_mod: KitMod = null


static func read(reader: DataReader) -> UpgradeDef:
	var def := UpgradeDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.text = reader.req_string("text")
	if reader.has("hero") == reader.has("path"):
		reader.error("an upgrade is for a hero or for a path: give one of hero and path")
	if reader.has("hero"):
		def.layer = Layer.HERO
		def.hero = reader.req_string("hero")
	else:
		def.layer = Layer.PATH
		def.path = reader.opt_string("path", "")
	def.vow = reader.opt_bool("vow", false)
	if def.vow and def.layer != Layer.PATH:
		reader.error("only a path's upgrade can be a vow pick")
	var mod_reader: DataReader = reader.req_object("mod")
	if mod_reader != null:
		def.mod = KitMod.read(mod_reader)
	if reader.has("transformed_mod"):
		if not def.vow:
			reader.error("only a vow pick has a transformed_mod")
		var transformed_reader: DataReader = reader.req_object("transformed_mod")
		if transformed_reader != null:
			def.transformed_mod = KitMod.read(transformed_reader)
	reader.finish()
	return def


## The mod a hero on `stage_transformed` takes from this upgrade.
func mod_for(stage_transformed: bool) -> KitMod:
	if stage_transformed and transformed_mod != null:
		return transformed_mod
	return mod
