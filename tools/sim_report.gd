extends RefCounted
## The sim runner's work, apart from its command line so a test can run it
## (docs/plans/rebuild-phase2-heroes-enemies.md, section 7). Each encounter
## is fought from the named formations and from formations drawn from a
## seed, each over a number of fight seeds (which only change crits).
##   - A win is a victory or a tie (a tie counts as a guild victory).
##   - For each formation: its win rate, its median fight length, and per
##     hero how often they fell and their mean damage dealt and taken
##     (FightTally's, as the fight chart counts them).
##   - The gate ("placement matters"): the best formation's win rate is at
##     least GATE_POINTS above the worst's.
##   - Since the seeds only change crits, a formation mostly wins every fight
##     or none, so the report also counts the formations that win at least
##     half their fights: the gate passes when one loses, but a question
##     worth asking has many formations on each side.
##   - The tactics report (docs/plans/rebuild-phase3b-tactics.md, section 5):
##     the same formations and seeds with no tactics, then with each tactic
##     on each hero who can take it, one at a time. Per variant, its win rate
##     and how many formations it helps (wins more than with no tactics) or
##     hurts. Not a gate: it answers whether a tactic ever changes an outcome,
##     and whether one is right everywhere (tactics_summary).

## The gate, in percentage points (Decisions: 30 for now).
const GATE_POINTS: int = 30
## From Act 2 on (phase 8 part 3, rebuild-phase8-act2.md section 6), base
## heroes lose every fight, so the gate fights a transformed team instead
## (the Gallery's paths, tools/apex_teams.json), against enemies scaled down
## to stand for the team a run brings to that fight, with its upgrades,
## items, and relics: about a bare team x1.5 on the act's first day
## (enemies at OPENING_SCALE_BP), and x1.8 for fights that first come later
## (LATER_SCALE_BP), as the team grows through the act. The gate starts there
## and steps the enemies by SCALE_STEP_BP until the formations split (some
## win, some lose), since the act's fights are tuned to different
## strengths: placement is judged where the fight is in the balance. The
## placement data and check use the starting strength.
const LATER_ACT_VOWS: Dictionary[String, String] = {"brannoc": "hearthwall", "maren": "deadeye", "vell": "lanternbearer"}
const OPENING_SCALE_BP: int = 6700
const LATER_SCALE_BP: int = 5500
const SCALE_STEP_BP: int = 1500
const SCALE_STEPS: int = 6


## One formation's fights in one encounter.
class Row:
	var name: String
	var formation: Dictionary[String, Vector2i]
	var fights: int = 0
	var wins: int = 0
	## Every fight's length in ticks.
	var lengths: Array[int] = []
	## Per hero id: fights they fell in, and damage dealt and taken in all.
	var deaths: Dictionary[String, int] = {}
	var dealt: Dictionary[String, int] = {}
	var taken: Dictionary[String, int] = {}

	## Wins per 100 fights, rounded down.
	func win_percent() -> int:
		@warning_ignore("integer_division")
		return wins * 100 / maxi(fights, 1)

	func median_ticks() -> int:
		return Report.median(lengths)


## One encounter's fights from every formation.
class Report:
	var encounter: EncounterDef
	var seeds: int
	## From Act 2 on, the enemies' strength the gate was judged at
	## (run_encounter); 0 in Act 1.
	var scale_bp: int = 0
	## The named formations, then the drawn ones.
	var rows: Array[Row] = []
	var named: int = 0

	## The row with the most wins (ties: the earliest).
	func best() -> Row:
		var found: Row = rows[0]
		for row: Row in rows:
			if row.wins > found.wins:
				found = row
		return found

	## The row with the fewest wins (ties: the earliest).
	func worst() -> Row:
		var found: Row = rows[0]
		for row: Row in rows:
			if row.wins < found.wins:
				found = row
		return found

	func gap_points() -> int:
		return best().win_percent() - worst().win_percent()

	## A day-1 fight (its only day is 1) is exempt from the split
	## (docs/plans/easy-start.md, Decision 11): it's sized so even the
	## weakest team wins, and the Glass check (tests/tools/test_easy_start.gd)
	## is its gate.
	func exempt() -> bool:
		return encounter != null and encounter.days.size() == 1 and encounter.days[0] == 1

	func passes() -> bool:
		return exempt() or gap_points() >= GATE_POINTS

	## How many formations win at least half their fights.
	func winning() -> int:
		var count: int = 0
		for row: Row in rows:
			if row.wins * 2 >= row.fights:
				count += 1
		return count

	## Every fight's length in ticks, all formations together.
	func median_ticks() -> int:
		var all: Array[int] = []
		for row: Row in rows:
			all.append_array(row.lengths)
		return median(all)

	static func median(values: Array[int]) -> int:
		if values.is_empty():
			return 0
		var sorted: Array[int] = values.duplicate()
		sorted.sort()
		@warning_ignore("integer_division")
		return sorted[sorted.size() / 2]


