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
	for report: RunBot.Report in reports:
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
	if stuck > 0:
		out.append("! %d run(s) got stuck or hit errors" % stuck)
	return out


## The most common ids, "id (N%)", highest first (ties by id).
static func _top(counts: Dictionary[String, int], limit: int, runs: int) -> PackedStringArray:
	var ids: Array = counts.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return counts[a] > counts[b] or (counts[a] == counts[b] and a < b))
	var out := PackedStringArray()
	for i: int in mini(limit, ids.size()):
		out.append("%s %.1f/run" % [ids[i], float(counts[ids[i]]) / runs])
	return out
