extends "res://tools/bots/bot.gd"
## The good bot (docs/plans/rebuild-phase6-bot-tuning.md, sections 2.2 and
## 2.3): it places by reading the fight (tools/bots/placement.gd), never by
## fighting it, and judges its choices by practice fights
## (tools/bots/practice.gd): each option is tried on a copy of the run and
## is worth what the coming fights on the act map are worth after it, plus
## the shards it gains or spends. What a practice fight can't show (a pick
## still to come, a relic still to be drawn, the Magpie's stall) gets a
## fixed worth below.

const Placement = preload("res://tools/bots/placement.gd")
const Practice = preload("res://tools/bots/practice.gd")

## How many of the best-scored formations it keeps (the first legal one is
## placed; the expert tries them all).
const CANDIDATES: int = 6
## The least a choice must add to be made (against noise).
const MIN_GAIN: float = 0.005
## Worths practice can't see: a relic still to be drawn, by tier (Rift
## Tear's reward); a pick still to come (Train); a visit to the Magpie with
## shards to spend; swearing an oath (its doubled deeds).
const RELIC_WORTH: Dictionary[String, float] = {"common": 0.03, "rare": 0.06, "epic": 0.09, "legendary": 0.12}
const PICK_WORTH: float = 0.02
const MAGPIE_WORTH: float = 0.04
const OATH_WORTH: float = 0.03
## At most this many options are tried for one shop decision (the cheapest
## filter first: affordable, and for an item, a hero it changes).
const SHOP_TRIES: int = 8
## Rerolls a shop visit, at most, and the shards it keeps back.
const REROLLS: int = 1
const REROLL_KEEP: int = 20

var _rerolled: String = ""


func _init() -> void:
	label = "good"


func begin(_flow: RunFlow) -> void:
	Practice.clear_cache()


func formation(flow: RunFlow) -> Dictionary[String, Vector2i]:
	var found: Array[Dictionary] = candidates(flow)
	if found.is_empty():
		return super.formation(flow)
	var hexes: Dictionary[String, Vector2i] = {}
	hexes.assign(found[0])
	return hexes


## The best-scored legal formations for the waiting fight, best first.
func candidates(flow: RunFlow) -> Array[Dictionary]:
	return Practice.candidates(flow, CANDIDATES)


## Today's fight: each option in practice, plus its pay when it's won
## surely; the harder fight only when it's a sure win.
func route(flow: RunFlow) -> int:
	var options: Array[String] = flow.state.today()
	if options.size() < 2:
		return 0
	var best: int = 0
	var best_value: float = -INF
	for i: int in options.size():
		var trial: RunFlow = Practice.copy(flow)
		trial.choose_fight(i)
		var fight: float = Practice.fight_worth(trial, options[i])
		var tier: String = flow.run.content.encounters[options[i]].tier
		var value: float = fight + (flow.run.act.pay.get(tier, 0) * Practice.shard_worth(flow) if fight >= Practice.SURE else 0.0)
		if tier == "harder" and fight < Practice.SURE:
			value -= 1.0
		if value > best_value:
			best_value = value
			best = i
	return best


## Equips what waits in the stash on a hero with a free slot that it
## changes.
func loadout(flow: RunFlow) -> void:
	for item_id: String in flow.state.stash.duplicate():
		for hero: RunState.Hero in flow.state.heroes:
			var free: int = hero.slots.find("")
			if free >= 0 and Simple.suits(flow, flow.run.items[item_id], hero) and flow.equip(hero.id, free, item_id).is_empty():
				break


func pick(flow: RunFlow) -> int:
	var coming: Array[String] = Practice.practice_set(flow)
	var best: int = -1
	var best_value: float = Practice.value(flow, func(trial: RunFlow) -> String: return trial.take_shards(), coming)
	for i: int in flow.state.pick.size():
		var value: float = Practice.value(flow, func(trial: RunFlow) -> String: return trial.take_pick(i), coming)
		if value > best_value + MIN_GAIN:
			best_value = value
			best = i
	return best


func relic(flow: RunFlow) -> int:
	var coming: Array[String] = Practice.practice_set(flow)
	if coming.is_empty():
		return 0 if flow.state.shards >= flow.state.relic_choice_price else -1
	var best: int = -1
	var best_value: float = Practice.value(flow, func(trial: RunFlow) -> String: return trial.decline_relic(), coming)
	for i: int in flow.state.relic_choice.size():
		var value: float = Practice.value(flow, func(trial: RunFlow) -> String: return trial.take_relic(i), coming)
		if value > best_value + MIN_GAIN:
			best_value = value
			best = i
	return best