## Reads tools/sim_formations.json into name -> formation by role (role ->
## hex: HeroTeam.ROLES), in the file's order. Errors go in `errors`. `for_team`
## puts a team in them.
static func read_formations(text: String, errors: Array[String]) -> Dictionary[String, Dictionary]:
	var formations: Dictionary[String, Dictionary] = {}
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("sim_formations.json: expected an object")
		return formations
	for key: Variant in (data as Dictionary).keys():
		var name: String = key
		if name.begins_with("_"):
			continue
		if typeof(data[key]) != TYPE_DICTIONARY:
			errors.append("sim_formations.json (%s): expected role -> [col, row]" % name)
			continue
		var formation: Dictionary[String, Vector2i] = {}
		for role: Variant in (data[key] as Dictionary).keys():
			var path: String = "sim_formations.json (%s).%s" % [name, role]
			if not HeroTeam.ROLES.has(str(role)):
				errors.append("%s: not a role (%s)" % [path, ", ".join(HeroTeam.ROLES)])
				continue
			var hex: Variant = data[key][role]
			if typeof(hex) != TYPE_ARRAY or (hex as Array).size() != 2:
				errors.append("%s: expected [col, row]" % path)
				continue
			formation[role] = Vector2i(DataReader.to_int(hex[0], path, errors), DataReader.to_int(hex[1], path, errors))
		formations[name] = formation
	return formations


## `named` (name -> role -> hex) with `team` cast in it (name -> hero id ->
## hex; HeroTeam.roles).
static func for_team(content: ContentDb, named: Dictionary[String, Dictionary], team: Array[String]) -> Dictionary[String, Dictionary]:
	var placed: Dictionary[String, Dictionary] = {}
	for name: String in named:
		placed[name] = HeroTeam.place(content, team, named[name])
	return placed


## `count` formations of `team` (the gate's three by default; phase 8 part
## 4), each on a distinct hex of the heroes' rows with no rock, drawn from
## `draw_seed`.
static func drawn_formations(content: ContentDb, rocks: Array[Vector2i], count: int, draw_seed: int, team: Array[String] = HeroTeam.DEFAULT) -> Array[Dictionary]:
	var grid: HexGrid = content.tuning.make_grid()
	var open: Array[Vector2i] = []
	for row: int in grid.zone_rows:
		for col: int in grid.width:
			if not rocks.has(Vector2i(col, row)):
				open.append(Vector2i(col, row))
	var rng := SimRng.new(draw_seed)
	var formations: Array[Dictionary] = []
	for i: int in count:
		var left: Array[Vector2i] = open.duplicate()
		var formation: Dictionary[String, Vector2i] = {}
		for hero_id: String in HeroTeam.ordered(content, team):
			formation[hero_id] = left.pop_at(rng.range_int(left.size()))
		formations.append(formation)
	return formations


## The named formations, then `drawn` drawn ones ("drawn #1", ...): their
## names in `names`, and the formations.
static func formations_for(content: ContentDb, encounter: EncounterDef, named: Dictionary[String, Dictionary], drawn: int, draw_seed: int, names: Array[String],
		team: Array[String] = HeroTeam.DEFAULT) -> Array[Dictionary]:
	var formations: Array[Dictionary] = []
	for name: String in named:
		names.append(name)
		formations.append(named[name] if team == HeroTeam.DEFAULT else recast(content, named[name], team))
	var i: int = 0
	# Never on a rock, or over the void (phase 8 part 3, 8c-6c).
	var closed: Array[Vector2i] = encounter.rocks.duplicate()
	closed.append_array(encounter.void_hexes)
	for formation: Dictionary in drawn_formations(content, closed, drawn, draw_seed, team):
		i += 1
		names.append("drawn #%d" % i)
		formations.append(formation)
	return formations


