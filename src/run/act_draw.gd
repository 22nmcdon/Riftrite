class_name ActDraw
extends RefCounted
## Every day's fight options, drawn when the act starts
## (docs/plans/rebuild-phase5-run.md, section 2, Decision 5), from the run's
## seed alone, so the whole act is known from the start:
##   - a normal day: one easier and one harder fight allowed that day
##     (encounter `days`), neither of them one of the day before's if it can
##     be helped; with no harder fight for the day, two easier ones;
##   - an elite day: two elites; a boss day: the boss;
##   - a day with nothing of its kind yet (elites and the boss come in step
##     7) draws like a normal day, from any of the act's normal fights if none
##     lists that day.


static func draw(run: RunContent, run_seed: int) -> Array[Array]:
	var days: Array[Array] = []
	var previous: Array[String] = []
	for day: int in range(1, run.act.days.size() + 1):
		var rng: SimRng = RunRandom.stream(run_seed, [RunRandom.ACT_DRAW, run.act.act, day])
		var kind: String = run.act.days[day - 1]
		var picked: Array[String] = []
		if kind == "elite":
			picked = _pick(rng, run.encounters_for("elite", day), 2, previous)
		elif kind == "boss":
			picked = _pick(rng, run.encounters_for("boss", day), 1, previous)
		if picked.is_empty():
			picked = _pick(rng, run.encounters_for("easier", day), 1, previous)
			var harder: Array[String] = _pick(rng, run.encounters_for("harder", day), 1, previous)
			if harder.is_empty():
				var others: Array[String] = run.encounters_for("easier", day).filter(func(id: String) -> bool: return not picked.has(id))
				harder = _pick(rng, others, 1, previous)
			picked.append_array(harder)
		if picked.is_empty():
			picked = _pick(rng, run.normal_encounters(), 2, previous)
		days.append(picked)
		previous = picked
	return days


## Up to `count` of `pool`, drawn without repeats, avoiding `avoid` while
## anything else is left.
static func _pick(rng: SimRng, pool: Array[String], count: int, avoid: Array[String]) -> Array[String]:
	var fresh: Array[String] = pool.filter(func(id: String) -> bool: return not avoid.has(id))
	var left: Array[String] = fresh if fresh.size() >= count else pool.duplicate()
	var picked: Array[String] = []
	while picked.size() < count and not left.is_empty():
		picked.append(left.pop_at(rng.range_int(left.size())))
	return picked
