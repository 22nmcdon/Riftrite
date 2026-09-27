class_name RunFlow
extends RefCounted
## Drives a run through its days (docs/plans/new-day.md):
##   start_hero (x3: the team draft) -> start_package -> [(stop_choice -> stop)
##   x stops_per_day -> fight_choice -> fight -> rewards] x days -> act_end
## Each stop visit offers a shop and other stops; the boss day's last visit
## is always the Upgrade stop. A first loss replays the day (fresh stops, the
## same two fights); a second ends the run (run_over).
##
## Every action checks the phase, applies, and returns a RunActions.Result;
## a refused action changes nothing. RunActions' between-fight actions
## (moving items, infusing, formation) work in any phase but run_over.
##
## Offers are plain dictionaries (so they save as JSON):
##   type: "hero" (hero, rank, specialization: a draft pick), "item" (item,
##         tier: a shop's ware, loot, or a reward), "rank_up" (after an
##         elite: give it to a hero),
##         "relic" (relic), "essence" (essence), "gold" (amount), "key",
##         "stop" (stop: a node or event id, see RunContent.node_pool),
##         "package" (package: "gold" | "relic" | "item", plus that package's
##         fields)
##   price: gold to pay (0 = free); group: taking one takes the whole group
##   (a relic choice, the reward pick); taken: already taken or bought.
## Randomness comes from RunRandom streams, never from earlier picks.

const PHASES: Array[String] = ["start_hero", "start_package", "stop_choice", "stop", "fight_choice", "fight", "rewards", "act_end", "run_over"]
## What a stop does (a node's kind, "event", or the fixed "upgrade").
const STOP_KINDS: Array[String] = ["shop", "forge", "loot", "vault", "retrain", "event", "upgrade"]
## The reward pick's group (taking one takes them all).
const REWARD_PICK: String = "reward_pick"
const INT_KEYS: Array[String] = ["rank", "tier", "amount", "price"]
const LOSSES_TO_END: int = 2


static func _ok(note: String) -> RunActions.Result:
	return RunActions._ok(note)


static func _fail(error: String) -> RunActions.Result:
	return RunActions._fail(error)


static func _phase_problem(state: RunState, phase: String) -> String:
	return "" if state.phase == phase else "that isn't possible now (the run is at %s)" % state.phase


# --- the run start ------------------------------------------------------------

## A new run: the team draft (docs/plans/heroes-and-deeds.md, section 1).
## Pick 1 of 3 heroes, three times; each offer leaves out heroes already
## picked.
static func new_run(run_seed: int, content: ContentDb) -> RunState:
	var state: RunState = RunState.make(run_seed)
	state.phase = "start_hero"
	_offer_draft(state, content)
	return state


## Three heroes not yet in the team, from the draft stream for this pick.
static func _offer_draft(state: RunState, content: ContentDb) -> void:
	state.offers.clear()
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.START, state.heroes.size()] as Array[int])
	var pool: Array[String] = []
	for hero_id: String in content.hero_ids:
		if state.hero(hero_id) == null:
			pool.append(hero_id)
	for i: int in mini(3, pool.size()):
		var hero_id: String = pool.pop_at(rng.range_int(pool.size()))
		state.offers.append({"type": "hero", "hero": hero_id, "rank": 0, "specialization": "", "price": 0, "taken": false})


## Drafts one of the offered heroes. After the third, on to the starting
## package.
static func pick_start_hero(state: RunState, content: ContentDb, index: int) -> RunActions.Result:
	var problem: String = _phase_problem(state, "start_hero")
	if not problem.is_empty():
		return _fail(problem)
	if index < 0 or index >= state.offers.size():
		return _fail("no offer there")
	var result: RunActions.Result = RunActions.add_hero(state, content, state.offers[index]["hero"])
	if not result.ok:
		return result
	if state.heroes.size() < RunState.TEAM_SIZE:
		_offer_draft(state, content)
		return result
	state.phase = "start_package"
	state.offers.clear()
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.PACKAGE] as Array[int])
	state.offers.append({"type": "package", "package": "gold", "price": 0, "taken": false})
	var relic: String = _pick_relic(state, content, rng, _rarity_only("common"), [])
	if not relic.is_empty():
		state.offers.append({"type": "package", "package": "relic", "relic": relic, "price": 0, "taken": false})
	var item: String = _pick_item(state, content, rng, _rarity_only("common"), false)
	if not item.is_empty():
		state.offers.append({"type": "package", "package": "item", "item": item, "tier": 0, "price": 0, "taken": false})
	return result