## A named formation (the old three's) recast for `team` by role.
static func recast(content: ContentDb, formation: Dictionary, team: Array[String]) -> Dictionary[String, Vector2i]:
	var by_role: Dictionary[String, Vector2i] = {}
	var old_roles: Dictionary[String, String] = HeroTeam.roles(content, HeroTeam.DEFAULT)
	for role: String in old_roles:
		by_role[role] = formation[old_roles[role]]
	return HeroTeam.place(content, team, by_role)


## Fights `encounter_id` from each named formation and `drawn` drawn ones,
## `seeds` fights each (seeds 1 to `seeds`).
static func run_encounter(content: ContentDb, encounter_id: String, named: Dictionary[String, Dictionary], drawn: int, seeds: int, draw_seed: int = 1) -> Report:
	var encounter: EncounterDef = content.encounters[encounter_id]
	if encounter.act <= 1:
		return _run_at(content, encounter_id, named, drawn, seeds, draw_seed, 0)
	# A later act: step the enemies' strength until the formations split
	# (see LATER_ACT_VOWS), keeping the last report if they never do.
	var scale_bp: int = gate_scale_bp(encounter)
	var report: Report = null
	var went: int = 0
	for step: int in SCALE_STEPS:
		report = _run_at(content, encounter_id, named, drawn, seeds, draw_seed, scale_bp)
		var way: int = 1 if report.winning() == report.rows.size() else (-1 if report.winning() == 0 else 0)
		if way == 0 or (went != 0 and way != went):
			break
		went = way
		scale_bp = maxi(scale_bp + way * SCALE_STEP_BP, SCALE_STEP_BP)
	return report


static func _run_at(content: ContentDb, encounter_id: String, named: Dictionary[String, Dictionary], drawn: int, seeds: int, draw_seed: int, scale_bp: int) -> Report:
	var report := Report.new()
	report.encounter = content.encounters[encounter_id]
	report.seeds = seeds
	report.scale_bp = scale_bp
	var names: Array[String] = []
	var formations: Array[Dictionary] = formations_for(content, report.encounter, named, drawn, draw_seed, names)
	report.named = named.size()
	for f: int in formations.size():
		var row := Row.new()
		row.name = names[f]
		row.formation.assign(formations[f])
		for fight_seed: int in range(1, seeds + 1):
			_fight(content, encounter_id, row, fight_seed, scale_bp)
		report.rows.append(row)
	return report


## The gate's fight: base heroes in Act 1, and from Act 2 on the later
## acts' team against enemies scaled down (see LATER_ACT_VOWS).
static func gate_scale_bp(encounter: EncounterDef) -> int:
	return OPENING_SCALE_BP if not encounter.days.is_empty() and encounter.days.min() <= 1 else LATER_SCALE_BP


## The gate's fight (see gate_scale_bp).
static func gate_setup(content: ContentDb, encounter_id: String, formation: Dictionary[String, Vector2i], fight_seed: int, errors: Array[String], scale_bp: int = 0) -> FightSetup:
	if content.encounters[encounter_id].act <= 1:
		return Encounters.setup(content, encounter_id, formation, fight_seed, errors)
	var transformed: Array[String] = []
	transformed.assign(LATER_ACT_VOWS.keys())
	var setup: FightSetup = Encounters.setup(content, encounter_id, formation, fight_seed, errors, {}, LATER_ACT_VOWS, transformed)
	if setup == null:
		return null
	scale_for_gate(content, encounter_id, setup, scale_bp)
	return setup


## Scales a later act's enemies (and summon kits) down by gate_scale_bp, in
## place; an Act 1 setup is left alone. The placement data and check use it
## too, so the good bot learns on fights that can go either way.
static func scale_for_gate(content: ContentDb, encounter_id: String, setup: FightSetup, scale_bp: int = 0) -> void:
	if content.encounters[encounter_id].act <= 1:
		return
	if scale_bp <= 0:
		scale_bp = gate_scale_bp(content.encounters[encounter_id])
	for enemy: UnitSetup in setup.enemies:
		enemy.def = Encounters.scaled(enemy.def, scale_bp)
	for i: int in setup.summon_kits.size():
		setup.summon_kits[i] = Encounters.scaled(setup.summon_kits[i], scale_bp)


