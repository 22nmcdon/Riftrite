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
