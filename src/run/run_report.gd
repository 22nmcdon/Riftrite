class_name RunReport
extends RefCounted
## Summarizes many run-bot runs for tools/run_runner.gd. (Floats are fine
## here: this is a report, not game logic.)


static func lines(reports: Array[RunBot.Report], first_seed: int) -> PackedStringArray:
	var out := PackedStringArray()
	var count: int = reports.size()
	out.append("== %d runs, seeds %d-%d ==" % [count, first_seed, first_seed + count - 1])
	if count == 0:
		return out
	var cleared: int = 0
	var stuck: int = 0
	var losses: int = 0
	var ended_on: Array[int] = []
	var gold_totals: Array[int] = []
	var gold_counts: Array[int] = []
	var bought: Dictionary[String, int] = {}
	var found: Dictionary[String, int] = {}
	var reached_boss: int = 0
	var boss_fights: int = 0
	var skirmishes: int = 0
	var skirmish_wins: int = 0
	var legendary_runs: int = 0
	var legendary_clears: int = 0
	var legendaries: Dictionary[String, int] = {}
	for report: RunBot.Report in reports:
		skirmishes += report.skirmishes
		skirmish_wins += report.skirmish_wins
		if not report.legendaries.is_empty():
			legendary_runs += 1
			if report.ending == "act_end":
				legendary_clears += 1
		for held: String in report.legendaries:
			legendaries[held] = legendaries.get(held, 0) + 1
		if report.reached_boss:
			reached_boss += 1
			boss_fights += report.boss_fights
		if report.ending == "act_end":
			cleared += 1
		elif report.ending == "stuck" or not report.errors.is_empty():
			stuck += 1
			out.append("  ! seed %d: %s %s" % [report.seed_value, report.ending, report.errors])
		losses += report.losses
		while ended_on.size() < report.day:
			ended_on.append(0)
		if report.ending == "run_over":
			ended_on[report.day - 1] += 1
		for i: int in report.gold_by_day.size():
			while gold_totals.size() <= i:
				gold_totals.append(0)
				gold_counts.append(0)
			gold_totals[i] += report.gold_by_day[i]
			gold_counts[i] += 1
		for id: String in report.bought:
			bought[id] = bought.get(id, 0) + 1
		for id: String in report.discovered:
			found[id] = found.get(id, 0) + 1
	out.append("Act cleared: %d%% (%d of %d)" % [roundi(100.0 * cleared / count), cleared, count])
	out.append("Losses per run: %.2f" % (float(losses) / count))
	if reached_boss > 0:
		out.append("Boss: reached in %d runs, beaten in %d (%d%%), %.2f fights each" % [reached_boss, cleared, roundi(100.0 * cleared / reached_boss), float(boss_fights) / reached_boss])
	var endings: PackedStringArray = PackedStringArray()
	for i: int in ended_on.size():
		if ended_on[i] > 0:
			endings.append("day %d: %d" % [i + 1, ended_on[i]])
	out.append("Runs ended on: %s" % (", ".join(endings) if not endings.is_empty() else "none"))
	var gold: PackedStringArray = PackedStringArray()
	for i: int in gold_totals.size():
		gold.append("d%d %.1f" % [i + 1, float(gold_totals[i]) / gold_counts[i]])
	out.append("Gold at the Caravan: %s" % ", ".join(gold))
	out.append("Most taken items and heroes: %s" % ", ".join(_top(bought, 8, count)))
	out.append("Synergies found: %s" % ", ".join(_top(found, 12, count)))
	if skirmishes > 0:
		out.append("Skirmishes: %.2f per run, %d%% won" % [float(skirmishes) / count, roundi(100.0 * skirmish_wins / skirmishes)])
	if legendary_runs > 0:
		out.append("Legendaries: held at the end of %d runs (%d%% of those cleared the act); by item:tier: %s" % [
			legendary_runs, roundi(100.0 * legendary_clears / legendary_runs), ", ".join(_counts(legendaries))])
	out.append_array(_deed_lines(reports))
	if stuck > 0:
		out.append("! %d run(s) got stuck or hit errors" % stuck)
	return out


## Deed levels and how even the team is (docs/plans/deeds.md, "How to
## measure it"): average levels, the spread between each run's highest and
## lowest hero, the clear rate by that spread, and the rank-up spread.
static func _deed_lines(reports: Array[RunBot.Report]) -> PackedStringArray:
	var out := PackedStringArray()
	var heroes: int = 0
	var calling: int = 0
	var spec: int = 0
	var spread_total: int = 0
	var rank_spread_total: int = 0
	var by_spread: Dictionary[int, Array] = {}
	for report: RunBot.Report in reports:
		if report.calling_levels.is_empty():
			continue
		var totals: Array[int] = []
		for i: int in report.calling_levels.size():
			heroes += 1
			calling += report.calling_levels[i]
			spec += report.spec_levels[i]
			totals.append(report.calling_levels[i] + report.spec_levels[i])
		var spread: int = totals.max() - totals.min()
		spread_total += spread
		rank_spread_total += report.ranks.max() - report.ranks.min()
		if not by_spread.has(spread):
			by_spread[spread] = [0, 0]
		by_spread[spread][0] += 1
		if report.ending == "act_end":
			by_spread[spread][1] += 1
	if heroes == 0:
		return out
	var runs: int = reports.size()
	out.append("Deed levels at the end, per hero: calling %.2f, specialization %.2f; spread (highest - lowest hero) %.2f; rank spread %.2f" % [
		float(calling) / heroes, float(spec) / heroes, float(spread_total) / runs, float(rank_spread_total) / runs])
	var spreads: Array = by_spread.keys()
	spreads.sort()
	var parts := PackedStringArray()
	for spread: int in spreads:
		parts.append("%d: %d runs, %d%% cleared" % [spread, by_spread[spread][0], roundi(100.0 * by_spread[spread][1] / by_spread[spread][0])])
	out.append("Clear rate by level spread: %s" % ", ".join(parts))
	return out


## Every id with its count, "id x N", highest first (ties by id).
static func _counts(counts: Dictionary[String, int]) -> PackedStringArray:
	var ids: Array = counts.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return counts[a] > counts[b] or (counts[a] == counts[b] and a < b))
	var out := PackedStringArray()
	for id: String in ids:
		out.append("%s x%d" % [id, counts[id]])
	return out


## The most common ids, "id (N%)", highest first (ties by id).
static func _top(counts: Dictionary[String, int], limit: int, runs: int) -> PackedStringArray:
	var ids: Array = counts.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return counts[a] > counts[b] or (counts[a] == counts[b] and a < b))
	var out := PackedStringArray()
	for i: int in mini(limit, ids.size()):
		out.append("%s %.1f/run" % [ids[i], float(counts[ids[i]]) / runs])
	return out