static func pick_package(state: RunState, content: ContentDb, run: RunContent, index: int) -> RunActions.Result:
	var problem: String = _phase_problem(state, "start_package")
	if not problem.is_empty():
		return _fail(problem)
	if index < 0 or index >= state.offers.size():
		return _fail("no offer there")
	var offer: Dictionary = state.offers[index]
	var result: RunActions.Result
	match offer["package"]:
		"gold":
			result = RunActions.gain_gold(state, run.economy.package_gold)
		"relic":
			result = RunActions.add_relic(state, content, offer["relic"])
		_:
			result = RunActions.add_item(state, content, offer["item"], offer["tier"])
	if not result.ok:
		return result
	state.gold += run.economy.base_gold
	_start_day(state, content, run)
	return result


# --- days -----------------------------------------------------------------------

## The day's fights to pick from, from the day alone (a replayed day keeps
## them): the boss on the boss day; otherwise one easier and one harder fight
## when the day's pool has both, or else two different ones.
static func _pick_fights(state: RunState, run: RunContent) -> Array[String]:
	var act: ActDef = run.act(state.act)
	var picked: Array[String] = []
	if act.is_boss_day(state.day):
		picked.append(act.boss)
		return picked
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.FIGHT, state.act, state.day] as Array[int])
	var easier: Array[String] = []
	var harder: Array[String] = []
	for encounter_id: String in act.encounters_for(act.pool_for(state.day), state.day):
		if act.is_hard(encounter_id, state.day):
			harder.append(encounter_id)
		else:
			easier.append(encounter_id)
	if not easier.is_empty() and not harder.is_empty():
		picked.append(easier[rng.range_int(easier.size())])
		picked.append(harder[rng.range_int(harder.size())])
		return picked
	var pool: Array[String] = easier + harder
	for i: int in mini(2, pool.size()):
		picked.append(pool.pop_at(rng.range_int(pool.size())))
	return picked


static func _start_day(state: RunState, content: ContentDb, run: RunContent) -> void:
	state.fight_options = _pick_fights(state, run)
	state.encounter_id = ""
	state.visit = 0
	_offer_stops(state, content, run)


## A fight's enemy HP scaling today (the act's pool entry).
static func fight_hp_bp(state: RunState, run: RunContent, encounter_id: String) -> int:
	return run.act(state.act).hp_bp(encounter_id, state.day)


## Whether a fight is the harder of the day's two.
static func is_hard_fight(state: RunState, run: RunContent, encounter_id: String) -> bool:
	return state.fight_options.size() > 1 and run.act(state.act).is_hard(encounter_id, state.day)


# --- stop choices -----------------------------------------------------------------

## The day's next stop visit: a pick of node_choices stops, one of them a
## shop and the rest anything but a shop, each drawn by weight from the
## stops that apply now. The boss day's last visit is always the Upgrade stop.
static func _offer_stops(state: RunState, content: ContentDb, run: RunContent) -> void:
	state.offers.clear()
	state.stop_kind = ""
	state.stop_node = ""
	state.stop_used = false
	if run.act(state.act).is_boss_day(state.day) and state.visit == run.economy.stops_per_day - 1:
		_enter_stop(state, content, run, "upgrade")
		return
	state.phase = "stop_choice"
	var shops: Array[String] = []
	var shop_weights: Array[int] = []
	var others: Array[String] = []
	var other_weights: Array[int] = []
	for node_id: String in run.node_pool():
		if not _stop_applies(state, run.node_kind(node_id)):
			continue
		if run.is_shop(node_id):
			shops.append(node_id)
			shop_weights.append(run.node_weight(node_id))
		else:
			others.append(node_id)
			other_weights.append(run.node_weight(node_id))
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.STOPS, state.act, state.day, state.attempt, state.visit] as Array[int])
	var shop: int = RunRandom.pick_weighted(rng, shop_weights)
	if shop >= 0:
		state.offers.append({"type": "stop", "stop": shops[shop], "price": 0, "taken": false})
	for i: int in run.economy.node_choices - state.offers.size():
		var picked: int = RunRandom.pick_weighted(rng, other_weights)
		if picked < 0:
			break
		state.offers.append({"type": "stop", "stop": others[picked], "price": 0, "taken": false})
		others.remove_at(picked)
		other_weights.remove_at(picked)


## Whether a node of this kind can do anything right now.
static func _stop_applies(state: RunState, kind: String) -> bool:
	match kind:
		"forge":
			return _anything_infused(state)
		"vault":
			return state.keys > 0
		"retrain":
			return state.heroes.any(func(hero: RunHero) -> bool: return not hero.specialization_id.is_empty())
	return true


