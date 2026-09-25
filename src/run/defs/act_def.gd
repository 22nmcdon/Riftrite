class_name ActDef
extends RefCounted
## One act from data/acts.json: how many days, which encounters, and the
## Caravan's tier odds. The last day's fight is the boss.

var act: int
var name: String
var days: int
## Encounter pools for normal days and elite days: each entry is an
## encounter id with the days it can appear on (inclusive), as
## {"encounter": "pup_litter", "days": [1, 2]} ("days" optional: any day).
var normal: Array[Pool] = []
var elites: Array[Pool] = []
var elite_days: Array[int] = []
var boss: String
## Caravan tier odds (C..S), for items and heroes.
var caravan_tier_weights: Array[int] = []


class Pool:
	var encounter: String
	var from_day: int = 1
	var to_day: int = 999


static func read(reader: DataReader) -> ActDef:
	var def := ActDef.new()
	def.act = reader.req_int("act", 1)
	def.name = reader.req_string("name")
	def.days = reader.req_int("days", 1)
	def.normal = _read_pools(reader, "normal")
	def.elites = _read_pools(reader, "elites")
	def.elite_days = reader.req_int_array("elite_days")
	def.boss = reader.req_string("boss")
	def.caravan_tier_weights = EconomyDef._table(reader, "caravan_tier_weights", TuningDef.TIER_NAMES, 0)
	for day: int in def.elite_days:
		if day < 1 or day >= def.days:
			reader.error("elite day %d must be between 1 and %d (the last day is the boss)" % [day, def.days - 1])
	for day: int in range(1, def.days):
		var pool: Array[Pool] = def.elites if def.is_elite_day(day) else def.normal
		if def.encounters_for(pool, day).is_empty():
			reader.error("day %d has no %s encounter" % [day, "elite" if def.is_elite_day(day) else "normal"])
	reader.finish()
	return def


static func _read_pools(reader: DataReader, key: String) -> Array[Pool]:
	var pools: Array[Pool] = []
	for entry: DataReader in reader.opt_object_array(key):
		var pool := Pool.new()
		pool.encounter = entry.req_string("encounter")
		if entry.has("days"):
			var days: Array[int] = entry.req_int_array("days")
			if days.size() != 2 or days[0] > days[1]:
				entry.error("days needs [first, last]")
			else:
				pool.from_day = days[0]
				pool.to_day = days[1]
		entry.finish()
		pools.append(pool)
	return pools


## The encounters a pool offers on a day, in pool order.
func encounters_for(pool: Array[Pool], day: int) -> Array[String]:
	var result: Array[String] = []
	for entry: Pool in pool:
		if day >= entry.from_day and day <= entry.to_day:
			result.append(entry.encounter)
	return result


## Every encounter id the act names, for content checks.
func all_encounters() -> Array[Array]:
	var normal_ids: Array[String] = []
	for entry: Pool in normal:
		normal_ids.append(entry.encounter)
	var elite_ids: Array[String] = []
	for entry: Pool in elites:
		elite_ids.append(entry.encounter)
	var boss_ids: Array[String] = [boss]
	return [[normal_ids, "normal"], [elite_ids, "elite"], [boss_ids, "boss"]]


func is_boss_day(day: int) -> bool:
	return day == days


func is_elite_day(day: int) -> bool:
	return elite_days.has(day)
