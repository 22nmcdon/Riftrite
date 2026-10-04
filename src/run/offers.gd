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
## On endless floors only apex cards are offered (rebuild-phase8-apexes.md,
## Decision 11): no hero, taste, or path cards.
static func pick(run: RunContent, state: RunState, visit: int, extra: int = 0) -> Array[String]:
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.PICK, state.act, state.day, state.attempt, visit])
	var wild_at: int = -1
	if rng.range_int(100) < run.act_of(state).wild_card_pct:
		wild_at = rng.range_int(state.heroes.size())
	var everyone: Array[String] = []
	for hero: RunState.Hero in state.heroes:
		everyone.append_array(_offered(run, state, hero))
	var cards: Array[String] = []
	for i: int in state.heroes.size():
		var pool: Array[String] = []
		if i != wild_at:
			pool = _offered(run, state, state.heroes[i])
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


## The cards the pick can offer `hero` now: on endless floors, only its
## apex's.
static func _offered(run: RunContent, state: RunState, hero: RunState.Hero) -> Array[String]:
	var ids: Array[String] = run.upgrades_for(hero)
	if state.endless:
		return ids.filter(func(id: String) -> bool: return run.upgrades[id].layer == UpgradeDef.Layer.APEX)
	return ids


## Each enemy of day fight option `index` (`encounter_id`) of today: one of
## its specialization ids, or "" (phase 8 part 3, rebuild-phase8-act2.md
## section 2): from the act's specialized_from_day, the act's share of its
## enemies, rounded down (Decision 1), chosen from those that have any, each
## given one of its two; none before that day, and none for a Hunt (Decision
## 2). Drawn afresh on each attempt.
static func specializations(run: RunContent, state: RunState, index: int, encounter_id: String) -> Array[String]:
	var encounter: EncounterDef = run.content.encounters[encounter_id]
	var specs: Array[String] = []
	for placed: EncounterDef.Placed in encounter.enemies:
		specs.append("")
	var act_def: ActDef = run.act_of(state)
	if act_def.specialized_from_day <= 0 or state.day < act_def.specialized_from_day or encounter.tier == "hunt" or state.endless:
		return specs
	var eligible: Array[int] = []
	for i: int in encounter.enemies.size():
		if not run.content.enemies[encounter.enemies[i].enemy].specializations.is_empty():
			eligible.append(i)
	@warning_ignore("integer_division")
	var count: int = mini(encounter.enemies.size() * act_def.specialized_share_pct / 100, eligible.size())
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.SPECIALIZE, state.act, state.day, state.attempt, index])
	for n: int in count:
		var i: int = eligible.pop_at(rng.range_int(eligible.size()))
		var options: Array[SpecializationDef] = run.content.enemies[encounter.enemies[i].enemy].specializations
		specs[i] = options[rng.range_int(options.size())].id
	return specs


## The Pedlar's wares: act.pedlar_wares different items of any kind, never
## one the run holds at rank III, and never filtered by what the team can
## use (loadout rule 2; phase 5c step 6). `rerolls` draws a fresh set.
static func pedlar(run: RunContent, state: RunState, rerolls: int) -> Array[String]:
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.PEDLAR, state.act, state.day, state.attempt, rerolls])
	return _draw(rng, _for_sale(run, state), run.act_of(state).pedlar_wares + run.relic_sum(state, "wares_add"))


## The Magpie's wares (phase 5c step 6e, magpie.md): act.magpie_wares
## charms, sold at rank II (never one the run holds at rank III); one look,
## no rerolls.
static func magpie(run: RunContent, state: RunState) -> Array[String]:
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.MAGPIE, state.act, state.day, state.attempt])
	var charms: Array[String] = _for_sale(run, state).filter(func(id: String) -> bool: return run.items[id].kind == ItemDef.Kind.CHARM)
	return _draw(rng, charms, run.act_of(state).magpie_wares)


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
	return [place.id, options]


## The nodes shown at the end of the day (phase 5c step 8, Decision 41):
## Camp, then two each drawn from Event, Rift Tear, and the Magpie (from
## magpie_from_day, while he's come fewer than magpie_per_act times this
## act), each equally likely; a Rift Tear or Magpie drawn again is an Event
## instead. An Event is a Bloodied Oath oath_pct in 100 ("oath", once a
## day), else a scene not already shown ("event:<scene id>").
static func nodes(run: RunContent, state: RunState) -> Array[String]:
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.NODE, state.act, state.day])
	var kinds: Array[String] = ["event", "rift_tear"]
	if state.day >= run.camps.magpie_from_day and state.magpie_visits < run.camps.magpie_per_act:
		kinds.append("magpie")
	var shown: Array[String] = ["camp"]
	for i: int in 2:
		var kind: String = kinds[rng.range_int(kinds.size())]
		if kind == "event" or shown.has(kind):
			kind = _event(run, rng, shown)
		if not kind.is_empty():
			shown.append(kind)
	return shown


