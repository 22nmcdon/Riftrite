class_name RiftLearns
extends RefCounted
## The rift learns (phase 8 part 3, docs/plans/rebuild-phase8-act3.md
## section 5; enemy-growth.md section 5; its data RiftLearnsDef). A run
## piece: it reads fights after they're fought and changes no fight but the
## boss's, through the specializations and upgrades it picks.
##
##   - summary: what one fight counts toward each measure, read from its log
##     and the formation (RunFlow.record keeps it on the fight's Fought).
##   - habits: the run's habits from its last `fights` fights, scored against
##     each habit's per_fight; the top one that can be answered is always
##     answered, the second only at second_at_pct or more.
##   - picks: on a boss day of an act with rift_learns, up to half of the
##     boss's adds (every enemy of the fight but the first, the boss), rounded
##     down, each carry one answer, the habits taking turns: an upgrade any
##     add it changes can carry, or a specialization only its enemy has (a
##     turn leaves the adds a later habit's turn needs, while it has others). A
##     learned add carries that alone: it replaces what it drew (the swap of
##     enemy-growth.md). Drawn on the LEARN stream, fresh on each attempt.


## What a fight counts toward each measure (RiftLearnsDef.MEASURES), only
## those above 0.
static func summary(run: RunContent, state: RunState, formation: Dictionary[String, Vector2i], result: FightResult) -> Dictionary[String, int]:
	var counts: Dictionary[String, int] = {}
	var heroes: Dictionary[String, String] = {}
	for hero: RunState.Hero in state.heroes:
		var kit: UnitDef = run.hero_kit(hero)
		heroes[hero.id] = kit.signature.id if kit.signature != null else ""
	for entry: LogEntry in result.combat_log.entries:
		var by_heroes: bool = heroes.has(entry.source_unit) if entry.source_relic_side < 0 else entry.source_relic_side == EffectSource.Team.HEROES
		if not by_heroes:
			continue
		match entry.kind:
			LogEntry.Kind.STATUS_APPLIED:
				var status: StatusDef = run.content.statuses.get(entry.status)
				if status != null and RiftLearnsDef.KEYWORD_MEASURES.has(status.keyword):
					_add(counts, status.keyword, 1)
			LogEntry.Kind.HEAL, LogEntry.Kind.LIFESTEAL:
				_add(counts, "healing", entry.amount)
			LogEntry.Kind.SHIELD:
				_add(counts, "shields", entry.amount)
			LogEntry.Kind.FIRE:
				if not entry.source_ability.is_empty() and entry.source_ability == heroes.get(entry.source_unit, ""):
					_add(counts, "casts", 1)
	var grid: HexGrid = HexGrid.make()
	var hexes: Array[Vector2i] = []
	for hero: RunState.Hero in state.heroes:
		if formation.has(hero.id):
			hexes.append(formation[hero.id])
	for i: int in hexes.size():
		if hexes[i].y == 0:
			_add(counts, "back", 1)
		elif hexes[i].y >= grid.zone_rows - 1:
			_add(counts, "front", 1)
		for j: int in range(i + 1, hexes.size()):
			if grid.neighbors(hexes[i].x, hexes[i].y).has(hexes[j]):
				_add(counts, "bunched", 1)
	return counts


static func _add(counts: Dictionary[String, int], measure: String, amount: int) -> void:
	if amount > 0:
		counts[measure] = counts.get(measure, 0) + amount


## Each habit's score (basis points: 10000 is per_fight a fight) from the
## run's last fights, in the data's order: habit id -> score.
static func scores(run: RunContent, state: RunState) -> Dictionary[String, int]:
	var scored: Dictionary[String, int] = {}
	var read: Array[RunState.Fought] = state.fought.slice(maxi(state.fought.size() - run.learns.fights, 0))
	for habit: RiftLearnsDef.Habit in run.learns.habits:
		var total: int = 0
		for fought: RunState.Fought in read:
			total += fought.habits.get(habit.measure, 0)
		scored[habit.id] = total * 10000 / (habit.per_fight * maxi(read.size(), 1))
	return scored