static func _anything_infused(state: RunState) -> bool:
	for item: RunItem in state.stash:
		if not item.essence_ids.is_empty():
			return true
	for hero: RunHero in state.heroes:
		for item: RunItem in hero.items:
			if not item.essence_ids.is_empty():
				return true
	return false


# --- stops ----------------------------------------------------------------------

static func pick_stop(state: RunState, content: ContentDb, run: RunContent, index: int) -> RunActions.Result:
	var problem: String = _phase_problem(state, "stop_choice")
	if not problem.is_empty():
		return _fail(problem)
	if index < 0 or index >= state.offers.size():
		return _fail("no offer there")
	var stop: String = state.offers[index]["stop"]
	if not run.node_pool().has(stop):
		return _fail("unknown stop \"%s\"" % stop)
	_enter_stop(state, content, run, stop)
	return _ok("stopped at %s" % run.node_name(stop))


## Enters a stop: a node or event id from the pool, or "upgrade".
static func _enter_stop(state: RunState, content: ContentDb, run: RunContent, stop: String) -> void:
	var kind: String = "upgrade" if stop == "upgrade" else run.node_kind(stop)
	state.phase = "stop"
	state.stop_kind = kind
	state.stop_node = stop
	state.stop_used = false
	state.reroll_count = 0
	state.offers.clear()
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.STOP, state.act, state.day, state.attempt, state.visit] as Array[int])
	match kind:
		"shop":
			_fill_shop(state, content, run)
		"loot":
			_add_loot(state, content, run, rng, run.nodes[stop].loot)
		"vault":
			state.keys -= 1
			if rng.range_int(2) == 0:
				_add_relic_offers(state, content, rng, run.economy.relic_weights, 1, "", 0)
			else:
				_add_item_offer(state, content, rng, run.economy.vault_rarity_weights, run.economy.loot_tier_weights, true)
		"event":
			_add_event(state, content, run, rng, run.events[stop])


static func _add_loot(state: RunState, content: ContentDb, run: RunContent, rng: SimRng, loot: String) -> void:
	match loot:
		"item":
			_add_item_offer(state, content, rng, run.economy.rarity_weights, run.economy.loot_tier_weights, true)
		"essence":
			state.offers.append({"type": "essence", "essence": content.essence_ids[rng.range_int(content.essence_ids.size())], "price": 0, "taken": false})
		_:
			state.offers.append({"type": "gold", "amount": run.economy.loot_gold, "price": 0, "taken": false})


static func _add_event(state: RunState, content: ContentDb, run: RunContent, rng: SimRng, event: EventDef) -> void:
	var flat_tiers: Array[int] = [1, 0, 0, 0]
	match event.kind:
		"gold":
			state.offers.append({"type": "gold", "amount": event.amount, "price": 0, "taken": false})
		"item_by_rarity":
			_add_item_offer(state, content, rng, run.economy.event_rarity_weights, flat_tiers, true)
		"item_by_tier":
			var common_up: Array[int] = [1, 1, 1, 1, 0]
			_add_item_offer(state, content, rng, common_up, run.economy.loot_tier_weights, false)
		"relic_by_rarity":
			_add_relic_offers(state, content, rng, run.economy.relic_weights, 1, "", 0)
		"relic_merchant":
			_add_relic_offers(state, content, rng, run.economy.relic_weights, run.economy.relic_choices, "merchant", -1, run.economy)
		"legendary_relic":
			_add_relic_offers(state, content, rng, _rarity_only("legendary"), 1, "", 0)
		"legendary_item":
			_add_item_offer(state, content, rng, _rarity_only("legendary"), flat_tiers, false)
		"essence":
			state.offers.append({"type": "essence", "essence": content.essence_ids[rng.range_int(content.essence_ids.size())], "price": 0, "taken": false})
		"key":
			state.offers.append({"type": "key", "price": 0, "taken": false})
	for offer: Dictionary in state.offers:
		offer["event"] = event.id


# --- shops ------------------------------------------------------------------------

## Whether the run is at a shop stop (where buy, sell, and reroll work).
static func at_shop(state: RunState) -> bool:
	return state.phase == "stop" and state.stop_kind == "shop"


