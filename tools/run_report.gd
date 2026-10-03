extends RefCounted
## The run report (docs/plans/rebuild-phase5-run.md, section 12; phase 6
## plays it with any bot, tools/bots/): a bot plays many runs, and this
## measures pacing: runs won and where the
## rest end, when each hero first transforms (the design: the first around
## days 3-4, all three by the boss), picks per hero, shards earned and
## spent, wounds taken, relics found, the nodes shown and taken (phase 5c
## step 8), and how each encounter goes. A report,
## not a gate. tools/run_runner.gd prints it.
## Each run's vows cycle through every combination of paths (seed n takes
## combination n mod 27), so every path is measured.

const Bot = preload("res://tools/run_bot.gd")
const RunPlayer = preload("res://tools/bots/run_player.gd")
const BaseBot = preload("res://tools/bots/bot.gd")
const RandomBot = preload("res://tools/bots/random_bot.gd")
const GoodBot = preload("res://tools/bots/good_bot.gd")
const ExpertBot = preload("res://tools/bots/expert_bot.gd")
## The bots by name (--bot): "simple-peek" is the report's bot before phase
## 6 (the simple bot, trying the named formations in the real fight).
const BOTS: Array[String] = ["simple", "simple-peek", "random", "good", "expert"]


## One run, as measured.
class RunLine:
	var seed_value: int
	var vows: Dictionary[String, String] = {}
	var outcome: RunState.Outcome
	## The day it ended (or the boss's, won).
	var day: int
	## Hero id -> the day it first transformed (0: never).
	var transformed_on: Dictionary[String, int] = {}
	var picks: Dictionary[String, int] = {}
	## Picks taken by layer (UpgradeDef.Layer: hero, taste, path; phase 5c
	## step 7), and the stacking cards' takes and what they locked in.
	var layer_picks: Array[int] = [0, 0, 0, 0]
	var stack_takes: int = 0
	var stack_points: int = 0
	var shards_earned: int = 0
	var shards_spent: int = 0
	var wounds: int = 0
	var relics: int = 0
	## Relics held at the end, by tier (RelicDef.Tier; phase 5c step 5a).
	var relic_tiers: Array[int] = [0, 0, 0, 0, 0, 0]
	## Items owned at the end, by rank (phase 5c step 6: I, II, III).
	var item_ranks: Array[int] = [0, 0, 0]
	## Node kind -> the days it was shown, and taken (phase 5c step 8).
	var nodes_shown: Dictionary[String, int] = {}
	var nodes_taken: Dictionary[String, int] = {}
	## Rift Tear fights (phase 5c step 8b): fought, and won (each attempt).
	var rift_fights: int = 0
	var rift_wins: int = 0
	## Event scenes taken (phase 5c step 8c): scene id -> times.
	var scenes: Dictionary[String, int] = {}
	## The heroes' engines over the day fights (phase 5c step 9b, --engines):
	## engine name -> [fights it fired or added in, fires, fires from chains,
	## deepest chain, what it added, its team's output in those fights], and
	## each event passive held -> the fights it was held in.
	var engines: Dictionary[String, Array] = {}
	var held: Dictionary[String, int] = {}
	var errors: Array[String] = []
	## The bot that played it.
	var bot: String = ""
	## Every card, item, and relic offered in the run, and every one it held
	## at some point ("card:", "item:", "relic:" ids; --choices, phase 6
	## step 6d).
	var offered: Dictionary[String, bool] = {}
	var taken: Dictionary[String, bool] = {}
	## [encounter id, won?] for each fight.
	var fights: Array[Array] = []
	## Path id -> what the run's fights put into it while its hero was vowed
	## to it and not yet transformed, and how many fights that was.
	var vowed_gain: Dictionary[String, int] = {}
	var vowed_fights: Dictionary[String, int] = {}
	## Growing upgrade id -> what it counted by the run's end, and the
	## fights it was held for (phase 5c step 4).
	var grown: Dictionary[String, int] = {}
	var grown_fights: Dictionary[String, int] = {}
	## Endless (phase 8 part 1, --endless): the floor the run reached (0: it
	## didn't go deeper), the fight it fell to there, and the rift modifiers
	## it had gathered.
	var floor_reached: int = 0
	var fell_to: String = ""
	var endless_mods: Array[String] = []
	## Apexes (phase 8 part 2): hero id -> the apex it earned, and the floor
	## it earned it on.
	var apexes: Dictionary[String, String] = {}
	var apexed_on: Dictionary[String, int] = {}

	## Its measures as a Dictionary (what --jobs passes between processes,
	## with FileAccess.store_var, so types survive).
	func to_dict() -> Dictionary:
		var data: Dictionary = {}
		for property: Dictionary in get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				data[property.name] = get(property.name)
		return data

	static func from_dict(data: Dictionary) -> RunLine:
		var line := RunLine.new()
		for key: String in data:
			line.set(key, data[key])
		return line


