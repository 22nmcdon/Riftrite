extends GutTest
## Hob's paths (phase 8 part 6, docs/plans/rebuild-phase8-last-heroes.md
## 8f-5; rebuild-heroes.md section 8f) in real fights: the Hoarder's Nest Egg
## and Heavy Purse, the Fence's Cut Purse, the Bounty Hunter's Bounty and
## Collect, Grab as each one's habit, and each fight deed moving only with
## its taste (Fence's is the run's: shards saved on rerolls).

const K = preload("res://tests/sim/sim_test_kit.gd")
const TEAM: Array[String] = ["brannoc", "maren", "hob"]
const PATHS: Array[String] = ["hoarder", "fence", "bounty_hunter"]

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


## A fight of Hob with the old two, on `path_id` ("" for his base kit;
## transformed if `transformed`), with `shards` held.
func _fight(encounter_id: String, path_id: String, transformed: bool, shards: int = 0) -> CombatSim:
	var errors: Array[String] = []
	var vows: Dictionary[String, String] = {}
	if not path_id.is_empty():
		vows["hob"] = path_id
	var stages: Array[String] = []
	if transformed:
		stages.append("hob")
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, TEAM, HeroTeam.GUARDED)
	var setup: FightSetup = Encounters.setup(_content, encounter_id, formation, 1, errors, {}, vows, stages)
	assert_eq(errors, [] as Array[String])
	setup.shards = shards
	var sim: CombatSim = CombatSim.new(setup, _content)
	while not sim.finished:
		sim.step()
	return sim


func _of(sim: CombatSim, kind: LogEntry.Kind, ability_id: String) -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in sim.combat_log.of_kind(kind):
		if entry.source_unit == "hob" and entry.source_ability == ability_id:
			found.append(entry)
	return found


func _deed(sim: CombatSim, path_id: String) -> int:
	return CombatSim.result_of(sim).deed_amount("hob", path_id)


func test_hob_can_be_drafted() -> void:
	assert_true(HeroTeam.ready(_content, "hob"), "his three paths are built")
	for path_id: String in PATHS:
		var habit: PartDef = null
		for part: PartDef in _content.paths[path_id].transformed_kit.passives:
			if part.id == "grab":
				habit = part
		assert_not_null(habit, "%s keeps Grab as a habit" % path_id)
		assert_eq(habit.ability.effects[0].every, 6, path_id)


func test_his_base_kit_fills_no_deed() -> void:
	var sim: CombatSim = _fight("cairn_road", "", false, 50)
	for path_id: String in PATHS:
		assert_eq(_deed(sim, path_id), 0, "%s needs its taste" % path_id)


func test_the_hoarder_hits_harder_for_the_purse() -> void:
	var base: int = _content.heroes["hob"].kit.stats.get_stat(UnitStats.Stat.HP)
	assert_eq(_content.paths["hoarder"].vowed_kit.stats.get_stat(UnitStats.Stat.HP), base * 9 / 10, "10% less max HP")
	var vowed: CombatSim = _fight("cairn_road", "hoarder", false, 50)
	var stones: Array[LogEntry] = _of(vowed, LogEntry.Kind.DAMAGE, "sling_stone")
	assert_gt(stones.size(), 0)
	assert_eq(stones[0].rule_power, 500, "+1% for every 10 shards: 50 held is +5%")
	assert_gt(_deed(vowed, "hoarder"), 0)
	var poor: CombatSim = _fight("cairn_road", "hoarder", false, 0)
	assert_eq(_deed(poor, "hoarder"), 0, "nothing held, nothing added")
	var rich: CombatSim = _fight("cairn_road", "hoarder", false, 500)
	assert_eq(_of(rich, LogEntry.Kind.DAMAGE, "sling_stone")[0].rule_power, 1000, "at most +10% vowed")
	var sim: CombatSim = _fight("cairn_road", "hoarder", true, 50)
	assert_eq(_of(sim, LogEntry.Kind.DAMAGE, "sling_stone")[0].rule_power, 1000, "+1% for every 5, no cap")
	var purse: Array[LogEntry] = _of(sim, LogEntry.Kind.DAMAGE, "heavy_purse")
	assert_gt(purse.size(), 0, "Heavy Purse")
	var light: CombatSim = _fight("cairn_road", "hoarder", true, 0)
	assert_gt(purse[0].rule_base, _of(light, LogEntry.Kind.DAMAGE, "heavy_purse")[0].rule_base + 90, "2 damage a shard")
	var maren: UnitState = sim.unit_by_id("maren")
	assert_eq(maren.stats.get_stat(UnitStats.Stat.DEF), FixedMath.apply_bp(maren.def.stats.get_stat(UnitStats.Stat.DEF), 10500), "his allies get half: +5% DEF at 50 held")
	assert_gt(_of(sim, LogEntry.Kind.DAMAGE, "grab").size(), 0, "Grab is a habit")


