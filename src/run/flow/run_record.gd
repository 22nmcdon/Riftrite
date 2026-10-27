class_name RunRecord
extends RefCounted
## What a fight leaves behind, for RunFlow (docs/plans/phases/rebuild-phase5-run.md,
## sections 4 to 6): RunFlow.record's work after each fight: pay, wounds,
## deeds and transformations, Tithe, the pick, growing cards and relics, the
## run's own counts, items ranking up, and the streak. RunFlow keeps record()
## and delegates here; every function takes the flow it acts on.


## Records a fought fight: the formation, deeds, wounds (a win heals one
## on each hero first, then each hero who fell takes one), transformations
## (and bonds found), then the outcome. A Hunt pays its shards on a win and
## is done, won or lost (its loss isn't a loss). The day's fight: a win pays
## by its tier (plus relics), offers the pick, and (an elite, or a Rift
## Tear) a relic choice; a loss replays the day, or ends the run. Either way
## the day's camp modifiers are spent. fight() calls it; tests call it with
## a result of their own.
static func record(flow: RunFlow, formation: Dictionary[String, Vector2i], result: FightResult) -> void:
	# The shards held as the fight started (phase 8 part 6: "won_holding").
	var held: int = flow.state.shards
	var hunting: bool = flow.fight_encounter() == flow.state.hunt and not flow.state.hunt.is_empty()
	var encounter_id: String = flow.state.hunt if hunting else flow.state.chosen
	var won: bool = result.outcome != FightResult.Outcome.DEFEAT
	flow.state.formation = formation.duplicate()
	flow.state.just_transformed.clear()
	flow.state.just_apexed.clear()
	var fought := RunState.Fought.new()
	fought.act = flow.state.act
	fought.day = flow.state.day
	fought.attempt = flow.state.attempt
	fought.encounter = encounter_id
	fought.outcome = result.outcome
	@warning_ignore("integer_division")
	fought.seconds = result.end_tick / FixedMath.TICKS_PER_SECOND
	fought.habits = RiftLearns.summary(flow.run, flow.state, formation, result)
	flow.state.fought.append(fought)
	# Edric's run pieces (phase 8 part 5): what Collection gathered (any
	# fight), and each Tithe after a won day fight; their deeds count it.
	var flawless: bool = won and _fallen(flow, result) == 0
	var tithes: Dictionary[String, int] = {}
	if won and not hunting:
		tithes = _tithes(flow, result, encounter_id)
	fought.collected = _collected(flow, result)
	for paid: int in tithes.values():
		fought.tithe += paid
	# The Tithe's shards held (The Counting House): what spending since the
	# last fight left of them (spent last), and today's.
	flow.state.tithe_held = mini(flow.state.tithe_held, held) + fought.tithe
	for hero: RunState.Hero in flow.state.heroes:
		# An oath doubles what the fight puts into its hero's deeds (step 8c).
		var oath: EventDef.Oath = RunEvents.oath_of(flow, hero) if not hunting else null
		for path_id: String in hero.deeds:
			var amount: int = result.deed_amount(hero.id, path_id)
			var deed: DeedDef = _deed_of(flow, path_id)
			if deed != null and deed.by_the_run():
				# Tithe's are paid here; the rest the run counts as they happen
				# (phase 8 part 6: items transmuted).
				amount = tithes.get(hero.id, 0) if deed.counts == DeedDef.Counts.TITHE or deed.counts == DeedDef.Counts.TITHE_FLAWLESS and flawless else 0
			hero.deeds[path_id] += FixedMath.apply_bp(amount, oath.deed_bp) if oath != null else amount
	_grow(flow, result)
	_rank_items(flow, formation, result, won)
	if won:
		for hero: RunState.Hero in flow.state.heroes:
			hero.wounds = maxi(hero.wounds - 1, 0)
	# A wound for each hero down at the fight's end (Decision 23: one Second
	# Dawn raised, standing at the end, takes none).
	for hero_id: String in result.down_at_end():
		var fallen: RunState.Hero = flow.state.hero(hero_id)
		if fallen != null:
			var oath: EventDef.Oath = RunEvents.oath_of(flow, fallen) if not hunting else null
			fallen.wounds = mini(fallen.wounds + (oath.fall_wounds if oath != null else 1), flow.run.content.tuning.max_wounds)
	for hero: RunState.Hero in flow.state.heroes:
		if not hero.transformed and hero.deeds.get(hero.path, 0) >= flow.run.content.paths[hero.path].deed.threshold:
			hero.transformed = true
			flow.state.just_transformed.append(hero.id)
			flow._open_apex(hero)
		elif not hero.apex.is_empty() and not hero.apex_earned and hero.deeds.get(hero.apex, 0) >= flow.run.content.apexes[hero.apex].deed.threshold:
			hero.apex_earned = true
			flow.state.just_apexed.append(hero.id)
	for bond: BondDef in flow.run.active_bonds(flow.state):
		if not flow.state.bonds_found.has(bond.id):
			flow.state.bonds_found.append(bond.id)
	flow.state.shards += fought.collected
	if fought.collected > 0:
		_grow_by_run(flow, "shards", fought.collected)
	if hunting:
		flow.state.hunt = ""
		if won:
			flow.state.shards += flow.act.pay["hunt"]
		return
	# An oath lasts its hero's next day fights, won or lost.
	for hero: RunState.Hero in flow.state.heroes:
		if not hero.oath.is_empty():
			hero.oath_fights -= 1
			if hero.oath_fights <= 0:
				hero.oath = ""
				hero.oath_fights = 0
	if not won:
		# What the last node set up for this fight holds for its replay
		# (Decision 42).
		flow.state.streak = 0
		flow.state.losses += 1
		flow.state.chosen = ""
		# Endless (phase 8 part 1): the first loss ends the run; the act was won.
		if flow.state.endless:
			flow._end(RunState.Outcome.WON)
		elif flow.state.losses >= flow.act.losses_to_end:
			flow._end(RunState.Outcome.LOST)
		else:
			flow.state.attempt += 1
			flow._start_day()
		return
	var depth: CampsDef.Depth = flow.run.camps.depth(flow.state.rift_depth)
	flow.state.fortify = false
	flow.state.dig_in = false
	flow.state.rock.clear()
	flow.state.rift_depth = ""
	flow.state.rift_mods.clear()
	for hero: RunState.Hero in flow.state.heroes:
		hero.next_fight.clear()
	flow.state.rested = false
	var tier: String = flow.run.content.encounters[flow.state.chosen].tier
	flow.state.shards += flow.act.pay[tier] + flow.run.relic_sum(flow.state, "pay_add") + (flow.run.relic_sum(flow.state, "elite_pay_add") if tier == "elite" else 0)
	flow.state.shards += fought.tithe
	_streak(flow, result)
	if tier == "elite":
		_grow_by_run(flow, "elite_wins")
	_grow_by_run(flow, "wins")
	if flawless:
		_grow_by_run(flow, "flawless")
	_grow_by_run(flow, "won_holding", 1, held)
	flow.state.phase = RunState.Phase.AFTER
	flow.state.relic_choice_price = 0
	if flow.run.day_kind(flow.state, flow.state.day) == "boss":
		# The boss relic choice (Decision 18), then the boss shop (finish_day;
		# Decision 48), then the run's end or the endless choice (leave_shop).
		# Once every boss relic is held, legendaries (endless.md).
		var boss_tier: String = "boss" if RunShop._boss_relic_left(flow) else "legendary"
		flow.state.relic_choice = Offers.relics(flow.run, flow.state, RunFlow.RELIC_AFTER_FIGHT, flow.act.boss_relics, boss_tier)
		return
	flow.state.pick = _pick_cards(flow, 0)
	if tier == "elite":
		flow.state.relic_choice = Offers.relics(flow.run, flow.state, RunFlow.RELIC_AFTER_FIGHT, 2, "rare", flow.act.elite_epic_pct)
	elif depth != null:
		flow.state.relic_choice = Offers.relics_of_tiers(flow.run, flow.state, RunFlow.RELIC_AFTER_FIGHT, depth.relics)


