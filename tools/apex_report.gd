extends RefCounted
## The sim runner's apexes report (--apexes; docs/plans/rebuild-phase8-apexes.md,
## Decisions 9 and 10). A report, not a gate. Each team in tools/apex_teams.json
## (an apex per hero; good teams name their carry) is fought from the
## placement report's formations (sim_report.gd) against the Act 1 encounters
## with their enemies' HP and ATK scaled up step by step (SCALES, as endless
## floors scale them; once a formation loses, the steps above count as lost
## unfought), as:
##   - its transformed team: each hero transformed on its apex's path;
##   - its apex team: all three at their apexes;
##   - with --singles, each hero alone at its apex, the others transformed.
## For each: its win rate at each step, where it wins half (by straight-line
## reading between steps), and for the transformed team where it first wins
## no more than ZERO_PERCENT (about 0%). Decision 9's curve for a good team:
## at the transformed team's half point the apex team wins about 100%, and
## the apex team's half point is the transformed team's zero point. The carry's
## share of its team's damage in the apex fights (Decision 10).
## With --apex-deeds, what a fight puts into each apex's deed with its taste
## (the hero vowed to it, the others transformed) at each of DEED_SCALES: the
## numbers the stand-in thresholds were set from (Decision 8; since phase 8
## part 3's 8c-4c they're sized from runs: the run report's Apex vows). A run's team
## carries its upgrades, items, and relics, so at endless floor 3 (x1.52) it
## wins about as often as the bare team does at x1.0; both are shown.

const Placement = preload("res://tools/sim_report.gd")
const PathReport = preload("res://tools/path_report.gd")

const TEAMS_FILE: String = "res://tools/apex_teams.json"
const SCALES: Array[int] = [10000, 12500, 15000, 17500, 20000, 25000, 30000, 40000, 50000]
const ZERO_PERCENT: int = 5
## The bare team as strong as a run's at the first floors, and endless floor 3
## (1.15^3) as written.
const DEED_SCALES: Array[int] = [10000, 15000]


class Team:
	var name: String
	var kind: String
	var carry: String = ""
	## Hero id -> apex id, in heroes.json's order.
	var apexes: Dictionary[String, String] = {}


## One way to field a team: hero id -> path, the transformed heroes, the
## apex vows, and the heroes who've earned theirs.
class Lineup:
	var label: String
	var vows: Dictionary[String, String] = {}
	var transformed: Array[String] = []
	var apex_vows: Dictionary[String, String] = {}
	var apexed: Array[String] = []
	## Per scale step: fights and wins.
	var fights: Array[int] = []
	var wins: Array[int] = []
	## Heroes' damage, by hero, over every fight.
	var damage: Dictionary[String, int] = {}
	## Apex id -> what the fights put into its deed.
	var deeds: Dictionary[String, int] = {}

	func percent(step: int) -> float:
		return 100.0 * wins[step] / maxf(fights[step], 1.0)

	## The scale (as a multiplier) where it wins half, read between steps;
	## past the last step, -1.
	func half_point(scales: Array[int]) -> float:
		return crossing(scales, 50.0)

	func crossing(scales: Array[int], level: float) -> float:
		if percent(0) <= level:
			return scales[0] / 10000.0
		for i: int in range(1, scales.size()):
			if percent(i) <= level:
				var a: float = percent(i - 1)
				var b: float = percent(i)
				var t: float = (a - level) / maxf(a - b, 0.0001)
				return lerpf(scales[i - 1], scales[i], t) / 10000.0
		return -1.0

	## The first step it wins no more than ZERO_PERCENT, as a multiplier; -1:
	## none.
	func zero_point(scales: Array[int]) -> float:
		for i: int in scales.size():
			if percent(i) <= ZERO_PERCENT:
				return scales[i] / 10000.0
		return -1.0

	## Its win rate at multiplier `at`, read between steps.
	func percent_at(scales: Array[int], at: float) -> float:
		var bp: float = at * 10000.0
		if bp <= scales[0]:
			return percent(0)
		for i: int in range(1, scales.size()):
			if bp <= scales[i]:
				return lerpf(percent(i - 1), percent(i), (bp - scales[i - 1]) / float(scales[i] - scales[i - 1]))
		return percent(scales.size() - 1)

	func share(hero_id: String) -> int:
		var total: int = 0
		for amount: int in damage.values():
			total += amount
		@warning_ignore("integer_division")
		return damage.get(hero_id, 0) * 100 / maxi(total, 1)


static func read_teams(errors: Array[String]) -> Array[Team]:
	var found: Array[Team] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEAMS_FILE))
	if not parsed is Dictionary:
		errors.append("%s isn't a JSON object" % TEAMS_FILE)
		return found
	for entry: Dictionary in parsed.get("teams", []):
		var team := Team.new()
		team.name = entry["name"]
		team.kind = entry["kind"]
		team.carry = entry.get("carry", "")
		team.apexes.assign(entry["apexes"])
		found.append(team)
	return found