## The shop's best buy by practice (an item on the hero it suits best, a
## relic, a wound treated), if it's worth its price; else a reroll when the
## shards allow one and nothing was worth buying; else selling an item that
## changes no hero. Nothing after the boss (no fights left to buy for).
func shop(flow: RunFlow) -> bool:
	var coming: Array[String] = Practice.practice_set(flow)
	if coming.is_empty():
		return false
	var state: RunState = flow.state
	var tries: Array[Callable] = []
	for i: int in state.wares.size():
		var item_id: String = state.wares[i]
		if item_id.is_empty() or flow.price_of(item_id) > state.shards:
			continue
		if state.item_ranks.has(item_id):
			tries.append(func(trial: RunFlow) -> String: return trial.buy(i))
			continue
		for hero: RunState.Hero in state.heroes:
			var free: int = hero.slots.find("")
			if free >= 0 and Simple.suits(flow, flow.run.items[item_id], hero):
				var hero_id: String = hero.id
				tries.append(func(trial: RunFlow) -> String:
					var said: String = trial.buy(i)
					return said if not said.is_empty() else trial.equip(hero_id, free, item_id))
	for i: int in state.shop_relics.size():
		if not state.shop_relics[i].is_empty() and flow.relic_price(i) <= state.shards:
			tries.append(func(trial: RunFlow) -> String: return trial.buy_relic(i))
	for hero: RunState.Hero in state.heroes:
		if hero.wounds > 0 and flow.wound_price() <= state.shards:
			var hero_id: String = hero.id
			tries.append(func(trial: RunFlow) -> String: return trial.treat_wound(hero_id))
	tries = tries.slice(0, SHOP_TRIES)
	if not tries.is_empty():
		var baseline: float = Practice.team_worth(flow, coming)
		var best: Callable = Callable()
		var best_value: float = baseline + MIN_GAIN
		for action: Callable in tries:
			var value: float = Practice.value(flow, action, coming)
			if value > best_value:
				best_value = value
				best = action
		if best.is_valid():
			return str(best.call(flow)).is_empty()
	var visit: String = "%d:%d:%s:%d" % [state.day, state.attempt, state.shop, state.phase]
	if state.shop == "pedlar" and _rerolled != visit and state.shards - flow.reroll_price() >= REROLL_KEEP:
		_rerolled = visit
		return flow.reroll().is_empty()
	if state.shop == "pedlar":
		for item_id: String in state.stash:
			if not state.heroes.any(func(hero: RunState.Hero) -> bool: return Simple.suits(flow, flow.run.items[item_id], hero)):
				return flow.sell(item_id).is_empty()
	return false


## The node worth most: Camp's best option, a Rift Tear at its best depth
## (its relics if tomorrow's fight there is a sure win), the Magpie with
## shards to spend, an event's best choice, or an oath's.
func node(flow: RunFlow) -> int:
	var best: int = 0
	var best_value: float = -INF
	for i: int in flow.state.nodes.size():
		var value: float = node_worth(flow, i)
		if value > best_value:
			best_value = value
			best = i
	return best


func node_worth(flow: RunFlow, index: int) -> float:
	var node_id: String = flow.state.nodes[index]
	var coming: Array[String] = Practice.practice_set(flow)
	var baseline: float = Practice.team_worth(flow, coming)
	var trial: RunFlow = Practice.copy(flow)
	if not trial.choose_node(index).is_empty():
		return -INF
	if node_id == "camp":
		return _best_camp(trial, coming)[1]
	if node_id == "magpie":
		return baseline + (MAGPIE_WORTH if flow.state.shards >= 15 else 0.0)
	if node_id == "rift_tear":
		var chosen: Array = _best_depth(trial)
		return baseline + chosen[1]
	if node_id == "oath":
		return _best_oath(trial, coming)[1]
	if node_id.begins_with("event:"):
		return _best_event(trial, coming)[1]
	return baseline


func camp(flow: RunFlow) -> int:
	return _best_camp(flow, Practice.practice_set(flow))[0]


func depth(flow: RunFlow) -> int:
	return maxi(_best_depth(flow)[0], 0)


func event(flow: RunFlow) -> Array:
	return _best_event(flow, Practice.practice_set(flow))[0]


func oath(flow: RunFlow) -> int:
	return _best_oath(flow, Practice.practice_set(flow))[0]


## The Shrine: shards if it has them, else a wound on an unwounded hero,
## else its lowest-tier relic; the relic it's shown is then judged like any
## relic choice (a wound or a relic given up shows in practice).
func shrine(flow: RunFlow) -> Array:
	if flow.state.shards >= flow.run.act.shrine_price:
		return ["shards", ""]
	for hero: RunState.Hero in flow.state.heroes:
		if hero.wounds == 0:
			return ["wound", hero.id]
	var lowest: String = ""
	for relic_id: String in flow.state.relics:
		if flow.shrine_tier(relic_id).is_empty() and (lowest.is_empty() or flow.run.relics[relic_id].tier < flow.run.relics[lowest].tier):
			lowest = relic_id
	return ["relic", lowest] if not lowest.is_empty() else []