static func _fight(content: ContentDb, encounter_id: String, row: Row, fight_seed: int, scale_bp: int = 0) -> void:
	var errors: Array[String] = []
	var setup: FightSetup = gate_setup(content, encounter_id, row.formation, fight_seed, errors, scale_bp)
	if setup == null:
		push_error("sim runner: %s" % ", ".join(errors))
		return
	var result: FightResult = CombatSim.run(setup, content)
	if not result.errors.is_empty():
		push_error("sim runner: %s from %s: %s" % [encounter_id, row.name, ", ".join(result.errors)])
		return
	row.fights += 1
	if result.outcome != FightResult.Outcome.DEFEAT:
		row.wins += 1
	row.lengths.append(result.end_tick)
	var tally: FightTally = FightTally.of_fight(setup, result.combat_log)
	for hero: UnitSetup in setup.heroes:
		row.dealt[hero.id] = row.dealt.get(hero.id, 0) + tally.bar(FightTally.Tab.DAMAGE, hero.id).total()
		row.taken[hero.id] = row.taken.get(hero.id, 0) + tally.bar(FightTally.Tab.TAKEN, hero.id).total()
	for entry: LogEntry in result.combat_log.entries:
		if entry.kind == LogEntry.Kind.DEATH and row.formation.has(entry.target):
			row.deaths[entry.target] = row.deaths.get(entry.target, 0) + 1


# --- tactics ----------------------------------------------------------------------

## One variant of the tactics report: a hero on a tactic ("" and "": none),
## over every formation.
class TacticRow:
	var hero_id: String = ""
	var tactic_id: String = ""
	var fights: int = 0
	var wins: int = 0
	## Wins per formation, in the report's formation order.
	var formation_wins: Array[int] = []

	func win_percent() -> int:
		@warning_ignore("integer_division")
		return wins * 100 / maxi(fights, 1)

	## Formations it wins more (helps) or fewer (hurts) fights in than `base`.
	func helps(base: TacticRow) -> int:
		return _count(base, 1)

	func hurts(base: TacticRow) -> int:
		return _count(base, -1)

	func _count(base: TacticRow, sign: int) -> int:
		var count: int = 0
		for f: int in formation_wins.size():
			if signi(formation_wins[f] - base.formation_wins[f]) == sign:
				count += 1
		return count


## One encounter's tactics report: rows[0] is no tactics.
class TacticReport:
	var encounter: EncounterDef
	var seeds: int
	var formations: int = 0
	var rows: Array[TacticRow] = []

	func base() -> TacticRow:
		return rows[0]


## Every variant: no tactics, then each tactic (tactics.json's order) on each
## of the gate's heroes who can follow it (heroes.json's order).
static func tactic_variants(content: ContentDb) -> Array[TacticRow]:
	var variants: Array[TacticRow] = [TacticRow.new()]
	for tactic_id: String in content.tactic_ids:
		for hero_id: String in HeroTeam.DEFAULT:
			if content.tactics[tactic_id].allows(hero_id) and Tactics.can_follow(content.tactics[tactic_id], content.heroes[hero_id].kit):
				var row := TacticRow.new()
				row.hero_id = hero_id
				row.tactic_id = tactic_id
				variants.append(row)
	return variants


