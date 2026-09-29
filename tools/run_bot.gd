extends RefCounted
## The simple run bot (docs/plans/rebuild-phase5-run.md, section 12, Decision
## 14): plays whole runs through RunFlow, for tests and pacing, not for a win
## rate (the good bot is phase 6). It vows each hero to its first path unless
## told otherwise, leaves camp, takes today's first fight, places the sim
## runner's "guarded" formation, and takes a pick's first card.

const Report = preload("res://tools/sim_report.gd")
const FORMATIONS_FILE: String = "res://tools/sim_formations.json"
const FORMATION: String = "guarded"
## A run is at most 7 days of at most 2 attempts, a few actions each;
## anything past this is a bug.
const MAX_STEPS: int = 200


## The formation the bot places.
static func formation() -> Dictionary[String, Vector2i]:
	var errors: Array[String] = []
	var named: Dictionary[String, Dictionary] = Report.read_formations(FileAccess.get_file_as_string(FORMATIONS_FILE), errors)
	var hexes: Dictionary[String, Vector2i] = {}
	hexes.assign(named[FORMATION])
	return hexes


## Each hero's first path.
static func first_vows(content: ContentDb) -> Dictionary[String, String]:
	var vows: Dictionary[String, String] = {}
	for hero_id: String in content.hero_ids:
		vows[hero_id] = content.heroes[hero_id].paths[0].id
	return vows


## Plays a run from `run_seed` to its end. Errors (a refused action) go in
## `errors` and stop it.
static func play(run: RunContent, run_seed: int, errors: Array[String], vows: Dictionary[String, String] = {}) -> RunFlow:
	var flow: RunFlow = RunFlow.start(run, run_seed, vows if not vows.is_empty() else first_vows(run.content), errors)
	if flow == null:
		return null
	var hexes: Dictionary[String, Vector2i] = formation()
	for step: int in MAX_STEPS:
		if flow.state.phase == RunState.Phase.ENDED:
			return flow
		var refused: String = step_once(flow, hexes, errors)
		if not refused.is_empty():
			errors.append("day %d (%s): %s" % [flow.state.day, RunState.PHASE_NAMES[flow.state.phase], refused])
			return flow
	errors.append("the run didn't end in %d steps" % MAX_STEPS)
	return flow


## One action for wherever the day is. Returns why it was refused ("": done).
static func step_once(flow: RunFlow, hexes: Dictionary[String, Vector2i], errors: Array[String]) -> String:
	if not flow.state.pick.is_empty():
		return flow.take_pick(0)
	match flow.state.phase:
		RunState.Phase.CAMP:
			return flow.leave_camp()
		RunState.Phase.ROUTE:
			return flow.choose_fight(0)
		RunState.Phase.LOADOUT:
			var fight_errors: Array[String] = []
			if flow.fight(hexes, fight_errors) == null:
				return ", ".join(fight_errors)
			return ""
		RunState.Phase.AFTER:
			return flow.finish_day()
	return "nothing to do"