## Every combination of one path per hero, in heroes.json's and paths.json's
## order.
static func vow_combinations(content: ContentDb) -> Array[Dictionary]:
	var combos: Array[Dictionary] = [{}]
	for hero_id: String in content.hero_ids:
		var next: Array[Dictionary] = []
		for combo: Dictionary in combos:
			for path: PathDef in content.heroes[hero_id].paths:
				var more: Dictionary = combo.duplicate()
				more[hero_id] = path.id
				next.append(more)
		combos = next
	return combos


## A fresh bot by name (BOTS).
static func make_bot(bot_name: String) -> BaseBot:
	match bot_name:
		"random":
			return RandomBot.new()
		"good":
			return GoodBot.new()
		"expert":
			return ExpertBot.new()
		"simple-peek":
			var peeking: BaseBot = BaseBot.new()
			peeking.label = "simple-peek"
			peeking.peek = true
			return peeking
	return BaseBot.new()


## Plays run `run_seed` to its end with the bot named `bot_name`, measuring
## it.
static func play(run: RunContent, run_seed: int, bot_name: String = "simple-peek", endless: bool = false) -> RunLine:
	var line := RunLine.new()
	line.seed_value = run_seed
	line.bot = bot_name
	var bot: BaseBot = make_bot(bot_name)
	bot.deeper = endless
	var combos: Array[Dictionary] = vow_combinations(run.content)
	line.vows.assign(combos[run_seed % combos.size()])
	var flow: RunFlow = RunFlow.start(run, run_seed, line.vows, line.errors)
	if flow == null:
		return line
	var state: RunState = flow.state
	bot.begin(flow)
	var shards: int = state.shards
	var wounds: int = 0
	var fought: int = 0
	var counted: FightResult = null
	var before: Dictionary[String, int] = {}
	for hero: RunState.Hero in state.heroes:
		before[hero.id] = hero.deeds[hero.path]
	for step: int in RunPlayer.MAX_STEPS:
		var vowed_to: Dictionary[String, String] = {}
		var was_transformed: Dictionary[String, bool] = {}
		for hero: RunState.Hero in state.heroes:
			vowed_to[hero.id] = hero.path
			was_transformed[hero.id] = hero.transformed
			before[hero.id] = hero.deeds[hero.path]
		if state.phase == RunState.Phase.ENDED:
			break
		if state.phase == RunState.Phase.NODES:
			for node: String in state.nodes:
				line.nodes_shown[node.get_slice(":", 0)] = line.nodes_shown.get(node.get_slice(":", 0), 0) + 1
		for id: String in state.pick:
			line.offered["card:" + id] = true
		for id: String in state.relic_choice:
			line.offered["relic:" + id] = true
		if not state.shop.is_empty():
			for id: String in state.wares:
				if not id.is_empty():
					line.offered["item:" + id] = true
			for id: String in state.shop_relics:
				if not id.is_empty():
					line.offered["relic:" + id] = true
		var torn: bool = not state.rift_depth.is_empty() and state.phase == RunState.Phase.LOADOUT
		var refused: String = RunPlayer.step(flow, bot)
		for hero: RunState.Hero in state.heroes:
			for id: String in hero.upgrades:
				line.taken["card:" + id] = true
		for id: String in state.relics:
			line.taken["relic:" + id] = true
		for id: String in state.item_ranks:
			line.taken["item:" + id] = true
		if not refused.is_empty():
			line.errors.append("day %d (%s): %s" % [state.day, RunState.PHASE_NAMES[state.phase], refused])
			break
		if state.shards > shards:
			line.shards_earned += state.shards - shards
		else:
			line.shards_spent += shards - state.shards
		shards = state.shards
		var now: int = state.heroes.reduce(func(sum: int, hero: RunState.Hero) -> int: return sum + hero.wounds, 0)
		line.wounds += maxi(now - wounds, 0)
		wounds = now
		if state.fought.size() > fought:
			fought = state.fought.size()
			var last: RunState.Fought = state.fought.back()
			# A sealed fight (phase 5c step 8c) wasn't fought, so it has no new result.
			if flow.last_result != null and flow.last_result != counted and run.content.encounters[last.encounter].tier != "hunt":
				counted = flow.last_result
				_count_engines(line, flow.last_setup, flow.last_result, run.content.tuning.chain_limit)
			line.fights.append([last.encounter, last.outcome != FightResult.Outcome.DEFEAT])
			if torn:
				line.rift_fights += 1
				line.rift_wins += 1 if last.outcome != FightResult.Outcome.DEFEAT else 0
			for hero: RunState.Hero in state.heroes:
				for upgrade: UpgradeDef in run.held_upgrades(hero):
					if upgrade.grows != null:
						line.grown_fights[upgrade.id] = line.grown_fights.get(upgrade.id, 0) + 1
			for hero: RunState.Hero in state.heroes:
				var path_id: String = vowed_to[hero.id]
				if not was_transformed[hero.id]:
					line.vowed_gain[path_id] = line.vowed_gain.get(path_id, 0) + hero.deeds[path_id] - before[hero.id]
					line.vowed_fights[path_id] = line.vowed_fights.get(path_id, 0) + 1
			for hero_id: String in state.just_transformed:
				if not line.transformed_on.has(hero_id):
					line.transformed_on[hero_id] = last.day
			for hero_id: String in state.just_apexed:
				if not line.apexed_on.has(hero_id):
					line.apexed_on[hero_id] = run.floor_of(state, last.day)
					line.apexes[hero_id] = state.hero(hero_id).apex
	line.outcome = state.outcome
	line.day = state.day
	if state.endless:
		line.floor_reached = flow.floor_number()
		line.endless_mods = state.endless_mods.duplicate()
		var last: RunState.Fought = state.fought.back() if not state.fought.is_empty() else null
		if last != null and last.outcome == FightResult.Outcome.DEFEAT and last.day == state.day:
			line.fell_to = last.encounter
	for hero: RunState.Hero in state.heroes:
		line.picks[hero.id] = hero.upgrades.size()
		for id: String in hero.upgrades:
			line.layer_picks[run.upgrades[id].layer] += 1
		for id: String in hero.locked:
			line.stack_takes += hero.locked[id].size()
			for amount: Variant in hero.locked[id]:
				line.stack_points += int(amount)
		if not line.transformed_on.has(hero.id):
			line.transformed_on[hero.id] = 0
	for node: String in state.taken_nodes:
		if not node.is_empty():
			var kind: String = node.get_slice(":", 0)
			line.nodes_taken[kind] = line.nodes_taken.get(kind, 0) + 1
			if kind == "event":
				line.scenes[node.get_slice(":", 1)] = line.scenes.get(node.get_slice(":", 1), 0) + 1
	line.relics = state.relics.size()
	for id: String in state.relics:
		line.relic_tiers[run.relics[id].tier] += 1
	for id: String in state.item_ranks:
		line.item_ranks[state.item_ranks[id] - 1] += 1
	for hero: RunState.Hero in state.heroes:
		for upgrade_id: String in hero.growth:
			line.grown[upgrade_id] = hero.growth[upgrade_id]
	return line


