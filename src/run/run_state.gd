class_name RunState
extends RefCounted
## Everything a run is, between fights (docs/plans/rebuild-phase5-run.md,
## section 1). Only RunFlow changes it. Offers are drawn from the run's seed
## and where they happen (RunRandom), so the state holds what was chosen and
## what's waiting, never a random stream; a save is this state as JSON
## (to_dict, from_dict).

## A save from another version can't be loaded (4: phase 5c step 8's new
## day).
const VERSION: int = 4

## Where the day is (phase 5c step 8, docs/plans/days-and-nodes.md):
## choosing the fight, the loadout (then placement and the fight), after the
## fight (a pick, a transformation, a relic waiting), the shop, choosing a
## node, in a node (camp's options, the Magpie's stall, ...), or the run is
## over. A pick can wait in a node too (Train).
enum Phase { ROUTE, LOADOUT, AFTER, SHOP, NODES, NODE, ENDED }
enum Outcome { NONE, WON, LOST }

const PHASE_NAMES: Array[String] = ["route", "loadout", "after", "shop", "nodes", "node", "ended"]
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
	## Upgrade ids taken, in order (a stacking card once per take).
	var upgrades: Array[String] = []
	## Its stacking cards' locked amounts (phase 5c step 7): upgrade id ->
	## each take's amount, in order (ints).
	var locked: Dictionary[String, Array] = {}
	var wounds: int = 0
	## Item ids in its loadout slots ("": empty).
	var slots: Array[String] = []
	## When its Switch Places swaps, if the player chose (seconds; 0: its
	## kit's moment; phase 5c step 6d).
	var gambit_at: int = 0
	## Its growing upgrades (phase 5c step 4): upgrade id -> what it has
	## counted since it was taken (a lookup; read in `upgrades`' order).
	var growth: Dictionary[String, int] = {}
	## Events (phase 5c step 8c): how many times The Old Well cut its max HP
	## this act; the event mods on its next day fight (EventDef's
	## next_fight_mods), spent once one is won; and its oath ("": none) with
	## the day fights it has left.
	var weakened: int = 0
	var next_fight: Array[String] = []
	var oath: String = ""
	var oath_fights: int = 0

	func to_dict() -> Dictionary:
		return {"id": id, "path": path, "transformed": transformed, "deeds": deeds.duplicate(), "upgrades": upgrades.duplicate(),
			"wounds": wounds, "slots": slots.duplicate(), "growth": growth.duplicate(), "gambit_at": gambit_at,
			"locked": locked.duplicate(true), "weakened": weakened, "next_fight": next_fight.duplicate(), "oath": oath, "oath_fights": oath_fights}

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
		hero.gambit_at = int(data.get("gambit_at", 0))
		var growth: Dictionary = data.get("growth", {})
		for card_id: Variant in growth:
			hero.growth[str(card_id)] = int(growth[card_id])
		var locked: Dictionary = data.get("locked", {})
		for card_id: Variant in locked:
			hero.locked[str(card_id)] = (locked[card_id] as Array).map(func(value: Variant) -> int: return int(value))
		hero.weakened = int(data.get("weakened", 0))
		hero.next_fight.assign((data.get("next_fight", []) as Array).map(func(value: Variant) -> String: return str(value)))
		hero.oath = str(data.get("oath", ""))
		hero.oath_fights = int(data.get("oath_fights", 0))
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
var phase: Phase = Phase.ROUTE
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
## Every item owned, in a slot or the stash (a run holds one of each; phase
## 5c step 6): its rank (1 to 3), and what it has counted toward the next
## since it reached this one (lookups; read in slot or stash order).
var item_ranks: Dictionary[String, int] = {}
var item_counts: Dictionary[String, int] = {}
## The items the last fight ranked up, for the screen after it.
var ranked: Array[String] = []
## The shop open: "" (none), "pedlar" (the day's shop), or "magpie" (his node).
var shop: String = ""
## Its wares (item ids; "" once bought), and how often it's been rerolled.
var wares: Array[String] = []
var rerolls: int = 0
## The Magpie's swap is used this visit (phase 5c step 6e).
var magpie_swapped: bool = false
## The relics the open shop sells (phase 5c step 5a: one, or more with The
## Magpie's Scale; "" once bought).
var shop_relics: Array[String] = []

# The nodes (phase 5c step 8).
## The nodes shown at the day's end ("camp", "rift_tear", "magpie",
## "event:<scene id>", "oath"), the one taken ("": none yet), and each past
## day's (by day: "camp:<place>", or the node; "" for a day without one).
var nodes: Array[String] = []
var node: String = ""
var taken_nodes: Array[String] = []
## How often the Magpie's node has been taken this act.
var magpie_visits: int = 0

# Camp (a node).
## Where the camp is (a place id), its options, and the one taken ("": none
## yet).
var place: String = ""
var camp: Array[String] = []
var camp_used: String = ""
## A Hunt's pack, waiting to be fought ("": none).
var hunt: String = ""
## Map the Rift waits for which of tomorrow's fights to swap.
var mapping: bool = false
## For the next day fight (not a Hunt), kept through its replays and spent
## once it's won (Decision 42): Fortify, Dig In (and the rock's hex once
## placed; empty: not yet), a Rift Tear (its depth, "" for none; and its
## rift modifiers, phase 5c step 8b), and a Rest with a relic that steadies.
var fortify: bool = false
var dig_in: bool = false
var rock: Array[int] = []
var rift_depth: String = ""
var rift_mods: Array[String] = []
var rested: bool = false
## Days whose fights are Scouted.
var scouted: Array[int] = []