## The team transformed, all at apex, and (singles) each alone at apex.
static func variants_for(content: ContentDb, team: Team, singles: bool) -> Array[Lineup]:
	var found: Array[Lineup] = [_variant(content, team, "transformed", []), _variant(content, team, "apex", team.apexes.keys())]
	if singles:
		for hero_id: String in team.apexes:
			found.append(_variant(content, team, "%s alone" % content.apexes[team.apexes[hero_id]].name, [hero_id]))
	return found


static func _variant(content: ContentDb, team: Team, label: String, at_apex: Array) -> Lineup:
	var variant := Lineup.new()
	variant.label = label
	for hero_id: String in team.apexes:
		var apex: ApexDef = content.apexes[team.apexes[hero_id]]
		variant.vows[hero_id] = apex.path
		variant.transformed.append(hero_id)
		if at_apex.has(hero_id):
			variant.apex_vows[hero_id] = apex.id
			variant.apexed.append(hero_id)
	return variant


## Fights `variant` against every encounter, from its formations, at each
## of `scales`.
static func run_variant(content: ContentDb, variant: Lineup, encounter_ids: Array[String], named: Dictionary[String, Dictionary], drawn: int, scales: Array[int]) -> void:
	variant.fights.resize(scales.size())
	variant.wins.resize(scales.size())
	variant.fights.fill(0)
	variant.wins.fill(0)
	var team: Array[String] = []
	team.assign(variant.vows.keys())
	team = HeroTeam.ordered(content, team)
	for encounter_id: String in encounter_ids:
		var names: Array[String] = []
		for formation: Dictionary in Placement.formations_for(content, content.encounters[encounter_id], named, drawn, 1, names, team):
			# Stronger enemies don't turn a loss into a win, so once a
			# formation loses, the steps above count as lost unfought.
			var lost: bool = false
			for step: int in scales.size():
				if lost:
					variant.fights[step] += 1
					continue
				var sim: CombatSim = fight(content, variant, encounter_id, formation, scales[step])
				if sim == null:
					continue
				variant.fights[step] += 1
				if sim.outcome != FightResult.Outcome.DEFEAT:
					variant.wins[step] += 1
				else:
					lost = true
				_tally(content, variant, sim)


## One fight of `variant` at `scale_bp`, stepped to its end (null if it
## can't be set up).
static func fight(content: ContentDb, variant: Lineup, encounter_id: String, formation: Dictionary, scale_bp: int) -> CombatSim:
	var hexes: Dictionary[String, Vector2i] = {}
	hexes.assign(formation)
	var errors: Array[String] = []
	var setup: FightSetup = Encounters.setup(content, encounter_id, hexes, 1, errors, {}, variant.vows, variant.transformed, {}, variant.apex_vows, variant.apexed)
	if setup == null:
		push_error("apexes report: %s %s: %s" % [encounter_id, variant.label, ", ".join(errors)])
		return null
	PathReport._place_snares(setup, content.encounters[encounter_id])
	for enemy: UnitSetup in setup.enemies:
		enemy.def = Encounters.scaled(enemy.def, scale_bp)
	for i: int in setup.summon_kits.size():
		setup.summon_kits[i] = Encounters.scaled(setup.summon_kits[i], scale_bp)
	var problems: Array[String] = setup.validate(content)
	if not problems.is_empty():
		push_error("apexes report: %s %s: %s" % [encounter_id, variant.label, ", ".join(problems)])
		return null
	var sim := CombatSim.new(setup, content)
	while not sim.finished:
		sim.step()
	return sim


## With --by-encounter (phase 8 part 3, tuning an act's scales): each
## encounter's half point for each team, transformed (T) and at apex (A),
## and their medians across the teams: the scale an encounter would need
## for a team to win half its fights there is its scale_bp times that.
static func by_encounter_text(content: ContentDb, teams: Array[Team], encounter_ids: Array[String], named: Dictionary[String, Dictionary], drawn: int, scales: Array[int]) -> String:
	var lines: Array[String] = ["Half points by encounter (x the encounter's scale_bp; steps %s):" % ", ".join(scales.map(func(s: int) -> String: return _x(s / 10000.0)))]
	for encounter_id: String in encounter_ids:
		var transformed: Array[float] = []
		var apex: Array[float] = []
		var cells: Array[String] = []
		for team: Team in teams:
			var variants: Array[Lineup] = variants_for(content, team, false)
			var halves: Array[float] = []
			for variant: Lineup in variants:
				run_variant(content, variant, [encounter_id] as Array[String], named, drawn, scales)
				halves.append(_half_or_top(variant, scales))
			transformed.append(halves[0])
			apex.append(halves[1])
			cells.append("%s %s/%s" % [team.name, _x(halves[0]), _x(halves[1])])
		var encounter: EncounterDef = content.encounters[encounter_id]
		lines.append("  %-20s %-7s scale %5d  median T %s  A %s   (%s)" % [encounter_id, encounter.tier, encounter.scale_bp,
			_x(_median(transformed)), _x(_median(apex)), "; ".join(cells)])
	return "\n".join(lines)


