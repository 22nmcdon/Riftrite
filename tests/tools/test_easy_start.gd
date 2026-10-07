extends GutTest
## The Glass check (docs/plans/easy-start.md, Decisions 1, 2, and 11): the
## weakest team, three back-liners with no front line, wins every day-1
## fight at least GLASS_FLOOR of the time, on every vow set it can take,
## with the good bot placing. It's the day-1 fights' gate, so a change to a
## hero or an enemy can't quietly push day 1 back over the cliff, where
## tankless teams lose every fight.

const Placement = preload("res://tools/bots/placement.gd")
const SimReport = preload("res://tools/sim_report.gd")
const Report = preload("res://tools/run_report.gd")

## Stands in for test-teams.md's B1 Glass (Ilse, Ottilie, Lucan) until they're
## built: three back-liners, no melee.
const GLASS: Array[String] = ["maren", "vell", "aldous"]
const GLASS_FLOOR: int = 90
const FIGHT_SEED: int = 7001

var _content: ContentDb


func before_all() -> void:
	_content = ContentDb.load_dir("res://data")


## Act 1's fights whose only day is 1.
func _day_one() -> Array[String]:
	var found: Array[String] = []
	for encounter_id: String in _content.encounter_ids:
		var encounter: EncounterDef = _content.encounters[encounter_id]
		if encounter.act == 1 and encounter.days.size() == 1 and encounter.days[0] == 1:
			found.append(encounter_id)
	return found


## True if Glass, vowed to `vows` and placed by the good bot, wins.
func _wins(encounter_id: String, vows: Dictionary[String, String], named: Dictionary[String, Dictionary]) -> bool:
	var errors: Array[String] = []
	var start: Dictionary[String, Vector2i] = {}
	start.assign(HeroTeam.place(_content, GLASS, named["guarded"]))
	var setup: FightSetup = Encounters.setup(_content, encounter_id, start, FIGHT_SEED, errors, {}, vows)
	assert_eq(errors, [] as Array[String], encounter_id)
	var placed: Array[Dictionary] = Placement.best_formations(setup, _content.tuning.make_grid(), 1)
	assert_false(placed.is_empty(), "%s: the good bot places" % encounter_id)
	for unit: UnitSetup in setup.heroes:
		unit.col = placed[0][unit.id].x
		unit.row = placed[0][unit.id].y
	assert_eq(setup.validate(_content), [] as Array[String], encounter_id)
	return CombatSim.run(setup, _content).outcome != FightResult.Outcome.DEFEAT


func test_day_one_has_its_own_fights_and_no_flankers() -> void:
	var day_one: Array[String] = _day_one()
	assert_eq(day_one, ["warren_mouth", "smouldering_den"] as Array[String])
	for encounter_id: String in _content.encounter_ids:
		var encounter: EncounterDef = _content.encounters[encounter_id]
		if encounter.act != 1 or not encounter.days.has(1) or encounter.tier == "hunt":
			continue
		assert_true(day_one.has(encounter_id), "%s isn't a day-1 fight (Decision 9)" % encounter_id)
		assert_eq(encounter.tier, "easier", "%s: no harder fight on day 1 (Decision 10)" % encounter_id)
		for placed: EncounterDef.Placed in encounter.enemies:
			assert_ne(_content.enemies[placed.enemy].kit.archetype, "flanker", "%s: no flankers on day 1" % encounter_id)


func test_glass_wins_every_day_one_fight() -> void:
	var errors: Array[String] = []
	var named: Dictionary[String, Dictionary] = SimReport.read_formations(FileAccess.get_file_as_string("res://tools/sim_formations.json"), errors)
	var all_vows: Array[Dictionary] = Report._team_vows(_content, HeroTeam.ordered(_content, GLASS))
	for encounter_id: String in _day_one():
		var wins: int = 0
		for vows_any: Dictionary in all_vows:
			var vows: Dictionary[String, String] = {}
			vows.assign(vows_any)
			wins += 1 if _wins(encounter_id, vows, named) else 0
		var percent: int = wins * 100 / all_vows.size()
		assert_gte(percent, GLASS_FLOOR, "%s: Glass wins %d%% of its %d vow sets (Decision 2: at least %d%%)" % [encounter_id, percent, all_vows.size(), GLASS_FLOOR])
