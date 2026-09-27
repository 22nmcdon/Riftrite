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
	var legendary_runs: int = 0
	var legendary_clears: int = 0
	var legendaries: Dictionary[String, int] = {}
	for report: RunBot.Report in reports:
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
	out.append("Gold at the start of each day: %s" % ", ".join(gold))
	out.append("Most taken items and heroes: %s" % ", ".join(_top(bought, 8, count)))
	out.append("Synergies found: %s" % ", ".join(_top(found, 12, count)))
	if legendary_runs > 0:
		out.append("Legendaries: held at the end of %d runs (%d%% of those cleared the act); by item:tier: %s" % [
			legendary_runs, roundi(100.0 * legendary_clears / legendary_runs), ", ".join(_counts(legendaries))])
	var infused: int = 0
	var resonant: int = 0
	var fused: int = 0
	for report: RunBot.Report in reports:
		infused += report.infused
		resonant += report.resonant
		fused += report.fused
	out.append("Equipped infusions at the end, per run: %.2f (%.2f Resonant, %.2f with two essences)" % [float(infused) / count, float(resonant) / count, float(fused) / count])
	out.append_array(_fight_lines(reports))
	out.append_array(_deed_lines(reports))
	if stuck > 0:
		out.append("! %d run(s) got stuck or hit errors" % stuck)
	return out


## Fights by kind (docs/plans/new-day.md, the pacing targets): how many,
## the share lost, and the average length, for normal fights (easier and
## harder), elites (easier and harder), and the boss; then the clear rate of
## runs that always took the harder fight against those that took the easier.
static func _fight_lines(reports: Array[RunBot.Report]) -> PackedStringArray:
	var out := PackedStringArray()
	var groups: Array[String] = ["normal, easier", "normal, harder", "elite, easier", "elite, harder", "boss"]
	var counts: Array[int] = [0, 0, 0, 0, 0]
	var lost: Array[int] = [0, 0, 0, 0, 0]
	var seconds: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
	var hard_runs: Array[int] = [0, 0]
	var easy_runs: Array[int] = [0, 0]
	# By day and by encounter: [fights, lost, seconds].
	var by_day: Dictionary[int, Array] = {}
	var by_encounter: Dictionary[String, Array] = {}
	for report: RunBot.Report in reports:
		var tally: Array[int] = hard_runs if report.took_hard else easy_runs
		tally[0] += 1
		if report.ending == "act_end":
			tally[1] += 1
		for fought: Array in report.fights:
			var group: int = 4
			if fought[0] != "boss":
				group = (0 if fought[0] == "normal" else 2) + (1 if fought[1] else 0)
			counts[group] += 1
			if not fought[2]:
				lost[group] += 1
			seconds[group] += fought[3]
			for pair: Array in [[by_day, fought[4]], [by_encounter, fought[5]]]:
				var table: Dictionary = pair[0]
				if not table.has(pair[1]):
					table[pair[1]] = [0, 0, 0.0]
				table[pair[1]][0] += 1
				table[pair[1]][1] += 0 if fought[2] else 1
				table[pair[1]][2] += fought[3]
	var parts := PackedStringArray()
	for i: int in groups.size():
		if counts[i] > 0:
			parts.append("%s: %d, %d%% lost, %.1fs" % [groups[i], counts[i], roundi(100.0 * lost[i] / counts[i]), seconds[i] / counts[i]])
	out.append("Fights: %s" % "; ".join(parts))
	for pair: Array in [["Lost by day", by_day], ["Lost by encounter", by_encounter]]:
		var table: Dictionary = pair[1]
		var keys: Array = table.keys()
		keys.sort()
		var cells := PackedStringArray()
		for key: Variant in keys:
			cells.append("%s %d%% (%.0fs)" % [str(key), roundi(100.0 * table[key][1] / table[key][0]), table[key][2] / table[key][0]])
		out.append("%s: %s" % [pair[0], ", ".join(cells)])
	if hard_runs[0] > 0 and easy_runs[0] > 0:
		out.append("Always the harder fight: %d%% cleared (%d runs); always the easier: %d%% (%d runs)" % [
			roundi(100.0 * hard_runs[1] / hard_runs[0]), hard_runs[0], roundi(100.0 * easy_runs[1] / easy_runs[0]), easy_runs[0]])
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
