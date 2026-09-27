class_name RunBot
extends RefCounted
## Plays whole runs headlessly with a simple strategy, through RunFlow and
## RunActions only (like a player would), so the run runner can report
## run-level balance (tools/run_runner.gd). The strategy:
##   - draft the first offered hero three times, then take the first kit
##   - stops: the shop on the day's first visit; on the second, Loot, Events,
##     the Vault, Retrain, the Forge (a shop if nothing else); upgrade the
##     best item before the boss
##   - at a shop: buy items (and an essence merchant's essence): upgrades for
##     held copies first, then the rarest first, cheapest first within a
##     rarity
##   - the fight: in even-seeded runs always the harder one, in odd-seeded
##     runs the easier one (so the report can compare them)
##   - combine copies, equip what fits, feed Legendaries (the essences an
##     Essence-hungry one wants; stash leftovers to a Devourer), infuse (a
##     single for each equipped item, then fuse into Base infusions), sturdy
##     classes in the front row and the rest in the back
##   - take what fits at other stops; rewards: take everything that fits
##     (the first relic of a choice, the rarest item of the reward pick);
##     give each rank-up to the lowest-ranked hero

## Node kinds for the day's second visit, best first.
const STOP_PREFERENCE: Array[String] = ["loot", "event", "vault", "retrain", "forge", "shop"]
## Classes that stand in the front row; the rest stand in the back.
const FRONT_CLASSES: Array[String] = ["warden", "striker", "trickster"]
const MAX_ACTIONS: int = 2000


class Report:
	var seed_value: int
	## "act_end", "run_over", or "stuck" (a bug: the bot couldn't move on).
	var ending: String = ""
	var day: int = 0
	var losses: int = 0
	var wins: int = 0
	## Gold at the start of each day (index 0 = day 1).
	var gold_by_day: Array[int] = []
	## Whether this run always took the harder fight.
	var took_hard: bool = false
	## Every fight: [kind ("normal", "elite", "boss"), hard, won, seconds, day,
	## encounter id].
	var fights: Array[Array] = []
	var bought: Array[String] = []
	var discovered: Array[String] = []
	## Reached the act's last day (the boss), and how many boss fights it took.
	var reached_boss: bool = false
	var boss_fights: int = 0
	## Legendaries held at the end, with their tier: "tallymans_bow:B".
	var legendaries: Array[String] = []
	## Per hero at the end (draft order): calling level, specialization
	## level, and rank (docs/plans/deeds.md, "How to measure it").
	var calling_levels: Array[int] = []
	var spec_levels: Array[int] = []
	var ranks: Array[int] = []
	## Equipped items at the end: infused, Resonant, and holding two essences.
	var infused: int = 0
	var resonant: int = 0
	var fused: int = 0
	var errors: Array[String] = []


static func play(run_seed: int, content: ContentDb, run: RunContent) -> Report:
	var report := Report.new()
	report.seed_value = run_seed
	report.took_hard = run_seed % 2 == 0
	var state: RunState = RunFlow.new_run(run_seed, content)
	for step: int in MAX_ACTIONS:
		if state.phase == "act_end" or state.phase == "run_over":
			break
		_act(state, content, run, report)
		if not report.errors.is_empty():
			break
	report.ending = state.phase if state.phase == "act_end" or state.phase == "run_over" else "stuck"
	report.day = state.day
	report.losses = state.losses
	report.wins = state.wins
	report.discovered = state.discovered.duplicate()
	report.reached_boss = state.day >= run.act(state.act).days
	var held: Array[RunItem] = state.stash.duplicate()
	for hero: RunHero in state.heroes:
		held.append_array(hero.items)
	for item: RunItem in held:
		if content.items[item.item_id].legendary != null:
			report.legendaries.append("%s:%s" % [item.item_id, TuningDef.TIER_LABELS[item.tier]])
	for hero: RunHero in state.heroes:
		report.calling_levels.append(hero.deed_level(content, DeedSetup.CALLING))
		report.spec_levels.append(hero.deed_level(content, DeedSetup.SPECIALIZATION))
		report.ranks.append(hero.rank)
		for item: RunItem in hero.items:
			if item.essence_ids.is_empty():
				continue
			report.infused += 1
			if item.essence_ids.size() > 1:
				report.fused += 1
			if Infusions.level_for(item.xp, content.tuning) == Infusions.Level.RESONANT:
				report.resonant += 1
	var problems: Array[String] = state.check(content)
	report.errors.append_array(problems)
	return report


