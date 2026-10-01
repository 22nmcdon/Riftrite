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
## `extra` more cards from anyone's (Widened Offering, phase 5c step 5a).
static func pick(run: RunContent, state: RunState, visit: int, extra: int = 0) -> Array[String]:
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
	for i: int in extra:
		var rest: Array[String] = everyone.filter(func(id: String) -> bool: return not cards.has(id))
		if rest.is_empty():
			break
		cards.append(rest[rng.range_int(rest.size())])
	return cards


## The Pedlar's wares: act.pedlar_wares different items of any kind, never
## one the run holds at rank III, and never filtered by what the team can
## use (loadout rule 2; phase 5c step 6). `rerolls` draws a fresh set.
static func pedlar(run: RunContent, state: RunState, rerolls: int) -> Array[String]:
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.PEDLAR, state.act, state.day, state.attempt, rerolls])
	return _draw(rng, _for_sale(run, state), run.act.pedlar_wares + run.relic_sum(state, "wares_add"))


## The Magpie's wares (phase 5c step 6e, magpie.md): act.magpie_wares
## charms, sold at rank II (never one the run holds at rank III); one look,
## no rerolls.
static func magpie(run: RunContent, state: RunState) -> Array[String]:
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.MAGPIE, state.act, state.day, state.attempt])
	var charms: Array[String] = _for_sale(run, state).filter(func(id: String) -> bool: return run.items[id].kind == ItemDef.Kind.CHARM)
	return _draw(rng, charms, run.act.magpie_wares)


## The Magpie's swap for `relic_id`: a relic of the same tier the run
## doesn't hold (a boss relic for a boss relic), or "" if there's none. A
## bond relic doesn't swap.
static func magpie_swap(run: RunContent, state: RunState, relic_id: String) -> String:
	var tier: RelicDef.Tier = run.relics[relic_id].tier
	if tier == RelicDef.Tier.BOND:
		return ""
	var pool: Array[String] = run.relic_ids.filter(func(id: String) -> bool: return run.relics[id].tier == tier and not state.relics.has(id))
	if pool.is_empty():
		return ""
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.MAGPIE, state.act, state.day, state.attempt, 1 + run.relic_ids.find(relic_id)])
	return pool[rng.range_int(pool.size())]


## Every item a shop can lay out: all but those the run holds at rank III.
static func _for_sale(run: RunContent, state: RunState) -> Array[String]:
	return run.item_ids.filter(func(id: String) -> bool: return state.item_ranks.get(id, 0) < ItemDef.RANKS)


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
	var place: CampsDef.Place = _draw_place(run, rng)
	var offered: Array[String] = place.options.filter(func(id: String) -> bool: return camp_option_open(run, state, id))
	var picked: Array[String] = _draw(rng, offered, run.camps.shown)
	var options: Array[String] = offered.filter(func(id: String) -> bool: return picked.has(id))
	# The boss day's camp always has the pre-boss shop (phase 5c step 5a).
	if state.day >= 1 and state.day <= run.act.days.size() and run.act.days[state.day - 1] == "boss" and not options.has("pedlar"):
		options.append("pedlar")
	return [place.id, options]


## Whether a camp option has anything to do today: a Hunt needs a pack
## allowed today; Map the Rift and Scout need days ahead (Map the Rift, one
## that isn't the boss's).
## Where a day camped (or camps) on an attempt: its camp stream's first
## draw, so the act map can show a past day's place without the state
## keeping it (docs/plans/rebuild-phase5b-art.md, section 4). "magpie" on the
## Magpie's day's first try.
static func place(run: RunContent, run_seed: int, act: int, day: int, attempt: int, magpie_day: int) -> String:
	if day == magpie_day and attempt == 0:
		return "magpie"
	return _draw_place(run, RunRandom.stream(run_seed, [RunRandom.CAMP, act, day, attempt])).id


