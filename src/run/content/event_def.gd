class_name EventDef
extends RefCounted
## The Event node's data (data/events.json; phase 5c step 8c,
## docs/plans/events.md, rebuild-phase5c-combos.md section 16.7): the
## scenes, each with its choices and their results, and the Bloodied Oath's
## oaths. What each result does is RunFlow's (one job each, like camp's
## options), so a result's "do" must be one of RESULTS. Leaving the node
## without a choice is walking away, always free.

const RESULTS: Array[String] = ["item", "wound", "clear_wounds", "relic", "dear_shop", "pay", "gain", "deed", "next_fight", "seal",
	"rank_up_random", "rank_up_chosen", "weaken", "hunt", "mirror", "nothing"]
## What a choice needs the player to pick, from its results.
enum Needs { NOTHING, HERO, ITEM, PATH }


## One result of a choice.
class Result:
	var kind: String
	## item: the kinds drawn from, their rank, and how many.
	var kinds: Array[String] = []
	var rank: int = 1
	var count: int = 1
	## relic: its tier, or "shop_odds".
	var tier: String = ""
	## dear_shop and weaken: the factor; deed: the share of the threshold.
	var bp: int = FixedMath.BP_ONE
	## pay and gain.
	var shards: int = 0
	## next_fight: the mod's name (EventDef.next_fight_mods), and whether
	## it's on the whole team rather than a hero you choose.
	var mod: String = ""
	var team: bool = false


class Choice:
	var id: String
	var label: String
	var text: String
	var results: Array[Result] = []

	## What the player picks for it: a hero (a wound, a deed, a hero's next
	## fight), an item (one ranked up), or a hero and a path (the mirror).
	func needs() -> Needs:
		for result: Result in results:
			match result.kind:
				"mirror":
					return Needs.PATH
				"rank_up_chosen":
					return Needs.ITEM
				"wound", "deed":
					return Needs.HERO
				"next_fight":
					if not result.team:
						return Needs.HERO
		return Needs.NOTHING

	func has(kind: String) -> bool:
		return results.any(func(result: Result) -> bool: return result.kind == kind)

	func result(kind: String) -> Result:
		for found: Result in results:
			if found.kind == kind:
				return found
		return null


class Scene:
	var id: String
	var name: String
	var text: String
	var choices: Array[Choice] = []


## An oath: its burden and reward on its hero for its next oath_fights day
## fights. `mod` holds both stat sides (and drops_signature); the rest are
## the rules the run keeps.
class Oath:
	var id: String
	var name: String
	var burden: String
	var reward: String
	var mod: KitMod = null
	var deed_bp: int = FixedMath.BP_ONE
	var front_row: bool = false
	var no_tactic: bool = false
	var fall_wounds: int = 1


var oath_pct: int = 25
var oath_fights: int = 2
var next_fight_mods: Dictionary[String, KitMod] = {}
var scenes: Array[Scene] = []
var oaths: Array[Oath] = []


func scene(scene_id: String) -> Scene:
	for found: Scene in scenes:
		if found.id == scene_id:
			return found
	return null


func oath(oath_id: String) -> Oath:
	for found: Oath in oaths:
		if found.id == oath_id:
			return found
	return null


static func read(reader: DataReader) -> EventDef:
	var def := EventDef.new()
	def.oath_pct = reader.req_int("oath_pct", 0, 100)
	def.oath_fights = reader.req_int("oath_fights", 1)
	var mods_reader: DataReader = reader.req_object("next_fight_mods")
	if mods_reader != null:
		for key: String in mods_reader.map_keys():
			def.next_fight_mods[key] = KitMod.read(mods_reader.req_object(key))
		mods_reader.finish()
	for scene_reader: DataReader in reader.opt_object_array("scenes"):
		var scene := Scene.new()
		scene.id = scene_reader.req_string("id")
		scene.name = scene_reader.req_string("name")
		scene.text = scene_reader.req_string("text")
		for choice_reader: DataReader in scene_reader.opt_object_array("choices"):
			var choice := Choice.new()
			choice.id = choice_reader.req_string("id")
			choice.label = choice_reader.req_string("label")
			choice.text = choice_reader.req_string("text")
			for result_reader: DataReader in choice_reader.opt_object_array("results"):
				choice.results.append(_read_result(def, result_reader))
			if choice.results.is_empty():
				choice_reader.error("a choice needs its results")
			choice_reader.finish()
			scene.choices.append(choice)
		if scene.choices.is_empty():
			scene_reader.error("a scene needs choices")
		scene_reader.finish()
		if def.scene(scene.id) != null:
			scene_reader.error("duplicate scene \"%s\"" % scene.id)
		def.scenes.append(scene)
	for oath_reader: DataReader in reader.opt_object_array("oaths"):
		var oath := Oath.new()
		oath.id = oath_reader.req_string("id")
		oath.name = oath_reader.req_string("name")
		oath.burden = oath_reader.req_string("burden")
		oath.reward = oath_reader.req_string("reward")
		oath.deed_bp = oath_reader.opt_int("deed_bp", FixedMath.BP_ONE, FixedMath.BP_ONE)
		oath.front_row = oath_reader.opt_bool("front_row", false)
		oath.no_tactic = oath_reader.opt_bool("no_tactic", false)
		oath.fall_wounds = oath_reader.opt_int("fall_wounds", 1, 1, 3)
		if oath_reader.has("mod"):
			oath.mod = KitMod.read(oath_reader.req_object("mod"))
		oath_reader.finish()
		def.oaths.append(oath)
	if def.oaths.size() < 2:
		reader.error("a Bloodied Oath offers 2 oaths, so it needs at least 2")
	reader.finish()
	return def


static func _read_result(def: EventDef, reader: DataReader) -> Result:
	var result := Result.new()
	result.kind = reader.req_choice("do", RESULTS)
	match result.kind:
		"item":
			result.kinds = reader.req_string_array("kinds")
			for kind: String in result.kinds:
				if not ItemDef.KIND_NAMES.has(kind):
					reader.error("kinds: unknown item kind \"%s\"" % kind)
			result.rank = reader.opt_int("rank", 1, 1, 3)
			result.count = reader.opt_int("count", 1, 1, 4)
		"relic":
			result.tier = reader.req_string("tier")
			if result.tier != "shop_odds" and (not RelicDef.TIER_NAMES.has(result.tier) or result.tier == "boss" or result.tier == "bond"):
				reader.error("tier: \"%s\" isn't a tier an event gives" % result.tier)
		"dear_shop", "weaken":
			result.bp = reader.req_int("bp", 1)
		"deed":
			result.bp = reader.req_int("share_bp", 1, FixedMath.BP_ONE)
		"pay", "gain":
			result.shards = reader.req_int("shards", 1)
		"next_fight":
			result.mod = reader.req_string("mod")
			result.team = reader.opt_bool("team", false)
			if not def.next_fight_mods.has(result.mod):
				reader.error("mod: no next_fight_mods \"%s\"" % result.mod)
	reader.finish()
	return result


## The Old Well's cut on max HP (its weaken result's factor), for each drink.
func weaken_bp() -> int:
	for scene: Scene in scenes:
		for choice: Choice in scene.choices:
			var found: Result = choice.result("weaken")
			if found != null:
				return found.bp
	return FixedMath.BP_ONE
