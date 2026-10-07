extends RefCounted
## The sim runner's builds report (--builds; docs/plans/build-tuning.md,
## phase 8 part 4). A report, not a gate. Each entry in tools/build_teams.json
## names a path to judge, its type, and the build team it's meant for (each
## hero on a path, all transformed, with the build's relics). Every encounter
## is fought from the placement report's formations (sim_report.gd, recast
## for each team by role, and drawn for the team), seed by seed, as:
##   - floor: the path's hero transformed in the neutral team (the old three
##     with it in place of the one of its role, the others on base, no
##     relics), against that team all on base: the paths report's number;
##   - ceiling: the build team, all transformed with the relics, against the
##     same team with the path's hero on base;
##   - lift (an enabler, with "swap"): the build team against the same team
##     with the hero transformed on its "swap" path instead; "swap": "base"
##     (a hero with no self-sufficient path, rebuild-phase8-heroes.md
##     Decision 17) against the same team with it on base: the ceiling's
##     own lineups.
## Each number is the win-rate gain in points over every fight of the act.
## A build team with its relics wins nearly every Act 1 fight, which caps
## its gain, so the ceiling and lift lineups can fight stronger enemies
## (`strength_bp`: their HP and ATK, as the apexes report scales them).
## build-tuning.md's targets for each type are printed beside them.

const Placement = preload("res://tools/sim_report.gd")
const PathReport = preload("res://tools/path_report.gd")

const TEAMS_FILE: String = "res://tools/build_teams.json"
## A build's "swap" that measures its lift against its hero on base.
const BASE: String = "base"
## Each type's floor and ceiling targets [low, high] (build-tuning.md,
## section 2); an enabler's second pair is its lift.
const TARGETS: Dictionary[String, Array] = {
	"self-sufficient": [[25, 35], [35, 45]],
	"engine": [[5, 15], [45, 55]],
	"enabler": [[10, 20], [10, 20]],
	"long-game": [[0, 10], [0, 0]],
}


## One entry: the path judged, and its build team.
class Build:
	var name: String = ""
	var hero: String = ""
	var path: String = ""
	var type: String = ""
	## Hero id -> its path, for the whole build team.
	var team: Dictionary[String, String] = {}
	var relics: Array[String] = []
	## An enabler's comparison path for its lift ("": none).
	var swap: String = ""
	var note: String = ""


## A lineup's wins over the fights it fought.
class Tally:
	var wins: int = 0
	var fights: int = 0

	func percent() -> int:
		@warning_ignore("integer_division")
		return wins * 100 / maxi(fights, 1)


## One build's results: each lineup's tally.
class Result:
	var build: Build
	var strength_bp: int = FixedMath.BP_ONE
	var neutral_base := Tally.new()
	var neutral := Tally.new()
	var team_base := Tally.new()
	var team := Tally.new()
	var swapped := Tally.new()

	func floor_gain() -> int:
		return neutral.percent() - neutral_base.percent()

	func ceiling_gain() -> int:
		return team.percent() - team_base.percent()

	func lift() -> int:
		if build.swap == BASE:
			return ceiling_gain()
		return team.percent() - swapped.percent()


static func read_builds(content: ContentDb, run: RunContent, errors: Array[String]) -> Array[Build]:
	var found: Array[Build] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEAMS_FILE))
	if not parsed is Dictionary:
		errors.append("%s isn't a JSON object" % TEAMS_FILE)
		return found
	for entry: Dictionary in parsed.get("builds", []):
		var build := Build.new()
		build.name = entry["name"]
		build.path = entry["path"]
		build.type = entry["type"]
		build.swap = entry.get("swap", "")
		build.note = entry.get("note", "")
		build.team.assign(entry["team"])
		build.relics.assign(entry.get("relics", []))
		if not content.paths.has(build.path):
			errors.append("%s: no path %s" % [build.name, build.path])
			continue
		build.hero = content.paths[build.path].hero
		if build.team.get(build.hero, "") != build.path:
			errors.append("%s: its team doesn't put %s on %s" % [build.name, build.hero, build.path])
		if not TARGETS.has(build.type):
			errors.append("%s: no type %s" % [build.name, build.type])
		for hero_id: String in build.team:
			if not content.paths.has(build.team[hero_id]) or content.paths[build.team[hero_id]].hero != hero_id:
				errors.append("%s: %s isn't %s's path" % [build.name, build.team[hero_id], hero_id])
		for relic_id: String in build.relics:
			if not run.relics.has(relic_id):
				errors.append("%s: no relic %s" % [build.name, relic_id])
		if not build.swap.is_empty() and build.swap != BASE and (not content.paths.has(build.swap) or content.paths[build.swap].hero != build.hero):
			errors.append("%s: %s isn't %s's path" % [build.name, build.swap, build.hero])
		found.append(build)
	return found


