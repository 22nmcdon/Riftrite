class_name DeedDef
extends RefCounted
## A deed (docs/plans/deeds.md): a goal a hero works toward in fights,
## counted from the combat log. Progress carries over from fight to fight;
## each goal reached is a level.
##   {"text": "Heal your allies", "counts": "healing", "goals": [150, 450, 900]}
##
## What it counts ("counts"), always for the deed's own hero:
##   damage        damage they deal (hits and damage over time; the full hit,
##                 shield included). Filters: statuses, target_row, keyword
##   shield        Shield they give
##   healing       HP they restore
##   damage_taken  damage they take from hits. Filter: own_row
##   crits         their critical hits. Filters: target_row, keyword
##   stacks        status stacks they apply. Filter: statuses
##   fires         their item fires. Filter: keyword
## Filters ("filter"):
##   statuses: ["burn", ...]  damage: only that damage over time; stacks:
##                            only those statuses
##   target_row: "back"       only hits on that row
##   own_row: "front"         only while the hero stands in that row
##   keyword: "spell"         only from items with that keyword
## Relic effects never count; relic grants on the hero's items do.

enum Counts { DAMAGE, SHIELD, HEALING, DAMAGE_TAKEN, CRITS, STACKS, FIRES }

const COUNT_NAMES: Array[String] = ["damage", "shield", "healing", "damage_taken", "crits", "stacks", "fires"]
const ROW_NAMES: Array[String] = ["front", "back"]
## Levels per deed track (docs/plans/deeds.md).
const LEVELS: int = 3
## Which filters each kind takes.
const FILTERS: Dictionary[int, Array] = {
	Counts.DAMAGE: ["statuses", "target_row", "keyword"],
	Counts.SHIELD: [],
	Counts.HEALING: [],
	Counts.DAMAGE_TAKEN: ["own_row"],
	Counts.CRITS: ["target_row", "keyword"],
	Counts.STACKS: ["statuses"],
	Counts.FIRES: ["keyword"],
}

## What the player reads: "Heal your allies".
var text: String
var counts: Counts
## Progress needed for each level, rising.
var goals: Array[int] = []
var statuses: Array[String] = []
## -1 = any row.
var target_row: int = -1
var own_row: int = -1
var keyword: String = ""


static func read(reader: DataReader) -> DeedDef:
	var def := DeedDef.new()
	def.text = reader.req_string("text")
	var counts_name: String = reader.req_choice("counts", COUNT_NAMES)
	def.counts = maxi(COUNT_NAMES.find(counts_name), 0) as Counts
	def.goals = reader.req_int_array("goals")
	if def.goals.size() != LEVELS:
		reader.error("a deed needs %d goals, one per level" % LEVELS)
	for i: int in def.goals.size():
		if def.goals[i] < 1 or (i > 0 and def.goals[i] <= def.goals[i - 1]):
			reader.error("goals must be at least 1 and rise each level")
			break
	if reader.has("filter"):
		var filter: DataReader = reader.req_object("filter")
		if filter != null:
			var allowed: Array = FILTERS[def.counts]
			for key: String in filter.map_keys():
				if not allowed.has(key) and not key.begins_with("_"):
					filter.error("\"%s\" doesn't filter %s" % [key, counts_name])
			if filter.has("statuses") and allowed.has("statuses"):
				def.statuses = filter.req_string_array("statuses")
			if filter.has("target_row") and allowed.has("target_row"):
				def.target_row = ROW_NAMES.find(filter.req_choice("target_row", ROW_NAMES))
			if filter.has("own_row") and allowed.has("own_row"):
				def.own_row = ROW_NAMES.find(filter.req_choice("own_row", ROW_NAMES))
			if filter.has("keyword") and allowed.has("keyword"):
				def.keyword = filter.req_string("keyword")
	reader.finish()
	return def


## The level `progress` reaches (0 to LEVELS).
func level_for(progress: int) -> int:
	var level: int = 0
	for goal: int in goals:
		if progress >= goal:
			level += 1
	return level


## How much `entry` adds to this deed for the unit `holder` in `sim`.
func progress_from(entry: LogEntry, holder: UnitState, sim: CombatSim) -> int:
	if counts == Counts.DAMAGE_TAKEN:
		if entry.kind != LogEntry.Kind.DAMAGE or entry.target != holder.id:
			return 0
		if own_row >= 0 and holder.row != own_row:
			return 0
		return entry.amount
	# Relic effects have no source unit, so they never count; relic grants
	# on the hero's items do.
	if entry.source_unit != holder.id:
		return 0
	match counts:
		Counts.DAMAGE:
			if entry.kind == LogEntry.Kind.STATUS_DAMAGE:
				if not statuses.is_empty() and not statuses.has(entry.status):
					return 0
			elif entry.kind != LogEntry.Kind.DAMAGE or not statuses.is_empty():
				return 0
			return entry.amount if _row_and_keyword_match(entry, holder, sim) else 0
		Counts.SHIELD:
			return entry.amount if entry.kind == LogEntry.Kind.SHIELD else 0
		Counts.HEALING:
			return entry.amount if entry.kind == LogEntry.Kind.HEAL else 0
		Counts.CRITS:
			return 1 if entry.kind == LogEntry.Kind.DAMAGE and entry.crit and _row_and_keyword_match(entry, holder, sim) else 0
		Counts.STACKS:
			if entry.kind != LogEntry.Kind.STATUS_APPLIED or (not statuses.is_empty() and not statuses.has(entry.status)):
				return 0
			return entry.amount
		Counts.FIRES:
			return 1 if entry.kind == LogEntry.Kind.FIRE and _keyword_matches(entry, holder) else 0
	return 0


func _row_and_keyword_match(entry: LogEntry, holder: UnitState, sim: CombatSim) -> bool:
	if target_row >= 0:
		var target: UnitState = sim.unit_by_id(entry.target)
		if target == null or target.row != target_row:
			return false
	return _keyword_matches(entry, holder)


## True if the entry's item (one the holder carries) has the keyword.
func _keyword_matches(entry: LogEntry, holder: UnitState) -> bool:
	if keyword.is_empty():
		return true
	for item: ItemState in holder.items:
		if item.def.id == entry.source_item:
			return item.def.keywords.has(keyword)
	return false