## Adds a day fight's engines to `line` (ComboTally over its log), and the
## event passives its heroes held.
static func _count_engines(line: RunLine, setup: FightSetup, result: FightResult, chain_limit: int) -> void:
	var hero_ids: Array[String] = []
	for unit: UnitSetup in setup.heroes:
		hero_ids.append(unit.id)
		for part: PartDef in unit.def.passives:
			if part.kind == PartDef.Kind.ABILITY:
				var held_name: String = "%s · %s" % [unit.id, part.name]
				line.held[held_name] = line.held.get(held_name, 0) + 1
	var tally: ComboTally = ComboTally.of_log(result.combat_log, chain_limit, hero_ids)
	var team: int = 0
	var rows: Array[ComboTally.EngineRow] = tally.engines.filter(func(row: ComboTally.EngineRow) -> bool: return row.side == EffectSource.Team.HEROES)
	for row: ComboTally.EngineRow in rows:
		team += row.total()
	for row: ComboTally.EngineRow in rows:
		if row.fires == 0 and row.total() == 0:
			continue
		var stats: Array = line.engines.get(row.name, [0, 0, 0, 0, 0, 0])
		stats[0] += 1
		stats[1] += row.fires
		stats[2] += row.from_chains
		stats[3] = maxi(stats[3], row.deepest)
		stats[4] += row.total()
		stats[5] += team
		line.engines[row.name] = stats


