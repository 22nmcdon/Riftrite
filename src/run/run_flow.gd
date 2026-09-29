class_name RunFlow
extends RefCounted
## The run's rules (docs/plans/rebuild-phase5-run.md, sections 1 and 3): the
## only thing that changes a RunState, one action at a time. Each action
## checks it's legal now and returns "" if it happened, or why it didn't
## (the state is then untouched). The UI and the run bot both drive it.
## A day: camp, then the route (choose one of today's two fights), then the
## loadout and placement, then the fight (fight() runs it, CombatSim.run on
## fight_setup()'s setup), then after it. A win or a tie pays shards by the
## fight's tier and moves on to after the fight; a loss replays the day (camp
## again, the same options), and the act's losses_to_end-th ends the run.
## Deeds and wounds count from every fight, won or lost; winning the boss
## ends the run won.

var run: RunContent
var state: RunState


## A new run from `run_seed`, each hero vowed to one of its own paths
## (`vows`: hero id -> path id, every hero). Null with the reasons in
## `errors` if the vows aren't right.
static func start(run_content: RunContent, run_seed: int, vows: Dictionary[String, String], errors: Array[String]) -> RunFlow:
	var content: ContentDb = run_content.content
	for hero_id: String in content.hero_ids:
		if not vows.has(hero_id):
			errors.append("%s needs a vow" % hero_id)
		elif not content.paths.has(vows[hero_id]) or content.paths[vows[hero_id]].hero != hero_id:
			errors.append("%s can't vow to \"%s\"" % [hero_id, vows[hero_id]])
	for hero_id: String in vows:
		if not content.heroes.has(hero_id):
			errors.append("unknown hero \"%s\"" % hero_id)
	if not errors.is_empty():
		return null
	var state := RunState.new()
	state.seed_value = run_seed
	state.act = run_content.act.act
	state.shards = run_content.act.start_shards
	for hero_id: String in content.hero_ids:
		var hero := RunState.Hero.new()
		hero.id = hero_id
		hero.path = vows[hero_id]
		for path: PathDef in content.heroes[hero_id].paths:
			hero.deeds[path.id] = 0
		for i: int in run_content.act.slots:
			hero.slots.append("")
		state.heroes.append(hero)
	state.options = ActDraw.draw(run_content, run_seed)
	return resume(run_content, state)


## A flow over a state already made (a loaded save).
static func resume(run_content: RunContent, run_state: RunState) -> RunFlow:
	var flow := RunFlow.new()
	flow.run = run_content
	flow.state = run_state
	return flow


# --- the day ---------------------------------------------------------------------

## Leaves camp without taking an option (step 5 brings the options).
func leave_camp() -> String:
	if state.phase != RunState.Phase.CAMP:
		return _not_now("leave camp")
	state.phase = RunState.Phase.ROUTE
	return ""


## Chooses today's fight: `index` into today's options.
func choose_fight(index: int) -> String:
	if state.phase != RunState.Phase.ROUTE:
		return _not_now("choose a fight")
	var options: Array[String] = state.today()
	if index < 0 or index >= options.size():
		return "there's no fight %d today" % index
	state.chosen = options[index]
	state.phase = RunState.Phase.LOADOUT
	return ""


## The chosen fight from `formation` (hero id -> hex), with every hero as the
## run has it (path, stage, wounds), or null with the reasons in `errors`.
func fight_setup(formation: Dictionary[String, Vector2i], errors: Array[String]) -> FightSetup:
	if state.phase != RunState.Phase.LOADOUT:
		errors.append(_not_now("fight"))
		return null
	var content: ContentDb = run.content
	var vows: Dictionary[String, String] = {}
	var transformed: Array[String] = []
	var extras: Dictionary[String, HeroExtras] = {}
	for hero: RunState.Hero in state.heroes:
		if not formation.has(hero.id):
			continue
		vows[hero.id] = hero.path
		if hero.transformed:
			transformed.append(hero.id)
		extras[hero.id] = HeroExtras.make([], hero.wounds)
	var setup: FightSetup = Encounters.setup(content, state.chosen, formation, fight_seed(), errors, {}, vows, transformed, extras)
	if setup != null:
		errors.append_array(setup.validate(content))
		for hero: RunState.Hero in state.heroes:
			if not formation.has(hero.id):
				errors.append("%s isn't placed" % hero.id)
	return setup if errors.is_empty() else null


## The seed of today's fight (this attempt's).
func fight_seed() -> int:
	return RunRandom.stream(state.seed_value, [RunRandom.FIGHT, state.act, state.day, state.attempt]).range_int(1 << 30) + 1


## Fights the chosen fight from `formation` and records it. Returns the
## result, or null with the reasons in `errors`.
func fight(formation: Dictionary[String, Vector2i], errors: Array[String]) -> FightResult:
	var setup: FightSetup = fight_setup(formation, errors)
	if setup == null:
		return null
	var result: FightResult = CombatSim.run(setup, run.content)
	record(formation, result)
	return result


## Records a fought fight: the formation, deeds, wounds, then a win (shards
## by the fight's tier) or a loss (a replay, or the run's end). fight() calls
## it; tests call it with a result of their own.
func record(formation: Dictionary[String, Vector2i], result: FightResult) -> void:
	state.formation = formation.duplicate()
	var fought := RunState.Fought.new()
	fought.day = state.day
	fought.attempt = state.attempt
	fought.encounter = state.chosen
	fought.outcome = result.outcome
	@warning_ignore("integer_division")
	fought.seconds = result.end_tick / FixedMath.TICKS_PER_SECOND
	state.fought.append(fought)
	for hero: RunState.Hero in state.heroes:
		for path_id: String in hero.deeds:
			hero.deeds[path_id] += result.deed_amount(hero.id, path_id)
	for entry: LogEntry in result.combat_log.entries:
		if entry.kind == LogEntry.Kind.DEATH:
			var fallen: RunState.Hero = state.hero(entry.target)
			if fallen != null:
				fallen.wounds = mini(fallen.wounds + 1, run.content.tuning.max_wounds)
	if result.outcome == FightResult.Outcome.DEFEAT:
		state.losses += 1
		state.chosen = ""
		if state.losses >= run.act.losses_to_end:
			_end(RunState.Outcome.LOST)
		else:
			state.attempt += 1
			state.phase = RunState.Phase.CAMP
		return
	state.shards += run.act.pay[run.content.encounters[state.chosen].tier]
	if run.act.days[state.day - 1] == "boss":
		_end(RunState.Outcome.WON)
		return
	state.phase = RunState.Phase.AFTER


## Moves on to the next day's camp once nothing is waiting after the fight.
func finish_day() -> String:
	if state.phase != RunState.Phase.AFTER:
		return _not_now("move on to the next day")
	state.day += 1
	state.attempt = 0
	state.chosen = ""
	state.phase = RunState.Phase.CAMP
	return ""


func _end(outcome: RunState.Outcome) -> void:
	state.outcome = outcome
	state.phase = RunState.Phase.ENDED


func _not_now(what: String) -> String:
	return "can't %s now (the day is at %s)" % [what, RunState.PHASE_NAMES[state.phase]]