## Fills the shop being visited (docs/plans/new-day.md, "Shops"): an essence
## merchant's essence, then items that fit the shop (topped up with any item),
## at the shop's tier or by the act's shop tier odds. Never relics,
## enemy-only items, or Legendaries; outside tier shops, never at a different
## tier than a copy the guild holds.
static func _fill_shop(state: RunState, content: ContentDb, run: RunContent) -> void:
	state.offers.clear()
	var shop: ShopDef = run.nodes[state.stop_node].shop
	var economy: EconomyDef = run.economy
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.SHOP, state.act, state.day, state.attempt, state.visit, state.reroll_count] as Array[int])
	if not shop.essence.is_empty():
		state.offers.append({"type": "essence", "essence": shop.essence, "price": economy.essence_price, "taken": false})
	var partners: Array[String] = []
	if shop.partners:
		partners = partner_items(state, content)
	var fits: Callable = func(def: ItemDef) -> bool:
		return shop.fits(def) and (not shop.partners or partners.has(def.id))
	var offered: Array[String] = []
	for i: int in shop.count if shop.count > 0 else economy.shop_items:
		var item_id: String = _pick_item(state, content, rng, economy.rarity_weights, false, offered, fits)
		if item_id.is_empty():
			item_id = _pick_item(state, content, rng, economy.rarity_weights, false, offered)
		if item_id.is_empty():
			break
		offered.append(item_id)
		var tier: int = shop.tier
		if tier < 0:
			tier = maxi(RunRandom.pick_weighted(rng, run.act(state.act).shop_tier_weights), 0)
			var held: Array[int] = _held_tiers(state, item_id)
			if not held.is_empty() and not held.has(tier):
				tier = held.min()
		state.offers.append({"type": "item", "item": item_id, "tier": tier, "price": economy.item_price_for(content.items[item_id].rarity, tier), "taken": false})


## The Synergy Peddler's wares: items that would complete a synergy with what
## the guild holds (a pair's missing half, a signature item for a hero in the
## team, an item that transforms with an essence held), minus items held.
static func partner_items(state: RunState, content: ContentDb) -> Array[String]:
	var held: Array[String] = []
	var essences: Array[String] = state.pouch.duplicate()
	for list: Array in _item_lists(state):
		for item: RunItem in list:
			held.append(item.item_id)
			essences.append_array(item.essence_ids)
	var wanted: Array[String] = []
	for synergy_id: String in content.synergy_ids:
		var synergy: SynergyDef = content.synergies[synergy_id]
		match synergy.layer:
			SynergyDef.Layer.PAIR:
				for i: int in 2:
					if held.has(synergy.items[i]):
						wanted.append(synergy.items[1 - i])
			SynergyDef.Layer.SIGNATURE:
				if state.hero(synergy.hero) != null:
					wanted.append(synergy.items[0])
			SynergyDef.Layer.TRANSFORMATION:
				if essences.has(synergy.essence):
					wanted.append(synergy.items[0])
	var result: Array[String] = []
	for item_id: String in wanted:
		if not held.has(item_id) and not result.has(item_id):
			result.append(item_id)
	return result


## The stash, then each hero's items.
static func _item_lists(state: RunState) -> Array:
	var lists: Array = [state.stash]
	for hero: RunHero in state.heroes:
		lists.append(hero.items)
	return lists


static func _held_tiers(state: RunState, item_id: String) -> Array[int]:
	var tiers: Array[int] = []
	for list: Array in _item_lists(state):
		for item: RunItem in list:
			if item.item_id == item_id and not tiers.has(item.tier):
				tiers.append(item.tier)
	return tiers


## Buys a shop offer. An item that would combine with a copy the guild holds
## (see upgrade_target) combines straight into that copy, so buying an
## upgrade needs no stash room.
static func buy(state: RunState, content: ContentDb, index: int) -> RunActions.Result:
	if not at_shop(state):
		return _fail("buying needs a shop")
	var target: int = upgrade_target(state, content, index)
	if target < 0:
		return _take_offer(state, content, index)
	var offer: Dictionary = state.offers[index]
	if offer["price"] > state.gold:
		return _fail("not enough gold (%d of %d)" % [state.gold, offer["price"]])
	var held: RunItem = state.find_item(target)
	held.tier += 1
	state.gold -= offer["price"]
	offer["taken"] = true
	return _ok("%s upgraded to %s" % [content.items[held.item_id].name, TuningDef.TIER_LABELS[held.tier]])