static func _event(run: RunContent, rng: SimRng, shown: Array[String]) -> String:
	if not shown.has("oath") and rng.range_int(100) < run.events.oath_pct:
		return "oath"
	var scenes: Array[String] = []
	for scene: EventDef.Scene in run.events.scenes:
		if not shown.has("event:" + scene.id):
			scenes.append("event:" + scene.id)
	return scenes[rng.range_int(scenes.size())] if not scenes.is_empty() else ""


## An event's random relic (phase 5c step 8c): one of `tier`, or with
## "shop_odds" a tier drawn by the shops' odds.
static func event_relic(run: RunContent, state: RunState, tier: String) -> String:
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.EVENT, state.act, state.day, 2])
	if tier == "shop_odds":
		tier = _weighted(rng, run.act_of(state).relic_odds, run.act_of(state).relic_weights)
	return _relic_of(run, state, rng, tier, [] as Array[String])


## An event's random picks (phase 5c step 8c): `count` different ones of
## `pool`, on the event's stream (`what` keeps one result's draws apart).
static func event_picks(state: RunState, pool: Array[String], count: int, what: int) -> Array[String]:
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.EVENT, state.act, state.day, 3, what])
	var left: Array[String] = pool.duplicate()
	var picked: Array[String] = []
	while picked.size() < count and not left.is_empty():
		picked.append(left.pop_at(rng.range_int(left.size())))
	return picked


## A Bloodied Oath's two oaths (phase 5c step 8c): two different oaths, each
## on a random hero, two different heroes ("<oath id>:<hero id>").
static func oaths(run: RunContent, state: RunState) -> Array[String]:
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.EVENT, state.act, state.day, 0])
	var pool: Array[String] = []
	for oath: EventDef.Oath in run.events.oaths:
		pool.append(oath.id)
	var heroes: Array[String] = []
	for hero: RunState.Hero in state.heroes:
		heroes.append(hero.id)
	var offer: Array[String] = []
	for i: int in mini(2, heroes.size()):
		var oath: String = pool.pop_at(rng.range_int(pool.size()))
		var hero: String = heroes.pop_at(rng.range_int(heroes.size()))
		offer.append("%s:%s" % [oath, hero])
	return offer


## Whether a camp option has anything to do today: a Hunt needs a pack
## allowed today; Map the Rift and Scout need days ahead (Map the Rift, one
## that isn't the boss's).
static func _draw_place(run: RunContent, rng: SimRng) -> CampsDef.Place:
	return run.camps.places[rng.range_int(run.camps.places.size())]


static func camp_option_open(run: RunContent, state: RunState, option: String) -> bool:
	match option:
		"hunt":
			return not run.encounters_for(run.act_of(state), "hunt", state.day).is_empty()
		"map_the_rift":
			return not ["", "boss"].has(run.day_kind(state, state.day + 1))
		"scout":
			return not run.day_kind(state, state.day + 1).is_empty()
	return true


## A Hunt's pack: one of the hunt encounters allowed today ("" if none).
static func hunt(run: RunContent, state: RunState) -> String:
	var packs: Array[String] = run.encounters_for(run.act_of(state), "hunt", state.day)
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


## A relic of each of `tiers` (a Rift Tear's depth, phase 5c step 8b; the
## Shrine's offering of a relic for one a tier higher), all different.
static func relics_of_tiers(run: RunContent, state: RunState, visit: int, tiers: Array[String]) -> Array[String]:
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.RELIC, state.act, state.day, state.attempt, visit])
	var drawn: Array[String] = []
	for tier: String in tiers:
		var id: String = _relic_of(run, state, rng, tier, drawn)
		if not id.is_empty():
			drawn.append(id)
	return drawn


## The day's two rift modifiers, in order (phase 5c step 8b): a Deep tear
## takes the first, an Abyssal one both, so the depths' cards can show them
## before one's chosen. In endless, never one the run has gathered (phase
## 8 part 1), so none is on twice.
static func rift_modifiers(run: RunContent, state: RunState) -> Array[String]:
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.NODE, state.act, state.day, 1])
	var pool: Array[String] = run.camps.modifier_ids.filter(func(id: String) -> bool: return not state.endless_mods.has(id))
	var drawn: Array[String] = []
	var most: int = 0
	for depth: CampsDef.Depth in run.camps.depths:
		most = maxi(most, depth.modifiers)
	while drawn.size() < most and not pool.is_empty():
		drawn.append(pool.pop_at(rng.range_int(pool.size())))
	return drawn


