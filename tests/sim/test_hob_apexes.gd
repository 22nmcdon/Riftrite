extends GutTest
## Hob's six apexes (phase 8 part 6, docs/plans/rebuild-phase8-last-heroes.md
## 8f-5; apexes.md) in real fights: each loads on its path's transformed kit
## with its taste and deed, and what it does at apex: Dragon's Hoard's Nest
## Egg for every hero, Golden Idol's purse of a Shield and Recast, Silver
## Tongue's wide cut that cheapens itself, Manhunter's two Bounties and
## execution, and Price on Their Heads' price on every head. The pieces they
## added: a Shield "up_to" its amount, and trigger_ally on on_enemy_fell (the
## ally that felled it). Black Market's are the run's (test_hob_shop.gd).

const K = preload("res://tests/sim/sim_test_kit.gd")
const APEXES: Dictionary[String, String] = {
	"dragons_hoard": "hoarder", "golden_idol": "hoarder",
	"black_market": "fence", "silver_tongue": "fence",
	"manhunter": "bounty_hunter", "price_on_their_heads": "bounty_hunter",
}
const TEAM: Array[String] = ["brannoc", "maren", "hob"]

var _content: ContentDb
var _run: RunContent


func before_all() -> void:
	_content = K.content()
	_run = RunContent.load_dir("res://data", _content)


## A fight of Hob with the old two, transformed on the path of `apex_id`,
## vowed to it, and at apex if `apexed`, holding `shards`.
func _fight(encounter_id: String, apex_id: String, apexed: bool, shards: int = 0) -> CombatSim:
	var errors: Array[String] = []
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, TEAM, HeroTeam.GUARDED)
	var at_apex: Array[String] = []
	if apexed:
		at_apex.append("hob")
	var setup: FightSetup = Encounters.setup(_content, encounter_id, formation, 1, errors, {}, {"hob": APEXES[apex_id]} as Dictionary[String, String],
		["hob"] as Array[String], {}, {"hob": apex_id} as Dictionary[String, String], at_apex)
	assert_eq(errors, [] as Array[String])
	setup.shards = shards
	var sim: CombatSim = CombatSim.new(setup, _content)
	while not sim.finished:
		sim.step()
	return sim


func _of(sim: CombatSim, kind: LogEntry.Kind, ability_id: String, unit_id: String = "hob") -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in sim.combat_log.of_kind(kind):
		if entry.source_unit == unit_id and entry.source_ability == ability_id:
			found.append(entry)
	return found


func _deed(sim: CombatSim, apex_id: String) -> int:
	return CombatSim.result_of(sim).deed_amount("hob", apex_id)


func test_his_six_apexes_load_on_their_paths() -> void:
	for apex_id: String in APEXES:
		var apex: ApexDef = _content.apexes[apex_id]
		assert_eq(apex.path, APEXES[apex_id], apex_id)
		var path_kit: UnitDef = _content.paths[apex.path].transformed_kit
		assert_eq(apex.apex_kit.stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(path_kit.stats.get_stat(UnitStats.Stat.HP), 11500), apex_id)
		assert_gt(apex.deed.threshold, 0, apex_id)
	assert_eq(_content.apexes.values().filter(func(apex: ApexDef) -> bool: return _content.paths[apex.path].hero == "hob").size(), 6)
	assert_eq(_content.apexes["golden_idol"].apex_kit.signature.id, "recast_the_idol")
	assert_eq(_content.apexes["golden_idol"].apex_kit.passives.filter(func(part: PartDef) -> bool: return part.id == "heavy_purse").size(), 1, "Heavy Purse becomes a habit")


func test_dragons_hoard() -> void:
	var vowed: CombatSim = _fight("cairn_road", "dragons_hoard", false, 40)
	var purse: Array[LogEntry] = _of(vowed, LogEntry.Kind.DAMAGE, "heavy_purse")
	assert_gt(purse.size(), 0)
	assert_gt(_deed(vowed, "dragons_hoard"), 0, "Heavy Purse's damage")
	var light: CombatSim = _fight("cairn_road", "dragons_hoard", false, 0)
	assert_gt(purse[0].rule_base, _of(light, LogEntry.Kind.DAMAGE, "heavy_purse")[0].rule_base + 110, "3 a shard")
	var sim: CombatSim = _fight("cairn_road", "dragons_hoard", true, 40)
	var maren: UnitState = sim.unit_by_id("maren")
	assert_eq(maren.stats.get_stat(UnitStats.Stat.DEF), FixedMath.apply_bp(maren.def.stats.get_stat(UnitStats.Stat.DEF), 10800), "his allies get Nest Egg in full: +8% at 40 held")
	assert_eq(maren.max_hp, FixedMath.apply_bp(maren.def.stats.get_stat(UnitStats.Stat.HP), 10800), "+1% max HP for every 5 held")
	var grows: GrowthDef = _content.apexes["dragons_hoard"].grows
	assert_eq([grows.run_counts, grows.team], ["won_holding", true], "the run snowball: fights won holding 30+")


