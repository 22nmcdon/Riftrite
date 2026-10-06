extends GutTest
## The base kits in data/heroes.json do what their text says
## (docs/plans/rebuild-phase2-heroes-enemies.md, section 3; Garrow from
## rebuild-phase8-heroes.md, 8d-1). Each test fights
## the real kits against still dummies; heroes that shouldn't walk are Rooted
## for the whole test.

const K = preload("res://tests/sim/sim_test_kit.gd")

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


func _kit(hero_id: String) -> UnitDef:
	return (_content.heroes[hero_id] as HeroDef).kit


## An enemy that stands still and never hurts anyone.
func _dummy(dummy_id: String = "dummy", stats: Dictionary = {}) -> UnitDef:
	var all_stats: Dictionary = {"hp": 10000, "speed": 0, "range": 1}
	all_stats.merge(stats, true)
	return K.kit(dummy_id, {"stats": all_stats, "basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


func _sim(heroes: Array[UnitSetup], enemies: Array[UnitSetup]) -> CombatSim:
	return CombatSim.new(K.fight(heroes, enemies), _content)


func _root_all(fight: CombatSim, units: Array[UnitState]) -> void:
	for unit: UnitState in units:
		Statuses.apply(fight, unit, "root", 0, 100000, EffectSource.make("", "test", "Test"))


func _def(unit: UnitState) -> int:
	return unit.stats.get_stat(UnitStats.Stat.DEF)


func _fill_mana(unit: UnitState) -> void:
	unit.mana = unit.mana_cap


func _rows(fight: CombatSim, kind: LogEntry.Kind, unit_id: String, ability: String = "") -> Array:
	return K.entries(fight, kind, unit_id).filter(func(entry: LogEntry) -> bool: return ability.is_empty() or entry.source_ability == ability) \
		.map(func(entry: LogEntry) -> Array: return [entry.target, entry.amount])


func test_the_kits_read_as_designed() -> void:
	assert_eq(_content.hero_ids, ["brannoc", "maren", "vell", "garrow"])
	var roles: Array = _content.hero_ids.map(func(hero_id: String) -> int: return (_content.heroes[hero_id] as HeroDef).role)
	assert_eq(roles, [HeroDef.Role.TANK, HeroDef.Role.DAMAGE, HeroDef.Role.SUPPORT, HeroDef.Role.TANK])
	var stats: Array = _content.hero_ids.map(func(hero_id: String) -> Array: return _kit(hero_id).stats.values)
	assert_eq(stats, [[630, 14, 0, 50, 0, 0, 2, 1], [270, 22, 0, 8, 8, 10, 2, 4], [300, 6, 20, 10, 0, 0, 2, 3], [550, 26, 0, 40, 0, 0, 2, 1]], "HP, ATK, MGK, DEF, CRIT, ATSP, speed, range (Garrow's tuned into the base band, build-tuning.md)")
	var mana: Array = _content.hero_ids.map(func(hero_id: String) -> Array:
		var bar: ManaDef = _kit(hero_id).mana
		return [bar.max, bar.start, bar.per_attack, bar.per_10_damage_taken, bar.regen_per_s])
	assert_eq(mana, [[80, 30, 8, 1, 0], [50, 0, 10, 0, 2], [60, 20, 12, 0, 2], [70, 20, 10, 1, 0]], "cost, start, per attack, per 10 damage taken, regen")
	assert_eq([_kit("brannoc").traits, _kit("maren").traits, _kit("vell").traits, _kit("garrow").traits], [["engage"], ["hop_away"], [], []])
	assert_eq(_kit("maren").hop_cooldown_ticks, 120)
	var names: Array = _content.hero_ids.map(func(hero_id: String) -> Array: return [_kit(hero_id).basic_attack.name, _kit(hero_id).signature.name])
	assert_eq(names, [["Shield Bash", "Hold the Line"], ["Longshot", "Marking Shot"], ["Lantern Glow", "Mend"], ["Chain Fist", "Haul"]])


# --- Brannoc ---------------------------------------------------------------------

func test_hold_the_line_taunts_within_2_hexes_and_his_def_follows_his_taunts() -> void:
	var fight: CombatSim = _sim([K.at(_kit("brannoc"), 3, 2), K.at(_kit("maren"), 0, 0)] as Array[UnitSetup],
		[K.foe(_dummy("near_a"), 3, 4), K.foe(_dummy("near_b"), 4, 4), K.foe(_dummy("far"), 3, 5)] as Array[UnitSetup])
	var brannoc: UnitState = fight.unit_by_id("brannoc")
	_root_all(fight, fight.heroes)
	assert_eq(_def(brannoc), 50)
	_fill_mana(brannoc)
	K.step(fight, 1)
	var taunts: Array = K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "brannoc").filter(func(entry: LogEntry) -> bool: return entry.status == "taunt") \
		.map(func(entry: LogEntry) -> Array: return [entry.target, entry.end_tick])
	assert_eq(taunts, [["near_a", 61], ["near_b", 61]], "enemies within 2 hexes, for Taunt's 3s")
	assert_eq(_def(brannoc), 75, "x1.5 DEF while they're taunted")
	K.step(fight, 59)
	assert_eq(_def(brannoc), 75)
	K.step(fight, 1)
	assert_eq(_def(brannoc), 50, "back as the Taunts run out")
	assert_eq(K.entries(fight, LogEntry.Kind.AURA, "brannoc").map(func(entry: LogEntry) -> Array: return [entry.tick, entry.source_ability_name]),
		[[1, "Hold the Line"], [61, "Hold the Line"]])

	var from_brannoc: EffectSource = EffectSource.make("brannoc", "hold_the_line", "Hold the Line")
	Statuses.apply(fight, fight.unit_by_id("near_a"), "taunt", 0, 60, from_brannoc)
	Statuses.apply(fight, fight.unit_by_id("near_a"), "taunt", 0, 60, EffectSource.make("maren", "jeer", "Jeer"))
	assert_eq(_def(brannoc), 50, "not once another unit's newer Taunt takes the enemy over")
	Statuses.apply(fight, fight.unit_by_id("near_b"), "taunt", 0, 200, from_brannoc)
	K.step(fight, 150)
	assert_eq(_def(brannoc), 75, "for as long as a longer Taunt lasts")


func test_hearthguard_shields_the_first_ally_below_40_percent_once() -> void:
	var fight: CombatSim = _sim([K.at(_kit("brannoc"), 3, 2), K.at(_kit("maren"), 0, 0), K.at(_kit("vell"), 7, 0)] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 6)] as Array[UnitSetup])
	_root_all(fight, fight.heroes)
	var maren: UnitState = fight.unit_by_id("maren")
	maren.hp = 109
	K.step(fight, 1)
	assert_eq(_rows(fight, LogEntry.Kind.SHIELD, "brannoc"), [], "109 of 270 isn't below 40%")
	maren.hp = 107
	fight.unit_by_id("vell").hp = 50
	fight.unit_by_id("brannoc").hp = 50
	K.step(fight, 5)
	assert_eq(_rows(fight, LogEntry.Kind.SHIELD, "brannoc", "hearthguard"), [["maren", 60]], "once a fight, and never for himself")
	assert_eq(maren.shield, 60)


