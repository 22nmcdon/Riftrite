class_name UnitStats
extends RefCounted
## A unit's six stats (see docs/plans/essence-rework.md):
##   HP    max health
##   ATK   attack power; items scale from it
##   MGK   magic power; items scale from it
##   DEF   hit damage taken is multiplied by C / (C + DEF), C from tuning
##   CRIT  each point adds crit chance to all the unit's items
##   ATSP  each point speeds up the unit's auto-attack
## CRIT and ATSP are "rate" stats: only Epic and Legendary items may scale
## their numbers from them.

enum Stat { HP, ATK, MGK, DEF, CRIT, ATSP }

const STAT_NAMES: Array[String] = ["hp", "atk", "mgk", "def", "crit", "atsp"]
const LABELS: Array[String] = ["HP", "ATK", "MGK", "DEF", "CRIT", "ATSP"]
const RATE_STATS: Array[Stat] = [Stat.CRIT, Stat.ATSP]

## Indexed by Stat.
var values: Array[int] = [0, 0, 0, 0, 0, 0]


static func make(hp: int, atk: int = 0, mgk: int = 0, def: int = 0, crit: int = 0, atsp: int = 0) -> UnitStats:
	var stats := UnitStats.new()
	stats.values = [hp, atk, mgk, def, crit, atsp]
	return stats


## Reads {"hp": 300, "atk": 20, ...}. HP is required; the rest default to 0.
static func read(reader: DataReader) -> UnitStats:
	var stats := UnitStats.new()
	stats.values[Stat.HP] = reader.req_int("hp", 1)
	for i: int in range(1, STAT_NAMES.size()):
		stats.values[i] = reader.opt_int(STAT_NAMES[i], 0, 0)
	reader.finish()
	return stats


func get_stat(stat: Stat) -> int:
	return values[stat]


## A copy with every stat multiplied by `bp` (for rank boosts).
func boosted(bp: int) -> UnitStats:
	var result := UnitStats.new()
	for i: int in values.size():
		result.values[i] = FixedMath.apply_bp(values[i], bp)
	return result
