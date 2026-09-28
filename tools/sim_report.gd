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

## The gate, in percentage points (Decisions: 30 for now).
const GATE_POINTS: int = 30


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

	func passes() -> bool:
		return gap_points() >= GATE_POINTS

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


## Reads tools/sim_formations.json into name -> formation (hero id ->
## hex), in the file's order. Errors go in `errors`.
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
			errors.append("sim_formations.json (%s): expected hero id -> [col, row]" % name)
			continue
		var formation: Dictionary[String, Vector2i] = {}
		for hero_id: Variant in (data[key] as Dictionary).keys():
			var path: String = "sim_formations.json (%s).%s" % [name, hero_id]
			var hex: Variant = data[key][hero_id]
			if typeof(hex) != TYPE_ARRAY or (hex as Array).size() != 2:
				errors.append("%s: expected [col, row]" % path)
				continue
			formation[hero_id] = Vector2i(DataReader.to_int(hex[0], path, errors), DataReader.to_int(hex[1], path, errors))
		formations[name] = formation
	return formations


## `count` formations of every hero in content, each on a distinct hex of the
## heroes' rows with no rock, drawn from `draw_seed`.
static func drawn_formations(content: ContentDb, rocks: Array[Vector2i], count: int, draw_seed: int) -> Array[Dictionary]:
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
		for hero_id: String in content.hero_ids:
			formation[hero_id] = left.pop_at(rng.range_int(left.size()))
		formations.append(formation)
	return formations


## Fights `encounter_id` from each named formation and `drawn` drawn ones,
## `seeds` fights each (seeds 1 to `seeds`).
static func run_encounter(content: ContentDb, encounter_id: String, named: Dictionary[String, Dictionary], drawn: int, seeds: int, draw_seed: int = 1) -> Report:
	var report := Report.new()
	report.encounter = content.encounters[encounter_id]
	report.seeds = seeds
	var names: Array[String] = []
	var formations: Array[Dictionary] = []
	for name: String in named:
		names.append(name)
		formations.append(named[name])
	report.named = names.size()
	var i: int = 0
	for formation: Dictionary in drawn_formations(content, report.encounter.rocks, drawn, draw_seed):
		i += 1
		names.append("drawn #%d" % i)
		formations.append(formation)
	for f: int in formations.size():
		var row := Row.new()
		row.name = names[f]
		row.formation.assign(formations[f])
		for fight_seed: int in range(1, seeds + 1):
			_fight(content, encounter_id, row, fight_seed)
		report.rows.append(row)
	return report


static func _fight(content: ContentDb, encounter_id: String, row: Row, fight_seed: int) -> void:
	var errors: Array[String] = []
	var setup: FightSetup = Encounters.setup(content, encounter_id, row.formation, fight_seed, errors)
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


# --- text -------------------------------------------------------------------------

## The report as text: a line per named formation, the drawn ones in sum,
## the gate, and the best and worst formations' boards.
static func text(content: ContentDb, report: Report, boards: bool = true) -> String:
	var lines: Array[String] = []
	var encounter: EncounterDef = report.encounter
	lines.append("%s (%s): %s. %d seeds, %d named + %d drawn formations" % [encounter.name, encounter.id, encounter.tests, report.seeds, report.named, report.rows.size() - report.named])
	var heroes: String = "/".join(content.hero_ids.map(func(hero_id: String) -> String: return hero_id.left(1)))
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
		"passes" if report.passes() else "FAILS", best.name, best.win_percent(), worst.name, worst.win_percent(), report.gap_points(), GATE_POINTS,
		report.winning(), report.rows.size(), seconds(report.median_ticks())])
	if boards:
		for pair: Array in [["best", best], ["worst", worst]]:
			lines.append("  %s (%s): %s" % [pair[0], (pair[1] as Row).name, formation_text((pair[1] as Row).formation)])
			lines.append(_board(content, encounter.id, (pair[1] as Row).formation))
	return "\n".join(lines)


static func _row_line(content: ContentDb, row: Row) -> String:
	var falls: Array[String] = []
	var dealt: Array[String] = []
	var taken: Array[String] = []
	for hero_id: String in content.hero_ids:
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
static func _board(content: ContentDb, encounter_id: String, formation: Dictionary[String, Vector2i]) -> String:
	var errors: Array[String] = []
	var sim := CombatSim.new(Encounters.setup(content, encounter_id, formation, 1, errors), content)
	var units: Array[ArenaPlane.Circle] = []
	for unit: UnitState in sim.units:
		units.append(unit.circle())
	return ArenaDebug.draw(sim.grid.bounds(), sim.safe, sim.rocks, units, [] as Array[Vector2i], 500).indent("    ")