## Bounty Board (phase 5c step 5a): a won day fight with no hero falling adds
## to the streak, anything else ends it; a streak relic pays once.
static func _streak(flow: RunFlow, result: FightResult) -> void:
	var fell: bool = result.combat_log.entries.any(func(entry: LogEntry) -> bool: return entry.kind == LogEntry.Kind.DEATH and flow.state.hero(entry.target) != null)
	flow.state.streak = 0 if fell else flow.state.streak + 1
	for id: String in flow.state.relics:
		var relic: RelicDef = flow.run.relics.get(id)
		if relic != null and relic.streak_wins > 0 and flow.state.streak >= relic.streak_wins and not flow.state.streaks_paid.has(id):
			flow.state.shards += relic.streak_shards
			flow.state.streaks_paid.append(id)


## Adds `amount` (one, but for "shards": phase 8 part 6) to every held relic
## that grows with what the run counts as `what` (Tally of the Dead:
## "elite_wins"), and (phase 8 part 5) every hero's held card and earned apex
## that does ("wins", "flawless").
static func _grow_by_run(flow: RunFlow, what: String, amount: int = 1, held: int = -1) -> void:
	for id: String in flow.state.relics:
		var relic: RelicDef = flow.run.relics.get(id)
		if relic == null or relic.grows == null or relic.grows.run_counts != what:
			continue
		if held >= 0 and held < RunFlow.WON_HOLDING_SHARDS:
			continue
		var before: int = flow.state.growth.get(id, 0)
		flow.state.growth[id] = before + amount
		if relic.grows.steps(flow.state.growth[id]) > relic.grows.steps(before) and not flow.state.grew.has(":" + id):
			flow.state.grew.append(":" + id)
	for hero: RunState.Hero in flow.state.heroes:
		# "won_holding" (`held` the shards as the fight started): from its own
		# threshold (phase 8 part 6, Low Bar).
		if held >= 0 and held < flow.run.holding_threshold(hero):
			continue
		for upgrade: UpgradeDef in flow.run.held_upgrades(hero):
			if upgrade.grows != null and upgrade.grows.run_counts == what:
				_step_hero(flow, hero, upgrade.id, upgrade.grows, amount)
		var apex: ApexDef = flow.run.earned_apex(hero)
		if apex != null and apex.grows != null and apex.grows.run_counts == what:
			_step_hero(flow, hero, RunContent.apex_growth_key(apex), apex.grows, amount)
		# A transformed path's own snowball (phase 8 part 6, Fence: "spent").
		var path: PathDef = flow.run.content.paths.get(hero.path) if hero.transformed else null
		if path != null and path.transformed_grows != null and path.transformed_grows.run_counts == what:
			_step_hero(flow, hero, RunContent.path_growth_key(path), path.transformed_grows, amount)