func test_golden_idol() -> void:
	var vowed: CombatSim = _fight("cairn_road", "golden_idol", false, 40)
	var start: Array[LogEntry] = _of(vowed, LogEntry.Kind.SHIELD, "idol_purse")
	assert_eq(start.size(), 1)
	assert_eq([start[0].tick, start[0].amount], [0, 80], "the taste: 2 a shard at the start")
	assert_eq(_deed(vowed, "golden_idol"), 80)
	var sim: CombatSim = _fight("cairn_road", "golden_idol", true, 40)
	assert_eq(_of(sim, LogEntry.Kind.SHIELD, "idol_purse")[0].amount, 120, "3 a shard at apex")
	var fresh: CombatSim = CombatSim.new(sim.setup, _content)
	fresh.step()
	var hob: UnitState = fresh.unit_by_id("hob")
	assert_eq(hob.stats.get_stat(UnitStats.Stat.ATK), hob.def.stats.get_stat(UnitStats.Stat.ATK) + 13, "+1 ATK for every 3 shards")
	assert_gt(_of(sim, LogEntry.Kind.FIRE, "recast_the_idol").size(), 0, "Recast the Idol")
	var recasts: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "recast_the_idol").filter(func(entry: LogEntry) -> bool: return entry.status == "compounding")
	assert_gt(recasts.size(), 0, "each Recast compounds")
	assert_gt(sim.unit_by_id("hob").stats.get_stat(UnitStats.Stat.ATK), hob.stats.get_stat(UnitStats.Stat.ATK), "so each shard counts for more ATK")
	var poor: CombatSim = _fight("cairn_road", "golden_idol", true, 3)
	assert_gt(_of(poor, LogEntry.Kind.STATUS_APPLIED, "idol_shattered").size(), 0, "a thin Shield breaks, and he speeds up")


func test_a_shield_up_to_its_amount() -> void:
	var dummy: UnitDef = K.kit("mark", {"stats": {"hp": 5000, "speed": 0, "range": 1, "def": 0},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var idol: UnitDef = K.kit("idol", {"stats": {"hp": 400, "atk": 100, "speed": 0, "range": 2},
		"basic_attack": {"id": "tap", "name": "Tap", "cooldown_ms": 1000, "effects": [
			{"type": "shield", "amount": 100, "up_to": true, "target": "self"}]},
		"passives": [{"id": "start", "name": "Start", "kind": "ability", "effects": [{"trigger": "on_fight_start", "type": "shield", "amount": 60, "target": "self"}]}]})
	var sim: CombatSim = K.sim(K.fight([K.at(idol, 3, 2)] as Array[UnitSetup], [K.foe(dummy, 3, 4)] as Array[UnitSetup]))
	for i: int in 30:
		sim.step()
	var shields: Array = sim.combat_log.of_kind(LogEntry.Kind.SHIELD).map(func(entry: LogEntry) -> int: return entry.amount)
	assert_eq(shields.slice(0, 2), [60, 40], "60, then up to 100")
	assert_eq(sim.unit_by_id("idol").shield, 100, "never past it")


func test_silver_tongue() -> void:
	var vowed: CombatSim = _fight("cairn_road", "silver_tongue", false)
	var cut: Array[LogEntry] = _of(vowed, LogEntry.Kind.STATUS_APPLIED, "cut_purse")
	assert_true(cut.all(func(entry: LogEntry) -> bool: return entry.status == "silver_cut"), "the taste: 20%")
	assert_eq(_deed(vowed, "silver_tongue"), cut.size())
	var sim: CombatSim = _fight("cairn_road", "silver_tongue", true)
	var fires: Array[LogEntry] = _of(sim, LogEntry.Kind.FIRE, "cut_purse")
	assert_gt(fires.size(), 0)
	var wide: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "cut_purse").filter(func(entry: LogEntry) -> bool: return entry.status == "silver_cut_deep")
	assert_gt(wide.size(), fires.size(), "every enemy within 2 hexes")
	assert_eq(sim.unit_by_id("hob").def.shard_cap, 12)
	var cheaper: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "silver_tongue_feed")
	assert_gt(cheaper.size(), 0, "each enemy cut makes it cheaper")
	var hob: UnitState = sim.unit_by_id("hob")
	assert_lte(Statuses.stacks_on(hob, "silver_tongue"), 35, "down to 15 mana at most")


