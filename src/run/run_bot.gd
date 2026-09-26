class_name RunBot
extends RefCounted
## Plays whole runs headlessly with a simple strategy, through RunFlow and
## RunActions only (like a player would), so the run runner can report
## run-level balance (tools/run_runner.gd). The strategy:
##   - pick the first starting hero and the gold package
##   - at the Caravan: buy heroes while the guild is small (or to rank one up),
##     then items: upgrades for held copies first, then the rarest (Epics for
##     alloys), cheapest first within a rarity
##   - combine copies, equip what fits, feed Legendaries (the essences an
##     Essence-hungry one wants; stash leftovers to a Devourer), infuse free
##     sockets, field up to 5, sturdy classes in the front row and the rest
##     in the back
##   - stops: Loot, then Events, the Vault, Retrain, the Forge; take what fits;
##     upgrade the best item before the boss
##   - rewards: take everything that fits (the first relic of a choice)

const STOP_PREFERENCE: Array[String] = ["loot", "event", "vault", "retrain", "forge"]
## Classes that stand in the front row; the rest stand in the back.
const FRONT_CLASSES: Array[String] = ["warden", "striker", "trickster"]
## Heroes to recruit before only buying copies (to rank up).
const RECRUIT_UP_TO: int = 4
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
	var bought: Array[String] = []
	var discovered: Array[String] = []
	## Reached the act's last day (the boss), and how many boss fights it took.
	var reached_boss: bool = false
	var boss_fights: int = 0
	## Legendaries held at the end, with their tier: "tallymans_bow:B".
	var legendaries: Array[String] = []
	var errors: Array[String] = []


static func play(run_seed: int, content: ContentDb, run: RunContent) -> Report:
	var report := Report.new()
	report.seed_value = run_seed
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
	var problems: Array[String] = state.check(content)
	report.errors.append_array(problems)
	return report


static func _act(state: RunState, content: ContentDb, run: RunContent, report: Report) -> void:
	match state.phase:
		"start_hero":
			_must(RunFlow.pick_start_hero(state, content, 0), report)
		"start_package":
			_must(RunFlow.pick_package(state, content, run, 0), report)
		"caravan":
			if report.gold_by_day.size() < state.day:
				report.gold_by_day.append(state.gold)
			_shop(state, content, report)
			_organize(state, content)
			_must(RunFlow.leave_caravan(state, content, run), report)
		"stop_choice":
			_must(RunFlow.pick_stop(state, content, run, _preferred_stop(state)), report)
		"stop":
			if state.stop_kind == "upgrade":
				_upgrade_best(state, content)
			else:
				_take_all(state, content, report)
			_organize(state, content)
			_must(RunFlow.leave_stop(state), report)
		"fight":
			_organize(state, content)
			if run.act(state.act).is_boss_day(state.day):
				report.boss_fights += 1
			var fought: Array = RunFlow.fight(state, content, run)
			_must(fought[0], report)
		"rewards":
			_take_all(state, content, report)
			_organize(state, content)
			_must(RunFlow.done(state, content, run), report)


static func _must(result: RunActions.Result, report: Report) -> void:
	if not result.ok:
		report.errors.append(result.error)


static func _shop(state: RunState, content: ContentDb, report: Report) -> void:
	for i: int in state.offers.size():
		var offer: Dictionary = state.offers[i]
		if offer["type"] == "hero" and (state.heroes.size() < RECRUIT_UP_TO or state.hero(offer["hero"]) != null) and offer["price"] <= state.gold:
			if RunFlow.buy(state, content, i).ok:
				report.bought.append(offer["hero"])
	var order: Array[int] = []
	for i: int in state.offers.size():
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


static func _preferred_stop(state: RunState) -> int:
	for stop: String in STOP_PREFERENCE:
		for i: int in state.offers.size():
			if state.offers[i]["stop"] == stop:
				return i
	return 0


static func _take_all(state: RunState, content: ContentDb, report: Report) -> void:
	for i: int in state.offers.size():
		var offer: Dictionary = state.offers[i]
		if not offer["taken"] and offer["price"] <= state.gold and RunFlow.take(state, content, i).ok:
			if offer["type"] == "item":
				report.bought.append(offer["item"])


static func _upgrade_best(state: RunState, content: ContentDb) -> void:
	var best: RunItem = null
	for hero: RunHero in state.heroes:
		for item: RunItem in hero.items:
			if item.tier < 3 and content.items[item.item_id].rarity != "legendary" and (best == null or item.tier > best.tier):
				best = item
	if best != null:
		RunFlow.upgrade(state, content, best.uid)


## Combine copies, pick specializations, equip, infuse, field up to 5.
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
	for item: RunItem in state.stash.duplicate():
		for hero: RunHero in state.heroes:
			if RunActions.move_item(state, content, item.uid, hero.hero_id, hero.items.size()).ok:
				break
	_feed_legendaries(state, content)
	var holders: Array[RunItem] = state.stash.duplicate()
	for hero: RunHero in state.heroes:
		holders.append_array(hero.items)
	for item: RunItem in holders:
		while not state.pouch.is_empty() and RunActions.infuse(state, content, item.uid, 0).ok:
			pass
	for hero: RunHero in state.heroes:
		if hero.benched:
			RunActions.set_benched(state, hero.hero_id, false)
	_arrange_rows(state, content)


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
