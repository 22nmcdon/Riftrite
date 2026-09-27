class_name FightResult
extends RefCounted
## How a fight ended. A tie (both sides wiped on the same tick, or anyone
## still standing at the tie time) counts as a guild victory. Paths (phase 4)
## add each hero's deed progress; the run (phase 5) adds duo bonds found.

enum Outcome { VICTORY, DEFEAT, TIE }

var outcome: Outcome = Outcome.TIE
var end_tick: int = 0
var combat_log: CombatLog = CombatLog.new()
## Non-empty if the setup was invalid; the fight did not run.
var errors: Array[String] = []


func guild_won() -> bool:
	return errors.is_empty() and outcome != Outcome.DEFEAT
