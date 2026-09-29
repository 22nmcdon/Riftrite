class_name RunState
extends RefCounted
## Everything a run is, between fights (docs/plans/rebuild-phase5-run.md,
## section 1). Only RunFlow changes it. Offers are drawn from the run's seed
## and where they happen (RunRandom), so the state holds what was chosen and
## what's waiting, never a random stream; a save is this state as JSON
## (to_dict, from_dict).

## A save from another version can't be loaded.
const VERSION: int = 1

## Where the day is: camp, choosing the fight, the loadout (then placement
## and the fight), after the fight (a pick, a transformation, a relic
## waiting), or the run is over. A pick can wait at camp too (Train).
enum Phase { CAMP, ROUTE, LOADOUT, AFTER, ENDED }
enum Outcome { NONE, WON, LOST }

const PHASE_NAMES: Array[String] = ["camp", "route", "loadout", "after", "ended"]
const OUTCOME_NAMES: Array[String] = ["none", "won", "lost"]


## One hero in the run.
class Hero:
	var id: String
	## The vowed path's id.
	var path: String = ""
	var transformed: bool = false
	## Path id -> what fights have put into that path's deed (all three
	## count, whatever the vow).
	var deeds: Dictionary[String, int] = {}
	## Upgrade ids taken, in order.
	var upgrades: Array[String] = []
	var wounds: int = 0
	## Item ids in its loadout slots ("": empty).
	var slots: Array[String] = []

	func to_dict() -> Dictionary:
		return {"id": id, "path": path, "transformed": transformed, "deeds": deeds.duplicate(), "upgrades": upgrades.duplicate(),
			"wounds": wounds, "slots": slots.duplicate()}

	static func from_dict(data: Dictionary) -> Hero:
		var hero := Hero.new()
		hero.id = str(data.get("id", ""))
		hero.path = str(data.get("path", ""))
		hero.transformed = bool(data.get("transformed", false))
		var deeds: Dictionary = data.get("deeds", {})
		for path_id: Variant in deeds:
			hero.deeds[str(path_id)] = int(deeds[path_id])
		hero.upgrades.assign((data.get("upgrades", []) as Array).map(func(value: Variant) -> String: return str(value)))
		hero.wounds = int(data.get("wounds", 0))
		hero.slots.assign((data.get("slots", []) as Array).map(func(value: Variant) -> String: return str(value)))
		return hero


## One fight fought (for the run's end screen and the run report).
class Fought:
	var day: int
	var attempt: int
	var encounter: String
	var outcome: FightResult.Outcome
	var seconds: int

	func to_dict() -> Dictionary:
		return {"day": day, "attempt": attempt, "encounter": encounter, "outcome": int(outcome), "seconds": seconds}

	static func from_dict(data: Dictionary) -> Fought:
		var fought := Fought.new()
		fought.day = int(data.get("day", 0))
		fought.attempt = int(data.get("attempt", 0))
		fought.encounter = str(data.get("encounter", ""))
		fought.outcome = int(data.get("outcome", 0)) as FightResult.Outcome
		fought.seconds = int(data.get("seconds", 0))
		return fought


var seed_value: int = 1
var act: int = 1
## Counts from 1.
var day: int = 1
## How many times this day has been replayed after a loss (0 the first time).
var attempt: int = 0
var losses: int = 0
var phase: Phase = Phase.CAMP
var outcome: Outcome = Outcome.NONE
## In heroes.json's order.
var heroes: Array[Hero] = []
var shards: int = 0
## Every day's fight options, drawn at the act's start (encounter ids).
var options: Array[Array] = []
## Today's chosen fight ("" until chosen).
var chosen: String = ""
## The last formation fought with (hero id -> hex), remembered.
var formation: Dictionary[String, Vector2i] = {}
var fought: Array[Fought] = []
## An upgrade pick waiting (upgrade ids; empty: none).
var pick: Array[String] = []
## The heroes the last fight transformed (for the screen that shows it).
var just_transformed: Array[String] = []


func hero(hero_id: String) -> Hero:
	for found: Hero in heroes:
		if found.id == hero_id:
			return found
	return null


## Today's fight options.
func today() -> Array[String]:
	var found: Array[String] = []
	if day >= 1 and day <= options.size():
		found.assign(options[day - 1])
	return found


func to_dict() -> Dictionary:
	var hexes: Dictionary = {}
	for hero_id: String in formation:
		hexes[hero_id] = [formation[hero_id].x, formation[hero_id].y]
	return {
		"version": VERSION, "seed": seed_value, "act": act, "day": day, "attempt": attempt, "losses": losses,
		"phase": PHASE_NAMES[phase], "outcome": OUTCOME_NAMES[outcome],
		"heroes": heroes.map(func(hero_state: Hero) -> Dictionary: return hero_state.to_dict()),
		"shards": shards, "options": options.duplicate(true), "chosen": chosen, "formation": hexes,
		"fought": fought.map(func(entry: Fought) -> Dictionary: return entry.to_dict()),
		"pick": pick.duplicate(), "just_transformed": just_transformed.duplicate(),
	}


## The state `data` holds, or null if it isn't a save of this version.
static func from_dict(data: Dictionary) -> RunState:
	if int(data.get("version", 0)) != VERSION:
		return null
	var state := RunState.new()
	state.seed_value = int(data.get("seed", 1))
	state.act = int(data.get("act", 1))
	state.day = int(data.get("day", 1))
	state.attempt = int(data.get("attempt", 0))
	state.losses = int(data.get("losses", 0))
	state.phase = maxi(PHASE_NAMES.find(str(data.get("phase", "camp"))), 0) as Phase
	state.outcome = maxi(OUTCOME_NAMES.find(str(data.get("outcome", "none"))), 0) as Outcome
	for hero_data: Variant in data.get("heroes", []):
		state.heroes.append(Hero.from_dict(hero_data))
	state.shards = int(data.get("shards", 0))
	for day_options: Variant in data.get("options", []):
		state.options.append((day_options as Array).map(func(value: Variant) -> String: return str(value)))
	state.chosen = str(data.get("chosen", ""))
	var hexes: Dictionary = data.get("formation", {})
	for hero_id: Variant in hexes:
		var hex: Array = hexes[hero_id]
		state.formation[str(hero_id)] = Vector2i(int(hex[0]), int(hex[1]))
	for entry: Variant in data.get("fought", []):
		state.fought.append(Fought.from_dict(entry))
	state.pick.assign((data.get("pick", []) as Array).map(func(value: Variant) -> String: return str(value)))
	state.just_transformed.assign((data.get("just_transformed", []) as Array).map(func(value: Variant) -> String: return str(value)))
	return state