func test_manhunter() -> void:
	var vowed: CombatSim = _fight("cairn_road", "manhunter", false)
	assert_gt(_deed(vowed, "manhunter"), 0, "damage to the Marked")
	var sim: CombatSim = _fight("cairn_road", "manhunter", true)
	var named: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "bounty").filter(func(entry: LogEntry) -> bool: return entry.tick == 0)
	assert_eq(named.size(), 2, "two Bounties at once")
	var collect: AbilityDef = _content.apexes["manhunter"].apex_kit.signature
	assert_eq(collect.effects[0].execute_below_bp, 2000, "Collect finishes a Bounty below 20%")
	assert_true(collect.effects[0].execute_vs.statuses.has("bounty"))
	assert_true(_content.apexes["manhunter"].grows.counted_in_fights(), "its snowball counts Bounties in the fights")


func test_price_on_their_heads() -> void:
	var vowed: CombatSim = _fight("cairn_road", "price_on_their_heads", false)
	var paid: Array[LogEntry] = _of(vowed, LogEntry.Kind.SHARDS, "bounty")
	assert_gt(paid.size(), 0)
	assert_eq(paid[0].amount, 4, "the taste: 1 more")
	var sim: CombatSim = _fight("cairn_road", "price_on_their_heads", true)
	var lesser: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "bounty_lesser")
	assert_eq(lesser.size(), _content.encounters["cairn_road"].enemies.size(), "a price on every head")
	var heads: Array[LogEntry] = _of(sim, LogEntry.Kind.SHARDS, "bounty_lesser")
	assert_gt(heads.size(), 0, "each pays a shard")
	assert_true(heads.all(func(entry: LogEntry) -> bool: return entry.amount == 1))
	assert_eq(_of(sim, LogEntry.Kind.SHARDS, "bounty")[0].amount, 5, "the toughest pays 5")
	assert_eq(sim.unit_by_id("hob").def.shard_cap, 12)
	assert_eq(_content.statuses["bounty_lesser"].keyword, "", "the other prices aren't Marks")
	assert_eq(_of(sim, LogEntry.Kind.STATUS_APPLIED, "bounty").size(), 1, "only the toughest is Marked, and its price stays on it")


func test_reward_poster_pays_whoever_felled_the_bounty() -> void:
	var dummy: UnitDef = K.kit("mark", {"stats": {"hp": 50, "speed": 0, "range": 1, "def": 0},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var hunter: UnitDef = K.kit("hunter", {"stats": {"hp": 400, "atk": 1, "speed": 0, "range": 3},
		"basic_attack": {"id": "tap", "name": "Tap", "cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]},
		"passives": [{"id": "price", "name": "Price", "kind": "ability", "effects": [
			{"trigger": "on_fight_start", "type": "apply_status", "status": "bounty", "duration_ms": 180000, "target": "all_enemies"},
			{"trigger": "on_enemy_fell", "vs": {"statuses": ["bounty"]}, "type": "gain_mana", "amount": 10, "target": "trigger_ally"}]}]})
	var killer: UnitDef = K.kit("killer", {"stats": {"hp": 400, "atk": 100, "speed": 0, "range": 3},
		"mana": {"max": 100, "per_attack": 0},
		"signature": {"id": "nothing", "name": "Nothing", "trigger": {"kind": "mana"}, "effects": [{"type": "damage", "amount": 1, "target": "target"}]},
		"basic_attack": {"id": "shot", "name": "Shot", "cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}})
	var sim: CombatSim = K.sim(K.fight([K.at(hunter, 2, 2), K.at(killer, 4, 2)] as Array[UnitSetup], [K.foe(dummy, 3, 4)] as Array[UnitSetup]))
	while not sim.finished:
		sim.step()
	var given: Array[LogEntry] = sim.combat_log.of_kind(LogEntry.Kind.MANA_GIVEN)
	assert_true(given.any(func(entry: LogEntry) -> bool: return entry.source_unit == "hunter" and entry.target == "killer"), "the ally that felled it gains the mana")