## Fights each lineup of `build` against every encounter in `encounter_ids`.
static func run_build(content: ContentDb, run: RunContent, build: Build, encounter_ids: Array[String], named: Dictionary[String, Dictionary], drawn: int, seeds: int,
		strength_bp: int = FixedMath.BP_ONE) -> Result:
	var result := Result.new()
	result.build = build
	result.strength_bp = strength_bp
	var neutral_team: Array[String] = PathReport.team_for(content, build.hero)
	var build_team: Array[String] = []
	build_team.assign(build.team.keys())
	build_team = HeroTeam.ordered(content, build_team)
	var state := RunState.new()
	state.relics = build.relics.duplicate()
	var all: Array[String] = build_team.duplicate()
	var others: Array[String] = build_team.filter(func(hero_id: String) -> bool: return hero_id != build.hero)
	var swapped_vows: Dictionary[String, String] = build.team.duplicate()
	if not build.swap.is_empty() and build.swap != BASE:
		swapped_vows[build.hero] = build.swap
	for encounter_id: String in encounter_ids:
		var encounter: EncounterDef = content.encounters[encounter_id]
		var closed: Array[Vector2i] = encounter.rocks.duplicate()
		closed.append_array(encounter.void_hexes)
		var neutral_hexes: Array[Dictionary] = _formations(content, named, closed, drawn, neutral_team)
		var team_hexes: Array[Dictionary] = _formations(content, named, closed, drawn, build_team)
		_fight(content, run, encounter_id, neutral_hexes, seeds, {}, [], null, result.neutral_base)
		_fight(content, run, encounter_id, neutral_hexes, seeds, {build.hero: build.path} as Dictionary[String, String], [build.hero], null, result.neutral)
		_fight(content, run, encounter_id, team_hexes, seeds, build.team, others, state, result.team_base, strength_bp)
		_fight(content, run, encounter_id, team_hexes, seeds, build.team, all, state, result.team, strength_bp)
		if not build.swap.is_empty() and build.swap != BASE:
			_fight(content, run, encounter_id, team_hexes, seeds, swapped_vows, all, state, result.swapped, strength_bp)
	return result


## The named formations recast for `team` by role, then `drawn` drawn for it.
static func _formations(content: ContentDb, named: Dictionary[String, Dictionary], closed: Array[Vector2i], drawn: int, team: Array[String]) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for name: String in named:
		found.append(PathReport.cast(content, named[name], team))
	found.append_array(Placement.drawn_formations(content, closed, drawn, 1, team))
	return found