## The uid of the held item a shop's item offer would upgrade (same item and
## tier, below S, not Legendary), or -1. The UI lights these up.
static func upgrade_target(state: RunState, content: ContentDb, index: int) -> int:
	if index < 0 or index >= state.offers.size():
		return -1
	var offer: Dictionary = state.offers[index]
	if offer["type"] != "item" or offer["taken"] or offer["tier"] >= 3 or content.items[offer["item"]].rarity == "legendary":
		return -1
	var lists: Array = []
	for hero: RunHero in state.heroes:
		lists.append(hero.items)
	lists.append(state.stash)
	for list: Array in lists:
		for item: RunItem in list:
			if item.item_id == offer["item"] and item.tier == offer["tier"]:
				return item.uid
	return -1


## What an item sells for: half its buy price (by rarity and tier), rounded
## down.
static func sell_price(content: ContentDb, run: RunContent, item: RunItem) -> int:
	return run.economy.sell_price(run.economy.item_price_for(content.items[item.item_id].rarity, item.tier))


static func sell(state: RunState, content: ContentDb, run: RunContent, uid: int) -> RunActions.Result:
	if not at_shop(state):
		return _fail("selling needs a shop")
	var item: RunItem = state.find_item(uid)
	if item == null:
		return _fail("that item isn't in the guild")
	var price: int = sell_price(content, run, item)
	var result: RunActions.Result = RunActions.discard_item(state, content, uid)
	if not result.ok:
		return result
	state.gold += price
	result.note = "sold %s for %d gold" % [content.items[item.item_id].name, price]
	return result


static func reroll_cost(state: RunState, run: RunContent) -> int:
	return run.economy.reroll_base + run.economy.reroll_step * state.reroll_count


static func reroll(state: RunState, content: ContentDb, run: RunContent) -> RunActions.Result:
	if not at_shop(state):
		return _fail("rerolling needs a shop")
	var cost: int = reroll_cost(state, run)
	var result: RunActions.Result = RunActions.spend_gold(state, cost)
	if not result.ok:
		return result
	state.reroll_count += 1
	_fill_shop(state, content, run)
	return _ok("rerolled the shop for %d gold" % cost)


# --- one-time stops -----------------------------------------------------------------

## Reforges at the Forge.
static func forge_reforge(state: RunState, content: ContentDb, uid: int) -> RunActions.Result:
	if state.phase != "stop" or state.stop_kind != "forge":
		return _fail("reforging needs the Forge")
	return RunActions.reforge(state, content, uid)


## Switches a hero to another of their specializations (once, at a Retrain
## stop). The new specialization's deed starts from zero; the calling is kept.
static func retrain(state: RunState, content: ContentDb, hero_id: String, specialization_id: String) -> RunActions.Result:
	if state.phase != "stop" or state.stop_kind != "retrain":
		return _fail("retraining needs a Retrain stop")
	if state.stop_used:
		return _fail("this stop's retraining is used")
	var hero: RunHero = state.hero(hero_id)
	if hero == null or hero.specialization_id.is_empty():
		return _fail("only a hero with a specialization can retrain")
	if hero.specialization_id == specialization_id:
		return _fail("that's already their specialization")
	var problem: String = RunActions._spec_problem(content, hero_id, specialization_id)
	if not problem.is_empty():
		return _fail(problem)
	hero.specialization_id = specialization_id
	hero.spec_progress = 0
	hero.spec_choice = -1
	state.stop_used = true
	return _ok("%s retrains as a %s" % [hero_id, content.specializations[specialization_id].name])


## Raises one item a tier, for free (once, at the Upgrade stop before the
## boss). Enemy-only items too; not S, not Legendaries.
static func upgrade(state: RunState, content: ContentDb, uid: int) -> RunActions.Result:
	if state.phase != "stop" or state.stop_kind != "upgrade":
		return _fail("upgrading needs the Upgrade stop")
	if state.stop_used:
		return _fail("this stop's upgrade is used")
	var item: RunItem = state.find_item(uid)
	if item == null:
		return _fail("that item isn't in the guild")
	var def: ItemDef = content.items[item.item_id]
	if def.rarity == "legendary":
		return _fail("Legendaries upgrade through their own paths")
	if item.tier >= 3:
		return _fail("%s is already S" % def.name)
	item.tier += 1
	state.stop_used = true
	return _ok("%s rises to %s" % [def.name, TuningDef.TIER_LABELS[item.tier]])


## Leaves the stop: on to the day's next stop visit, or to the fight pick
## after the last (straight to the fight when there's only one).
static func leave_stop(state: RunState, content: ContentDb, run: RunContent) -> RunActions.Result:
	var problem: String = _phase_problem(state, "stop")
	if not problem.is_empty():
		return _fail(problem)
	state.visit += 1
	if state.visit < run.economy.stops_per_day:
		_offer_stops(state, content, run)
		return _ok("back on the road")
	state.offers.clear()
	state.stop_kind = ""
	state.stop_node = ""
	state.reroll_count = 0
	if state.fight_options.size() == 1:
		state.encounter_id = state.fight_options[0]
		state.phase = "fight"
		return _ok("on to the fight")
	state.phase = "fight_choice"
	return _ok("choose the day's fight")


