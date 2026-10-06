extends GutTest
## The team (phase 8 part 4, docs/plans/rebuild-phase8-heroes.md, 8d-1):
## who can be drafted, why a team can't be, the roles that place any team,
## and the run's team (RunFlow.start and fight_setup).

const Bot = preload("res://tools/run_bot.gd")

var _run: RunContent
var _content: ContentDb


func before_all() -> void:
	_content = ContentDb.load_dir("res://data")
	_run = RunContent.load_dir("res://data", _content)


## The content with `hero_id`'s paths taken away (a hero still being built).
func _unbuilt(hero_id: String) -> ContentDb:
	var content: ContentDb = ContentDb.load_dir("res://data")
	content.heroes[hero_id].paths.clear()
	return content


func test_a_hero_is_drafted_once_its_paths_are_built() -> void:
	for hero_id: String in ["brannoc", "maren", "vell", "garrow", "tamsin"]:
		assert_true(HeroTeam.ready(_content, hero_id), hero_id)
	assert_false(HeroTeam.ready(_content, "nobody"))
	assert_eq(HeroTeam.draftable(_content), ["brannoc", "maren", "vell", "garrow", "tamsin"] as Array[String])
	var unbuilt: ContentDb = _unbuilt("garrow")
	assert_false(HeroTeam.ready(unbuilt, "garrow"), "not until his paths are built")
	assert_eq(HeroTeam.draftable(unbuilt), ["brannoc", "maren", "vell", "tamsin"] as Array[String])


func test_why_a_team_cant_be_drafted() -> void:
	assert_eq(HeroTeam.problem(_content, HeroTeam.DEFAULT), "")
	assert_eq(HeroTeam.problem(_content, ["brannoc", "maren"] as Array[String]), "a team is 3 heroes, not 2")
	assert_eq(HeroTeam.problem(_content, ["brannoc", "maren", "vell", "garrow"] as Array[String]), "a team is 3 heroes, not 4")
	assert_eq(HeroTeam.problem(_content, ["brannoc", "maren", "maren"] as Array[String]), "maren is on the team twice")
	assert_eq(HeroTeam.problem(_content, ["brannoc", "maren", "nobody"] as Array[String]), "unknown hero \"nobody\"")
	assert_eq(HeroTeam.problem(_content, ["brannoc", "maren", "garrow"] as Array[String]), "")
	var unbuilt: ContentDb = _unbuilt("garrow")
	assert_eq(HeroTeam.problem(unbuilt, ["brannoc", "maren", "garrow"] as Array[String]), "garrow can't be drafted yet: their paths aren't built")
	assert_eq(HeroTeam.problem(unbuilt, ["brannoc", "maren", "garrow"] as Array[String], false), "", "Practice fields such a hero at base")


func test_roles_place_any_team() -> void:
	assert_eq(HeroTeam.roles(_content, HeroTeam.DEFAULT), {"tank": "brannoc", "far": "maren", "mid": "vell"} as Dictionary[String, String])
	assert_eq(HeroTeam.roles(_content, ["vell", "garrow", "maren"] as Array[String]), {"tank": "garrow", "far": "maren", "mid": "vell"} as Dictionary[String, String],
		"the toughest is the tank, the longer reach the far one")
	assert_eq(HeroTeam.roles(_content, ["garrow", "brannoc", "vell"] as Array[String]), {"tank": "brannoc", "far": "vell", "mid": "garrow"} as Dictionary[String, String])
	assert_eq(HeroTeam.place(_content, HeroTeam.DEFAULT, HeroTeam.GUARDED), PracticeSession.DEFAULT_FORMATION, "the first team's guarded formation is the old default")
	assert_eq(HeroTeam.ordered(_content, ["vell", "garrow", "brannoc"]), ["brannoc", "vell", "garrow"] as Array[String], "heroes.json's order")


func test_the_run_fields_only_its_team() -> void:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, 7, {"vell": "lanternbearer", "brannoc": "hearthwall", "maren": "deadeye"} as Dictionary[String, String], errors)
	assert_eq(errors, [] as Array[String])
	assert_eq(flow.state.heroes.map(func(hero: RunState.Hero) -> String: return hero.id), ["brannoc", "maren", "vell"], "in heroes.json's order, whatever the vows' order")
	assert_null(RunFlow.start(_run, 7, {"garrow": "x", "brannoc": "hearthwall", "maren": "deadeye"} as Dictionary[String, String], errors))
	assert_eq(errors, ["garrow can't vow to \"x\""] as Array[String])
	flow.choose_fight(0)
	errors.clear()
	var formation: Dictionary[String, Vector2i] = Bot.formation()
	formation["garrow"] = Vector2i(5, 1)
	assert_null(flow.fight_setup(formation, errors))
	assert_eq(errors, ["garrow isn't on the team"] as Array[String])


func test_practice_fields_any_three() -> void:
	var session: PracticeSession = PracticeSession.make(_content)
	assert_eq(session.team, HeroTeam.DEFAULT)
	assert_eq(session.formation_for("the_pack"), PracticeSession.DEFAULT_FORMATION)
	assert_eq(session.set_team(["brannoc", "maren"] as Array[String]), "a team is 3 heroes, not 2")
	assert_eq(session.set_team(["vell", "garrow", "maren"] as Array[String]), "")
	assert_eq(session.team, ["maren", "vell", "garrow"] as Array[String])
	var placed: Dictionary[String, Vector2i] = session.formation_for("the_pack")
	assert_eq(placed.keys(), ["maren", "vell", "garrow"])
	assert_eq(placed, {"maren": Vector2i(3, 0), "vell": Vector2i(4, 0), "garrow": Vector2i(3, 2)} as Dictionary[String, Vector2i], "kept hexes, and Garrow on the tank's")
	assert_eq(session.errors("the_pack", placed), [] as Array[String])
	assert_eq(session.stage_of("garrow"), PathDef.Stage.BASE)
	placed["garrow"] = Vector2i(2, 1)
	session.remember(placed)
	session.set_team(HeroTeam.DEFAULT)
	assert_eq(session.formation_for("the_pack")["brannoc"], Vector2i(3, 2), "a hero back on the team stands where it last stood")
	session.set_team(["vell", "garrow", "maren"] as Array[String])
	assert_eq(session.formation_for("the_pack")["garrow"], Vector2i(2, 1))
