extends GutTest
## The sim runner's paths and deeds reports (tools/path_report.gd;
## docs/plans/rebuild-phase4-paths.md, section 7): the variants, a small run,
## where a hero stands, and the summaries' bars.

const Report = preload("res://tools/sim_report.gd")
const PathReport = preload("res://tools/path_report.gd")

var _content: ContentDb


func before_all() -> void:
	_content = ContentDb.load_dir("res://data")


func _named() -> Dictionary[String, Dictionary]:
	var errors: Array[String] = []
	var named: Dictionary[String, Dictionary] = Report.read_formations(FileAccess.get_file_as_string("res://tools/sim_formations.json"), errors)
	return Report.for_team(_content, named, HeroTeam.DEFAULT)


func test_the_variants() -> void:
	var names: Array = PathReport.variants_for(_content).map(func(variant: PathReport.Variant) -> String: return PathReport.variant_name(_content, variant))
	assert_eq(names.size(), 19)
	assert_eq(names.slice(0, 3), ["all base", "Maren, Deadeye (vowed)", "Maren, Deadeye (transformed)"])


func test_a_small_run() -> void:
	var named: Dictionary[String, Dictionary] = _named()
	var report: PathReport.PathReport = PathReport.run_paths(_content, "the_pack", named, 0, 1)
	assert_eq([report.formations.size(), report.variants.size()], [4, 19])
	for variant: PathReport.Variant in report.variants:
		assert_eq(variant.fights, 4)
	var plain: Report.Report = Report.run_encounter(_content, "the_pack", named, 0, 1)
	assert_eq(report.base().formation_wins, plain.rows.map(func(row: Report.Row) -> int: return row.wins), "all base is the placement report's own fights")
	var guarded: Dictionary[String, Vector2i] = {}
	guarded.assign(named["guarded"])
	var errors: Array[String] = []
	var result: FightResult = CombatSim.run(Encounters.setup(_content, "the_pack", guarded, 1, errors, {}, {"brannoc": "ironbrand"} as Dictionary[String, String]), _content)
	var ironbrand: PathReport.Variant = report.variants[9]
	assert_eq(PathReport.variant_name(_content, ironbrand), "Brannoc, Ironbrand (vowed)")
	assert_eq(ironbrand.formation_wins[0], 0 if result.outcome == FightResult.Outcome.DEFEAT else 1, "a variant fights on its path")
	assert_gt(ironbrand.deeds.get("brannoc/ironbrand", 0), 0, "and counts its deeds")
	assert_gt(report.guard_ticks, 0, "Brannoc's surroundings are measured in the base fights")
	assert_true(report.behind[1] <= report.behind[3] and report.behind[3] <= report.any_side[3])
	var text: String = PathReport.paths_text(_content, report)
	assert_string_contains(text, "The Pack (the_pack), paths: 4 formations x 1 seeds. All base win")
	assert_string_contains(text, "Brannoc, Ironbrand (vowed)")
	text = PathReport.deeds_text(_content, report)
	assert_string_contains(text, "  Brannoc: Hearthwall / Ironbrand / Last Watch")
	assert_string_contains(text, "    Ironbrand transformed")


func test_a_transformed_trapper_places_her_snares() -> void:
	var errors: Array[String] = []
	var setup: FightSetup = Encounters.setup(_content, "sentinel_gate", Report.drawn_formations(_content, [], 1, 1)[0], 1, errors, {},
		{"maren": "trapper"} as Dictionary[String, String], ["maren"] as Array[String])
	var encounter: EncounterDef = _content.encounters["sentinel_gate"]
	PathReport._place_snares(setup, encounter)
	var maren: UnitSetup = setup.heroes[1]
	assert_eq(maren.snares.size(), 2)
	for hex: Vector2i in maren.snares:
		assert_false(encounter.rocks.has(hex), "never on a rock")
	assert_eq(setup.validate(_content), [] as Array[String])