static func _step_hero(flow: RunFlow, hero: RunState.Hero, key: String, grows: GrowthDef, amount: int = 1) -> void:
	var before: int = hero.growth.get(key, 0)
	hero.growth[key] = before + amount
	var note: String = "%s:%s" % [hero.id, key]
	if grows.steps(hero.growth[key]) > grows.steps(before) and not flow.state.grew.has(note):
		flow.state.grew.append(note)


## How many of the team are down at the fight's end.
static func _fallen(flow: RunFlow, result: FightResult) -> int:
	return result.down_at_end().filter(func(hero_id: String) -> bool: return flow.state.hero(hero_id) != null).size()


## Each hero's Tithe after this won day fight (phase 8 part 5): hero id ->
## shards, for those with one.
static func _tithes(flow: RunFlow, result: FightResult, encounter_id: String) -> Dictionary[String, int]:
	var paid: Dictionary[String, int] = {}
	var fallen: int = _fallen(flow, result)
	var tier: String = flow.run.content.encounters[encounter_id].tier
	for hero: RunState.Hero in flow.state.heroes:
		var tithe: TitheDef = flow.run.tithe(hero)
		if tithe == null:
			continue
		var apex: ApexDef = flow.run.earned_apex(hero)
		var flawless_count: int = hero.growth.get(RunContent.apex_growth_key(apex), 0) if apex != null and apex.grows != null else 0
		paid[hero.id] = tithe.pays(flow.state.heroes.size() - fallen, fallen, tier, flawless_count, flow.run.tithe_steps(hero))
		if tithe.once_per_act > 0 and hero.tithe_act != flow.state.act:
			# Lucky Find (phase 8 part 6): the first won day fight each act.
			paid[hero.id] += tithe.once_per_act
			hero.tithe_act = flow.state.act
	return paid


## The shards the heroes' effects gathered in a fight (Collection's SHARDS
## lines).
static func _collected(flow: RunFlow, result: FightResult) -> int:
	var total: int = 0
	for entry: LogEntry in result.combat_log.of_kind(LogEntry.Kind.SHARDS):
		if flow.state.hero(entry.source_unit) != null and not entry.capped:
			total += entry.amount
	return total


## A path's or an apex's deed by its id (null: neither).
static func _deed_of(flow: RunFlow, key: String) -> DeedDef:
	if flow.run.content.paths.has(key):
		return flow.run.content.paths[key].deed
	return flow.run.content.apexes[key].deed if flow.run.content.apexes.has(key) else null


## A pick's cards at `visit` (Widened Offering adds some), and how many of
## them to take (The Hollow Throne: 2).
static func _pick_cards(flow: RunFlow, visit: int) -> Array[String]:
	flow.state.picks_left = 1 + flow.run.relic_sum(flow.state, "take_picks_add")
	return Offers.pick(flow.run, flow.state, visit, flow.run.relic_sum(flow.state, "pick_cards_add"))