## The engine report (phase 5c step 9b, `--engines`): every hero engine
## over the runs' day fights, most of its team's output first (fights, fires
## a fight, the share from chains, the deepest chain, its share of what its
## team dealt, healed, and Shielded in those fights), then the event
## passives held that never fired.
static func engines_summary(lines: Array[RunLine], shown: int = 40) -> String:
	var merged: Dictionary[String, Array] = {}
	var held: Dictionary[String, int] = {}
	for line: RunLine in lines:
		for name: String in line.engines:
			var stats: Array = merged.get(name, [0, 0, 0, 0, 0, 0])
			var more: Array = line.engines[name]
			for i: int in 6:
				stats[i] = maxi(stats[i], more[i]) if i == 3 else stats[i] + more[i]
			merged[name] = stats
		for name: String in line.held:
			held[name] = held.get(name, 0) + line.held[name]
	var names: Array[String] = []
	names.assign(merged.keys())
	names.sort_custom(func(a: String, b: String) -> bool:
		var share_a: int = _pct(merged[a][4], merged[a][5])
		var share_b: int = _pct(merged[b][4], merged[b][5])
		return share_a > share_b if share_a != share_b else a < b)
	var out: PackedStringArray = PackedStringArray()
	out.append("Engines (the heroes' sources over the bot's day fights: fights, fires a fight, from chains, deepest chain, share of the team's output in them):")
	for i: int in mini(shown, names.size()):
		var stats: Array = merged[names[i]]
		out.append("  %-40s %4d fights, %5.1f fires, %3d%% chained, deepest %d, %3d%% of output" % [names[i], stats[0], float(stats[1]) / maxi(stats[0], 1),
			_pct(stats[2], stats[1]), stats[3], _pct(stats[4], stats[5])])
	var silent: Array[String] = []
	for name: String in held:
		if not merged.has(name) or merged[name][1] == 0:
			silent.append("%s (%d)" % [name, held[name]])
	silent.sort()
	out.append("Held but never fired (fights held): %s" % (", ".join(silent) if not silent.is_empty() else "none"))
	return "\n".join(out)


## The bots side by side (--compare): runs won, the day lost runs end, and
## the encounters that end them most.
static func compare_summary(run: RunContent, by_bot: Dictionary[String, Array]) -> String:
	var out: PackedStringArray = PackedStringArray()
	out.append("Bots on the same seeds (runs won; lost runs by the day they end; the encounters that end the most):")
	for bot_name: String in by_bot:
		var lines: Array = by_bot[bot_name]
		var won: int = lines.filter(func(line: RunLine) -> bool: return line.outcome == RunState.Outcome.WON).size()
		var days: PackedStringArray = PackedStringArray()
		var ended: Dictionary[String, int] = {}
		for day: int in range(1, run.act.days.size() + 1):
			days.append(str(lines.filter(func(line: RunLine) -> bool: return line.outcome == RunState.Outcome.LOST and line.day == day).size()))
		for line: RunLine in lines:
			if line.outcome == RunState.Outcome.LOST and not line.fights.is_empty():
				var last: String = line.fights.back()[0]
				ended[last] = ended.get(last, 0) + 1
		var worst: Array = ended.keys()
		worst.sort_custom(func(a: String, b: String) -> bool: return ended[a] > ended[b] if ended[a] != ended[b] else a < b)
		var named: PackedStringArray = PackedStringArray()
		for id: String in worst.slice(0, 3):
			named.append("%s %d" % [run.content.encounters[id].name, ended[id]])
		out.append("  %-12s won %3d%% (%d of %d); lost on days 1-7: %s; ended by %s" % [bot_name, _pct(won, lines.size()), won, lines.size(),
			" ".join(days), ", ".join(named) if not named.is_empty() else "-"])
	return "\n".join(out)