func test_the_fence_cuts_purses_once_an_enemy() -> void:
	var base: int = _content.heroes["hob"].kit.stats.get_stat(UnitStats.Stat.ATK)
	assert_eq(_content.paths["fence"].vowed_kit.stats.get_stat(UnitStats.Stat.ATK), base * 9 / 10, "10% less ATK")
	assert_true(_content.paths["fence"].deed.by_the_run(), "shards saved on rerolls: the run's")
	var sim: CombatSim = _fight("cairn_road", "fence", true)
	var cut: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "cut_purse")
	assert_gt(cut.size(), 0, "Cut Purse")
	assert_eq(cut[0].status, "cut_purse")
	var paid: Array[LogEntry] = _of(sim, LogEntry.Kind.SHARDS, "cut_purse_shards")
	assert_gt(paid.size(), 0, "a shard dropped")
	assert_lte(paid.size(), _of(sim, LogEntry.Kind.DAMAGE, "cut_purse").size(), "at most one a hit")
	assert_lte(paid.size(), sim.units.filter(func(unit: UnitState) -> bool: return unit.side == EffectSource.Team.ENEMIES).size(), "once an enemy")


func test_the_bounty_hunter_names_a_price() -> void:
	var vowed: CombatSim = _fight("cairn_road", "bounty_hunter", false)
	var named: Array[LogEntry] = _of(vowed, LogEntry.Kind.STATUS_APPLIED, "bounty")
	assert_eq(named.size(), 1, "one Bounty vowed")
	assert_eq(named[0].tick, 0, "at the fight's start")
	var toughest: UnitState = null
	for unit: UnitState in vowed.units:
		if unit.side == EffectSource.Team.ENEMIES and (toughest == null or unit.max_hp > toughest.max_hp):
			toughest = unit
	assert_eq(named[0].target, toughest.id, "the toughest enemy")
	assert_eq(named[0].end_tick - named[0].tick, 8 * 20, "Marked for 8s")
	var sim: CombatSim = _fight("cairn_road", "bounty_hunter", true)
	var marks: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "bounty")
	assert_gt(marks.size(), 1, "each Bounty that dies passes it on")
	var paid: Array[LogEntry] = _of(sim, LogEntry.Kind.SHARDS, "bounty")
	assert_gt(paid.size(), 0)
	assert_eq(paid[0].amount, 3, "3 shards a Bounty")
	assert_eq(_deed(sim, "bounty_hunter"), paid.size(), "the deed counts each Bounty killed")
	var collects: Array[LogEntry] = _of(sim, LogEntry.Kind.DAMAGE, "collect")
	assert_gt(collects.size(), 0, "Collect")
	assert_gt(collects.filter(func(entry: LogEntry) -> bool: return entry.rule_vulnerability >= 4000).size(), 0, "on the Bounty, Marked for +40%")
	var hob: UnitDef = _content.paths["bounty_hunter"].transformed_kit
	assert_eq(hob.stats.get_stat(UnitStats.Stat.ATK), FixedMath.apply_bp(_content.heroes["hob"].kit.stats.get_stat(UnitStats.Stat.ATK), 12000), "+20% ATK")
