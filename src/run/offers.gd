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
