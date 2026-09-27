class_name UnitStats
extends RefCounted
## A unit's six stats:
##   HP    max health
##   ATK   attack power; abilities scale from it
##   MGK   magic power; abilities scale from it
##   DEF   hit damage taken is multiplied by C / (C + DEF), C from tuning
##   CRIT  each point adds crit chance to all the unit's abilities
##   ATSP  each point speeds up the unit's basic attack
##   SPEED hexes per second (0: it never walks)
##   RANGE the basic attack's reach in hexes (1: melee)
## CRIT and ATSP are "rate" stats. Effects can scale only from the first six
## (SCALING_STATS); speed and range are positioning stats
## (docs/plans/rebuild-phase1-arena-sim.md, section 2).

enum Stat { HP, ATK, MGK, DEF, CRIT, ATSP, SPEED, RANGE }

const STAT_NAMES: Array[String] = ["hp", "atk", "mgk", "def", "crit", "atsp", "speed", "range"]
const LABELS: Array[String] = ["HP", "ATK", "MGK", "DEF", "CRIT", "ATSP", "Speed", "Range"]
const RATE_STATS: Array[Stat] = [Stat.CRIT, Stat.ATSP]
## How many stats effects can scale from (HP through ATSP).
const SCALING_STATS: int = 6

## Indexed by Stat.
var values: Array[int] = [0, 0, 0, 0, 0, 0, 0, 1]


static func make(hp: int, atk: int = 0, mgk: int = 0, def: int = 0, crit: int = 0, atsp: int = 0, speed: int = 0, reach: int = 1) -> UnitStats:
	var stats := UnitStats.new()
	stats.values = [hp, atk, mgk, def, crit, atsp, speed, reach]
	return stats


## Reads {"hp": 300, "atk": 20, "speed": 2, "range": 4, ...}. HP is
## required; range defaults to 1 (melee) and the rest to 0.
static func read(reader: DataReader) -> UnitStats:
	var stats := UnitStats.new()
	stats.values[Stat.HP] = reader.req_int("hp", 1)
	for i: int in range(1, STAT_NAMES.size()):
		stats.values[i] = reader.opt_int(STAT_NAMES[i], 1 if i == Stat.RANGE else 0, 1 if i == Stat.RANGE else 0)
	reader.finish()
	return stats


func copy() -> UnitStats:
	var result := UnitStats.new()
	result.values = values.duplicate()
	return result


func get_stat(stat: Stat) -> int:
	return values[stat]


## A copy with only HP multiplied by `bp` (a run's fight scaling).
func with_hp_bp(bp: int) -> UnitStats:
	var result := UnitStats.new()
	result.values = values.duplicate()
	result.values[Stat.HP] = FixedMath.apply_bp(values[Stat.HP], bp)
	return result
