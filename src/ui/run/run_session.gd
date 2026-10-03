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
## Endless (phase 8 part 1): where the records are kept, and whether the run
## that just ended went deeper than any before.
var records_path: String = RunRecords.PATH
var new_best: bool = false
var _noted: bool = false


static func begin(run_content: RunContent, run_seed: int, hero_vows: Dictionary[String, String], errors_out: Array[String], path: String = RunSave.PATH, testing: bool = false) -> RunSession:
	var started: RunFlow = RunFlow.start(run_content, run_seed, hero_vows, errors_out, testing)
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
	apexes.clear()
	apexed.clear()
	tactics.clear()
	for hero: RunState.Hero in flow.state.heroes:
		vows[hero.id] = hero.path
		if hero.transformed:
			transformed.append(hero.id)
			if not hero.apex.is_empty():
				apexes[hero.id] = hero.apex
				if hero.apex_earned:
					apexed.append(hero.id)
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
	# An endless run's end goes in the records, once.
	if flow.state.phase == RunState.Phase.ENDED and flow.state.endless and not _noted:
		_noted = true
		new_best = RunRecords.note(flow.state, flow.floor_number(), records_path)


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
	var hero: RunState.Hero = flow.state.hero(hero_id)
	if not hero.transformed:
		return PathDef.Stage.VOWED
	if not hero.apex.is_empty():
		return PathDef.Stage.APEX if hero.apex_earned else PathDef.Stage.APEX_VOWED
	return PathDef.Stage.TRANSFORMED


func apex_of(hero_id: String) -> ApexDef:
	var hero: RunState.Hero = flow.state.hero(hero_id)
	return content.paths[hero.path].apex(hero.apex) if not hero.apex.is_empty() else null


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


## An apex choice from the hero panel or the day screen is the apex vow (or
## a switch, until the apex is earned; phase 8 part 2).
func set_apex(hero_id: String, apex_id: String, _stage: PathDef.Stage) -> void:
	act(flow.vow_apex.bind(hero_id, apex_id))


## The run's total in the hero's deed for `path_id`.
func last_deed(hero_id: String, path_id: String) -> int:
	return flow.state.hero(hero_id).deeds.get(path_id, 0)


## "1,240 / 2,000" toward the vowed path's threshold, and the share filled
## (the vowed apex's once the hero is vowed to one, until it's earned).
func deed_progress(hero_id: String) -> Array:
	var deed: DeedDef = deed_now(hero_id)
	var amount: int = flow.state.hero(hero_id).deeds.get(deed_key(hero_id), 0)
	return [amount, deed.threshold, clampf(float(amount) / maxf(deed.threshold, 1), 0.0, 1.0)]


## The deed the hero is filling now: its apex's while vowed to one and not
## earned, else its path's.
func deed_now(hero_id: String) -> DeedDef:
	var apex: ApexDef = apex_of(hero_id)
	return apex.deed if apex != null and not flow.state.hero(hero_id).apex_earned else content.paths[flow.state.hero(hero_id).path].deed


## Its key in the hero's deeds (an apex id or a path id).
func deed_key(hero_id: String) -> String:
	var hero: RunState.Hero = flow.state.hero(hero_id)
	return hero.apex if not hero.apex.is_empty() and not hero.apex_earned else hero.path


## The share of max HP the hero's wounds take now (for the greyed chunk).
func wound_share(hero_id: String) -> float:
	var each: int = content.tuning.wound_bp
	return float(flow.state.hero(hero_id).wounds * each) / FixedMath.BP_ONE
