class_name EncounterDef
extends RefCounted
## A hand-placed fight in data/encounters.json
## (docs/plans/rebuild-phase2-heroes-enemies.md, section 2): the enemies on
## their hexes, the rocks, and when it can come.
##   {"id": "the_pack", "name": "The Pack", "tests": "protecting the back line",
##    "act": 1, "days": [2, 3],
##    "enemies": [{"enemy": "rift_hound", "hex": [2, 4]}, ...],
##    "rocks": [[3, 3]],
##    "scale_bp": 10000, "tier": "easier"}
## `scale_bp` multiplies each enemy's HP and ATK (the small growth per day;
## 10000 = as the enemy is). ContentDb checks the enemies exist and stand in
## their zone, and that nothing shares a hex.
## `tier` (phase 5, docs/plans/rebuild-phase5-run.md, section 2): where a run
## offers it: easier (the default) or harder on a normal day, elite, boss, or
## hunt (a camp's optional small fight).

## One enemy placed on a hex.
class Placed:
	var enemy: String
	var hex: Vector2i


var id: String
var name: String
## The question it asks, in a few words.
var tests: String
var act: int
var days: Array[int] = []
var enemies: Array[Placed] = []
var rocks: Array[Vector2i] = []
var scale_bp: int = FixedMath.BP_ONE
var tier: String = "easier"

const TIERS: Array[String] = ["easier", "harder", "elite", "boss", "hunt"]


static func read(reader: DataReader) -> EncounterDef:
	var def := EncounterDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.tests = reader.req_string("tests")
	def.act = reader.req_int("act", 1)
	def.days = reader.req_int_array("days")
	for day: int in def.days:
		if day < 1:
			reader.error("days count from 1 (got %d)" % day)
	var placed_readers: Array[DataReader] = reader.opt_object_array("enemies")
	if placed_readers.is_empty():
		reader.error("an encounter needs enemies")
	for placed_reader: DataReader in placed_readers:
		var placed := Placed.new()
		placed.enemy = placed_reader.req_string("enemy")
		var hex: Array[int] = placed_reader.req_int_array("hex")
		placed_reader.finish()
		if hex.size() != 2:
			if placed_reader.has("hex"):
				placed_reader.error("hex: expected [col, row]")
			continue
		placed.hex = Vector2i(hex[0], hex[1])
		def.enemies.append(placed)
	if reader.has("rocks"):
		def.rocks = reader.req_hex_array("rocks")
	def.scale_bp = reader.opt_int("scale_bp", FixedMath.BP_ONE, 1)
	def.tier = reader.opt_string_choice("tier", "easier", TIERS)
	reader.finish()
	return def