static func _draw_place(run: RunContent, rng: SimRng) -> CampsDef.Place:
	return run.camps.places[rng.range_int(run.camps.places.size())]


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


## `count` different relics of `tier` the run doesn't hold, from the relic
## stream at `visit` (where the choice happens: see RunFlow). An elite's
## choice (`epic_pct` > 0) may make one of them an epic.
static func relics(run: RunContent, state: RunState, visit: int, count: int, tier: String = "rare", epic_pct: int = 0) -> Array[String]:
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.RELIC, state.act, state.day, state.attempt, visit])
	var drawn: Array[String] = []
	var epic_at: int = rng.range_int(count) if epic_pct > 0 and rng.range_int(100) < epic_pct else -1
	for i: int in count:
		var id: String = _relic_of(run, state, rng, "epic" if i == epic_at else tier, drawn)
		if not id.is_empty():
			drawn.append(id)
	return drawn


## A shop's relics (phase 5c step 5a): `count` of them, each of a tier drawn
## by the shop's odds (the Magpie's: epic or legendary); the pre-boss shop's
## first is a legendary. `rerolls` draws a fresh set.
static func shop_relics(run: RunContent, state: RunState, rerolls: int, count: int, magpie: bool, pre_boss: bool) -> Array[String]:
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.RELIC, state.act, state.day, state.attempt, -1 - rerolls])
	var drawn: Array[String] = []
	for i: int in count:
		var tier: String = "legendary" if pre_boss and i == 0 else (_weighted(rng, run.act.magpie_odds, run.act.magpie_weights) if magpie \
			else _weighted(rng, run.act.relic_odds, run.act.relic_weights))
		var id: String = ""
		if not magpie and not (pre_boss and i == 0):
			id = _bond_relic(run, state, rng, drawn)
		if id.is_empty():
			id = _relic_of(run, state, rng, tier, drawn)
		if not id.is_empty():
			drawn.append(id)
	return drawn


## An on bond's relic for a shop's relic draw (phase 5c step 5d): with
## bond_relic_pct, one of the bond relics the run may find (Decision 28: any
## of them) that isn't in `taken`; "" otherwise. No roll without one, so a
## run without bonds draws as it did.
static func _bond_relic(run: RunContent, state: RunState, rng: SimRng, taken: Array[String]) -> String:
	var pool: Array[String] = []
	pool.assign(run.bond_relics(state).filter(func(id: String) -> bool: return not taken.has(id)))
	if pool.is_empty() or rng.range_int(100) >= run.act.bond_relic_pct:
		return ""
	return pool[rng.range_int(pool.size())]


## One relic of `tier` the run doesn't hold and that isn't in `taken`; if the
## tier has none left, the nearest tier that does (lower first), never a boss
## relic unless `tier` is boss.
static func _relic_of(run: RunContent, state: RunState, rng: SimRng, tier: String, taken: Array[String]) -> String:
	var wanted: int = RelicDef.TIER_NAMES.find(tier)
	var order: Array[int] = [wanted]
	if wanted != RelicDef.Tier.BOSS:
		for step: int in range(1, RelicDef.Tier.BOSS):
			for other: int in [wanted - step, wanted + step]:
				if other >= 0 and other < RelicDef.Tier.BOSS:
					order.append(other)
	for tier_index: int in order:
		var pool: Array[String] = run.relic_ids.filter(func(id: String) -> bool:
			return run.relics[id].tier == tier_index and not state.relics.has(id) and not taken.has(id))
		if not pool.is_empty():
			return pool[rng.range_int(pool.size())]
	return ""


static func _weighted(rng: SimRng, tiers: Array[String], weights: Array[int]) -> String:
	var total: int = 0
	for weight: int in weights:
		total += weight
	var roll: int = rng.range_int(maxi(total, 1))
	for i: int in tiers.size():
		roll -= weights[i]
		if roll < 0:
			return tiers[i]
	return tiers.back() if not tiers.is_empty() else "common"


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
