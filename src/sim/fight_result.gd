class_name FightResult
extends RefCounted
## How a fight ended. A tie (both sides wiped on the same tick, or anyone
## still standing at the tie time) counts as a guild victory. Paths (phase 4)
## add what the fight put into each hero's deeds; the run (phase 5) adds duo
## bonds found.

enum Outcome { VICTORY, DEFEAT, TIE }

var outcome: Outcome = Outcome.TIE
var end_tick: int = 0
var combat_log: CombatLog = CombatLog.new()
## Non-empty if the setup was invalid; the fight did not run.
var errors: Array[String] = []
## Each hero's deeds (Deeds), in the fight's order and each hero's path order.
var deeds: Array[Deed] = []


## What a fight put into one deed.
class Deed:
	var hero: String
	var path: String
	var amount: int

	static func make(hero_id: String, path_id: String, deed_amount: int) -> Deed:
		var deed := Deed.new()
		deed.hero = hero_id
		deed.path = path_id
		deed.amount = deed_amount
		return deed


## What the fight put into `path_id`'s deed for `hero_id` (0 if it counted none).
func deed_amount(hero_id: String, path_id: String) -> int:
	for deed: Deed in deeds:
		if deed.hero == hero_id and deed.path == path_id:
			return deed.amount
	return 0


func guild_won() -> bool:
	return errors.is_empty() and outcome != Outcome.DEFEAT
