class_name GrowthDef
extends RefCounted
## How a card grows for the rest of the run (docs/plans/rebuild-phase5c-combos.md,
## step 4, section 9.3; part 7, section 4): it counts something its holder
## does, the way a deed does, and every `per` of it is a step; the next fight
## gets the step's mod that many times over.
##   "grows": {"counts": {"counts": "damage", "beyond_hexes": 4}, "per": 300,
##             "each": {"passives": [...an aura...]}, "max_steps": 1}
## counts: a DeedDef's counting (no text); per: how much makes a step;
## each: one step's mod (KitMod.step_problem says what it may change);
## max_steps: a cap (0: none; a quest is 1). A hero's card counts its holder,
## a relic the whole team (RunContent). It counts from when it's taken
## (Decision 15).

var counts: DeedDef
var per: int = 1
var each: KitMod
var max_steps: int = 0


static func read(reader: DataReader) -> GrowthDef:
	var def := GrowthDef.new()
	var counts_reader: DataReader = reader.req_object("counts")
	def.counts = DeedDef.read(counts_reader, false) if counts_reader != null else DeedDef.new()
	def.per = reader.req_int("per", 1)
	var each_reader: DataReader = reader.req_object("each")
	if each_reader != null:
		def.each = KitMod.read(each_reader)
		var problem: String = def.each.step_problem()
		if not problem.is_empty():
			reader.error(problem)
	else:
		def.each = KitMod.make()
	def.max_steps = reader.opt_int("max_steps", 0, 0)
	reader.finish()
	return def


## Whole steps from `count` (capped by max_steps).
func steps(count: int) -> int:
	@warning_ignore("integer_division")
	var whole: int = maxi(count, 0) / per
	return mini(whole, max_steps) if max_steps > 0 else whole


## The mod the next fight gets from `count` (null: no step yet).
func mod_for(count: int) -> KitMod:
	return each.times(steps(count))