## The choices report (--choices, phase 6 step 6d): each card, item, and
## relic offered in at least `least` runs: how often it was offered and
## taken, and the runs won when it was taken against when it was offered and
## not. Flags what's never taken and what wins far above its kind.
static func choices_summary(run: RunContent, lines: Array[RunLine], least: int = 5) -> String:
	var out: PackedStringArray = PackedStringArray()
	for kind: String in ["card", "item", "relic"]:
		var rows: Array = []
		var ids: Dictionary[String, bool] = {}
		for line: RunLine in lines:
			for key: String in line.offered:
				if key.begins_with(kind + ":"):
					ids[key] = true
		var kind_won: int = 0
		var kind_taken: int = 0
		for key: String in ids:
			var offered: int = 0
			var taken: int = 0
			var won_taken: int = 0
			var passed: int = 0
			var won_passed: int = 0
			for line: RunLine in lines:
				if not line.offered.has(key):
					continue
				offered += 1
				var won: bool = line.outcome == RunState.Outcome.WON
				if line.taken.has(key):
					taken += 1
					won_taken += 1 if won else 0
				else:
					passed += 1
					won_passed += 1 if won else 0
			kind_won += won_taken
			kind_taken += taken
			if offered >= least:
				rows.append([key.get_slice(":", 1), offered, taken, won_taken, passed, won_passed])
		var average: int = _pct(kind_won, kind_taken)
		rows.sort_custom(func(a: Array, b: Array) -> bool: return _pct(a[3], a[2]) > _pct(b[3], b[2]) if _pct(a[3], a[2]) != _pct(b[3], b[2]) else a[0] < b[0])
		out.append("%ss (offered in %d+ runs; won when taken against offered and passed; the kind's runs won when taken: %d%%):" % [kind.capitalize(), least, average])
		var never: PackedStringArray = PackedStringArray()
		for row: Array in rows:
			if row[2] == 0:
				never.append("%s (%d)" % [_choice_name(run, kind, row[0]), row[1]])
				continue
			var flag: String = "  << wins far above its kind" if _pct(row[3], row[2]) > average + 15 and row[2] >= least else ""
			out.append("  %-26s offered %3d, taken %3d%%, won %3d%% taken / %s passed%s" % [_choice_name(run, kind, row[0]), row[1], _pct(row[2], row[1]),
				_pct(row[3], row[2]), "%3d%%" % _pct(row[5], row[4]) if row[4] > 0 else "   -", flag])
		out.append("  never taken when offered: %s" % (", ".join(never) if not never.is_empty() else "none"))
	return "\n".join(out)


static func _choice_name(run: RunContent, kind: String, id: String) -> String:
	match kind:
		"card":
			return run.upgrades[id].name if run.upgrades.has(id) else id
		"item":
			return run.items[id].name if run.items.has(id) else id
	return run.relics[id].name if run.relics.has(id) else id


static func play_many(run: RunContent, seeds: Array[int], bot_name: String = "simple-peek", endless: bool = false) -> Array[RunLine]:
	var lines: Array[RunLine] = []
	for run_seed: int in seeds:
		lines.append(play(run, run_seed, bot_name, endless))
	return lines