static func _fight(content: ContentDb, run: RunContent, encounter_id: String, formations: Array[Dictionary], seeds: int, vows: Dictionary[String, String], transformed: Array[String],
		state: RunState, tally: Tally, strength_bp: int = FixedMath.BP_ONE) -> void:
	for formation: Dictionary in formations:
		var hexes: Dictionary[String, Vector2i] = {}
		hexes.assign(formation)
		var extras: Dictionary[String, HeroExtras] = {}
		if state != null:
			for hero_id: String in hexes:
				var kit: UnitDef = content.heroes[hero_id].kit
				if transformed.has(hero_id):
					kit = content.paths[vows[hero_id]].kit(PathDef.Stage.TRANSFORMED, kit)
				extras[hero_id] = HeroExtras.make(run.relic_mods(state, kit), 0, content.tuning.wound_bp)
		for fight_seed: int in range(1, seeds + 1):
			var errors: Array[String] = []
			# A hero on base fights unvowed (no taste), as the paths report's base.
			var fight_vows: Dictionary[String, String] = {}
			for hero_id: String in vows:
				if transformed.has(hero_id) or state == null:
					fight_vows[hero_id] = vows[hero_id]
			var setup: FightSetup = Encounters.setup(content, encounter_id, hexes, fight_seed, errors, {}, fight_vows, transformed, extras)
			if setup == null:
				push_error("builds report: %s: %s" % [encounter_id, ", ".join(errors)])
				continue
			PathReport._place_snares(setup, content.encounters[encounter_id])
			if strength_bp != FixedMath.BP_ONE:
				for enemy: UnitSetup in setup.enemies:
					enemy.def = Encounters.scaled(enemy.def, strength_bp)
				for i: int in setup.summon_kits.size():
					setup.summon_kits[i] = Encounters.scaled(setup.summon_kits[i], strength_bp)
			if state != null:
				for start: Array in run.relic_starts(state):
					setup.relic_effects.append(start[1])
					setup.relic_sources.append(EffectSource.relic(start[0].id, start[0].name, EffectSource.Team.HEROES))
					setup.relic_scales.append(start[2])
				for relic_id: String in state.relics:
					if run.relics[relic_id].salt_circle:
						setup.salt_circles += 1
				setup.hero_rules = run.hero_rules(state)
			var problems: Array[String] = setup.validate(content)
			if not problems.is_empty():
				push_error("builds report: %s: %s" % [encounter_id, ", ".join(problems)])
				continue
			tally.fights += 1
			if CombatSim.run(setup, content).outcome != FightResult.Outcome.DEFEAT:
				tally.wins += 1


static func text(content: ContentDb, results: Array[Result]) -> String:
	var lines: Array[String] = ["Builds (build-tuning.md): win-rate gain from the transform, in points over every fight"]
	for result: Result in results:
		var build: Build = result.build
		var targets: Array = TARGETS[build.type]
		lines.append("  %s, %s (%s) in %s" % [content.heroes[build.hero].name, content.paths[build.path].name, build.type, build.name])
		lines.append("    floor   %+4d  (%d%% from %d%%)  target %+d to %+d  %s" % [result.floor_gain(), result.neutral.percent(), result.neutral_base.percent(),
			targets[0][0], targets[0][1], _verdict(result.floor_gain(), targets[0])])
		var ceiling_target: Array = targets[1]
		lines.append("    ceiling %+4d  (%d%% from %d%%%s; relics: %s)%s" % [result.ceiling_gain(), result.team.percent(), result.team_base.percent(),
			"" if result.strength_bp == FixedMath.BP_ONE else ", enemies x%.2f" % (result.strength_bp / 10000.0),
			", ".join(build.relics) if not build.relics.is_empty() else "none",
			"  target %+d to %+d  %s" % [ceiling_target[0], ceiling_target[1], _verdict(result.ceiling_gain(), ceiling_target)] if build.type != "enabler" else ""])
		if not build.swap.is_empty():
			var against: String = "against %s on base: %d%%" % [content.heroes[build.hero].name, result.team_base.percent()] if build.swap == BASE \
				else "against %s: %d%%" % [content.paths[build.swap].name, result.swapped.percent()]
			lines.append("    lift    %+4d  (%s)  target %+d to %+d  %s" % [result.lift(), against, targets[1][0], targets[1][1], _verdict(result.lift(), targets[1])])
		if not build.note.is_empty():
			lines.append("    (%s)" % build.note)
	return "\n".join(lines)


static func _verdict(gain: int, target: Array) -> String:
	if gain < int(target[0]):
		return "low"
	if gain > int(target[1]):
		return "high"
	return "ok"