## The half point, or past the last step the last step itself (a floor).
static func _half_or_top(variant: Lineup, scales: Array[int]) -> float:
	var half: float = variant.half_point(scales)
	return half if half > 0.0 else scales.back() / 10000.0


static func _median(values: Array[float]) -> float:
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	@warning_ignore("integer_division")
	return sorted[sorted.size() / 2] if not sorted.is_empty() else 0.0


static func _tally(content: ContentDb, variant: Lineup, sim: CombatSim) -> void:
	for entry: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.DAMAGE):
		if variant.vows.has(entry.source_unit):
			var hit: UnitState = sim.unit_by_id(entry.target)
			if hit != null and hit.side == EffectSource.Team.ENEMIES:
				variant.damage[entry.source_unit] = variant.damage.get(entry.source_unit, 0) + entry.amount
	for deed: FightResult.Deed in sim.deed_amounts():
		if content.apexes.has(deed.path):
			variant.deeds[deed.path] = variant.deeds.get(deed.path, 0) + deed.amount


static func team_text(content: ContentDb, team: Team, variants: Array[Lineup], scales: Array[int]) -> String:
	var heading: Array[String] = []
	for hero_id: String in team.apexes:
		var apex: ApexDef = content.apexes[team.apexes[hero_id]]
		heading.append("%s %s%s" % [content.heroes[hero_id].name, apex.name, " (carry)" if hero_id == team.carry else ""])
	var lines: Array[String] = ["%s (%s): %s" % [team.name, team.kind, ", ".join(heading)]]
	var steps: Array[String] = []
	for scale: int in scales:
		steps.append("x%-4s" % str(scale / 10000.0))
	lines.append("  %-26s %s   half  zero" % ["enemies", " ".join(steps)])
	for variant: Lineup in variants:
		var row: Array[String] = []
		for step: int in scales.size():
			row.append("%4d%%" % roundi(variant.percent(step)))
		var half: float = variant.half_point(scales)
		var zero: float = variant.zero_point(scales)
		lines.append("  %-26s %s   %s  %s" % [variant.label, " ".join(row), _x(half), _x(zero)])
	var transformed: Lineup = variants[0]
	var apex: Lineup = variants[1]
	var t_half: float = transformed.half_point(scales)
	var t_zero: float = transformed.zero_point(scales)
	lines.append("  curve: at the transformed half point (%s) the apex team wins %d%% (target about 100%%); its half point %s against the transformed zero point %s" % [
		_x(t_half), roundi(apex.percent_at(scales, t_half)) if t_half > 0 else -1, _x(apex.half_point(scales)), _x(t_zero)])
	if not team.carry.is_empty():
		var shares: Array[String] = []
		for hero_id: String in team.apexes:
			shares.append("%s %d%%" % [content.heroes[hero_id].name, apex.share(hero_id)])
		lines.append("  damage share at apex: %s" % ", ".join(shares))
	return "\n".join(lines)


static func _x(multiplier: float) -> String:
	if multiplier < 0:
		return "past"
	return "x%.2f" % multiplier


## What a fight puts into each apex's deed, its hero vowed to it (the taste)
## and the others transformed on their team's paths, at DEED_SCALE.
static func deeds_text(content: ContentDb, teams: Array[Team], encounter_ids: Array[String], named: Dictionary[String, Dictionary], drawn: int) -> String:
	var lines: Array[String] = ["Apex deeds with the taste, a fight's worth (and its wins) at %s (the thresholds are sized from runs: the run report's Apex vows):"
		% " and ".join(DEED_SCALES.map(func(scale: int) -> String: return "x" + str(scale / 10000.0)))]
	var done: Array[String] = []
	for team: Team in teams:
		for hero_id: String in team.apexes:
			var apex_id: String = team.apexes[hero_id]
			if done.has(apex_id):
				continue
			done.append(apex_id)
			var apex: ApexDef = content.apexes[apex_id]
			var cells: Array[String] = []
			var first_mean: float = 0.0
			for scale: int in DEED_SCALES:
				var variant: Lineup = _variant(content, team, "taste", [])
				variant.apex_vows[hero_id] = apex_id
				run_variant(content, variant, encounter_ids, named, drawn, [scale] as Array[int])
				var mean: float = variant.deeds.get(apex_id, 0) / maxf(variant.fights[0], 1.0)
				if cells.is_empty():
					first_mean = mean
				cells.append("%7.1f (%3.0f%%)" % [mean, variant.percent(0)])
			lines.append("  %-18s %-48s %s   threshold %5d (%.1f fights at x1)" % [apex.name, apex.deed.text, "  ".join(cells), apex.deed.threshold, apex.deed.threshold / maxf(first_mean, 0.1)])
	return "\n".join(lines)