## The adds of a boss fight: every enemy but the first.
static func adds(encounter: EncounterDef) -> Array[int]:
	var indices: Array[int] = []
	for i: int in range(1, encounter.enemies.size()):
		indices.append(i)
	return indices


## The habits the rift answers in `encounter`: the top-scoring one with an
## answer among its adds, and the next such if it scores second_at_pct or
## more; none if no habit scores.
static func habits(run: RunContent, state: RunState, encounter: EncounterDef) -> Array[RiftLearnsDef.Habit]:
	var scored: Dictionary[String, int] = scores(run, state)
	var ranked: Array[RiftLearnsDef.Habit] = run.learns.habits.filter(func(habit: RiftLearnsDef.Habit) -> bool:
		return scored[habit.id] > 0 and not _answers(run, habit, encounter, adds(encounter)).is_empty())
	# Highest first; the data's order breaks a tie (a stable sort).
	var order: Array[String] = []
	for habit: RiftLearnsDef.Habit in run.learns.habits:
		order.append(habit.id)
	ranked.sort_custom(func(a: RiftLearnsDef.Habit, b: RiftLearnsDef.Habit) -> bool:
		return scored[a.id] > scored[b.id] or (scored[a.id] == scored[b.id] and order.find(a.id) < order.find(b.id)))
	var chosen: Array[RiftLearnsDef.Habit] = []
	if not ranked.is_empty():
		chosen.append(ranked[0])
	if ranked.size() > 1 and scored[ranked[1].id] >= run.learns.second_at_bp:
		chosen.append(ranked[1])
	return chosen


## Each answer of `habit` an add among `free` can carry: [add index, kind
## ("upgrade" or "specialization"), id].
static func _answers(run: RunContent, habit: RiftLearnsDef.Habit, encounter: EncounterDef, free: Array[int]) -> Array[Array]:
	var found: Array[Array] = []
	for i: int in free:
		var enemy_id: String = encounter.enemies[i].enemy
		for upgrade_id: String in habit.upgrades:
			if run.content.enemy_upgrades[upgrade_id].changes(run.content.enemies[enemy_id].kit):
				found.append([i, "upgrade", upgrade_id])
		for spec_id: String in habit.specializations:
			if run.content.specializations[spec_id].enemy == enemy_id:
				found.append([i, "specialization", spec_id])
	return found


## What the rift learned for day fight option `index` (`encounter_id`) of
## today: {"enemy": add index, "habit": habit id, and "upgrade" or
## "specialization": its id} for each learned add; none but on a boss day of
## an act with rift_learns.
static func picks(run: RunContent, state: RunState, index: int, encounter_id: String) -> Array[Dictionary]:
	var learned: Array[Dictionary] = []
	var encounter: EncounterDef = run.content.encounters[encounter_id]
	if run.learns == null or not run.act_of(state).rift_learns or encounter.tier != "boss":
		return learned
	var answering: Array[RiftLearnsDef.Habit] = habits(run, state, encounter)
	if answering.is_empty():
		return learned
	var free: Array[int] = adds(encounter)
	var rng: SimRng = RunRandom.stream(state.seed_value, [RunRandom.LEARN, state.act, state.day, state.attempt, index])
	@warning_ignore("integer_division")
	var budget: int = free.size() / 2
	for n: int in budget:
		var habit: RiftLearnsDef.Habit = answering[n % answering.size()]
		var found: Array[Array] = _answers(run, habit, encounter, free)
		if found.is_empty():
			continue
		# Leave the adds another habit's later turn could answer on, while
		# this one has others.
		var needed: Array[int] = []
		for later: int in range(n + 1, budget):
			var other: RiftLearnsDef.Habit = answering[later % answering.size()]
			if other != habit:
				for answer: Array in _answers(run, other, encounter, free):
					needed.append(answer[0])
		var spare: Array[Array] = found.filter(func(answer: Array) -> bool: return not needed.has(answer[0]))
		if not spare.is_empty():
			found = spare
		var pick: Array = found[rng.range_int(found.size())]
		free.erase(pick[0])
		learned.append({"enemy": pick[0], "habit": habit.id, pick[1]: pick[2]})
	return learned