## Endless's report (phase 8 part 1, --endless; Decision 5: a report, not
## tuned): how deep the runs that won the act went, what floor kinds and
## fights ended them, and the rift modifiers on at the end.
static func endless_summary(run: RunContent, lines: Array[RunLine]) -> String:
	var out: PackedStringArray = PackedStringArray()
	var deeper: Array[RunLine] = []
	deeper.assign(lines.filter(func(line: RunLine) -> bool: return line.floor_reached > 0))
	out.append("Endless: %d of %d runs won the act and went deeper" % [deeper.size(), lines.size()])
	if deeper.is_empty():
		return "\n".join(out)
	var floors: Array[int] = []
	for line: RunLine in deeper:
		floors.append(line.floor_reached)
	floors.sort()
	@warning_ignore("integer_division")
	out.append("  Floor reached: median %d, quartiles %d-%d, deepest %d, shallowest %d" % [floors[floors.size() / 2], floors[floors.size() / 4], floors[floors.size() * 3 / 4], floors.back(), floors.front()])
	var buckets: Dictionary[int, int] = {}
	for f: int in floors:
		@warning_ignore("integer_division")
		var bucket: int = (f - 1) / 5
		buckets[bucket] = buckets.get(bucket, 0) + 1
	var bucket_text: PackedStringArray = PackedStringArray()
	for bucket: int in range(0, buckets.keys().max() + 1):
		bucket_text.append("%d-%d: %d" % [bucket * 5 + 1, bucket * 5 + 5, buckets.get(bucket, 0)])
	out.append("  Runs falling by floors: " + ", ".join(bucket_text))
	var kinds: Dictionary[String, int] = {}
	var fights: Dictionary[String, int] = {}
	for line: RunLine in deeper:
		if line.fell_to.is_empty():
			continue
		var kind: String = run.act.endless.kind(line.floor_reached) if run.act.endless != null else "?"
		kinds[kind] = kinds.get(kind, 0) + 1
		fights[line.fell_to] = fights.get(line.fell_to, 0) + 1
	out.append("  Fell on a floor that was: normal %d, elite %d, boss %d" % [kinds.get("normal", 0), kinds.get("elite", 0), kinds.get("boss", 0)])
	var worst: Array = fights.keys()
	worst.sort_custom(func(a: String, b: String) -> bool: return fights[a] > fights[b] if fights[a] != fights[b] else a < b)
	var named: PackedStringArray = PackedStringArray()
	for id: String in worst:
		named.append("%s %d" % [run.content.encounters[id].name, fights[id]])
	out.append("  Fell to: " + ", ".join(named))
	var mods: Dictionary[String, int] = {}
	var mod_total: int = 0
	for line: RunLine in deeper:
		mod_total += line.endless_mods.size()
		for id: String in line.endless_mods:
			mods[id] = mods.get(id, 0) + 1
	var mod_text: PackedStringArray = PackedStringArray()
	for id: String in run.camps.modifier_ids:
		if mods.has(id):
			mod_text.append("%s %d" % [run.camps.modifiers[id].name, mods[id]])
	out.append("  Rift modifiers on at the end: %.1f a run (%s)" % [float(mod_total) / deeper.size(), ", ".join(mod_text) if not mod_text.is_empty() else "none"])
	var by_vow: Dictionary[String, Array] = {}
	for line: RunLine in deeper:
		for hero_id: String in line.vows:
			var path_id: String = line.vows[hero_id]
			if not by_vow.has(path_id):
				by_vow[path_id] = []
			by_vow[path_id].append(line.floor_reached)
	var vow_text: PackedStringArray = PackedStringArray()
	for path_id: String in run.content.path_ids:
		if by_vow.has(path_id):
			var values: Array[int] = []
			values.assign(by_vow[path_id])
			vow_text.append("%s %s" % [run.content.paths[path_id].name, _median(values)])
	out.append("  Median floor by vow: " + ", ".join(vow_text))
	# Apexes (phase 8 part 2): when each is earned, and how far runs get with
	# and without one.
	var earned: Dictionary[String, Array] = {}
	var with_apex: Array[int] = []
	var without: Array[int] = []
	for line: RunLine in deeper:
		(with_apex if not line.apexed_on.is_empty() else without).append(line.floor_reached)
		for hero_id: String in line.apexed_on:
			var apex_id: String = line.apexes[hero_id]
			if not earned.has(apex_id):
				earned[apex_id] = []
			earned[apex_id].append(line.apexed_on[hero_id])
	out.append("  Runs with an apex: %d (median floor %s), without: %d (median floor %s)" % [with_apex.size(), _median(with_apex) if not with_apex.is_empty() else "-",
		without.size(), _median(without) if not without.is_empty() else "-"])
	var apex_text: PackedStringArray = PackedStringArray()
	for apex_id: String in run.content.apex_ids:
		if earned.has(apex_id):
			var values: Array[int] = []
			values.assign(earned[apex_id])
			apex_text.append("%s %d (floor %s)" % [run.content.apexes[apex_id].name, values.size(), _median(values)])
	out.append("  Apexes earned (times, median floor): " + (", ".join(apex_text) if not apex_text.is_empty() else "none"))
	return "\n".join(out)


