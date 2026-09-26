class_name LegendaryDef
extends RefCounted
## A Legendary item's upgrade path (docs/plans/legendary-items.md). Legendaries
## never combine; each tiers up its own way, from its own start tier:
##   "legendary": {"path": "hits", "start_tier": "c", "goals": [60, 120, 200]}
## `goals` has one number per step from start_tier up to S. Paths:
##   hits     the item's direct-damage hits in fights
##   essence  essences fed from the pouch; "wants" names one per step
##   devour   items fed to it (a meal is worth the item's tier + 1); each meal
##            leaves a trace: "trace_bp" by the eaten item's rarity, a
##            lasting boost to the item's own numbers
##   bonded   its holder ranking up
##   martyr   its holder falling in a fight the guild still wins
##   boss     a boss beaten while it's on a hero's row

const PATHS: Array[String] = ["hits", "essence", "devour", "bonded", "martyr", "boss"]
## How each path's progress reads, for the UI ("23/60 hits").
const UNITS: Dictionary[String, String] = {
	"hits": "hits", "essence": "fed", "devour": "meals", "bonded": "rank-ups", "martyr": "falls", "boss": "bosses",
}
## Plain-words path names for the UI.
const NAMES: Dictionary[String, String] = {
	"hits": "Grows by use", "essence": "Essence-hungry", "devour": "Devourer",
	"bonded": "Bonded", "martyr": "Martyr", "boss": "Boss-forged",
}
## Rarities a Devourer can eat (never a Legendary).
const EDIBLE_RARITIES: Array[String] = ["common", "uncommon", "rare", "epic"]

var path: String
## 0 = C ... 3 = S.
var start_tier: int = 0
## Progress needed for each step, from start_tier up (3 - start_tier numbers).
var goals: Array[int] = []
## essence: the essence each step wants.
var wants: Array[String] = []
## devour: the trace each meal leaves, by the eaten item's rarity (in
## EDIBLE_RARITIES order), in basis points.
var trace_bp: Array[int] = []


static func read(reader: DataReader) -> LegendaryDef:
	var def := LegendaryDef.new()
	def.path = reader.req_choice("path", PATHS)
	def.start_tier = maxi(TuningDef.TIER_NAMES.find(reader.req_choice("start_tier", TuningDef.TIER_NAMES)), 0)
	def.goals = reader.req_int_array("goals")
	var steps: int = 3 - def.start_tier
	if def.start_tier >= 3:
		reader.error("start_tier: a Legendary can't start at S (it would have no path)")
	elif def.goals.size() != steps:
		reader.error("goals: needs %d number(s), one per tier from %s to S" % [steps, TuningDef.TIER_LABELS[def.start_tier]])
	for i: int in def.goals.size():
		if def.goals[i] < 1:
			reader.error("goals[%d]: must be at least 1" % i)
	if def.path == "essence":
		def.wants = reader.req_string_array("wants")
		if def.wants.size() != def.goals.size():
			reader.error("wants: needs one essence per goal (%d)" % def.goals.size())
	if def.path == "devour":
		var table: DataReader = reader.req_object("trace_bp")
		for rarity: String in EDIBLE_RARITIES:
			def.trace_bp.append(table.req_int(rarity, 0, FixedMath.BP_ONE) if table != null else 0)
		if table != null:
			table.finish()
	reader.finish()
	return def


## The goal for the step out of `tier`, or 0 at S (or below the start tier).
func goal_at(tier: int) -> int:
	var step: int = tier - start_tier
	return goals[step] if step >= 0 and step < goals.size() else 0


## essence: the essence the step out of `tier` wants, or "".
func wanted_at(tier: int) -> String:
	var step: int = tier - start_tier
	return wants[step] if step >= 0 and step < wants.size() else ""


## devour: the trace an eaten item of `rarity` leaves (0 if it can't be eaten).
func trace_for(rarity: String) -> int:
	var index: int = EDIBLE_RARITIES.find(rarity)
	return trace_bp[index] if index >= 0 and index < trace_bp.size() else 0
