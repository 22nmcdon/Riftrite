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
## max_steps: a cap (0: none; a quest is 1). Instead of "each", a relic may
## pay shards for each step ("each_shards": Bloodied Coin), and instead of
## "counts", a relic may grow with what the run counts ("run_counts":
## "elite_wins", one for each elite won; Tally of the Dead; phase 5c step 5a).
## max_steps_per_fight: at most that many steps from one fight (0: none;
## the tuning phase, Decision 8: Lucky Strike's 5), the rest of the fight's
## count dropped.
## A hero's card counts its holder,
## a relic the whole team (RunContent). It counts from when it's taken
## (Decision 15).

var counts: DeedDef
var per: int = 1
var each: KitMod
var max_steps: int = 0
var max_steps_per_fight: int = 0
## Shards each step pays (0: none; then `each` may be empty).
var each_shards: int = 0
## "" (the sim counts it, `counts`) or what the run counts: "elite_wins",
## "wins" (day fights won), or "flawless" (day fights won with no hero down
## at the end; phase 8 part 5, Edric's apexes and cards).
var run_counts: String = ""
## Its steps' mod goes to every hero, not only its holder (phase 8 part 5:
## Golden Aegis, Gold Leaf).
var team: bool = false

## "shards" (phase 8 part 6, Midas Touch): the shards the heroes' effects
## collect in fights (SHARDS lines, not those past a cap), one for each.
const RUN_COUNTS: Array[String] = ["elite_wins", "wins", "flawless", "shards"]


## `counts_only`: its steps pay through something else (a card's Tithe), so
## it needs no "each" (phase 8 part 6, Ottilie's Ledger).
static func read(reader: DataReader, counts_only: bool = false) -> GrowthDef:
	var def := GrowthDef.new()
	if reader.has("run_counts"):
		def.run_counts = reader.req_choice("run_counts", RUN_COUNTS)
		def.counts = DeedDef.new()
	else:
		var counts_reader: DataReader = reader.req_object("counts")
		def.counts = DeedDef.read(counts_reader, false) if counts_reader != null else DeedDef.new()
	def.per = reader.req_int("per", 1)
	def.each_shards = reader.opt_int("each_shards", 0, 0, 100)
	def.each = KitMod.make()
	# One the run counts may be only a count (phase 8 part 5: Ledger of
	# Debts' steps pay through its Tithe, Collector of Debts' raise its own).
	if (def.each_shards == 0 and def.run_counts.is_empty() and not counts_only) or reader.has("each"):
		var each_reader: DataReader = reader.req_object("each")
		if each_reader != null:
			def.each = KitMod.read(each_reader)
			var problem: String = def.each.step_problem()
			if not problem.is_empty():
				reader.error(problem)
	def.max_steps = reader.opt_int("max_steps", 0, 0)
	def.max_steps_per_fight = reader.opt_int("max_steps_per_fight", 0, 0)
	def.team = reader.opt_bool("team", false)
	if def.team and not def.each.changes_anything():
		reader.error("a team growth gives every hero its step (\"each\")")
	reader.finish()
	return def


## Whole steps from `count` (capped by max_steps).
func steps(count: int) -> int:
	@warning_ignore("integer_division")
	var whole: int = maxi(count, 0) / per
	return mini(whole, max_steps) if max_steps > 0 else whole


## The mod the next fight gets from `count` (null: no step yet, or a growth
## that pays shards).
func mod_for(count: int) -> KitMod:
	return each.times(steps(count)) if each.changes_anything() else null


## True if the sim counts it (a fight's tally), not the run.
func counted_in_fights() -> bool:
	return run_counts.is_empty()


## The count after a fight adds `counted` to `before`: with
## max_steps_per_fight, no more than that many steps past `before`'s (what
## the fight counted past them is dropped).
func grown(before: int, counted: int) -> int:
	var after: int = before + counted
	if max_steps_per_fight > 0 and steps(after) - steps(before) > max_steps_per_fight:
		@warning_ignore("integer_division")
		after = (maxi(before, 0) / per + max_steps_per_fight) * per
	return after
