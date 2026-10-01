extends RefCounted
## The run report (docs/plans/rebuild-phase5-run.md, section 12): the simple
## run bot plays many runs, and this measures pacing: runs won and where the
## rest end, when each hero first transforms (the design: the first around
## days 3-4, all three by the boss), picks per hero, shards earned and
## spent, wounds taken, relics found, the nodes shown and taken (phase 5c
## step 8), and how each encounter goes. A report,
## not a gate. tools/run_runner.gd prints it.
## Each run's vows cycle through every combination of paths (seed n takes
## combination n mod 27), so every path is measured.

const Bot = preload("res://tools/run_bot.gd")


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
	var layer_picks: Array[int] = [0, 0, 0]
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
	var errors: Array[String] = []
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


## Plays run `run_seed` to its end with the bot, measuring it (`look_ahead`:
## the bot tries the named formations and keeps the first that doesn't
## lose, as a player who places well would).
static func play(run: RunContent, run_seed: int, look_ahead: bool = true) -> RunLine:
	var line := RunLine.new()
	line.seed_value = run_seed
	var combos: Array[Dictionary] = vow_combinations(run.content)
	line.vows.assign(combos[run_seed % combos.size()])
	var flow: RunFlow = RunFlow.start(run, run_seed, line.vows, line.errors)
	if flow == null:
		return line
	var state: RunState = flow.state
	var hexes: Dictionary[String, Vector2i] = Bot.formation()
	var shards: int = state.shards
	var wounds: int = 0
	var fought: int = 0
	var before: Dictionary[String, int] = {}
	for hero: RunState.Hero in state.heroes:
		before[hero.id] = hero.deeds[hero.path]
	for step: int in Bot.MAX_STEPS:
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
				line.nodes_shown[node] = line.nodes_shown.get(node, 0) + 1
		var refused: String = Bot.step_once(flow, hexes, line.errors, look_ahead)
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
			line.fights.append([last.encounter, last.outcome != FightResult.Outcome.DEFEAT])
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
	line.outcome = state.outcome
	line.day = state.day
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
	line.relics = state.relics.size()
	for id: String in state.relics:
		line.relic_tiers[run.relics[id].tier] += 1
	for id: String in state.item_ranks:
		line.item_ranks[state.item_ranks[id] - 1] += 1
	for hero: RunState.Hero in state.heroes:
		for upgrade_id: String in hero.growth:
			line.grown[upgrade_id] = hero.growth[upgrade_id]
	return line


static func play_many(run: RunContent, seeds: Array[int], look_ahead: bool = true) -> Array[RunLine]:
	var lines: Array[RunLine] = []
	for run_seed: int in seeds:
		lines.append(play(run, run_seed, look_ahead))
	return lines


## The report's text.
static func summary(run: RunContent, lines: Array[RunLine]) -> String:
	var content: ContentDb = run.content
	var out: PackedStringArray = PackedStringArray()
	var n: int = lines.size()
	var won: int = lines.filter(func(line: RunLine) -> bool: return line.outcome == RunState.Outcome.WON).size()
	out.append("Runs: %d (the simple bot, trying the four named formations each fight), won %d (%d%%)" % [n, won, _pct(won, n)])
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
				by_boss += 1 if day > 0 else 0
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
