class_name Offers
extends RefCounted
## What the run offers, drawn from the run's seed and where it happens
## (RunRandom), so an offer is a pure function of the seed and the state
## (docs/plans/rebuild-phase5-run.md, sections 1 and 5).


## An upgrade pick's cards (upgrade ids): one per hero, in the team's order,
## from what that hero can be offered now (RunContent.upgrades_for); with
## the act's wild_card_pct chance, one card is drawn from every hero's
## instead, so there's room to double down. A hero with nothing left gives
## its card to the others; with nothing left at all, fewer cards.
## `visit` tells apart picks on the same attempt (0: after the fight; camp's
## Train uses its own).
static func pick(run: RunContent, state: RunState, visit: int) -> Array[String]:
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.PICK, state.act, state.day, state.attempt, visit])
	var wild_at: int = -1
	if rng.range_int(100) < run.act.wild_card_pct:
		wild_at = rng.range_int(state.heroes.size())
	var everyone: Array[String] = []
	for hero: RunState.Hero in state.heroes:
		everyone.append_array(run.upgrades_for(hero))
	var cards: Array[String] = []
	for i: int in state.heroes.size():
		var pool: Array[String] = []
		if i != wild_at:
			pool = run.upgrades_for(state.heroes[i])
		pool = pool.filter(func(id: String) -> bool: return not cards.has(id))
		if pool.is_empty():
			pool = everyone.filter(func(id: String) -> bool: return not cards.has(id))
		if pool.is_empty():
			break
		cards.append(pool[rng.range_int(pool.size())])
	return cards


## The Pedlar's wares: act.pedlar_wares different charms, tactics, and
## sigils (never grafts), each one that works on someone on the team as they
## are now (part 6, section 8). `rerolls` draws a fresh set.
static func pedlar(run: RunContent, state: RunState, rerolls: int) -> Array[String]:
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.PEDLAR, state.act, state.day, state.attempt, rerolls])
	var pool: Array[String] = []
	for id: String in run.item_ids:
		var item: ItemDef = run.items[id]
		if item.kind != ItemDef.Kind.GRAFT and state.heroes.any(func(hero: RunState.Hero) -> bool: return item.works_on(run.hero_kit(hero), hero.id)):
			pool.append(id)
	return _draw(rng, pool, run.act.pedlar_wares)


## The Magpie's wares (Decision 13): up to half grafts, the rest any other
## gear, whoever it suits; one look, no rerolls.
static func magpie(run: RunContent, state: RunState) -> Array[String]:
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.MAGPIE, state.act, state.day, state.attempt])
	var grafts: Array[String] = run.item_ids.filter(func(id: String) -> bool: return run.items[id].kind == ItemDef.Kind.GRAFT)
	var gear: Array[String] = run.item_ids.filter(func(id: String) -> bool: return run.items[id].kind != ItemDef.Kind.GRAFT)
	@warning_ignore("integer_division")
	var wares: Array[String] = _draw(rng, grafts, run.act.magpie_wares / 2)
	wares.append_array(_draw(rng, gear, run.act.magpie_wares - wares.size()))
	return wares


## `count` different ids from `pool` (fewer if it's short), in draw order.
static func _draw(rng: SimRng, pool: Array[String], count: int) -> Array[String]:
	var left: Array[String] = pool.duplicate()
	var drawn: Array[String] = []
	while drawn.size() < count and not left.is_empty():
		drawn.append(left.pop_at(rng.range_int(left.size())))
	return drawn


## Today's camp: a place (by the camp stream), then camps.shown different
## options from its menu that have something to do today, in the menu's
## order. Returns [place id, options].
static func camp(run: RunContent, state: RunState) -> Array:
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.CAMP, state.act, state.day, state.attempt])
	var place: CampsDef.Place = run.camps.places[rng.range_int(run.camps.places.size())]
	var offered: Array[String] = place.options.filter(func(id: String) -> bool: return camp_option_open(run, state, id))
	var picked: Array[String] = _draw(rng, offered, run.camps.shown)
	var options: Array[String] = offered.filter(func(id: String) -> bool: return picked.has(id))
	return [place.id, options]


## Whether a camp option has anything to do today: a Hunt needs a pack
## allowed today; Map the Rift and Scout need days ahead (Map the Rift, one
## that isn't the boss's).
static func camp_option_open(run: RunContent, state: RunState, option: String) -> bool:
	match option:
		"hunt":
			return not run.encounters_for("hunt", state.day).is_empty()
		"map_the_rift":
			return state.day < run.act.days.size() and run.act.days[state.day] != "boss"
		"scout":
			return state.day < run.act.days.size()
	return true


## The day the Magpie comes: one of camps.magpie_days, drawn once a run.
static func magpie_day(run: RunContent, run_seed: int, act: int) -> int:
	var days: Array[int] = run.camps.magpie_days
	if days.is_empty():
		return 0
	return days[RunRandom.stream(run_seed, [RunRandom.MAGPIE, act, 0]).range_int(days.size())]


## A Hunt's pack: one of the hunt encounters allowed today ("" if none).
static func hunt(run: RunContent, state: RunState) -> String:
	var packs: Array[String] = run.encounters_for("hunt", state.day)
	if packs.is_empty():
		return ""
	return packs[RunRandom.stream(state.seed_value, [RunRandom.HUNT, state.act, state.day, state.attempt]).range_int(packs.size())]


## `count` different relics the run doesn't hold, from the relic stream at
## `visit` (where the choice happens: see RunFlow).
static func relics(run: RunContent, state: RunState, visit: int, count: int) -> Array[String]:
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.RELIC, state.act, state.day, state.attempt, visit])
	var pool: Array[String] = run.relic_ids.filter(func(id: String) -> bool: return not state.relics.has(id))
	return _draw(rng, pool, count)


## Map the Rift: a fight to swap in for tomorrow's option `index`, of the
## same tier, allowed that day, and not already offered ("" if there's none).
static func swap(run: RunContent, state: RunState, index: int) -> String:
	var tomorrow: int = state.day + 1
	var offered: Array = state.options[tomorrow - 1]
	var tier: String = run.content.encounters[offered[index]].tier
	var pool: Array[String] = run.encounters_for(tier, tomorrow).filter(func(id: String) -> bool: return not offered.has(id))
	if pool.is_empty():
		return ""
	return pool[RunRandom.stream(state.seed_value, [RunRandom.ACT_DRAW, state.act, tomorrow, index, 1]).range_int(pool.size())]