# Relics and bonds.
var relics: Array[String] = []
## A relic choice waiting (relic ids; empty: none), and what taking one
## costs (the Shrine's; 0: free).
var relic_choice: Array[String] = []
var relic_choice_price: int = 0
## The Shrine (phase 5c step 8b): "" (not taken, or done), "open" (waiting
## for an offering), or the offering its relic choice waits on ("shards",
## "wound:<hero id>", "relic:<relic id>"), spent only if the relic's taken.
var shrine: String = ""

# Events (phase 5c step 8c).
## The event node's choice is made (one an event).
var event_done: bool = false
## A Bloodied Oath's two oaths, each "<oath id>:<hero id>".
var oath_offer: Array[String] = []
## The Rift Merchant: the next shop's prices times this (0: none), and the
## open shop's.
var dear_shop_bp: int = 0
var shop_dear_bp: int = 0
## A Bleeding Tear sealed: the next day's fight is won without fighting.
var sealed: bool = false
## Cards still to take from the waiting pick (The Hollow Throne: 2).
var picks_left: int = 1
## Won day fights in a row with no hero falling, and the streak relics
## already paid (phase 5c step 5a; Bounty Board).
var streak: int = 0
var streaks_paid: Array[String] = []
## Duo bonds found (on at least once), in the order found.
var bonds_found: Array[String] = []
## Growing relics (phase 5c step 4): relic id -> what the team has counted
## since it was taken (a lookup; read in `relics`' order).
var growth: Dictionary[String, int] = {}
## The growing cards the last fight stepped up ("hero id:upgrade id", or
## ":relic id"), for the screen after it.
var grew: Array[String] = []


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
		"stash": stash.duplicate(), "shop": shop, "wares": wares.duplicate(), "rerolls": rerolls, "shop_relics": shop_relics.duplicate(), "magpie_swapped": magpie_swapped,
		"place": place, "camp": camp.duplicate(), "camp_used": camp_used, "hunt": hunt, "mapping": mapping,
		"fortify": fortify, "dig_in": dig_in, "rock": rock.duplicate(), "rift_depth": rift_depth, "rift_mods": rift_mods.duplicate(), "rested": rested,
		"scouted": scouted.duplicate(), "nodes": nodes.duplicate(), "node": node, "taken_nodes": taken_nodes.duplicate(), "magpie_visits": magpie_visits,
		"relics": relics.duplicate(), "relic_choice": relic_choice.duplicate(), "relic_choice_price": relic_choice_price, "shrine": shrine,
		"event_done": event_done, "oath_offer": oath_offer.duplicate(), "dear_shop_bp": dear_shop_bp, "shop_dear_bp": shop_dear_bp, "sealed": sealed, "picks_left": picks_left,
		"streak": streak, "streaks_paid": streaks_paid.duplicate(), "bonds_found": bonds_found.duplicate(),
		"growth": growth.duplicate(), "grew": grew.duplicate(),
		"item_ranks": item_ranks.duplicate(), "item_counts": item_counts.duplicate(), "ranked": ranked.duplicate(),
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
	state.phase = maxi(PHASE_NAMES.find(str(data.get("phase", "route"))), 0) as Phase
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
	state.magpie_swapped = bool(data.get("magpie_swapped", false))
	state.shop_relics = _strings(data.get("shop_relics", []))
	state.place = str(data.get("place", ""))
	state.camp = _strings(data.get("camp", []))
	state.camp_used = str(data.get("camp_used", ""))
	state.hunt = str(data.get("hunt", ""))
	state.mapping = bool(data.get("mapping", false))
	state.fortify = bool(data.get("fortify", false))
	state.dig_in = bool(data.get("dig_in", false))
	state.rock.assign((data.get("rock", []) as Array).map(func(value: Variant) -> int: return int(value)))
	state.rift_depth = str(data.get("rift_depth", ""))
	state.rift_mods = _strings(data.get("rift_mods", []))
	state.rested = bool(data.get("rested", false))
	state.scouted.assign((data.get("scouted", []) as Array).map(func(value: Variant) -> int: return int(value)))
	var growth: Dictionary = data.get("growth", {})
	for relic_id: Variant in growth:
		state.growth[str(relic_id)] = int(growth[relic_id])
	state.grew = _strings(data.get("grew", []))
	var ranks: Dictionary = data.get("item_ranks", {})
	for item_id: Variant in ranks:
		state.item_ranks[str(item_id)] = int(ranks[item_id])
	var counts: Dictionary = data.get("item_counts", {})
	for item_id: Variant in counts:
		state.item_counts[str(item_id)] = int(counts[item_id])
	state.ranked = _strings(data.get("ranked", []))
	state.nodes = _strings(data.get("nodes", []))
	state.node = str(data.get("node", ""))
	state.taken_nodes = _strings(data.get("taken_nodes", []))
	state.magpie_visits = int(data.get("magpie_visits", 0))
	state.relics = _strings(data.get("relics", []))
	state.relic_choice = _strings(data.get("relic_choice", []))
	state.relic_choice_price = int(data.get("relic_choice_price", 0))
	state.shrine = str(data.get("shrine", ""))
	state.event_done = bool(data.get("event_done", false))
	state.oath_offer = _strings(data.get("oath_offer", []))
	state.dear_shop_bp = int(data.get("dear_shop_bp", 0))
	state.shop_dear_bp = int(data.get("shop_dear_bp", 0))
	state.sealed = bool(data.get("sealed", false))
	state.picks_left = int(data.get("picks_left", 1))
	state.streak = int(data.get("streak", 0))
	state.streaks_paid = _strings(data.get("streaks_paid", []))
	state.bonds_found = _strings(data.get("bonds_found", []))
	return state


static func _strings(values: Variant) -> Array[String]:
	var found: Array[String] = []
	found.assign((values as Array).map(func(value: Variant) -> String: return str(value)))
	return found
