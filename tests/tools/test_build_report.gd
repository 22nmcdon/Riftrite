extends GutTest
## The sim runner's builds report (tools/build_report.gd; docs/plans/
## build-tuning.md): its teams file reads, and a small run gives each
## lineup's fights and the gains.

const Report = preload("res://tools/sim_report.gd")
const BuildReport = preload("res://tools/build_report.gd")

var _content: ContentDb
var _run: RunContent


func before_all() -> void:
	_content = ContentDb.load_dir("res://data")
	_run = RunContent.load_dir("res://data", _content)


func test_the_teams_file_reads() -> void:
	var errors: Array[String] = []
	var builds: Array[BuildReport.Build] = BuildReport.read_builds(_content, _run, errors)
	assert_eq(errors, [] as Array[String])
	assert_eq(builds.map(func(build: BuildReport.Build) -> String: return "%s %s" % [build.path, build.type]),
		["aegisfang engine", "chainwarden self-sufficient", "spitemail self-sufficient", "garrote engine", "headhunter engine", "nightblade self-sufficient"])


func test_a_small_run() -> void:
	var errors: Array[String] = []
	var named: Dictionary[String, Dictionary] = Report.read_formations(FileAccess.get_file_as_string("res://tools/sim_formations.json"), errors)
	named = Report.for_team(_content, named, HeroTeam.DEFAULT)
	var build: BuildReport.Build = BuildReport.read_builds(_content, _run, errors)[1]
	build.type = "enabler"
	build.swap = "spitemail"
	var result: BuildReport.Result = BuildReport.run_build(_content, _run, build, ["the_pack"] as Array[String], named, 0, 1)
	for tally: BuildReport.Tally in [result.neutral_base, result.neutral, result.team_base, result.team, result.swapped]:
		assert_eq(tally.fights, named.size(), "each lineup fights every formation")
	assert_eq(result.ceiling_gain(), result.team.percent() - result.team_base.percent())
	var text: String = BuildReport.text(_content, [result] as Array[BuildReport.Result])
	assert_string_contains(text, "Garrow of the Chains, Chainwarden (enabler) in Whirlpool", "an enabler's lift is against a path of its own hero")
	assert_string_contains(text, "lift")
