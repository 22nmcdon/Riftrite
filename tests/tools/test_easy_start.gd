extends GutTest
## The Glass check (docs/plans/easy-start.md, Decisions 1, 2, and 11): the
## weakest team, three back-liners with no front line, wins every day-1
## fight at least GLASS_FLOOR of the time, on every vow set it can take,
## with the good bot placing. It's the day-1 fights' gate, so a change to a
## hero or an enemy can't quietly push day 1 back over the cliff, where
## tankless teams lose every fight. Day 2 (ES-2) is held to DAY_TWO_FLOOR,
## and to DAY_TWO_MARGIN_FLOOR with its enemies DAY_TWO_MARGIN_BP stronger,
## so it stays a step back from its cliff too. Day 3's own elites (ES-4,
## Decision 15) are held to the same.

const Placement = preload("res://tools/bots/placement.gd")
const SimReport = preload("res://tools/sim_report.gd")
const Report = preload("res://tools/run_report.gd")

## Stands in for test-teams.md's B1 Glass (Ilse, Ottilie, Lucan) until they're
## built: three back-liners, no melee.
const GLASS: Array[String] = ["maren", "vell", "aldous"]
const GLASS_FLOOR: int = 90
const DAY_TWO_FLOOR: int = 85
const DAY_TWO_MARGIN_BP: int = 11000
const DAY_TWO_MARGIN_FLOOR: int = 50
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


## Act 1's day fights whose first day is 2 (Hunts aside).
func _day_two() -> Array[String]:
	var found: Array[String] = []
	for encounter_id: String in _content.encounter_ids:
		var encounter: EncounterDef = _content.encounters[encounter_id]
		if encounter.act == 1 and encounter.tier != "hunt" and not encounter.days.is_empty() and encounter.days.min() == 2:
			found.append(encounter_id)
	return found


## Act 1's fights whose only day is 3: its own elites (Decision 15).
func _day_three() -> Array[String]:
	var found: Array[String] = []
	for encounter_id: String in _content.encounter_ids:
		var encounter: EncounterDef = _content.encounters[encounter_id]
		if encounter.act == 1 and encounter.days.size() == 1 and encounter.days[0] == 3:
			found.append(encounter_id)
	return found


## How often (percent) Glass wins `encounter_id` over its vow sets, its
## enemies `extra_bp` as strong.
func _glass_percent(encounter_id: String, named: Dictionary[String, Dictionary], extra_bp: int = 10000) -> int:
	var all_vows: Array[Dictionary] = Report._team_vows(_content, HeroTeam.ordered(_content, GLASS))
	var wins: int = 0
	for vows_any: Dictionary in all_vows:
		var vows: Dictionary[String, String] = {}
		vows.assign(vows_any)
		wins += 1 if _wins(encounter_id, vows, named, extra_bp) else 0
	return wins * 100 / all_vows.size()


## True if Glass, vowed to `vows` and placed by the good bot, wins.
func _wins(encounter_id: String, vows: Dictionary[String, String], named: Dictionary[String, Dictionary], extra_bp: int = 10000) -> bool:
	var errors: Array[String] = []
	var start: Dictionary[String, Vector2i] = {}
	start.assign(HeroTeam.place(_content, GLASS, named["guarded"]))
	var setup: FightSetup = Encounters.setup(_content, encounter_id, start, FIGHT_SEED, errors, {}, vows)
	assert_eq(errors, [] as Array[String], encounter_id)
	if extra_bp != 10000:
		for enemy: UnitSetup in setup.enemies:
			enemy.def = Encounters.scaled(enemy.def, extra_bp)
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
	for encounter_id: String in _day_one():
		var percent: int = _glass_percent(encounter_id, named)
		assert_gte(percent, GLASS_FLOOR, "%s: Glass wins %d%% of its vow sets (Decision 2: at least %d%%)" % [encounter_id, percent, GLASS_FLOOR])


func test_glass_holds_day_two_with_a_margin() -> void:
	var errors: Array[String] = []
	var named: Dictionary[String, Dictionary] = SimReport.read_formations(FileAccess.get_file_as_string("res://tools/sim_formations.json"), errors)
	var day_two: Array[String] = _day_two()
	assert_eq(day_two.size(), 7, "five easier fights and two harder ones: %s" % [day_two])
	for encounter_id: String in day_two:
		var percent: int = _glass_percent(encounter_id, named)
		assert_gte(percent, DAY_TWO_FLOOR, "%s: Glass wins %d%% (ES-2: at least %d%%)" % [encounter_id, percent, DAY_TWO_FLOOR])
		var stronger: int = _glass_percent(encounter_id, named, DAY_TWO_MARGIN_BP)
		assert_gte(stronger, DAY_TWO_MARGIN_FLOOR, "%s: Glass wins %d%% with the enemies x%.2f (ES-2: at least %d%%)" % [encounter_id, stronger, DAY_TWO_MARGIN_BP / 10000.0, DAY_TWO_MARGIN_FLOOR])


func test_glass_holds_day_three_with_a_margin() -> void:
	var errors: Array[String] = []
	var named: Dictionary[String, Dictionary] = SimReport.read_formations(FileAccess.get_file_as_string("res://tools/sim_formations.json"), errors)
	var day_three: Array[String] = _day_three()
	assert_eq(day_three, ["alphas_trail", "witchs_ward", "cairn_sentry"] as Array[String], "day 3's own elites")
	for encounter_id: String in _content.encounter_ids:
		var encounter: EncounterDef = _content.encounters[encounter_id]
		if encounter.act == 1 and encounter.tier == "elite":
			assert_eq(encounter.days.has(3), day_three.has(encounter_id), "%s: the full elites come on day 5 only" % encounter_id)
	for encounter_id: String in day_three:
		var percent: int = _glass_percent(encounter_id, named)
		assert_gte(percent, DAY_TWO_FLOOR, "%s: Glass wins %d%% (Decision 15: at least %d%%)" % [encounter_id, percent, DAY_TWO_FLOOR])
		var stronger: int = _glass_percent(encounter_id, named, DAY_TWO_MARGIN_BP)
		assert_gte(stronger, DAY_TWO_MARGIN_FLOOR, "%s: Glass wins %d%% with the enemies x%.2f (at least %d%%)" % [encounter_id, stronger, DAY_TWO_MARGIN_BP / 10000.0, DAY_TWO_MARGIN_FLOOR])