## Map the Rift: swaps tomorrow's fight that does worst in practice.
func swap(flow: RunFlow) -> int:
	var tomorrow: Array = flow.state.options[flow.state.day]
	var worst: int = 0
	var worst_value: float = INF
	for i: int in tomorrow.size():
		var value: float = Practice.team_worth(flow, [tomorrow[i]] as Array[String])
		if value < worst_value:
			worst_value = value
			worst = i
	return worst


## [option index, worth] of the camp's best option: Rest, Fortify, and Dig
## In by practice; Train a pick's worth; a Hunt its pay when it's a sure
## win; the Shrine a rare relic's when it has the shards; the rest nothing.
func _best_camp(flow: RunFlow, coming: Array[String]) -> Array:
	var state: RunState = flow.state
	var baseline: float = Practice.team_worth(flow, coming)
	var best: int = 0
	var best_value: float = -INF
	for i: int in state.camp.size():
		var value: float = baseline
		match state.camp[i]:
			"rest", "fortify":
				value = Practice.value(flow, func(trial: RunFlow) -> String: return trial.choose_camp(i), coming)
			"dig_in":
				value = Practice.value(flow, func(trial: RunFlow) -> String:
					var said: String = trial.choose_camp(i)
					return said if not said.is_empty() else trial.place_rock(rock(trial)), coming)
			"train":
				value = baseline + PICK_WORTH
			"hunt":
				var trial: RunFlow = Practice.copy(flow)
				if trial.choose_camp(i).is_empty():
					var hunt: float = Practice.fight_worth(trial, trial.state.hunt)
					value = baseline + (flow.run.act.pay.get("hunt", 0) * Practice.shard_worth(flow) if hunt >= Practice.SURE else -0.01)
			"shrine":
				value = baseline + (RELIC_WORTH["rare"] - flow.run.act.shrine_price * Practice.shard_worth(flow) if state.shards >= flow.run.act.shrine_price else 0.0)
		if value > best_value:
			best_value = value
			best = i
	return [best, best_value]


## [depth index, worth] of a Rift Tear's best depth: the deepest whose
## fight tomorrow is a sure win in practice, worth its relics; -1 and a
## loss's worth when none is.
func _best_depth(flow: RunFlow) -> Array:
	var tomorrow: Array[String] = []
	if flow.state.day < flow.run.act.days.size():
		tomorrow.assign(flow.state.options[flow.state.day])
	var best: Array = [-1, -0.5]
	for d: int in flow.run.camps.depths.size():
		var trial: RunFlow = Practice.copy(flow)
		if not trial.choose_depth(d).is_empty():
			continue
		var fight: float = Practice.team_worth(trial, tomorrow.slice(0, 1))
		if fight < Practice.SURE:
			break
		var relics: float = 0.0
		for tier: String in flow.run.camps.depths[d].relics:
			relics += RELIC_WORTH.get(tier, 0.0)
		best = [d, relics]
	return best


## [[choice, target] or [] to walk away, worth] of an event's best choice
## by practice.
func _best_event(flow: RunFlow, coming: Array[String]) -> Array:
	var scene: EventDef.Scene = flow.event_scene()
	var best: Array = []
	var best_value: float = Practice.team_worth(flow, coming) + MIN_GAIN
	if scene == null:
		return [best, best_value]
	for i: int in scene.choices.size():
		var choice: EventDef.Choice = scene.choices[i]
		var targets: Array[String] = [""]
		if choice.needs() != EventDef.Needs.NOTHING:
			targets = flow.event_targets(choice)
		for target: String in targets:
			if not flow.event_problem(i, target).is_empty():
				continue
			var value: float = Practice.value(flow, func(trial: RunFlow) -> String: return trial.choose_event(i, target), coming)
			if value > best_value:
				best_value = value
				best = [i, target]
	return [best, best_value]


## [oath index or -1, worth] of the best oath: one whose burden still wins
## the coming fights surely, worth its doubled deeds.
func _best_oath(flow: RunFlow, coming: Array[String]) -> Array:
	var baseline: float = Practice.team_worth(flow, coming)
	var best: Array = [-1, baseline]
	for i: int in flow.state.oath_offer.size():
		var trial: RunFlow = Practice.copy(flow)
		if not trial.take_oath(i).is_empty():
			continue
		var value: float = Practice.team_worth(trial, coming)
		if value >= Practice.SURE and value + OATH_WORTH > best[1]:
			best = [i, value + OATH_WORTH]
	return best