## Fights `encounter_id` from the same formations as run_encounter, once per
## variant, `seeds` fights each.
static func run_tactics(content: ContentDb, encounter_id: String, named: Dictionary[String, Dictionary], drawn: int, seeds: int, draw_seed: int = 1) -> TacticReport:
	var report := TacticReport.new()
	report.encounter = content.encounters[encounter_id]
	report.seeds = seeds
	var names: Array[String] = []
	var formations: Array[Dictionary] = formations_for(content, report.encounter, named, drawn, draw_seed, names)
	report.formations = formations.size()
	for row: TacticRow in tactic_variants(content):
		var tactics: Dictionary[String, String] = {}
		if not row.hero_id.is_empty():
			tactics[row.hero_id] = row.tactic_id
		for formation: Dictionary in formations:
			var hexes: Dictionary[String, Vector2i] = {}
			hexes.assign(formation)
			var won: int = 0
			for fight_seed: int in range(1, seeds + 1):
				var errors: Array[String] = []
				var setup: FightSetup = Encounters.setup(content, encounter_id, hexes, fight_seed, errors, tactics)
				var result: FightResult = CombatSim.run(setup, content) if setup != null else null
				if result == null or not result.errors.is_empty():
					push_error("sim runner: %s with %s" % [encounter_id, tactics])
					continue
				row.fights += 1
				if result.outcome != FightResult.Outcome.DEFEAT:
					won += 1
			row.wins += won
			row.formation_wins.append(won)
		report.rows.append(row)
	return report


## "Maren on Hold your ground", or "no tactics".
static func variant_name(content: ContentDb, row: TacticRow) -> String:
	if row.hero_id.is_empty():
		return "no tactics"
	return "%s on %s" % [row.hero_id.capitalize(), content.tactics[row.tactic_id].name]


## The tactics report as text: a line per variant, against no tactics.
static func tactics_text(content: ContentDb, report: TacticReport) -> String:
	var lines: Array[String] = []
	var base: TacticRow = report.base()
	lines.append("%s (%s), tactics: %d formations x %d seeds. No tactics win %d%% (%d/%d)" % [report.encounter.name, report.encounter.id, report.formations, report.seeds,
		base.win_percent(), base.wins, base.fights])
	for row: TacticRow in report.rows.slice(1):
		lines.append("  %-30s %3d%%  %+4d   helps %2d, hurts %2d formations" % [variant_name(content, row), row.win_percent(), row.win_percent() - base.win_percent(),
			row.helps(base), row.hurts(base)])
	return "\n".join(lines)


## Across encounters, a line per variant (in how many encounters it helps
## on the whole, hurts, or changes nothing), then the plan's two questions:
## does every tactic change an outcome somewhere, and is any variant a help
## in every encounter?
static func tactics_summary(content: ContentDb, reports: Array[TacticReport]) -> String:
	var lines: Array[String] = ["Tactics across %d encounters (a variant helps in an encounter if it wins more there than no tactics):" % reports.size()]
	var variants: int = reports[0].rows.size() if not reports.is_empty() else 0
	var changed: Dictionary[String, bool] = {}
	var always_right: Array[String] = []
	for v: int in range(1, variants):
		var helped: int = 0
		var hurt: int = 0
		var flips: int = 0
		for report: TacticReport in reports:
			var row: TacticRow = report.rows[v]
			helped += 1 if row.wins > report.base().wins else 0
			hurt += 1 if row.wins < report.base().wins else 0
			flips += row.helps(report.base()) + row.hurts(report.base())
		var row: TacticRow = reports[0].rows[v]
		if flips > 0:
			changed[row.tactic_id] = true
		if helped == reports.size():
			always_right.append(variant_name(content, row))
		lines.append("  %-30s helps in %d, hurts in %d, no change in %d; changes %d formation outcomes" % [variant_name(content, row), helped, hurt,
			reports.size() - helped - hurt, flips])
	var unchanged: Array[String] = []
	for tactic_id: String in content.tactic_ids:
		if not changed.has(tactic_id):
			unchanged.append(content.tactics[tactic_id].name)
	lines.append("Every tactic changes an outcome: %s" % ("yes" if unchanged.is_empty() else "no (%s)" % ", ".join(unchanged)))
	lines.append("None is right everywhere: %s" % ("yes" if always_right.is_empty() else "no (%s)" % ", ".join(always_right)))
	return "\n".join(lines)


# --- text -------------------------------------------------------------------------