static func _act(state: RunState, content: ContentDb, run: RunContent, report: Report) -> void:
	match state.phase:
		"start_hero":
			_must(RunFlow.pick_start_hero(state, content, run, 0), report)
		"start_package":
			var kit: int = 0
			for i: int in range(state.offers.size() - 1, -1, -1):
				if state.offers[i]["package"] == "kit":
					kit = i
			_must(RunFlow.pick_package(state, content, run, kit), report)
		"stop_choice":
			if report.gold_by_day.size() < state.day:
				report.gold_by_day.append(state.gold)
			_must(RunFlow.pick_stop(state, content, run, _preferred_stop(state, run)), report)
		"stop":
			match state.stop_kind:
				"upgrade":
					_upgrade_best(state, content)
				"shop":
					_shop(state, content, report)
				_:
					_take_all(state, content, report)
			_organize(state, content)
			_must(RunFlow.leave_stop(state, content, run), report)
		"fight_choice":
			var pick: int = 0
			for i: int in state.fight_options.size():
				if RunFlow.is_hard_fight(state, run, state.fight_options[i]) == report.took_hard:
					pick = i
			_must(RunFlow.pick_fight(state, content, pick), report)
		"fight":
			_organize(state, content)
			if run.act(state.act).is_boss_day(state.day):
				report.boss_fights += 1
			var kind: String = content.encounters[state.encounter_id].kind
			var hard: bool = RunFlow.is_hard_fight(state, run, state.encounter_id)
			var encounter_id: String = state.encounter_id
			var day: int = state.day
			var fought: Array = RunFlow.fight(state, content, run)
			_must(fought[0], report)
			var result: FightResult = fought[1]
			if result != null:
				report.fights.append([kind, hard, result.guild_won(), float(result.end_tick) / FixedMath.TICKS_PER_SECOND, day, encounter_id])
		"rewards":
			_take_all(state, content, report)
			_organize(state, content)
			_must(RunFlow.done(state, content, run), report)


static func _must(result: RunActions.Result, report: Report) -> void:
	if not result.ok:
		report.errors.append(result.error)


static func _shop(state: RunState, content: ContentDb, report: Report) -> void:
	var order: Array[int] = []
	for i: int in state.offers.size():
		if state.offers[i]["type"] == "essence" and state.offers[i]["price"] <= state.gold:
			RunFlow.buy(state, content, i)
		if state.offers[i]["type"] == "item":
			order.append(i)
	var rank: Callable = func(i: int) -> Array:
		var upgrade: int = 0 if RunFlow.upgrade_target(state, content, i) >= 0 else 1
		var rarity: int = -ItemDef.RARITIES.find(content.items[state.offers[i]["item"]].rarity)
		return [upgrade, rarity, state.offers[i]["price"], i]
	order.sort_custom(func(a: int, b: int) -> bool: return rank.call(a) < rank.call(b))
	for i: int in order:
		var offer: Dictionary = state.offers[i]
		if offer["price"] <= state.gold and RunFlow.buy(state, content, i).ok:
			report.bought.append(offer["item"])
			_organize(state, content)


static func _preferred_stop(state: RunState, run: RunContent) -> int:
	if state.visit == 0:
		for i: int in state.offers.size():
			if run.is_shop(state.offers[i]["stop"]):
				return i
	for kind: String in STOP_PREFERENCE:
		for i: int in state.offers.size():
			if run.node_kind(state.offers[i]["stop"]) == kind:
				return i
	return 0


static func _take_all(state: RunState, content: ContentDb, report: Report) -> void:
	# The reward pick: the rarest item (or the relic, when it's all there is).
	var best: int = -1
	for i: int in state.offers.size():
		var offer: Dictionary = state.offers[i]
		if offer.get("group", "") != RunFlow.REWARD_PICK or offer["taken"]:
			continue
		if best < 0 or _rarity(content, offer) > _rarity(content, state.offers[best]):
			best = i
	if best >= 0 and RunFlow.take(state, content, best).ok and state.offers[best]["type"] == "item":
		report.bought.append(state.offers[best]["item"])
	for i: int in state.offers.size():
		var offer: Dictionary = state.offers[i]
		if offer["type"] == "rank_up" and not offer["taken"]:
			var lowest: RunHero = null
			for hero: RunHero in state.heroes:
				if hero.rank < 3 and (lowest == null or hero.rank < lowest.rank):
					lowest = hero
			if lowest != null:
				RunFlow.give_rank_up(state, content, i, lowest.hero_id)
			continue
		if not offer["taken"] and offer["price"] <= state.gold and RunFlow.take(state, content, i).ok:
			if offer["type"] == "item":
				report.bought.append(offer["item"])