## Picks one of the day's fights.
static func pick_fight(state: RunState, content: ContentDb, index: int) -> RunActions.Result:
	var problem: String = _phase_problem(state, "fight_choice")
	if not problem.is_empty():
		return _fail(problem)
	if index < 0 or index >= state.fight_options.size():
		return _fail("no fight there")
	state.encounter_id = state.fight_options[index]
	state.phase = "fight"
	return _ok("on to fight %s" % content.encounters[state.encounter_id].name)


## Gives a rank-up (an elite's reward) to a hero of your choice
## (docs/plans/heroes-and-deeds.md, section 3).
static func give_rank_up(state: RunState, content: ContentDb, index: int, hero_id: String) -> RunActions.Result:
	if state.phase != "rewards":
		return _fail("there's no rank-up to give now")
	if index < 0 or index >= state.offers.size() or state.offers[index]["type"] != "rank_up":
		return _fail("no rank-up there")
	if state.offers[index]["taken"]:
		return _fail("already given")
	var result: RunActions.Result = RunActions.rank_up(state, content, hero_id)
	if result.ok:
		state.offers[index]["taken"] = true
	return result


## Takes an offer at a stop or among rewards (or a relic-merchant purchase;
## at a shop, buys it).
static func take(state: RunState, content: ContentDb, index: int) -> RunActions.Result:
	if at_shop(state):
		return buy(state, content, index)
	if state.phase != "stop" and state.phase != "rewards":
		return _fail("there's nothing to take now")
	return _take_offer(state, content, index)


static func _take_offer(state: RunState, content: ContentDb, index: int) -> RunActions.Result:
	if index < 0 or index >= state.offers.size():
		return _fail("no offer there")
	var offer: Dictionary = state.offers[index]
	if offer["taken"]:
		return _fail("already taken")
	var price: int = offer["price"]
	if price > state.gold:
		return _fail("not enough gold (%d of %d)" % [state.gold, price])
	var result: RunActions.Result
	match offer["type"]:
		"item":
			result = RunActions.add_item(state, content, offer["item"], offer["tier"])
		"rank_up":
			return _fail("choose which hero gets the rank-up")
		"relic":
			result = RunActions.add_relic(state, content, offer["relic"])
		"essence":
			result = RunActions.add_essence(state, content, offer["essence"])
		"gold":
			result = RunActions.gain_gold(state, offer["amount"])
		"key":
			state.keys += 1
			result = _ok("took a key")
		_:
			return _fail("that can't be taken")
	if not result.ok:
		return result
	state.gold -= price
	offer["taken"] = true
	if offer.has("group"):
		for other: Dictionary in state.offers:
			if other.get("group", "") == offer["group"]:
				other["taken"] = true
	return result


# --- fights and rewards ---------------------------------------------------------

## Runs today's fight. Returns [Result, FightResult, FightSetup] (the last two
## are null if the fight couldn't start). The UI replays the fight from the
## setup (same setup, same fight).
static func fight(state: RunState, content: ContentDb, run: RunContent) -> Array:
	var problem: String = _phase_problem(state, "fight")
	if not problem.is_empty():
		return [_fail(problem), null, null]
	for hero: RunHero in state.heroes:
		if hero.needs_specialization:
			return [_fail("%s needs a specialization first" % hero.hero_id), null, null]
	var setup: FightSetup = RunFight.setup_for(state, content, state.encounter_id, fight_hp_bp(state, run, state.encounter_id))
	var result: FightResult = CombatSim.run(setup, content)
	if not result.errors.is_empty():
		return [_fail("the fight couldn't start: %s" % result.errors[0]), result, setup]
	var grown: Array[String] = RunFight.apply_result(state, content, result)
	var outcome: RunActions.Result
	if result.guild_won():
		_give_rewards(state, content, run)
		outcome = _ok("won")
	elif state.losses >= LOSSES_TO_END:
		state.phase = "run_over"
		state.offers.clear()
		outcome = _ok("the guild falls; the run is over")
	else:
		state.gold += run.economy.loss_gold_base + run.economy.loss_gold_per_win * state.wins
		state.attempt += 1
		_start_day(state, content, run)
		outcome = _ok("lost; the day starts over")
	outcome.notes = grown
	return [outcome, result, setup]


