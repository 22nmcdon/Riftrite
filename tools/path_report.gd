extends RefCounted
## The sim runner's paths and deeds reports (docs/plans/rebuild-phase4-paths.md,
## section 7). Reports, not gates. Each encounter is fought from the same
## formations as the placement report (sim_report.gd), once with every hero
## on base, then with one hero on one path, vowed and then transformed (the
## others on base): the variants.
##   - The paths report (--paths): per variant, its win rate against base,
##     and where the hero stands in the formations it wins (at least half
##     their fights): how far forward (its row, 0 back to 2 front), how far
##     to the side (columns from the middle), and how near the other heroes
##     (hexes). Base's winning formations are the comparison: a path that
##     moves its hero wins from other spots. The summary checks Decision 3:
##     a vowed hero's team wins within VOWED_POINTS of base, and a
##     transformed hero's team TRANSFORMED_MIN to TRANSFORMED_MAX points more.
##   - The deeds report (--deeds): what a fight puts into each of a hero's
##     three deeds, per stage (base, each vow, each transformation), on
##     average. The summary checks the plan's bar: each vow puts at least
##     TASTE_TIMES as much into its own deed as base or the hero's other vows
##     do. It gives phase 5 the numbers to set thresholds from.
##   - Where allies stand around Brannoc (Guard, Decision 6), over the base
##     fights, on the ticks he has a target: how often an ally is within 1,
##     2, and 3 hexes of him behind (away from his target) and on any side.
##   - A transformed Trapper places her snares on SNARE_HEXES (the first
##     that aren't rocks), like Practice's first placement.
##   - Teams (phase 8 part 4): the first base is the old three's. A hero
##     outside them fights in their team with it in place of the one of its
##     role (Garrow for Brannoc), from the same formations by role, and its
##     paths are measured against that team's own base.

const Placement = preload("res://tools/sim_report.gd")