## Adds what a fight counted to the growing cards (phase 5c step 4; won or
## lost, a Hunt too), and notes the ones that stepped up (`grew`).
static func _grow(flow: RunFlow, result: FightResult) -> void:
	flow.state.grew.clear()
	for hero: RunState.Hero in flow.state.heroes:
		for upgrade: UpgradeDef in flow.run.held_upgrades(hero):
			if upgrade.grows == null:
				continue
			var before: int = hero.growth.get(upgrade.id, 0)
			hero.growth[upgrade.id] = upgrade.grows.grown(before, _faster(flow, result.tally_amount(hero.id, "upgrade:" + upgrade.id)))
			if upgrade.grows.steps(hero.growth[upgrade.id]) > upgrade.grows.steps(before):
				flow.state.grew.append("%s:%s" % [hero.id, upgrade.id])
		# Its earned apex's snowball, if its fights count it (phase 8 part 6).
		var apex: ApexDef = flow.run.earned_apex(hero)
		if apex != null and apex.grows != null and apex.grows.counted_in_fights():
			var key: String = RunContent.apex_growth_key(apex)
			var had: int = hero.growth.get(key, 0)
			hero.growth[key] = apex.grows.grown(had, _faster(flow, result.tally_amount(hero.id, key)))
			if apex.grows.steps(hero.growth[key]) > apex.grows.steps(had):
				flow.state.grew.append("%s:%s" % [hero.id, key])
	for id: String in flow.state.relics:
		var relic: RelicDef = flow.run.relics.get(id)
		if relic == null or relic.grows == null or not relic.grows.counted_in_fights():
			continue
		var before: int = flow.state.growth.get(id, 0)
		var counted: int = 0
		for hero: RunState.Hero in flow.state.heroes:
			counted += result.tally_amount(hero.id, "relic:" + id)
		flow.state.growth[id] = relic.grows.grown(before, _faster(flow, counted))
		var stepped: int = relic.grows.steps(flow.state.growth[id]) - relic.grows.steps(before)
		if stepped > 0:
			flow.state.grew.append(":" + id)
			flow.state.shards += stepped * relic.grows.each_shards


## The loadout's ranks (phase 5c step 6): each item equipped on a hero who
## fought counts toward its next rank by its kind (ActDef.item_ranks):
## charms won fights, gambits fights, tactics the ms its hero stood, sigils
## its signature's casts (the last two from the fight's tallies). Reaching
## the need ranks it up; the count goes on from what's left over.
static func _rank_items(flow: RunFlow, formation: Dictionary[String, Vector2i], result: FightResult, won: bool) -> void:
	flow.state.ranked.clear()
	for hero: RunState.Hero in flow.state.heroes:
		if not formation.has(hero.id):
			continue
		for item_id: String in hero.slots:
			var item: ItemDef = flow.run.items.get(item_id)
			if item == null or flow.state.item_ranks.get(item_id, 1) >= ItemDef.RANKS:
				continue
			var counted: int = 0
			match item.kind:
				ItemDef.Kind.CHARM:
					counted = 1 if won else 0
				ItemDef.Kind.GAMBIT:
					counted = 1
				_:
					counted = result.tally_amount(hero.id, "item:" + item_id)
			if counted > 0:
				_count_item(flow, item, counted)


static func _count_item(flow: RunFlow, item: ItemDef, counted: int) -> void:
	var needs: Array = flow.act.item_ranks[ItemDef.KIND_NAMES[item.kind]]
	flow.state.item_counts[item.id] = flow.state.item_counts.get(item.id, 0) + counted
	while flow.state.item_ranks.get(item.id, 1) < ItemDef.RANKS and flow.state.item_counts[item.id] >= int(needs[flow.state.item_ranks.get(item.id, 1) - 1]):
		flow.state.item_counts[item.id] -= int(needs[flow.state.item_ranks[item.id] - 1])
		flow.state.item_ranks[item.id] += 1
		if not flow.state.ranked.has(item.id):
			flow.state.ranked.append(item.id)
	if flow.state.item_ranks[item.id] >= ItemDef.RANKS:
		flow.state.item_counts[item.id] = 0


## What's counted, made faster by Rift-Bound Heart's growth_bp while held.
static func _faster(flow: RunFlow, counted: int) -> int:
	for id: String in flow.state.relics:
		if flow.run.relics.has(id) and flow.run.relics[id].growth_bp > 0:
			counted = FixedMath.apply_bp(counted, flow.run.relics[id].growth_bp)
	return counted


## What `item_id` has counted toward its next rank, and what that rank needs
## (0 at rank III).
static func rank_progress(flow: RunFlow, item_id: String) -> Vector2i:
	var rank: int = flow.state.item_ranks.get(item_id, 1)
	if rank >= ItemDef.RANKS or not flow.run.items.has(item_id):
		return Vector2i(0, 0)
	var needs: Array = flow.act.item_ranks[ItemDef.KIND_NAMES[flow.run.items[item_id].kind]]
	return Vector2i(flow.state.item_counts.get(item_id, 0), int(needs[rank - 1]))
