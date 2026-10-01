class_name RunSession
extends PracticeSession
## A run on screen (docs/plans/rebuild-phase5-run.md, section 11): the run's
## RunFlow, seen through the same questions Practice's session answers, so
## ArenaScreen, HeroBar, and HeroPanel show the run's heroes (their paths,
## stages, upgrades, loadouts, relics, bonds, and wounds). Only RunFlow
## changes the run; every change is saved at once (RunSave).
##   - A fight's setup is RunFlow.fight_setup: the waiting fight (the day's
##     or a Hunt), with the run's seed for it. Practice's seed and tactic and
##     path choices don't apply: the run's loadout and vows decide.
##   - The formation is the run's last one (or Brannoc guarding the others).

var run: RunContent
var flow: RunFlow
## Where the run is saved (tests point it elsewhere).
var save_path: String = RunSave.PATH


static func begin(run_content: RunContent, run_seed: int, hero_vows: Dictionary[String, String], errors_out: Array[String], path: String = RunSave.PATH) -> RunSession:
	var started: RunFlow = RunFlow.start(run_content, run_seed, hero_vows, errors_out)
	if started == null:
		return null
	return over(run_content, started, path)


## A session over a flow (a new run, or a loaded save).
static func over(run_content: RunContent, run_flow: RunFlow, path: String = RunSave.PATH) -> RunSession:
	var session := RunSession.new()
	session.run = run_content
	session.flow = run_flow
	session.content = run_content.content
	session.save_path = path
	session.formation = run_flow.state.formation.duplicate() if not run_flow.state.formation.is_empty() else DEFAULT_FORMATION.duplicate()
	session.sync()
	return session


func state() -> RunState:
	return flow.state


## Keeps Practice's view of the heroes (vows, stages, tactics, snares) in
## step with the run's, after anything changes.
func sync() -> void:
	vows.clear()
	transformed.clear()
	tactics.clear()
	for hero: RunState.Hero in flow.state.heroes:
		vows[hero.id] = hero.path
		if hero.transformed:
			transformed.append(hero.id)
		var tactic: TacticDef = run.loadout_tactic(hero, flow.state)
		if tactic != null:
			tactics[hero.id] = tactic.id
		var can_place: int = kit_of(hero.id).placed_markers()
		if can_place == 0:
			snares.erase(hero.id)
		elif not snares.has(hero.id):
			snares[hero.id] = DEFAULT_SNARES.slice(0, can_place)


## Saves the run as it stands.
func save() -> void:
	sync()
	RunSave.save(flow.state, save_path)


## Does a RunFlow action (a Callable returning "" or why not), saves if it
## happened, and returns what it said.
func act(action: Callable) -> String:
	var said: String = action.call()
	if said.is_empty():
		save()
	return said


func setup(_encounter_id: String, hero_hexes: Dictionary[String, Vector2i], _fight_seed: int = 1) -> FightSetup:
	var found: Array[String] = []
	return flow.fight_setup(hero_hexes, found, snares)


## What's wrong with `hero_hexes` for the waiting fight (a hero not placed
## yet isn't counted: placement adds heroes one at a time).
func errors(_encounter_id: String, hero_hexes: Dictionary[String, Vector2i]) -> Array[String]:
	var found: Array[String] = []
	flow.fight_setup(hero_hexes, found, snares)
	return found.filter(func(message: String) -> bool: return not message.ends_with("isn't placed"))


func path_of(hero_id: String) -> PathDef:
	return content.paths[flow.state.hero(hero_id).path]


func stage_of(hero_id: String) -> PathDef.Stage:
	return PathDef.Stage.TRANSFORMED if flow.state.hero(hero_id).transformed else PathDef.Stage.VOWED


func kit_of(hero_id: String) -> UnitDef:
	return flow.kit_of(hero_id)


## The run's loadout decides tactics.
func set_tactic(_hero_id: String, _tactic_id: String) -> void:
	pass


## A path choice from the hero panel is a Switch vow (until the hero
## transforms); the run has no other way to change a path.
func set_path(hero_id: String, path_id: String, stage: PathDef.Stage) -> void:
	if stage == PathDef.Stage.VOWED:
		act(flow.switch_vow.bind(hero_id, path_id))


## The run's total in the hero's deed for `path_id`.
func last_deed(hero_id: String, path_id: String) -> int:
	return flow.state.hero(hero_id).deeds.get(path_id, 0)


## "1,240 / 2,000" toward the vowed path's threshold, and the share filled.
func deed_progress(hero_id: String) -> Array:
	var hero: RunState.Hero = flow.state.hero(hero_id)
	var path: PathDef = content.paths[hero.path]
	var amount: int = hero.deeds.get(hero.path, 0)
	var threshold: int = path.deed.threshold
	return [amount, threshold, clampf(float(amount) / maxf(threshold, 1), 0.0, 1.0)]


## The share of max HP the hero's wounds take now (for the greyed chunk).
func wound_share(hero_id: String) -> float:
	var each: int = content.tuning.wound_bp
	return float(flow.state.hero(hero_id).wounds * each) / FixedMath.BP_ONE
