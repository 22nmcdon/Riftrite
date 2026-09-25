class_name FightResult
extends RefCounted
## How a fight ended. A tie (both sides wiped on the same tick, or anyone
## still standing at the tie time) counts as a guild victory.

enum Outcome { VICTORY, DEFEAT, TIE }


## One infused item's XP over the fight (fires plus the per-battle XP), for
## the run layer to keep.
class InfusionResult:
	var unit_id: String
	var item_id: String
	var slot: int
	var xp_before: int
	var xp_after: int
	var level_before: int
	var level_after: int


## A synergy that was active, for the run layer to record discoveries.
class SynergyResult:
	var synergy_id: String
	## The hero holding a pair, signature, or transformation; "" otherwise.
	var unit_id: String
	## Resonance and class traits: the count reached; 0 otherwise.
	var count: int


var outcome: Outcome = Outcome.TIE
var end_tick: int = 0
var combat_log: CombatLog = CombatLog.new()
## Non-empty if the setup was invalid; the fight did not run.
var errors: Array[String] = []
## Every infused item's XP, in resolution order.
var infusions: Array[InfusionResult] = []
## The guild's active synergies, in data order.
var synergies: Array[SynergyResult] = []


func guild_won() -> bool:
	return errors.is_empty() and outcome != Outcome.DEFEAT
