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
## Items owned and not in a slot (item ids, in the order they came).
var stash: Array[String] = []
## The shop open at camp: "" (none), "pedlar", or "magpie".
var shop: String = ""
## Its wares (item ids; "" once bought), and how often it's been rerolled.
var wares: Array[String] = []
var rerolls: int = 0
## A relic the open shop sells ("": none, or bought).
var shop_relic: String = ""

# Camp.
## Where today's camp is (a place id; "" on the Magpie's day), its options,
## and the one taken ("": none yet).
var place: String = ""
var camp: Array[String] = []
var camp_used: String = ""
## A Hunt's pack, waiting to be fought ("": none).
var hunt: String = ""
## Map the Rift waits for which of tomorrow's fights to swap.
var mapping: bool = false
## For the next fight (the day's, not a Hunt): Fortify, Dig In (and the
## rock's hex once placed; empty: not yet), Rift Tear, and a Rest with a
## relic that steadies.
var fortify: bool = false
var dig_in: bool = false
var rock: Array[int] = []
var rift_tear: bool = false
var rested: bool = false
## Days whose fights are Scouted.
var scouted: Array[int] = []
## The day the Magpie comes (drawn at the start).
var magpie_day: int = 0

# Relics and bonds.
var relics: Array[String] = []
## A relic choice waiting (relic ids; empty: none).
var relic_choice: Array[String] = []
## Duo bonds found (on at least once), in the order found.
var bonds_found: Array[String] = []


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
		"stash": stash.duplicate(), "shop": shop, "wares": wares.duplicate(), "rerolls": rerolls, "shop_relic": shop_relic,
		"place": place, "camp": camp.duplicate(), "camp_used": camp_used, "hunt": hunt, "mapping": mapping,
		"fortify": fortify, "dig_in": dig_in, "rock": rock.duplicate(), "rift_tear": rift_tear, "rested": rested,
		"scouted": scouted.duplicate(), "magpie_day": magpie_day,
		"relics": relics.duplicate(), "relic_choice": relic_choice.duplicate(), "bonds_found": bonds_found.duplicate(),
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
	state.stash.assign((data.get("stash", []) as Array).map(func(value: Variant) -> String: return str(value)))
	state.shop = str(data.get("shop", ""))
	state.wares.assign((data.get("wares", []) as Array).map(func(value: Variant) -> String: return str(value)))
	state.rerolls = int(data.get("rerolls", 0))
	state.shop_relic = str(data.get("shop_relic", ""))
	state.place = str(data.get("place", ""))
	state.camp = _strings(data.get("camp", []))
	state.camp_used = str(data.get("camp_used", ""))
	state.hunt = str(data.get("hunt", ""))
	state.mapping = bool(data.get("mapping", false))
	state.fortify = bool(data.get("fortify", false))
	state.dig_in = bool(data.get("dig_in", false))
	state.rock.assign((data.get("rock", []) as Array).map(func(value: Variant) -> int: return int(value)))
	state.rift_tear = bool(data.get("rift_tear", false))
	state.rested = bool(data.get("rested", false))
	state.scouted.assign((data.get("scouted", []) as Array).map(func(value: Variant) -> int: return int(value)))
	state.magpie_day = int(data.get("magpie_day", 0))
	state.relics = _strings(data.get("relics", []))
	state.relic_choice = _strings(data.get("relic_choice", []))
	state.bonds_found = _strings(data.get("bonds_found", []))
	return state


static func _strings(values: Variant) -> Array[String]:
	var found: Array[String] = []
	found.assign((values as Array).map(func(value: Variant) -> String: return str(value)))
	return found