## The report as text: a line per named formation, the drawn ones in sum,
## the gate, and the best and worst formations' boards.
static func text(content: ContentDb, report: Report, boards: bool = true) -> String:
	var lines: Array[String] = []
	var encounter: EncounterDef = report.encounter
	lines.append("%s (%s): %s. %d seeds, %d named + %d drawn formations%s" % [encounter.name, encounter.id, encounter.tests, report.seeds, report.named, report.rows.size() - report.named,
		"" if encounter.act <= 1 else "; heroes transformed (%s), enemies x%.2f" % [", ".join(LATER_ACT_VOWS.values()), report.scale_bp / 10000.0]])
	var heroes: String = "/".join(HeroTeam.DEFAULT.map(func(hero_id: String) -> String: return hero_id.left(1)))
	lines.append("  %-10s %6s %8s   %-18s %-20s %s" % ["formation", "wins", "median", "falls (%s)" % heroes, "dealt (%s)" % heroes, "taken (%s)" % heroes])
	for i: int in report.named:
		lines.append(_row_line(content, report.rows[i]))
	var drawn: Array[Row] = report.rows.slice(report.named)
	if not drawn.is_empty():
		var percents: Array[int] = []
		for row: Row in drawn:
			percents.append(row.win_percent())
		percents.sort()
		lines.append("  drawn: worst %d%%, median %d%%, best %d%%" % [percents[0], Report.median(percents), percents[-1]])
	var best: Row = report.best()
	var worst: Row = report.worst()
	lines.append("  gate: %s. Best %s %d%%, worst %s %d%%: a %d-point gap (needs %d). %d of %d formations win. Median fight %s" % [
		("exempt (day 1)" if report.exempt() else "passes") if report.passes() else "FAILS", best.name, best.win_percent(), worst.name, worst.win_percent(), report.gap_points(), GATE_POINTS,
		report.winning(), report.rows.size(), seconds(report.median_ticks())])
	if boards:
		for pair: Array in [["best", best], ["worst", worst]]:
			lines.append("  %s (%s): %s" % [pair[0], (pair[1] as Row).name, formation_text((pair[1] as Row).formation)])
			lines.append(_board(content, encounter.id, (pair[1] as Row).formation, report.scale_bp))
	return "\n".join(lines)


static func _row_line(content: ContentDb, row: Row) -> String:
	var falls: Array[String] = []
	var dealt: Array[String] = []
	var taken: Array[String] = []
	for hero_id: String in HeroTeam.DEFAULT:
		falls.append(_share(row.deaths.get(hero_id, 0), row.fights))
		@warning_ignore("integer_division")
		dealt.append(str(row.dealt.get(hero_id, 0) / maxi(row.fights, 1)))
		@warning_ignore("integer_division")
		taken.append(str(row.taken.get(hero_id, 0) / maxi(row.fights, 1)))
	return "  %-10s %6s %8s   %-18s %-20s %s" % [row.name, "%d/%d" % [row.wins, row.fights], seconds(row.median_ticks()), " ".join(falls), " ".join(dealt), " ".join(taken)]


## A share like "0.4" (one decimal, rounded down).
static func _share(count: int, of: int) -> String:
	@warning_ignore("integer_division")
	var tenths: int = count * 10 / maxi(of, 1)
	@warning_ignore("integer_division")
	return "%d.%d" % [tenths / 10, tenths % 10]


## Ticks as seconds with one decimal ("27.5s").
static func seconds(ticks: int) -> String:
	var ms: int = ticks * FixedMath.MS_PER_TICK
	@warning_ignore("integer_division")
	return "%d.%ds" % [ms / 1000, (ms % 1000) / 100]


static func formation_text(formation: Dictionary[String, Vector2i]) -> String:
	var parts: Array[String] = []
	for hero_id: String in formation:
		parts.append("%s (%d, %d)" % [hero_id, formation[hero_id].x, formation[hero_id].y])
	return ", ".join(parts)


## The board at the start of the fight, a character per half hex: heroes
## (by their ids' first letters) at the top, row 0.
static func _board(content: ContentDb, encounter_id: String, formation: Dictionary[String, Vector2i], scale_bp: int = 0) -> String:
	var errors: Array[String] = []
	var sim := CombatSim.new(gate_setup(content, encounter_id, formation, 1, errors, scale_bp), content)
	var units: Array[ArenaPlane.Circle] = []
	for unit: UnitState in sim.units:
		units.append(unit.circle())
	return ArenaDebug.draw(sim.grid.bounds(), sim.safe, sim.rocks, units, [] as Array[Vector2i], 500).indent("    ")