## A win's rewards (docs/plans/new-day.md): gold now (more after the harder
## fight), and offers for the rest: the team's essence, the reward pick, and
## after an elite the rank-up and a relic choice (and maybe a key), after the
## boss a relic choice.
static func _give_rewards(state: RunState, content: ContentDb, run: RunContent) -> void:
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.REWARDS, state.act, state.day] as Array[int])
	state.phase = "rewards"
	state.offers.clear()
	var encounter: EncounterDef = content.encounters[state.encounter_id]
	var economy: EconomyDef = run.economy
	var hard: bool = is_hard_fight(state, run, state.encounter_id)
	var gold: int = economy.win_gold_base + economy.win_gold_per_day * state.day
	match encounter.kind:
		"elite":
			gold = FixedMath.apply_bp(gold, economy.elite_gold_bp)
		"boss":
			gold = economy.boss_gold
	if hard:
		gold = FixedMath.apply_bp(gold, economy.hard_gold_bp)
	state.gold += gold
	var essence: String = team_essence(content, encounter)
	if not essence.is_empty():
		state.offers.append({"type": "essence", "essence": essence, "price": 0, "taken": false})
	_add_reward_pick(state, content, run, encounter, economy.hard_reward_rarity_weights if hard else economy.reward_rarity_weights, rng)
	if encounter.kind == "elite":
		state.offers.append({"type": "rank_up", "price": 0, "taken": false})
		_add_relic_offers(state, content, rng, economy.elite_relic_weights, economy.relic_choices, "relic_choice", 0)
		if rng.roll_bp(economy.elite_key_chance_bp):
			state.keys += 1
	elif encounter.kind == "boss":
		_add_relic_offers(state, content, rng, economy.boss_relic_weights, economy.relic_choices, "relic_choice", 0)


## Finishes the rewards: on to the next day, or the act's end after the boss.
static func done(state: RunState, content: ContentDb, run: RunContent) -> RunActions.Result:
	var problem: String = _phase_problem(state, "rewards")
	if not problem.is_empty():
		return _fail(problem)
	state.offers.clear()
	if run.act(state.act).is_boss_day(state.day):
		state.phase = "act_end"
		return _ok("the act is won")
	state.day += 1
	state.attempt = 0
	_start_day(state, content, run)
	return _ok("day %d begins" % state.day)


## The essence a team yields: its most common enemy essence (ties go to the
## first in the encounter), or "".
static func team_essence(content: ContentDb, encounter: EncounterDef) -> String:
	var best: String = ""
	var best_count: int = 0
	for slot: EncounterDef.Slot in encounter.units:
		var essence: String = content.enemies[slot.enemy_id].essence
		if essence.is_empty():
			continue
		var count: int = 0
		for other: EncounterDef.Slot in encounter.units:
			if content.enemies[other.enemy_id].essence == essence:
				count += 1
		if count > best_count:
			best = essence
			best_count = count
	return best


## The reward pick (take one): one drop from the enemy team's items (at
## their tier) and relics (not already held), enemy-only ones included; then
## reward_pool_items different items from the pool (never enemy-only or
## Legendary), rarity by `weights`, tier by the act's shop tier odds.
static func _add_reward_pick(state: RunState, content: ContentDb, run: RunContent, encounter: EncounterDef, weights: Array[int], rng: SimRng) -> void:
	var candidates: Array[Dictionary] = []
	for slot: EncounterDef.Slot in encounter.units:
		for entry: LoadoutEntry in content.enemies[slot.enemy_id].items:
			candidates.append({"type": "item", "item": entry.item_id, "tier": entry.tier, "price": 0, "taken": false, "group": REWARD_PICK, "drop": "yes"})
	for relic_id: String in encounter.relics:
		if not state.relics.has(relic_id):
			candidates.append({"type": "relic", "relic": relic_id, "price": 0, "taken": false, "group": REWARD_PICK, "drop": "yes"})
	var picked: Array[String] = []
	if not candidates.is_empty():
		var drop: Dictionary = candidates[rng.range_int(candidates.size())]
		state.offers.append(drop)
		if drop["type"] == "item":
			picked.append(drop["item"])
	for i: int in run.economy.reward_pool_items:
		var item_id: String = _pick_item(state, content, rng, weights, false, picked)
		if item_id.is_empty():
			break
		picked.append(item_id)
		var tier: int = maxi(RunRandom.pick_weighted(rng, run.act(state.act).shop_tier_weights), 0)
		state.offers.append({"type": "item", "item": item_id, "tier": tier, "price": 0, "taken": false, "group": REWARD_PICK})