# --- Garrow (8d-1) ---------------------------------------------------------------

func test_haul_drags_the_farthest_enemy_within_4_hexes_beside_him() -> void:
	var fight: CombatSim = _sim([K.at(_kit("garrow"), 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy("near"), 3, 4), K.foe(_dummy("far"), 3, 6), K.foe(_dummy("beyond"), 0, 6)] as Array[UnitSetup])
	var garrow: UnitState = fight.unit_by_id("garrow")
	_root_all(fight, fight.heroes)
	_fill_mana(garrow)
	K.step(fight, 10)
	var pulls: Array = K.entries(fight, LogEntry.Kind.PUSH, "garrow").map(func(entry: LogEntry) -> String: return entry.target)
	assert_eq(pulls, ["far"], "the farthest within 4 hexes, not the one beyond")
	assert_true(ArenaPlane.length(fight.unit_by_id("far").pos - garrow.pos) <= 2 * 100 + 50, "dragged beside him")


func test_stand_fast_shields_him_once_below_half() -> void:
	var fight: CombatSim = _sim([K.at(_kit("garrow"), 3, 2)] as Array[UnitSetup], [K.foe(_dummy(), 3, 6)] as Array[UnitSetup])
	var garrow: UnitState = fight.unit_by_id("garrow")
	_root_all(fight, fight.heroes)
	garrow.hp = 276
	K.step(fight, 1)
	assert_eq(_rows(fight, LogEntry.Kind.SHIELD, "garrow", "stand_fast"), [], "276 of 550 isn't below half")
	garrow.hp = 274
	K.step(fight, 1)
	garrow.hp = 400
	K.step(fight, 1)
	garrow.hp = 100
	K.step(fight, 1)
	assert_eq(_rows(fight, LogEntry.Kind.SHIELD, "garrow", "stand_fast"), [["garrow", 83]], "15% of his max HP, once a fight")


