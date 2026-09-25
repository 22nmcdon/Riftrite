class_name RunFlow
extends RefCounted
## Drives a run through its days (docs/plans/day-structure.md):
##   start_hero -> start_package -> [caravan -> stop_choice -> stop -> fight
##   -> rewards] x days -> act_end
## A first loss replays the day (back to the Caravan, same fight); a second
## ends the run (run_over). The day before the boss, the stop is always the
## Upgrade stop.
##
## Every action checks the phase, applies, and returns a RunActions.Result;
## a refused action changes nothing. RunActions' between-fight actions
## (moving items, infusing, formation) work in any phase but run_over.
##
## Offers are plain dictionaries (so they save as JSON):
##   type: "hero" (hero, rank, specialization), "item" (item, tier),
##         "relic" (relic), "essence" (essence), "gold" (amount), "key",
##         "stop" (stop), "package" (package: "gold" | "relic" | "item", plus
##         that package's fields)
##   price: gold to pay (0 = free); group: taking one takes the whole group
##   (a relic choice); taken: already taken or bought.
## Randomness comes from RunRandom streams, never from earlier picks.

const PHASES: Array[String] = ["start_hero", "start_package", "caravan", "stop_choice", "stop", "fight", "rewards", "act_end", "run_over"]
const STOP_KINDS: Array[String] = ["forge", "loot", "vault", "retrain", "event", "upgrade"]
const INT_KEYS: Array[String] = ["rank", "tier", "amount", "price"]
const LOSSES_TO_END: int = 2


static func _ok(note: String) -> RunActions.Result:
	return RunActions._ok(note)


static func _fail(error: String) -> RunActions.Result:
	return RunActions._fail(error)


static func _phase_problem(state: RunState, phase: String) -> String:
	return "" if state.phase == phase else "that isn't possible now (the run is at %s)" % state.phase


# --- the run start ------------------------------------------------------------

## A new run: 3 random heroes to pick from.
static func new_run(run_seed: int, content: ContentDb) -> RunState:
	var state: RunState = RunState.make(run_seed)
	state.phase = "start_hero"
	var rng: SimRng = RunRandom.stream(run_seed, [RunRandom.START] as Array[int])
	var pool: Array[String] = content.hero_ids.duplicate()
	for i: int in mini(3, pool.size()):
		var hero_id: String = pool.pop_at(rng.range_int(pool.size()))
		state.offers.append({"type": "hero", "hero": hero_id, "rank": 0, "specialization": "", "price": 0, "taken": false})
	return state


static func pick_start_hero(state: RunState, content: ContentDb, index: int) -> RunActions.Result:
	var problem: String = _phase_problem(state, "start_hero")
	if not problem.is_empty():
		return _fail(problem)
	if index < 0 or index >= state.offers.size():
		return _fail("no offer there")
	var result: RunActions.Result = RunActions.add_hero(state, content, state.offers[index]["hero"])
	if not result.ok:
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

## Today's fight, from the day alone (a replayed day keeps it).
static func _pick_encounter(state: RunState, run: RunContent) -> String:
	var act: ActDef = run.act(state.act)
	if act.is_boss_day(state.day):
		return act.boss
	var pool: Array[String] = act.encounters_for(act.elites if act.is_elite_day(state.day) else act.normal, state.day)
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.FIGHT, state.act, state.day] as Array[int])
	return pool[rng.range_int(pool.size())]


static func _start_day(state: RunState, content: ContentDb, run: RunContent) -> void:
	state.encounter_id = _pick_encounter(state, run)
	state.phase = "caravan"
	state.stop_kind = ""
	state.stop_used = false
	state.reroll_count = 0
	_convert_shards(state, content, run)
	_fill_caravan(state, content, run)


# --- the Caravan ----------------------------------------------------------------