# --- picking items and relics ---------------------------------------------------

static func _rarity_only(rarity: String) -> Array[int]:
	var weights: Array[int] = [0, 0, 0, 0, 0]
	weights[ItemDef.RARITIES.find(rarity)] = 1
	return weights


## A random item id: rarity by `weights` (rarities with nothing to offer are
## skipped), then any item of that rarity equally. Never a Legendary already
## seen (and an offered Legendary counts as seen). Enemy-only items only when
## `enemy_only_ok`; with `fits` (ItemDef -> bool), only items it accepts.
static func _pick_item(state: RunState, content: ContentDb, rng: SimRng, weights: Array[int], enemy_only_ok: bool, exclude: Array[String] = [], fits: Callable = Callable()) -> String:
	var by_rarity: Array[Array] = [[], [], [], [], []]
	for item_id: String in content.item_ids:
		var def: ItemDef = content.items[item_id]
		if (def.enemy_only and not enemy_only_ok) or exclude.has(item_id) or state.legendaries_seen.has(item_id):
			continue
		if fits.is_valid() and not fits.call(def):
			continue
		by_rarity[ItemDef.RARITIES.find(def.rarity)].append(item_id)
	var usable: Array[int] = []
	for i: int in weights.size():
		usable.append(weights[i] if not by_rarity[i].is_empty() else 0)
	var rarity: int = RunRandom.pick_weighted(rng, usable)
	if rarity < 0:
		return ""
	var pool: Array = by_rarity[rarity]
	var item_id: String = pool[rng.range_int(pool.size())]
	if content.items[item_id].rarity == "legendary":
		state.legendaries_seen.append(item_id)
	return item_id


static func _add_item_offer(state: RunState, content: ContentDb, rng: SimRng, rarity_weights: Array[int], tier_weights: Array[int], enemy_only_ok: bool) -> void:
	var item_id: String = _pick_item(state, content, rng, rarity_weights, enemy_only_ok)
	if item_id.is_empty():
		return
	var tier: int = maxi(RunRandom.pick_weighted(rng, tier_weights), 0)
	var path: LegendaryDef = content.items[item_id].legendary
	if path != null:
		tier = path.start_tier
	state.offers.append({"type": "item", "item": item_id, "tier": tier, "price": 0, "taken": false})


static func _pick_relic(state: RunState, content: ContentDb, rng: SimRng, weights: Array[int], exclude: Array[String]) -> String:
	var by_rarity: Array[Array] = [[], [], [], [], []]
	for relic_id: String in content.relic_ids:
		var def: RelicDef = content.relics[relic_id]
		if def.enemy_only or state.relics.has(relic_id) or exclude.has(relic_id):
			continue
		by_rarity[ItemDef.RARITIES.find(def.rarity)].append(relic_id)
	var usable: Array[int] = []
	for i: int in weights.size():
		usable.append(weights[i] if not by_rarity[i].is_empty() else 0)
	var rarity: int = RunRandom.pick_weighted(rng, usable)
	if rarity < 0:
		return ""
	var pool: Array = by_rarity[rarity]
	return pool[rng.range_int(pool.size())]


## Adds up to `count` different relics. With a `group`, taking one takes them
## all (a relic choice). `price` 0 = free; -1 = priced by rarity (`economy`).
static func _add_relic_offers(state: RunState, content: ContentDb, rng: SimRng, weights: Array[int], count: int, group: String, price: int, economy: EconomyDef = null) -> void:
	var picked: Array[String] = []
	for i: int in count:
		var relic_id: String = _pick_relic(state, content, rng, weights, picked)
		if relic_id.is_empty():
			return
		picked.append(relic_id)
		var offer: Dictionary = {"type": "relic", "relic": relic_id, "price": price, "taken": false}
		if price < 0:
			offer["price"] = economy.relic_price[ItemDef.RARITIES.find(content.relics[relic_id].rarity)]
		if not group.is_empty():
			offer["group"] = group
		state.offers.append(offer)


# --- saving offers --------------------------------------------------------------

## Reads a saved offer back (JSON numbers come back as floats).
static func read_offer(reader: DataReader) -> Dictionary:
	var offer: Dictionary = {}
	for key: String in reader.map_keys():
		if INT_KEYS.has(key):
			offer[key] = reader.req_int(key)
		elif key == "taken":
			offer[key] = reader.opt_bool(key, false)
		else:
			offer[key] = reader.opt_string(key, "")
	reader.finish()
	return offer