func _variant(hero_id: String, path_id: String, stage: PathDef.Stage, formation_wins: Array[int], deeds: Dictionary[String, int] = {}) -> PathReport.Variant:
	var variant := PathReport.Variant.new()
	variant.hero_id = hero_id
	variant.path_id = path_id
	variant.stage = stage
	variant.formation_wins = formation_wins
	variant.wins = formation_wins.reduce(func(sum: int, wins: int) -> int: return sum + wins, 0)
	variant.fights = formation_wins.size()
	variant.deeds = deeds
	return variant


func test_where_a_hero_stands_in_the_formations_it_wins() -> void:
	var report := PathReport.PathReport.new()
	report.seeds = 1
	report.formations = [
		{"brannoc": Vector2i(3, 2), "maren": Vector2i(0, 0), "vell": Vector2i(4, 0)},
		{"brannoc": Vector2i(3, 0), "maren": Vector2i(7, 2), "vell": Vector2i(4, 1)},
		{"brannoc": Vector2i(1, 1), "maren": Vector2i(3, 1), "vell": Vector2i(5, 1)},
	]
	var variant: PathReport.Variant = _variant("maren", "deadeye", PathDef.Stage.VOWED, [1, 1, 0] as Array[int])
	var spot: Array[float] = PathReport.standing(report, variant, "maren", _content.tuning.make_grid())
	assert_eq(spot[3], 2.0, "two formations won")
	assert_almost_eq(spot[0], 1.0, 0.001, "rows 0 and 2")
	assert_almost_eq(spot[1], 3.5, 0.001, "both at an edge")
	assert_gt(spot[2], 2.0, "far from the others")
	var none: Array[float] = PathReport.standing(report, _variant("maren", "", PathDef.Stage.BASE, [0, 0, 0] as Array[int]), "maren", _content.tuning.make_grid())
	assert_eq(none[3], 0.0)
	assert_eq(PathReport._where(none), "wins from nowhere")


func test_the_summaries_check_the_bars() -> void:
	var reports: Array[PathReport.PathReport] = []
	var report := PathReport.PathReport.new()
	report.encounter = _content.encounters["witch_circle"]
	report.seeds = 1
	report.formations = [{"brannoc": Vector2i(3, 2), "maren": Vector2i(3, 0), "vell": Vector2i(4, 0)}]
	for variant: PathReport.Variant in PathReport.variants_for(_content):
		var won: Array[int] = [0]
		var deeds: Dictionary[String, int] = {"maren/deadeye": 100, "maren/volley": 10}
		if variant.path_id == "deadeye" and variant.stage == PathDef.Stage.TRANSFORMED:
			won = [1]
		if variant.path_id == "deadeye":
			deeds = {"maren/deadeye": 500}
		if variant.path_id == "volley":
			deeds = {"maren/volley": 50, "maren/deadeye": 100}
		var filled: PathReport.Variant = _variant(variant.hero_id, variant.path_id, variant.stage, won, deeds)
		report.variants.append(filled)
	reports.append(report)
	var text: String = PathReport.paths_summary(_content, reports)
	assert_string_contains(text, "  all base 0%")
	assert_string_contains(text, "%-38s %+4d  %-10s" % ["Maren, Deadeye (vowed)", 0, "ok"])
	assert_string_contains(text, "%-38s %+4d  %-10s" % ["Maren, Deadeye (transformed)", 100, "too strong"])
	text = PathReport.deeds_summary(_content, reports)
	assert_string_contains(text, "%-14s %-5s own vow %d vs best other %d" % ["Deadeye", "ok", 500, 100], "at least 4x base and the other vows")
	assert_string_contains(text, "%-14s %-5s own vow %d vs best other %d" % ["Volley", "ok", 50, 10])
	assert_string_contains(text, "%-14s %-5s own vow %d vs best other %d" % ["Trapper", "LOW", 0, 0], "a deed nothing fills")
	assert_string_contains(text, "Allies around Brannoc (base fights, 0 ticks with a target):")