## The report's text.
static func summary(run: RunContent, lines: Array[RunLine]) -> String:
	var content: ContentDb = run.content
	var out: PackedStringArray = PackedStringArray()
	var n: int = lines.size()
	var won: int = lines.filter(func(line: RunLine) -> bool: return line.outcome == RunState.Outcome.WON).size()
	out.append("Runs: %d (the %s bot), won %d (%d%%)" % [n, lines[0].bot if n > 0 else "-", won, _pct(won, n)])
	var ended: Array[int] = []
	for day: int in run.act.days.size() + 1:
		ended.append(0)
	for line: RunLine in lines:
		if line.outcome == RunState.Outcome.LOST:
			ended[line.day] += 1
	var where: PackedStringArray = PackedStringArray()
	for day: int in range(1, ended.size()):
		where.append("day %d: %d" % [day, ended[day]])
	out.append("Lost runs end on %s" % ", ".join(where))
	out.append("")
	out.append("First transformation (a run's first hero; the design: around days 3-4):")
	var firsts: Array[int] = []
	for line: RunLine in lines:
		var days: Array = line.transformed_on.values().filter(func(day: int) -> bool: return day > 0)
		if not days.is_empty():
			firsts.append(days.min())
	out.append("  %d of %d runs have one; median day %s" % [firsts.size(), n, _median(firsts)])
	out.append("By path (runs vowed to it: transformed at all, median day, by the boss among runs that reached it; its deed per fight while vowed, and the threshold):")
	for path_id: String in content.path_ids:
		var path: PathDef = content.paths[path_id]
		var vowed: Array[RunLine] = lines.filter(func(line: RunLine) -> bool: return line.vows.get(path.hero, "") == path_id)
		var days: Array[int] = []
		var reached: int = 0
		var by_boss: int = 0
		for line: RunLine in vowed:
			var day: int = line.transformed_on.get(path.hero, 0)
			if day > 0:
				days.append(day)
			if line.day >= run.act.days.size():
				reached += 1
				# A transformation on an endless floor came after the boss.
				by_boss += 1 if day > 0 and day <= run.act.days.size() else 0
		var gain: int = 0
		var fights: int = 0
		for line: RunLine in lines:
			gain += line.vowed_gain.get(path_id, 0)
			fights += line.vowed_fights.get(path_id, 0)
		out.append("  %-14s %3d runs: %3d%% transform, median day %s, by the boss %s; %s a fight (threshold %s)" % [path.name, vowed.size(), _pct(days.size(), vowed.size()),
			_median(days), "%d%%" % _pct(by_boss, reached) if reached > 0 else "-",
			_per_fight(path.deed, gain, fights), UnitInfo.deed_amount_text(path.deed, path.deed.threshold)])
	out.append("")
	var per_hero: PackedStringArray = PackedStringArray()
	for hero_id: String in content.hero_ids:
		var total: int = lines.reduce(func(sum: int, line: RunLine) -> int: return sum + line.picks.get(hero_id, 0), 0)
		per_hero.append("%s %.1f" % [content.heroes[hero_id].kit.id.capitalize(), float(total) / maxi(n, 1)])
	out.append("Picks taken per run: %s" % ", ".join(per_hero))
	var by_layer: PackedStringArray = PackedStringArray()
	for layer: int in UpgradeDef.LAYER_NAMES.size():
		var total: int = lines.reduce(func(sum: int, line: RunLine) -> int: return sum + line.layer_picks[layer], 0)
		by_layer.append("%s %.1f" % [UpgradeDef.LAYER_NAMES[layer], float(total) / maxi(n, 1)])
	var takes: int = lines.reduce(func(sum: int, line: RunLine) -> int: return sum + line.stack_takes, 0)
	var points: int = lines.reduce(func(sum: int, line: RunLine) -> int: return sum + line.stack_points, 0)
	out.append("Picks per run by layer: %s; stacking cards taken %.1f a run, %.1f points each" % [", ".join(by_layer), float(takes) / maxi(n, 1), float(points) / maxi(takes, 1)])
	out.append("Per run: %.1f shards earned, %.1f spent, %.1f wounds, %.1f relics" % [_mean(lines, "shards_earned"), _mean(lines, "shards_spent"), _mean(lines, "wounds"), _mean(lines, "relics")])
	var by_tier: PackedStringArray = PackedStringArray()
	for tier: int in RelicDef.TIER_NAMES.size():
		var total: int = lines.reduce(func(sum: int, line: RunLine) -> int: return sum + line.relic_tiers[tier], 0)
		by_tier.append("%s %.1f" % [RelicDef.TIER_NAMES[tier], float(total) / maxi(n, 1)])
	out.append("Relics per run by tier: %s" % ", ".join(by_tier))
	var by_rank: Array[String] = []
	for rank: int in ItemDef.RANKS:
		var total: int = lines.reduce(func(sum: int, line: RunLine) -> int: return sum + line.item_ranks[rank], 0)
		by_rank.append("rank %s %.1f" % [ItemDef.RANK_NAMES[rank], float(total) / maxi(n, 1)])
	out.append("Items held at the end per run: %s" % ", ".join(by_rank))
	var by_node: Array[String] = []
	for node: String in CampsDef.NODES:
		var shown: int = lines.reduce(func(sum: int, line: RunLine) -> int: return sum + line.nodes_shown.get(node, 0), 0)
		var taken: int = lines.reduce(func(sum: int, line: RunLine) -> int: return sum + line.nodes_taken.get(node, 0), 0)
		by_node.append("%s shown %.1f, taken %.1f" % [run.camps.nodes[node].name, float(shown) / maxi(n, 1), float(taken) / maxi(n, 1)])
	out.append("Nodes per run: %s" % ", ".join(by_node))
	var rift_fights: int = lines.reduce(func(sum: int, line: RunLine) -> int: return sum + line.rift_fights, 0)
	var rift_wins: int = lines.reduce(func(sum: int, line: RunLine) -> int: return sum + line.rift_wins, 0)
	out.append("Rift Tear fights: %d of %d won (%d%%)" % [rift_wins, rift_fights, _pct(rift_wins, rift_fights)])
	var by_scene: Array[String] = []
	for scene: EventDef.Scene in run.events.scenes:
		var taken: int = lines.reduce(func(sum: int, line: RunLine) -> int: return sum + line.scenes.get(scene.id, 0), 0)
		by_scene.append("%s %d" % [scene.name, taken])
	out.append("Event scenes taken: %s" % ", ".join(by_scene))
	out.append("")
	out.append("Encounters (fights won of fought):")
	for encounter_id: String in content.encounter_ids:
		var fought: int = 0
		var wins: int = 0
		for line: RunLine in lines:
			for fight: Array in line.fights:
				if fight[0] == encounter_id:
					fought += 1
					wins += 1 if fight[1] else 0
		if fought > 0:
			out.append("  %-22s %3d of %3d (%d%%)" % [content.encounters[encounter_id].name, wins, fought, _pct(wins, fought)])
	out.append("")
	out.append("Growing upgrades (runs that took it: fights held, steps by the run's end, and what a fight counts):")
	for upgrade_id: String in run.upgrade_ids:
		var upgrade: UpgradeDef = run.upgrades[upgrade_id]
		if upgrade.grows == null:
			continue
		var took: Array[RunLine] = lines.filter(func(line: RunLine) -> bool: return line.grown.has(upgrade_id))
		var steps: Array[int] = []
		var counted: int = 0
		var held: int = 0
		for line: RunLine in took:
			steps.append(upgrade.grows.steps(line.grown[upgrade_id]))
			counted += line.grown[upgrade_id]
			held += line.grown_fights.get(upgrade_id, 0)
		out.append("  %-16s %3d runs, %.1f fights held, steps: median %s, most %d; %.1f a fight (a step is %d)" % [upgrade.name, took.size(),
			float(held) / maxi(took.size(), 1), _median(steps), steps.max() if not steps.is_empty() else 0, float(counted) / maxi(held, 1), upgrade.grows.per])
	var errors: int = lines.filter(func(line: RunLine) -> bool: return not line.errors.is_empty()).size()
	out.append("")
	out.append("Runs with errors: %d" % errors)
	return "\n".join(out)


## A deed's average per fight, to a tenth ("2.1s" for time rooted).
static func _per_fight(deed: DeedDef, gain: int, fights: int) -> String:
	var mean: float = float(gain) / maxi(fights, 1)
	return "%.1fs" % (mean / 1000.0) if deed.counts == DeedDef.Counts.ROOTED_MS else "%.1f" % mean


static func _pct(part: int, whole: int) -> int:
	@warning_ignore("integer_division")
	return part * 100 / whole if whole > 0 else 0


static func _median(values: Array[int]) -> String:
	if values.is_empty():
		return "-"
	var sorted: Array[int] = values.duplicate()
	sorted.sort()
	@warning_ignore("integer_division")
	return str(sorted[sorted.size() / 2])


static func _mean(lines: Array[RunLine], key: String) -> float:
	var total: int = 0
	for line: RunLine in lines:
		total += int(line.get(key))
	return float(total) / maxi(lines.size(), 1)