func test_heavy_keeps_him_from_being_moved() -> void:
	var shover: UnitDef = K.kit("shover", {"stats": {"hp": 10000, "atk": 1, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 500,
		"effects": [{"type": "knockback", "hexes": 2, "target": "target"}]}})
	var fight: CombatSim = _sim([K.at(_kit("garrow"), 3, 2)] as Array[UnitSetup], [K.foe(shover, 3, 3)] as Array[UnitSetup])
	K.step(fight, 40)
	assert_eq(K.entries(fight, LogEntry.Kind.PUSH).filter(func(entry: LogEntry) -> bool: return entry.target == "garrow"), [] as Array[LogEntry], "never moved")
	assert_false(K.entries(fight, LogEntry.Kind.RESISTED).is_empty(), "he resists, and says so")


# --- Maren -----------------------------------------------------------------------

func test_maren_hops_away_once_every_6s() -> void:
	var biter: UnitDef = K.kit("biter", {"stats": {"hp": 10000, "speed": 3, "range": 1}, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var fight: CombatSim = _sim([K.at(_kit("maren"), 3, 2)] as Array[UnitSetup], [K.foe(biter, 3, 4)] as Array[UnitSetup])
	K.step(fight, 200)
	var hops: Array[LogEntry] = K.entries(fight, LogEntry.Kind.HOP, "maren")
	assert_gt(hops.size(), 1)
	for i: int in range(1, hops.size()):
		assert_gte(hops[i].tick - hops[i - 1].tick, 120, "at most once every 6s")


func test_maren_slips_from_sight_after_each_hop() -> void:
	# The biter goes for Maren (nearest); when she hops, Slip Away hides her
	# for 1s and it turns on the other hero (playtest gate 1).
	var biter: UnitDef = K.kit("biter", {"stats": {"hp": 10000, "speed": 2, "range": 1}, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var fight: CombatSim = _sim([K.at(_kit("maren"), 3, 2), K.at(_dummy("bait"), 0, 0)] as Array[UnitSetup], [K.foe(biter, 3, 4)] as Array[UnitSetup])
	K.step(fight, 60)
	var hop: LogEntry = K.entries(fight, LogEntry.Kind.HOP, "maren")[0]
	var hidden: LogEntry = K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "maren").filter(func(entry: LogEntry) -> bool: return entry.status == "stealth")[0]
	assert_eq([hidden.tick, hidden.target, hidden.source_ability, hidden.end_tick], [hop.tick, "maren", "slip_away", hop.tick + 20], "on the hop, for 1s")
	var picks: Array = K.entries(fight, LogEntry.Kind.TARGET, "biter").map(func(entry: LogEntry) -> Array: return [entry.tick, entry.target, entry.note])
	assert_eq(picks, [[1, "maren", "nearest"], [hop.tick + 1, "", "maren is stealthed"], [hop.tick + 1, "bait", "nearest"]], "it loses her at once and takes the other hero")
	var ended: Array[LogEntry] = K.entries(fight, LogEntry.Kind.STATUS_ENDED).filter(func(entry: LogEntry) -> bool: return entry.status == "stealth")
	assert_eq(ended[0].tick, hop.tick + 20)


func test_marking_shot_marks_the_nearest_enemy_for_4s() -> void:
	var fight: CombatSim = _sim([K.at(_kit("maren"), 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy("far"), 1, 5), K.foe(_dummy("near"), 3, 4)] as Array[UnitSetup])
	_root_all(fight, fight.heroes)
	_fill_mana(fight.unit_by_id("maren"))
	K.step(fight, 10)
	var marks: Array = K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "maren").filter(func(entry: LogEntry) -> bool: return entry.status == "marked") \
		.map(func(entry: LogEntry) -> Array: return [entry.target, entry.source_ability, entry.end_tick - entry.tick])
	assert_eq(marks, [["near", "marking_shot", 80]])


# --- Vell ------------------------------------------------------------------------

func test_mend_heals_the_ally_lowest_on_hp_within_3_hexes() -> void:
	var fight: CombatSim = _sim([K.at(_kit("brannoc"), 3, 2), K.at(_kit("maren"), 1, 1), K.at(_kit("vell"), 3, 1),
		K.at(K.kit("straggler", {"stats": {"hp": 100, "speed": 0}}), 7, 0)] as Array[UnitSetup], [K.foe(_dummy(), 3, 6)] as Array[UnitSetup])
	_root_all(fight, fight.heroes)
	fight.unit_by_id("brannoc").hp = 500
	fight.unit_by_id("maren").hp = 150
	fight.unit_by_id("straggler").hp = 10
	_fill_mana(fight.unit_by_id("vell"))
	K.step(fight, 10)
	assert_eq(_rows(fight, LogEntry.Kind.HEAL, "vell", "mend"), [["maren", 40]], "20 + 100% MGK, on the lowest HP% in reach (the straggler is 4 hexes off)")


func test_hearthlight_heals_allies_within_1_hex_by_1_percent_a_second_not_vell() -> void:
	var fight: CombatSim = _sim([K.at(_kit("brannoc"), 3, 2), K.at(_kit("maren"), 3, 0), K.at(_kit("vell"), 3, 1),
		K.at(K.kit("straggler", {"stats": {"hp": 1000, "speed": 0}}), 5, 1)] as Array[UnitSetup], [K.foe(_dummy(), 3, 6)] as Array[UnitSetup])
	_root_all(fight, fight.heroes)
	for unit: UnitState in fight.heroes:
		unit.hp = 100
	K.step(fight, 40)
	assert_eq(_rows(fight, LogEntry.Kind.HEAL, "vell", "hearthlight"), [["brannoc", 6], ["maren", 3], ["brannoc", 6], ["maren", 3]],
		"1% of each ally's max HP (6.3 and 2.7, rounded); the straggler is 2 hexes off")
	assert_eq(fight.unit_by_id("vell").hp, 100)


# --- together -----------------------------------------------------------------------

func test_the_three_fight_a_whole_fight_using_their_kits() -> void:
	var brute: UnitDef = K.kit("brute", {"stats": {"hp": 260, "atk": 12, "speed": 2, "range": 1}, "basic_attack": {"cooldown_ms": 1200,
		"effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}})
	var setup: FightSetup = K.fight([K.at(_kit("brannoc"), 3, 2), K.at(_kit("maren"), 3, 0), K.at(_kit("vell"), 4, 0)] as Array[UnitSetup],
		[K.foe(brute, 2, 4, "brute_a"), K.foe(brute, 3, 4, "brute_b"), K.foe(brute, 4, 4, "brute_c"), K.foe(brute, 5, 5, "brute_d")] as Array[UnitSetup], [] as Array[Vector2i], 3)
	var result: FightResult = CombatSim.run(setup, _content)
	assert_eq(result.errors, [] as Array[String])
	assert_eq(result.outcome, FightResult.Outcome.VICTORY)
	var used: Array[String] = []
	for entry: LogEntry in result.combat_log.entries:
		if not entry.source_ability_name.is_empty() and not used.has(entry.source_ability_name):
			used.append(entry.source_ability_name)
	for ability: String in ["Shield Bash", "Hold the Line", "Longshot", "Marking Shot", "Lantern Glow", "Mend", "Hearthlight"]:
		assert_has(used, ability)
