class_name ActDef
extends RefCounted
## One act from data/acts.json: how many days, which encounters, and the
## shops' tier odds. The last day's fight is the boss; every other day offers
## a pick of 2 fights (docs/plans/new-day.md).

var act: int
var name: String
var days: int
## Encounter pools for normal days and elite days: each entry is an
## encounter id with the days it can appear on (inclusive), as
## {"encounter": "pup_litter", "days": [1, 2], "hard": true, "hp_bp": 20000}
## ("days" optional: any day; "hard" optional: the harder kind of fight;
## "hp_bp" optional: the enemies' HP, times this, on those days).
var normal: Array[Pool] = []
var elites: Array[Pool] = []
var elite_days: Array[int] = []
var boss: String
## Shop and reward tier odds (C..S).
var shop_tier_weights: Array[int] = []


class Pool:
	var encounter: String
	var from_day: int = 1
	var to_day: int = 999
	## The harder kind of fight (docs/plans/new-day.md): more gold, better
	## reward odds.
	var hard: bool = false
	var hp_bp: int = FixedMath.BP_ONE


static func read(reader: DataReader) -> ActDef:
	var def := ActDef.new()
	def.act = reader.req_int("act", 1)
	def.name = reader.req_string("name")
	def.days = reader.req_int("days", 1)
	def.normal = _read_pools(reader, "normal")
	def.elites = _read_pools(reader, "elites")
	def.elite_days = reader.req_int_array("elite_days")
	def.boss = reader.req_string("boss")
	def.shop_tier_weights = EconomyDef._table(reader, "shop_tier_weights", TuningDef.TIER_NAMES, 0)
	for day: int in def.elite_days:
		if day < 1 or day >= def.days:
			reader.error("elite day %d must be between 1 and %d (the last day is the boss)" % [day, def.days - 1])
	for day: int in range(1, def.days):
		var pool: Array[Pool] = def.elites if def.is_elite_day(day) else def.normal
		if def.encounters_for(pool, day).size() < 2:
			reader.error("day %d needs at least 2 %s encounters (a pick of 2)" % [day, "elite" if def.is_elite_day(day) else "normal"])
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
		pool.hard = entry.opt_bool("hard", false)
		pool.hp_bp = entry.opt_int("hp_bp", FixedMath.BP_ONE, 1)
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


## The pool a day's fights come from (elite days: the elites).
func pool_for(day: int) -> Array[Pool]:
	return elites if is_elite_day(day) else normal


## Whether an encounter is the harder kind of fight on a day.
func is_hard(encounter_id: String, day: int) -> bool:
	var entry: Pool = _entry(encounter_id, day)
	return entry != null and entry.hard


## An encounter's HP scaling on a day (1x for the boss).
func hp_bp(encounter_id: String, day: int) -> int:
	var entry: Pool = _entry(encounter_id, day)
	return entry.hp_bp if entry != null else FixedMath.BP_ONE


func _entry(encounter_id: String, day: int) -> Pool:
	for entry: Pool in pool_for(day):
		if entry.encounter == encounter_id and day >= entry.from_day and day <= entry.to_day:
			return entry
	return null


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