## An item offer's rarity (0 = Common); relics count as Common.
static func _rarity(content: ContentDb, offer: Dictionary) -> int:
	return ItemDef.RARITIES.find(content.items[offer["item"]].rarity) if offer["type"] == "item" else 0


static func _upgrade_best(state: RunState, content: ContentDb) -> void:
	var best: RunItem = null
	for hero: RunHero in state.heroes:
		for item: RunItem in hero.items:
			if item.tier < 3 and content.items[item.item_id].rarity != "legendary" and (best == null or item.tier > best.tier):
				best = item
	if best != null:
		RunFlow.upgrade(state, content, best.uid)


## Combine copies, pick specializations and deed unlocks, equip, infuse,
## arrange the rows.
static func _organize(state: RunState, content: ContentDb) -> void:
	var combined: bool = true
	while combined:
		combined = false
		var all_items: Array[RunItem] = state.stash.duplicate()
		for hero: RunHero in state.heroes:
			all_items.append_array(hero.items)
		for a: int in all_items.size():
			for b: int in range(a + 1, all_items.size()):
				if not combined and all_items[a].item_id == all_items[b].item_id and all_items[a].tier == all_items[b].tier:
					combined = RunActions.combine_items(state, content, all_items[a].uid, all_items[b].uid).ok
	for hero: RunHero in state.heroes:
		if hero.needs_specialization:
			for spec_id: String in content.specialization_ids:
				if content.specializations[spec_id].hero == hero.hero_id:
					RunActions.choose_specialization(state, content, hero.hero_id, spec_id)
					break
	# Level-2 deed unlocks: alternate options across heroes and runs.
	for i: int in state.heroes.size():
		var hero: RunHero = state.heroes[i]
		for track_id: String in [DeedSetup.CALLING, DeedSetup.SPECIALIZATION]:
			if hero.choice_waiting(content, track_id):
				RunActions.choose_deed_unlock(state, content, hero.hero_id, track_id, (state.seed_value + i) % 2)
	for item: RunItem in state.stash.duplicate():
		for hero: RunHero in state.heroes:
			if RunActions.move_item(state, content, item.uid, hero.hero_id, hero.items.size()).ok:
				break
	_feed_legendaries(state, content)
	_infuse(state, content)
	_arrange_rows(state, content)


## Gives each equipped item without an infusion one essence, then fuses what's
## left into infusions that are still at Base (fusing resets XP, so it spares
## infusions that have grown).
static func _infuse(state: RunState, content: ContentDb) -> void:
	var equipped: Array[RunItem] = []
	for hero: RunHero in state.heroes:
		equipped.append_array(hero.items)
	for item: RunItem in equipped:
		if item.essence_ids.is_empty() and not state.pouch.is_empty():
			RunActions.infuse(state, content, item.uid, 0)
	for item: RunItem in equipped:
		if item.essence_ids.size() == 1 and item.xp < content.tuning.xp_to_attuned and not state.pouch.is_empty():
			RunActions.infuse(state, content, item.uid, 0)


## Essence-hungry Legendaries eat the essences they want before anything is
## infused; a Devourer eats whatever is left in the stash after equipping.
static func _feed_legendaries(state: RunState, content: ContentDb) -> void:
	var all_items: Array[RunItem] = state.stash.duplicate()
	for hero: RunHero in state.heroes:
		all_items.append_array(hero.items)
	for item: RunItem in all_items:
		var path: LegendaryDef = RunLegendary.path_of(content, item)
		if path == null or path.path != "essence":
			continue
		while item.tier < 3 and state.pouch.has(path.wanted_at(item.tier)):
			RunActions.feed_essence(state, content, item.uid, state.pouch.find(path.wanted_at(item.tier)))
	var devourers: Array[RunItem] = RunLegendary.devourers(state, content)
	if devourers.is_empty():
		return
	# Refused for the Devourer itself and other Legendaries.
	for food: RunItem in state.stash.duplicate():
		RunActions.devour_item(state, content, devourers[0].uid, food.uid)


## Sturdy classes in front, the rest behind; someone always stands in front.
static func _arrange_rows(state: RunState, content: ContentDb) -> void:
	var any_front: bool = false
	for hero: RunHero in state.heroes:
		var front: bool = FRONT_CLASSES.has(content.heroes[hero.hero_id].hero_class)
		RunActions.set_row(state, hero.hero_id, UnitSetup.Row.FRONT if front else UnitSetup.Row.BACK)
		any_front = any_front or front
	if not any_front and not state.heroes.is_empty():
		RunActions.set_row(state, state.heroes[0].hero_id, UnitSetup.Row.FRONT)