## A shop's relics (phase 5c step 5a): `count` of them, each of a tier drawn
## by the shop's odds (the Magpie's: epic or legendary); the boss shop's
## first is a legendary. `rerolls` draws a fresh set.
static func shop_relics(run: RunContent, state: RunState, rerolls: int, count: int, magpie: bool, boss: bool) -> Array[String]:
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.RELIC, state.act, state.day, state.attempt, -1 - rerolls])
	var drawn: Array[String] = []
	var odds: Array = shop_odds(run, state)
	for i: int in count:
		var tier: String = "legendary" if boss and i == 0 else (_weighted(rng, run.act_of(state).magpie_odds, run.act_of(state).magpie_weights) if magpie \
			else _weighted(rng, odds[0], odds[1]))
		var id: String = ""
		if not magpie and not (boss and i == 0):
			id = _bond_relic(run, state, rng, drawn)
		if id.is_empty():
			id = _relic_of(run, state, rng, tier, drawn)
		if not id.is_empty():
			drawn.append(id)
	return drawn


## The Pedlar's relic odds (tiers and weights): the act's, with a
## legendary added from endless.legendary_from_floor (phase 8 part 1).
static func shop_odds(run: RunContent, state: RunState) -> Array:
	var tiers: Array[String] = run.act_of(state).relic_odds.duplicate()
	var weights: Array[int] = run.act_of(state).relic_weights.duplicate()
	var endless: ActDef.Endless = run.act_of(state).endless
	if endless != null and run.floor_of(state, state.day) >= endless.legendary_from_floor and endless.legendary_weight > 0:
		var at: int = tiers.find("legendary")
		if at >= 0:
			weights[at] += endless.legendary_weight
		else:
			tiers.append("legendary")
			weights.append(endless.legendary_weight)
	return [tiers, weights]


## An endless floor's fight (phase 8 part 1, Decision 2: one a floor): one of
## the floor's kind's pool (RunContent.floor_pool), not the floor before's
## if anything else is left, from the floor's own stream.
static func endless_floor(run: RunContent, state: RunState, day: int) -> Array[String]:
	var pool: Array[String] = run.floor_pool(state, run.day_kind(state, day))
	var before: Array = state.options[day - 2] if day >= 2 and day - 2 < state.options.size() else []
	var fresh: Array[String] = pool.filter(func(id: String) -> bool: return not before.has(id))
	if not fresh.is_empty():
		pool = fresh
	var drawn: Array[String] = []
	if not pool.is_empty():
		drawn.append(pool[RunRandom.stream(state.seed_value, [RunRandom.ENDLESS, day]).range_int(pool.size())])
	return drawn


## The rift modifier an endless floor adds (phase 8 part 1): one the run
## hasn't gathered and that a Rift Tear hasn't set up for the floor's
## fight, from the floor's stream ("" once every one is on).
static func endless_modifier(run: RunContent, state: RunState, day: int) -> String:
	var pool: Array[String] = run.camps.modifier_ids.filter(func(id: String) -> bool: return not state.endless_mods.has(id) and not state.rift_mods.has(id))
	if pool.is_empty():
		return ""
	return pool[RunRandom.stream(state.seed_value, [RunRandom.ENDLESS, day, 1]).range_int(pool.size())]


## An on bond's relic for a shop's relic draw (phase 5c step 5d): with
## bond_relic_pct, one of the bond relics the run may find (Decision 28: any
## of them) that isn't in `taken`; "" otherwise. No roll without one, so a
## run without bonds draws as it did.
static func _bond_relic(run: RunContent, state: RunState, rng: SimRng, taken: Array[String]) -> String:
	var pool: Array[String] = []
	pool.assign(run.bond_relics(state).filter(func(id: String) -> bool: return not taken.has(id)))
	if pool.is_empty() or rng.range_int(100) >= run.act_of(state).bond_relic_pct:
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
	var allowed: Array[String] = run.encounters_for(run.act_of(state), tier, tomorrow)
	if run.floor_of(state, tomorrow) > 0:
		allowed.assign(run.floor_pool(state, run.day_kind(state, tomorrow)).filter(func(id: String) -> bool: return run.content.encounters[id].tier == tier))
	var pool: Array[String] = allowed.filter(func(id: String) -> bool: return not offered.has(id))
	if pool.is_empty():
		return ""
	return pool[RunRandom.stream(state.seed_value, [RunRandom.ACT_DRAW, state.act, tomorrow, index, 1]).range_int(pool.size())]