static func _fill_caravan(state: RunState, content: ContentDb, run: RunContent) -> void:
	state.offers.clear()
	var economy: EconomyDef = run.economy
	var tier_weights: Array[int] = run.act(state.act).caravan_tier_weights
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.CARAVAN, state.act, state.day, state.attempt, state.reroll_count] as Array[int])
	var offered: Array[String] = []
	for i: int in economy.caravan_items:
		var item_id: String = _pick_item(state, content, rng, economy.rarity_weights, false, offered)
		if item_id.is_empty():
			break
		offered.append(item_id)
		var tier: int = maxi(RunRandom.pick_weighted(rng, tier_weights), 0)
		var held: Array[int] = _held_tiers(state, item_id)
		if not held.is_empty() and not held.has(tier):
			tier = held.min()
		state.offers.append({"type": "item", "item": item_id, "tier": tier, "price": economy.item_price[tier], "taken": false})
	var heroes: Array[String] = []
	for hero_id: String in content.hero_ids:
		var held_hero: RunHero = state.hero(hero_id)
		if (held_hero != null and held_hero.rank < 3) or (held_hero == null and state.heroes.size() < FightSetup.ROSTER_CAP):
			heroes.append(hero_id)
	for i: int in mini(economy.caravan_heroes, heroes.size()):
		var hero_id: String = heroes.pop_at(rng.range_int(heroes.size()))
		var held_hero: RunHero = state.hero(hero_id)
		var rank: int = held_hero.rank if held_hero != null else maxi(RunRandom.pick_weighted(rng, tier_weights), 0)
		var spec: String = ""
		if held_hero == null and rank >= 1:
			spec = _random_specialization(content, hero_id, rng)
		state.offers.append({"type": "hero", "hero": hero_id, "rank": rank, "specialization": spec, "price": economy.hero_price[rank], "taken": false})


static func _held_tiers(state: RunState, item_id: String) -> Array[int]:
	var tiers: Array[int] = []
	var lists: Array = [state.stash]
	for hero: RunHero in state.heroes:
		lists.append(hero.items)
	for list: Array in lists:
		for item: RunItem in list:
			if item.item_id == item_id and not tiers.has(item.tier):
				tiers.append(item.tier)
	return tiers


static func _random_specialization(content: ContentDb, hero_id: String, rng: SimRng) -> String:
	var options: Array[String] = []
	for spec_id: String in content.specialization_ids:
		if content.specializations[spec_id].hero == hero_id:
			options.append(spec_id)
	return "" if options.is_empty() else options[rng.range_int(options.size())]


## Buys a Caravan offer. An item that would combine with a copy the guild
## holds (see upgrade_target) combines straight into that copy, so buying
## an upgrade needs no stash room.
static func buy(state: RunState, content: ContentDb, index: int) -> RunActions.Result:
	var problem: String = _phase_problem(state, "caravan")
	if not problem.is_empty():
		return _fail(problem)
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


## The uid of the held item a Caravan item offer would upgrade (same item
## and tier, below S, not Legendary), or -1. The UI lights these up.
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


static func sell(state: RunState, content: ContentDb, run: RunContent, uid: int) -> RunActions.Result:
	var problem: String = _phase_problem(state, "caravan")
	if not problem.is_empty():
		return _fail(problem)
	var item: RunItem = state.find_item(uid)
	if item == null:
		return _fail("that item isn't in the guild")
	var price: int = run.economy.sell_price(run.economy.item_price[item.tier])
	var result: RunActions.Result = RunActions.discard_item(state, content, uid)
	state.gold += price
	result.note = "sold %s for %d gold" % [content.items[item.item_id].name, price]
	return result


static func reroll_cost(state: RunState, run: RunContent) -> int:
	return run.economy.reroll_base + run.economy.reroll_step * state.reroll_count


static func reroll(state: RunState, content: ContentDb, run: RunContent) -> RunActions.Result:
	var problem: String = _phase_problem(state, "caravan")
	if not problem.is_empty():
		return _fail(problem)
	var cost: int = reroll_cost(state, run)
	var result: RunActions.Result = RunActions.spend_gold(state, cost)
	if not result.ok:
		return result
	state.reroll_count += 1
	_fill_caravan(state, content, run)
	return _ok("rerolled the Caravan for %d gold" % cost)


static func leave_caravan(state: RunState, content: ContentDb, run: RunContent) -> RunActions.Result:
	var problem: String = _phase_problem(state, "caravan")
	if not problem.is_empty():
		return _fail(problem)
	state.offers.clear()
	if run.act(state.act).is_boss_day(state.day):
		_enter_stop(state, content, run, "upgrade")
		return _ok("the road ends at an anvil before the boss")
	state.phase = "stop_choice"
	var available: Array[String] = []
	var weights: Array[int] = []
	for i: int in EconomyDef.STOPS.size():
		var stop: String = EconomyDef.STOPS[i]
		if _stop_applies(state, stop):
			available.append(stop)
			weights.append(run.economy.stop_weights[i])
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.STOPS, state.act, state.day, state.attempt] as Array[int])
	for i: int in mini(3, available.size()):
		var picked: int = RunRandom.pick_weighted(rng, weights)
		if picked < 0:
			break
		state.offers.append({"type": "stop", "stop": available[picked], "price": 0, "taken": false})
		available.remove_at(picked)
		weights.remove_at(picked)
	return _ok("left the Caravan")