const VOWED_POINTS: int = 5
const TRANSFORMED_MIN: int = 15
const TRANSFORMED_MAX: int = 25
const TASTE_TIMES: int = 4
const SNARE_HEXES: Array[Vector2i] = [Vector2i(2, 3), Vector2i(5, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(1, 3), Vector2i(6, 3)]
const MIDDLE_COL: float = 3.5


## One variant: every hero on base (path_id ""), or one hero on one path.
class Variant:
	var hero_id: String = ""
	var path_id: String = ""
	var stage: PathDef.Stage = PathDef.Stage.BASE
	## The heroes fighting (phase 8 part 4), and the index of its team's
	## base among the report's variants.
	var team: Array[String] = HeroTeam.DEFAULT.duplicate()
	var base_index: int = 0
	var fights: int = 0
	var wins: int = 0
	## Wins per formation, in the report's formation order.
	var formation_wins: Array[int] = []
	## "hero/path" -> what the fights put into that deed, summed.
	var deeds: Dictionary[String, int] = {}

	func win_percent() -> int:
		@warning_ignore("integer_division")
		return wins * 100 / maxi(fights, 1)

	## What a fight put into `hero_id`'s deed for `path_id`, on average.
	func deed_mean(hero_id: String, path_id: String) -> int:
		@warning_ignore("integer_division")
		return deeds.get("%s/%s" % [hero_id, path_id], 0) / maxi(fights, 1)


## One encounter's variants.
class PathReport:
	var content: ContentDb
	var encounter: EncounterDef
	var seeds: int
	var formations: Array[Dictionary] = []
	var variants: Array[Variant] = []
	## Base fights' ticks with Brannoc fighting, and those with an ally
	## within 1, 2, and 3 hexes behind him / on any side (index = hexes).
	var guard_ticks: int = 0
	var behind: Array[int] = [0, 0, 0, 0]
	var any_side: Array[int] = [0, 0, 0, 0]

	func base() -> Variant:
		return variants[0]

	## The base of `variant`'s team.
	func base_of(variant: Variant) -> Variant:
		return variants[variant.base_index]


## Base, then each path (paths.json's order) vowed, then transformed; a
## hero outside the old three gets its own team's base first (see the top).
static func variants_for(content: ContentDb) -> Array[Variant]:
	var found: Array[Variant] = [Variant.new()]
	var bases: Dictionary[String, int] = {}
	for path_id: String in content.path_ids:
		var hero_id: String = content.paths[path_id].hero
		var team: Array[String] = team_for(content, hero_id)
		var base_index: int = 0
		if team != HeroTeam.DEFAULT:
			if not bases.has(hero_id):
				var base := Variant.new()
				base.team = team
				base.base_index = found.size()
				bases[hero_id] = found.size()
				found.append(base)
			base_index = bases[hero_id]
		for stage: PathDef.Stage in [PathDef.Stage.VOWED, PathDef.Stage.TRANSFORMED]:
			var variant := Variant.new()
			variant.hero_id = hero_id
			variant.path_id = path_id
			variant.stage = stage
			variant.team = team
			variant.base_index = base_index
			found.append(variant)
	return found


## The old three, with `hero_id` in place of the one of its role if it
## isn't among them.
static func team_for(content: ContentDb, hero_id: String) -> Array[String]:
	if HeroTeam.DEFAULT.has(hero_id):
		return HeroTeam.DEFAULT.duplicate()
	var probe: Array[String] = HeroTeam.DEFAULT.duplicate()
	var roles: Dictionary[String, String] = HeroTeam.roles(content, probe)
	# Its role is the one it takes in a team with the two it doesn't replace:
	# try it in each slot and keep the slot whose role it takes.
	for role: String in HeroTeam.ROLES:
		var team: Array[String] = HeroTeam.DEFAULT.duplicate()
		team[team.find(roles[role])] = hero_id
		if HeroTeam.roles(content, team).get(role, "") == hero_id:
			return HeroTeam.ordered(content, team)
	var fallback: Array[String] = HeroTeam.DEFAULT.duplicate()
	fallback[0] = hero_id
	return HeroTeam.ordered(content, fallback)


## A formation of the old three recast for `team` by role.
static func cast(content: ContentDb, formation: Dictionary, team: Array[String]) -> Dictionary[String, Vector2i]:
	var hexes: Dictionary[String, Vector2i] = {}
	if team == HeroTeam.DEFAULT:
		hexes.assign(formation)
		return hexes
	var by_role: Dictionary[String, Vector2i] = {}
	var old_roles: Dictionary[String, String] = HeroTeam.roles(content, HeroTeam.DEFAULT)
	for role: String in old_roles:
		by_role[role] = formation[old_roles[role]]
	return HeroTeam.place(content, team, by_role)


static func run_paths(content: ContentDb, encounter_id: String, named: Dictionary[String, Dictionary], drawn: int, seeds: int, draw_seed: int = 1) -> PathReport:
	var report := PathReport.new()
	report.content = content
	report.encounter = content.encounters[encounter_id]
	report.seeds = seeds
	var names: Array[String] = []
	report.formations = Placement.formations_for(content, report.encounter, named, drawn, draw_seed, names)
	for variant: Variant in variants_for(content):
		var first: bool = report.variants.is_empty()
		var vows: Dictionary[String, String] = {}
		var transformed: Array[String] = []
		if not variant.path_id.is_empty():
			vows[variant.hero_id] = variant.path_id
			if variant.stage == PathDef.Stage.TRANSFORMED:
				transformed.append(variant.hero_id)
		for formation: Dictionary in report.formations:
			var hexes: Dictionary[String, Vector2i] = cast(content, formation, variant.team)
			var won: int = 0
			for fight_seed: int in range(1, seeds + 1):
				var errors: Array[String] = []
				var setup: FightSetup = Encounters.setup(content, encounter_id, hexes, fight_seed, errors, {}, vows, transformed)
				if setup != null:
					_place_snares(setup, report.encounter)
				if setup == null or not setup.validate(content).is_empty():
					push_error("sim runner: %s with %s %s: %s" % [encounter_id, vows, transformed, ", ".join(errors if setup == null else setup.validate(content))])
					continue
				var sim := CombatSim.new(setup, content)
				while not sim.finished:
					sim.step()
					if first:
						_measure_guard(sim, report)
				variant.fights += 1
				if sim.outcome != FightResult.Outcome.DEFEAT:
					won += 1
				for deed: FightResult.Deed in sim.deed_amounts():
					var key: String = "%s/%s" % [deed.hero, deed.path]
					variant.deeds[key] = variant.deeds.get(key, 0) + deed.amount
			variant.wins += won
			variant.formation_wins.append(won)
		report.variants.append(variant)
	return report


static func _place_snares(setup: FightSetup, encounter: EncounterDef) -> void:
	for hero: UnitSetup in setup.heroes:
		for hex: Vector2i in SNARE_HEXES:
			if hero.snares.size() < hero.def.placed_snares and not encounter.rocks.has(hex):
				hero.snares.append(hex)


static func _measure_guard(sim: CombatSim, report: PathReport) -> void:
	var guard: UnitState = sim.unit_by_id("brannoc")
	if guard == null or not guard.alive or guard.target == null or not guard.target.alive:
		return
	report.guard_ticks += 1
	var ahead: Vector2i = guard.target.pos - guard.pos
	var nearest_behind: int = 1 << 30
	var nearest: int = 1 << 30
	for ally: UnitState in sim.heroes:
		if ally == guard or not ally.alive:
			continue
		var offset: Vector2i = ally.pos - guard.pos
		var distance: int = ArenaPlane.distance(guard.pos, ally.pos)
		nearest = mini(nearest, distance)
		if ArenaPlane.dot(offset, ahead) < 0:
			nearest_behind = mini(nearest_behind, distance)
	for hexes: int in [1, 2, 3]:
		report.behind[hexes] += 1 if nearest_behind <= hexes * HexGrid.HEX else 0
		report.any_side[hexes] += 1 if nearest <= hexes * HexGrid.HEX else 0


# --- where the hero stands -----------------------------------------------------------

## Where `hero_id` stands, on average, in the formations `variant` wins at
## least half its fights in: [forward, side, near, formations], or
## formations 0 if it wins none.
static func standing(report: PathReport, variant: Variant, hero_id: String, grid: HexGrid) -> Array[float]:
	var sums: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for f: int in report.formations.size():
		if variant.formation_wins[f] * 2 < report.seeds:
			continue
		var formation: Dictionary = cast(report.content, report.formations[f], variant.team)
		var hex: Vector2i = formation[hero_id]
		sums[0] += hex.y
		sums[1] += absf(hex.x - MIDDLE_COL)
		var near: float = 0.0
		for other: String in formation:
			if other != hero_id:
				var there: Vector2i = formation[other]
				near += ArenaPlane.distance(grid.center(hex.x, hex.y), grid.center(there.x, there.y)) / float(HexGrid.HEX)
		sums[2] += near / maxf(formation.size() - 1, 1)
		sums[3] += 1.0
	if sums[3] > 0.0:
		for i: int in 3:
			sums[i] /= sums[3]
	return sums


static func variant_name(content: ContentDb, variant: Variant) -> String:
	if variant.path_id.is_empty():
		return "all base" if variant.team == HeroTeam.DEFAULT else "all base, with %s" % " ".join(variant.team.filter(func(hero_id: String) -> bool:
			return not HeroTeam.DEFAULT.has(hero_id)).map(func(hero_id: String) -> String: return hero_id.capitalize()))
	return "%s, %s (%s)" % [variant.hero_id.capitalize(), content.paths[variant.path_id].name, PathDef.STAGE_NAMES[variant.stage]]


static func _where(spot: Array[float]) -> String:
	if spot[3] == 0.0:
		return "wins from nowhere"
	return "forward %.1f  side %.1f  near %.1f  (%d formations)" % [spot[0], spot[1], spot[2], int(spot[3])]


## The paths report for one encounter: a line per variant.
static func paths_text(content: ContentDb, report: PathReport) -> String:
	var grid: HexGrid = content.tuning.make_grid()
	var base: Variant = report.base()
	var lines: Array[String] = ["%s (%s), paths: %d formations x %d seeds. All base win %d%% (%d/%d)" % [report.encounter.name, report.encounter.id,
		report.formations.size(), report.seeds, base.win_percent(), base.wins, base.fights]]
	for variant: Variant in report.variants.slice(1):
		var own_base: Variant = report.base_of(variant)
		if variant.path_id.is_empty():
			lines.append("  %-38s %3d%%" % [variant_name(content, variant), variant.win_percent()])
			continue
		lines.append("  %-38s %3d%% %+4d   %s   (base: %s)" % [variant_name(content, variant), variant.win_percent(), variant.win_percent() - own_base.win_percent(),
			_where(standing(report, variant, variant.hero_id, grid)), _where(standing(report, own_base, variant.hero_id, grid))])
	return "\n".join(lines)


## Across encounters: each variant's win rate against base, Decision 3's
## bars, and where the hero stands in its winning formations against base.
static func paths_summary(content: ContentDb, reports: Array[PathReport]) -> String:
	var grid: HexGrid = content.tuning.make_grid()
	var lines: Array[String] = ["Paths across %d encounters (vowed within %d points of base; transformed %d to %d points above):" % [reports.size(), VOWED_POINTS,
		TRANSFORMED_MIN, TRANSFORMED_MAX]]
	var variants: int = reports[0].variants.size() if not reports.is_empty() else 0
	# Each team's base across encounters.
	var base_percents: Dictionary[int, int] = {}
	for v: int in variants:
		if not reports[0].variants[v].path_id.is_empty():
			continue
		var base_wins: int = 0
		var base_fights: int = 0
		for report: PathReport in reports:
			base_wins += report.variants[v].wins
			base_fights += report.variants[v].fights
		@warning_ignore("integer_division")
		base_percents[v] = base_wins * 100 / maxi(base_fights, 1)
		lines.append("  %s %d%%" % [variant_name(content, reports[0].variants[v]), base_percents[v]])
	for v: int in range(1, variants):
		if reports[0].variants[v].path_id.is_empty():
			continue
		var wins: int = 0
		var fights: int = 0
		var spot: Array[float] = [0.0, 0.0, 0.0, 0.0]
		var base_spot: Array[float] = [0.0, 0.0, 0.0, 0.0]
		for report: PathReport in reports:
			var variant: Variant = report.variants[v]
			wins += variant.wins
			fights += variant.fights
			_add_spot(spot, standing(report, variant, variant.hero_id, grid))
			_add_spot(base_spot, standing(report, report.base_of(variant), variant.hero_id, grid))
		var variant: Variant = reports[0].variants[v]
		@warning_ignore("integer_division")
		var gain: int = wins * 100 / maxi(fights, 1) - base_percents[variant.base_index]
		var verdict: String
		if variant.stage == PathDef.Stage.VOWED:
			verdict = "ok" if absi(gain) <= VOWED_POINTS else ("too strong" if gain > 0 else "too weak")
		else:
			verdict = "ok" if gain >= TRANSFORMED_MIN and gain <= TRANSFORMED_MAX else ("too strong" if gain > TRANSFORMED_MAX else "too weak")
		lines.append("  %-38s %+4d  %-10s  stands: %s  (base: %s)" % [variant_name(content, variant), gain, verdict, _where(_mean_spot(spot)), _where(_mean_spot(base_spot))])
	return "\n".join(lines)


static func _add_spot(total: Array[float], spot: Array[float]) -> void:
	for i: int in 3:
		total[i] += spot[i] * spot[3]
	total[3] += spot[3]


static func _mean_spot(total: Array[float]) -> Array[float]:
	var mean: Array[float] = total.duplicate()
	if mean[3] > 0.0:
		for i: int in 3:
			mean[i] /= mean[3]
	return mean


# --- deeds ---------------------------------------------------------------------------

## The variants that change `hero_id`: base, then its paths vowed and
## transformed.
static func _hero_variants(report: PathReport, hero_id: String) -> Array[Variant]:
	var found: Array[Variant] = []
	for variant: Variant in report.variants:
		if variant.hero_id == hero_id:
			if found.is_empty():
				found.append(report.base_of(variant))
			found.append(variant)
	return found


static func _stage_name(content: ContentDb, variant: Variant) -> String:
	return "base" if variant.path_id.is_empty() else "%s %s" % [content.paths[variant.path_id].name, PathDef.STAGE_NAMES[variant.stage]]


## The deeds report for one encounter: per hero, a line per stage with what
## a fight put into each of its three deeds.
static func deeds_text(content: ContentDb, report: PathReport) -> String:
	var lines: Array[String] = ["%s (%s), deeds per fight:" % [report.encounter.name, report.encounter.id]]
	for hero_id: String in HeroTeam.draftable(content):
		var paths: Array[PathDef] = content.heroes[hero_id].paths
		lines.append("  %s: %s" % [hero_id.capitalize(), " / ".join(paths.map(func(path: PathDef) -> String: return path.name))])
		for variant: Variant in _hero_variants(report, hero_id):
			var amounts: Array[String] = []
			for path: PathDef in paths:
				amounts.append("%8d" % variant.deed_mean(hero_id, path.id))
			lines.append("    %-26s %s" % [_stage_name(content, variant), " ".join(amounts)])
	return "\n".join(lines)


## Across encounters: each deed per fight at each stage of its hero, the
## taste bar, and where allies stood around Brannoc.
static func deeds_summary(content: ContentDb, reports: Array[PathReport]) -> String:
	var lines: Array[String] = ["Deeds across %d encounters, per fight (each vow at least %dx base and the hero's other vows in its own deed):" % [reports.size(), TASTE_TIMES]]
	for hero_id: String in HeroTeam.draftable(content):
		var paths: Array[PathDef] = content.heroes[hero_id].paths
		for path: PathDef in paths:
			# Stage name -> the deed's mean over every fight of that stage.
			var means: Dictionary[String, int] = {}
			var order: Array[String] = []
			for v: int in reports[0].variants.size():
				var variant: Variant = reports[0].variants[v]
				if not variant.path_id.is_empty() and variant.hero_id != hero_id:
					continue
				if variant.path_id.is_empty() and not variant.team.has(hero_id):
					continue
				var sum: int = 0
				var fights: int = 0
				for report: PathReport in reports:
					sum += report.variants[v].deeds.get("%s/%s" % [hero_id, path.id], 0)
					fights += report.variants[v].fights
				var stage: String = _stage_name(content, variant)
				@warning_ignore("integer_division")
				means[stage] = sum / maxi(fights, 1)
				order.append(stage)
			var own: int = means["%s vowed" % path.name]
			var rival: int = means["base"]
			for other: PathDef in paths:
				if other != path:
					rival = maxi(rival, means["%s vowed" % other.name])
			var parts: Array[String] = []
			for stage: String in order:
				parts.append("%s %d" % [stage, means[stage]])
			lines.append("  %-14s %-5s own vow %d vs best other %d   (%s)" % [path.name, "ok" if own > 0 and own >= TASTE_TIMES * rival else "LOW", own, rival, ", ".join(parts)])
	var ticks: int = 0
	var behind: Array[int] = [0, 0, 0, 0]
	var any_side: Array[int] = [0, 0, 0, 0]
	for report: PathReport in reports:
		ticks += report.guard_ticks
		for hexes: int in [1, 2, 3]:
			behind[hexes] += report.behind[hexes]
			any_side[hexes] += report.any_side[hexes]
	lines.append("Allies around Brannoc (base fights, %d ticks with a target):" % ticks)
	for hexes: int in [1, 2, 3]:
		@warning_ignore("integer_division")
		lines.append("  within %d hex%s: behind him %d%%, any side %d%%" % [hexes, "" if hexes == 1 else "es", behind[hexes] * 100 / maxi(ticks, 1), any_side[hexes] * 100 / maxi(ticks, 1)])
	return "\n".join(lines)