static func _stop_applies(state: RunState, stop: String) -> bool:
	match stop:
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
	_enter_stop(state, content, run, stop)
	return _ok("stopped at the %s" % stop)


static func _enter_stop(state: RunState, content: ContentDb, run: RunContent, stop: String) -> void:
	state.phase = "stop"
	state.stop_kind = stop
	state.stop_used = false
	state.offers.clear()
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.STOP, state.act, state.day, state.attempt] as Array[int])
	match stop:
		"loot":
			_add_loot(state, content, run, rng)
		"vault":
			state.keys -= 1
			if rng.range_int(2) == 0:
				_add_relic_offers(state, content, rng, run.economy.relic_weights, 1, "", 0)
			else:
				var better: Array[int] = run.economy.rarity_weights.duplicate()
				better[0] = 0
				better[1] = 0
				_add_item_offer(state, content, rng, better, run.economy.loot_tier_weights, true)
		"event":
			_add_event(state, content, run, rng)


static func _add_loot(state: RunState, content: ContentDb, run: RunContent, rng: SimRng) -> void:
	match EconomyDef.LOOT_KINDS[maxi(RunRandom.pick_weighted(rng, run.economy.loot_weights), 0)]:
		"item":
			_add_item_offer(state, content, rng, run.economy.rarity_weights, run.economy.loot_tier_weights, true)
		"essence":
			state.offers.append({"type": "essence", "essence": content.essence_ids[rng.range_int(content.essence_ids.size())], "price": 0, "taken": false})
		_:
			state.offers.append({"type": "gold", "amount": run.economy.loot_gold, "price": 0, "taken": false})


static func _add_event(state: RunState, content: ContentDb, run: RunContent, rng: SimRng) -> void:
	var weights: Array[int] = []
	for event_id: String in run.event_ids:
		weights.append(run.events[event_id].weight)
	var event: EventDef = run.events[run.event_ids[RunRandom.pick_weighted(rng, weights)]]
	var flat_tiers: Array[int] = [1, 0, 0, 0]
	match event.kind:
		"gold":
			state.offers.append({"type": "gold", "amount": event.amount, "price": 0, "taken": false})
		"item_by_rarity":
			_add_item_offer(state, content, rng, run.economy.rarity_weights, flat_tiers, true)
		"item_by_tier":
			var common_up: Array[int] = [1, 1, 1, 1, 0]
			_add_item_offer(state, content, rng, common_up, run.economy.loot_tier_weights, false)
		"relic_by_rarity":
			_add_relic_offers(state, content, rng, run.economy.relic_weights, 1, "", 0)
		"relic_merchant":
			_add_relic_offers(state, content, rng, run.economy.relic_weights, run.economy.relic_choices, "merchant", -1, run.economy)
		"legendary_relic":
			_add_relic_offers(state, content, rng, _rarity_only("legendary"), 1, "", 0)
		"essence":
			state.offers.append({"type": "essence", "essence": content.essence_ids[rng.range_int(content.essence_ids.size())], "price": 0, "taken": false})
		"key":
			state.offers.append({"type": "key", "price": 0, "taken": false})
	for offer: Dictionary in state.offers:
		offer["event"] = event.id


## Reforges at the Forge.
static func forge_reforge(state: RunState, content: ContentDb, uid: int) -> RunActions.Result:
	if state.phase != "stop" or state.stop_kind != "forge":
		return _fail("reforging needs the Forge")
	return RunActions.reforge(state, content, uid)


## Switches a hero to another of their specializations (once, at a Retrain stop).
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


static func leave_stop(state: RunState) -> RunActions.Result:
	var problem: String = _phase_problem(state, "stop")
	if not problem.is_empty():
		return _fail(problem)
	state.phase = "fight"
	state.stop_kind = ""
	state.offers.clear()
	return _ok("on to the fight")


## Takes an offer at a stop or among rewards (or a relic-merchant purchase).
static func take(state: RunState, content: ContentDb, index: int) -> RunActions.Result:
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
		"hero":
			result = RunActions.add_hero(state, content, offer["hero"], offer["rank"], offer["specialization"] if state.hero(offer["hero"]) == null else "")
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
	var setup: FightSetup = RunFight.setup_for(state, content, state.encounter_id)
	var result: FightResult = CombatSim.run(setup, content)
	if not result.errors.is_empty():
		return [_fail("the fight couldn't start: %s" % result.errors[0]), result, setup]
	RunFight.apply_result(state, content, result)
	if result.guild_won():
		_give_rewards(state, content, run)
		return [_ok("won"), result, setup]
	if state.losses >= LOSSES_TO_END:
		state.phase = "run_over"
		state.offers.clear()
		return [_ok("the guild falls; the run is over"), result, setup]
	state.gold += run.economy.loss_gold_base + run.economy.loss_gold_per_win * state.wins
	state.attempt += 1
	_start_day(state, content, run)
	return [_ok("lost; the day starts over"), result, setup]


static func _give_rewards(state: RunState, content: ContentDb, run: RunContent) -> void:
	var economy: EconomyDef = run.economy
	var encounter: EncounterDef = content.encounters[state.encounter_id]
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.REWARDS, state.act, state.day] as Array[int])
	state.phase = "rewards"
	state.offers.clear()
	var essence: String = team_essence(content, encounter)
	var gold: int = economy.win_gold_base + economy.win_gold_per_day * state.day
	match encounter.kind:
		"elite":
			gold = FixedMath.apply_bp(gold, economy.elite_gold_bp)
		"boss":
			gold = economy.boss_gold
	state.gold += gold
	if encounter.kind == "normal":
		if not essence.is_empty():
			state.shards[essence] = state.shards.get(essence, 0) + 1
			_convert_shards(state, content, run)
	elif not essence.is_empty():
		state.offers.append({"type": "essence", "essence": essence, "price": 0, "taken": false})
	_add_drop(state, content, encounter, rng)
	if encounter.kind == "elite":
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


## Shards become essences while there's room in the pouch.
static func _convert_shards(state: RunState, content: ContentDb, run: RunContent) -> void:
	var ids: Array = state.shards.keys()
	ids.sort()
	for essence_id: String in ids:
		while state.shards[essence_id] >= run.economy.shards_per_essence and state.pouch.size() < content.tuning.pouch_cap:
			state.shards[essence_id] -= run.economy.shards_per_essence
			state.pouch.append(essence_id)


## The guaranteed drop: one of the enemy team's items (at its tier) or relics
## (not already held), enemy-only ones included.
static func _add_drop(state: RunState, content: ContentDb, encounter: EncounterDef, rng: SimRng) -> void:
	var candidates: Array[Dictionary] = []
	for slot: EncounterDef.Slot in encounter.units:
		for entry: LoadoutEntry in content.enemies[slot.enemy_id].items:
			candidates.append({"type": "item", "item": entry.item_id, "tier": entry.tier, "price": 0, "taken": false})
	for relic_id: String in encounter.relics:
		if not state.relics.has(relic_id):
			candidates.append({"type": "relic", "relic": relic_id, "price": 0, "taken": false})
	if not candidates.is_empty():
		state.offers.append(candidates[rng.range_int(candidates.size())])


# --- picking items and relics ---------------------------------------------------

static func _rarity_only(rarity: String) -> Array[int]:
	var weights: Array[int] = [0, 0, 0, 0, 0]
	weights[ItemDef.RARITIES.find(rarity)] = 1
	return weights


## A random item id: rarity by `weights` (rarities with nothing to offer are
## skipped), then any item of that rarity equally. Never a Legendary already
## seen (and an offered Legendary counts as seen). Enemy-only items only when
## `enemy_only_ok`.
static func _pick_item(state: RunState, content: ContentDb, rng: SimRng, weights: Array[int], enemy_only_ok: bool, exclude: Array[String] = []) -> String:
	var by_rarity: Array[Array] = [[], [], [], [], []]
	for item_id: String in content.item_ids:
		var def: ItemDef = content.items[item_id]
		if (def.enemy_only and not enemy_only_ok) or exclude.has(item_id) or state.legendaries_seen.has(item_id):
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
	if not item_id.is_empty():
		state.offers.append({"type": "item", "item": item_id, "tier": maxi(RunRandom.pick_weighted(rng, tier_weights), 0), "price": 0, "taken": false})


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
