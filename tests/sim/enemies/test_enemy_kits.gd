extends GutTest
## The nine Act 1 enemies in data/enemies.json: each one's threat happens
## (docs/plans/rebuild-phase2-heroes-enemies.md, section 5). Each test is a
## small fight built for one enemy; units that shouldn't walk are Rooted.

const K = preload("res://tests/sim/sim_test_kit.gd")

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


func _kit(enemy_id: String) -> UnitDef:
	return (_content.enemies[enemy_id] as EnemyDef).kit


## A hero that stands still and never hurts anyone.
func _still(hero_id: String, stats: Dictionary = {}, extra: Dictionary = {}) -> UnitDef:
	var all_stats: Dictionary = {"hp": 1000, "speed": 0, "range": 1}
	all_stats.merge(stats, true)
	var data: Dictionary = {"stats": all_stats, "basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}
	data.merge(extra, true)
	return K.kit(hero_id, data)


func _sim(heroes: Array[UnitSetup], enemies: Array[UnitSetup]) -> CombatSim:
	return CombatSim.new(K.fight(heroes, enemies), _content)


func _root(fight: CombatSim, units: Array[UnitState]) -> void:
	for unit: UnitState in units:
		Statuses.apply(fight, unit, "root", 0, 100000, EffectSource.make("", "test", "Test"))


func _fill_mana(unit: UnitState) -> void:
	unit.mana = unit.mana_cap


func _statuses(fight: CombatSim, unit_id: String, status: String) -> Array:
	return K.entries(fight, LogEntry.Kind.STATUS_APPLIED, unit_id).filter(func(entry: LogEntry) -> bool: return entry.status == status) \
		.map(func(entry: LogEntry) -> Array: return [entry.target, entry.source_ability, entry.amount])


func _moved(entry: LogEntry) -> int:
	return ArenaPlane.length(entry.to_pos - entry.from_pos)


func test_the_enemies_read_as_designed() -> void:
	assert_eq(_content.enemy_ids, ["rift_pup", "ashling", "rift_hound", "cinder_moth", "hollow_archer", "rift_worn_sentinel", "cairn_guardian", "bog_lurker", "gloam_witch",
		"hound_alpha", "hunt_hound", "gloam_totem", "ash_hound", "old_mother_ash",
		"mire_eel", "reedline_slinger", "tidecaller", "drowned_warden", "drowned_bellringer", "drowned_thrall", "glass_shambler", "glass_shard",
		"jagged_shard", "clouded_shard", "glass_matron", "brood_shambler", "matron_shard", "choir_tidecaller", "mournwater",
		"cliffmite", "cragram", "gulf_angler", "spire_chanter", "mirrorwight", "unbinder", "great_cragram", "herd_cragram", "mirror_queen", "heart_of_the_rift"])
	var rows: Array = _content.enemy_ids.map(func(enemy_id: String) -> Array:
		var enemy: EnemyDef = _content.enemies[enemy_id]
		var stats: UnitStats = enemy.kit.stats
		return [EnemyDef.ARCHETYPE_NAMES[enemy.archetype], stats.get_stat(UnitStats.Stat.HP), stats.get_stat(UnitStats.Stat.ATK), stats.get_stat(UnitStats.Stat.DEF),
			stats.get_stat(UnitStats.Stat.SPEED), stats.get_stat(UnitStats.Stat.RANGE), enemy.kit.traits])
	assert_eq(rows, [
		["swarm", 210, 8, 0, 2, 1, []],
		["swarm", 220, 25, 0, 2, 1, []],
		["flanker", 420, 18, 4, 3, 1, []],
		["caster", 260, 8, 0, 2, 3, ["flying"]],
		["ranged", 460, 18, 4, 2, 5, ["hop_away"]],
		["anchor", 520, 10, 25, 1, 1, ["engage"]],
		["charger", 440, 16, 20, 2, 1, []],
		["disruptor", 760, 32, 8, 1, 1, []],
		["support", 360, 22, 4, 2, 4, []],
		# Phase 5's elites and boss (before their encounters' scale_bp).
		["flanker", 900, 24, 6, 3, 1, []],
		["flanker", 420, 18, 4, 3, 1, []],
		["support", 520, 0, 10, 0, 1, ["inert"]],
		["flanker", 520, 20, 6, 3, 1, []],
		["caster", 2600, 26, 8, 1, 4, []],
		# Act 2, the Glassmere (phase 8 part 3, 8c-4a; placeholders until 8c-4c).
		["flanker", 300, 22, 4, 3, 1, ["swims", "submerges"]],
		["ranged", 280, 20, 2, 2, 4, ["swims", "hop_away"]],
		["caster", 320, 18, 2, 2, 4, []],
		["anchor", 620, 12, 20, 1, 1, ["engage"]],
		["summoner", 380, 14, 2, 1, 4, []],
		["swarm", 42, 16, 0, 2, 1, ["swims"]],
		["splitter", 560, 18, 10, 1, 1, []],
		["swarm", 224, 18, 6, 2, 1, []],
		["swarm", 224, 23, 6, 2, 1, []],
		["swarm", 224, 18, 6, 2, 1, []],
		["splitter", 1500, 24, 14, 1, 1, []],
		["splitter", 520, 18, 10, 1, 1, []],
		["swarm", 240, 18, 6, 2, 1, []],
		["caster", 900, 22, 6, 2, 4, []],
		["caster", 3200, 28, 8, 1, 6, ["swims"]],
		# Act 3, the Shattered Crown (phase 8 part 3, 8c-6a; placeholders until 8c-6c).
		["swarm", 200, 9, 2, 3, 1, []],
		["charger", 480, 18, 18, 2, 1, []],
		["disruptor", 420, 16, 6, 1, 4, []],
		["support", 340, 12, 4, 2, 4, ["hop_away"]],
		["mimic", 380, 14, 4, 2, 4, []],
		["warden_breaker", 460, 16, 10, 2, 1, []],
		["charger", 1300, 24, 22, 2, 1, []],
		["charger", 480, 18, 18, 2, 1, []],
		["mimic", 900, 20, 8, 2, 4, []],
		["caster", 4000, 30, 10, 0, 6, []],
	])
	assert_eq((_content.enemies["rift_hound"] as EnemyDef).threat, "Pounces on your weakest back-liner")
	assert_true(_content.enemy_ids.all(func(enemy_id: String) -> bool: return not (_content.enemies[enemy_id] as EnemyDef).threat.is_empty()))


# --- swarms ------------------------------------------------------------------------

func test_rift_pups_bite_harder_for_each_pup_beside_them() -> void:
	var alone: CombatSim = _sim([K.at(_still("hero", {"hp": 10000}), 3, 2)] as Array[UnitSetup], [K.foe(_kit("rift_pup"), 3, 4)] as Array[UnitSetup])
	K.step(alone, 100)
	var alone_bites: Array = K.entries(alone, LogEntry.Kind.DAMAGE, "rift_pup").map(func(entry: LogEntry) -> int: return entry.amount)
	assert_false(alone_bites.is_empty())
	assert_true(alone_bites.all(func(amount: int) -> bool: return amount == 8), "alone, a pup bites for its ATK: %s" % [alone_bites])

	var pack: CombatSim = _sim([K.at(_still("hero", {"hp": 10000}), 3, 2)] as Array[UnitSetup],
		[K.foe(_kit("rift_pup"), 2, 4, "pup_a"), K.foe(_kit("rift_pup"), 3, 4, "pup_b"), K.foe(_kit("rift_pup"), 4, 4, "pup_c")] as Array[UnitSetup])
	_root(pack, pack.heroes)
	K.step(pack, 100)
	var bites: Array = K.entries(pack, LogEntry.Kind.DAMAGE).filter(func(entry: LogEntry) -> bool: return entry.source_unit.begins_with("pup_")) \
		.map(func(entry: LogEntry) -> int: return entry.amount)
	assert_true(bites.all(func(amount: int) -> bool: return amount in [8, 10, 11]), "+20%% of 8 for each other pup within a hex (9.6 rounds to 10, 11.2 to 11): %s" % [bites])
	assert_true(bites.has(10) or bites.has(11), "in a pack, some bites are stronger: %s" % [bites])


func test_an_ashling_bursts_into_burn_on_every_unit_within_a_hex() -> void:
	var fight: CombatSim = _sim([K.at(_still("near"), 3, 2), K.at(_still("far"), 0, 0)] as Array[UnitSetup],
		[K.foe(_kit("ashling"), 3, 4), K.foe(_kit("rift_pup"), 3, 5, "pup"), K.foe(_kit("rift_pup"), 3, 6, "pup_two_off")] as Array[UnitSetup])
	_root(fight, fight.units)
	fight.unit_by_id("near").pos = fight.grid.center(3, 3)
	fight.unit_by_id("ashling").hp = 0
	K.step(fight, 1)
	assert_false(fight.unit_by_id("ashling").alive)
	assert_eq(_statuses(fight, "ashling", "burn"), [["near", "cinder_burst", 6], ["pup", "cinder_burst", 6]], "heroes and its own side alike; not pup_two_off or far")


# --- flanker -------------------------------------------------------------------------

func test_a_rift_hound_pounces_on_the_weakest_back_liner_at_the_start() -> void:
	var fight: CombatSim = _sim([K.at(_still("front"), 4, 2), K.at(_still("back_a"), 3, 0), K.at(_still("back_b"), 4, 0)] as Array[UnitSetup],
		[K.foe(_kit("rift_hound"), 4, 4)] as Array[UnitSetup])
	fight.unit_by_id("front").hp = 100
	fight.unit_by_id("back_b").hp = 600
	K.step(fight, 1)
	var leaps: Array = K.entries(fight, LogEntry.Kind.LEAP, "rift_hound").map(func(entry: LogEntry) -> Array: return [entry.tick, entry.target, entry.source_ability])
	assert_eq(leaps, [[1, "back_b", "pounce"]], "the lowest HP% of the back two rows, not the weaker front-liner")
	var bites: Array = K.entries(fight, LogEntry.Kind.DAMAGE, "rift_hound").map(func(entry: LogEntry) -> Array: return [entry.target, entry.source_ability, entry.amount])
	assert_eq(bites, [["back_b", "pounce", 18]], "then bites")


# --- caster ------------------------------------------------------------------------

func test_a_cinder_moth_burns_the_largest_group() -> void:
	# The loner is nearest the moth; group_c is the only group member in its
	# reach, and group_a and group_b are more than a hex from group_c.
	var fight: CombatSim = _sim([K.at(_still("loner"), 7, 2), K.at(_still("group_a"), 1, 1), K.at(_still("group_b"), 1, 2), K.at(_still("group_c"), 3, 1)] as Array[UnitSetup],
		[K.foe(_kit("cinder_moth"), 7, 4)] as Array[UnitSetup])
	_root(fight, fight.units)
	_fill_mana(fight.unit_by_id("cinder_moth"))
	K.step(fight, 1)
	var warnings: Array[LogEntry] = K.entries(fight, LogEntry.Kind.AREA_WARNING, "cinder_moth")
	assert_eq(warnings.size(), 1)
	assert_eq(warnings[0].from_pos, fight.grid.center(3, 1), "on group_c")
	assert_eq(warnings[0].end_tick, 21, "warned for 1s")
	assert_eq(_statuses(fight, "cinder_moth", "burn"), [])
	K.step(fight, 20)
	var burned: Array = _statuses(fight, "cinder_moth", "burn").map(func(row: Array) -> Array: return [row[0], row[2]])
	assert_eq(burned, [["group_a", 4], ["group_b", 4], ["group_c", 4]], "the whole group, 2 hexes round group_c; not the loner")


# --- ranged ------------------------------------------------------------------------

func test_a_hollow_archer_hops_away_when_approached_once_every_4s() -> void:
	var chaser: UnitDef = _still("chaser", {"hp": 10000, "speed": 3})
	var fight: CombatSim = _sim([K.at(chaser, 3, 2)] as Array[UnitSetup], [K.foe(_kit("hollow_archer"), 3, 4)] as Array[UnitSetup])
	K.step(fight, 300)
	var hops: Array[LogEntry] = K.entries(fight, LogEntry.Kind.HOP, "hollow_archer")
	assert_gt(hops.size(), 1)
	for i: int in range(1, hops.size()):
		assert_gte(hops[i].tick - hops[i - 1].tick, 80)


# --- anchor ------------------------------------------------------------------------

func test_a_sentinel_taunts_heroes_within_2_hexes_and_its_mana_comes_from_hits() -> void:
	var fight: CombatSim = _sim([K.at(_still("near"), 3, 2), K.at(_still("three_off"), 3, 1)] as Array[UnitSetup],
		[K.foe(_kit("rift_worn_sentinel"), 3, 4)] as Array[UnitSetup])
	_root(fight, fight.units)
	var sentinel: UnitState = fight.unit_by_id("rift_worn_sentinel")
	_fill_mana(sentinel)
	K.step(fight, 1)
	var taunts: Array = _statuses(fight, "rift_worn_sentinel", "taunt").map(func(row: Array) -> Array: return [row[0], row[1]])
	assert_eq(taunts, [["near", "bulwark"]])
	assert_eq(fight.unit_by_id("near").target, sentinel)
	assert_true(sentinel.def.has_trait("engage"))
	assert_eq([sentinel.def.mana.per_attack, sentinel.def.mana.per_10_damage_taken, sentinel.def.mana.regen_per_s], [4, 3, 0], "mostly from hits taken")


# --- charger -----------------------------------------------------------------------

func test_a_cairn_guardian_charges_and_knocks_the_first_hero_back_2_hexes() -> void:
	var fight: CombatSim = _sim([K.at(_still("front"), 3, 2), K.at(_still("back"), 1, 0)] as Array[UnitSetup],
		[K.foe(_kit("cairn_guardian"), 3, 4)] as Array[UnitSetup])
	_fill_mana(fight.unit_by_id("cairn_guardian"))
	K.step(fight, 1)
	var charges: Array = K.entries(fight, LogEntry.Kind.CHARGE, "cairn_guardian").map(func(entry: LogEntry) -> Array: return [entry.target, entry.source_ability])
	assert_eq(charges, [["front", "rampart_charge"]])
	var pushes: Array = K.entries(fight, LogEntry.Kind.PUSH, "cairn_guardian").map(func(entry: LogEntry) -> Array: return [entry.target, _moved(entry)])
	assert_eq(pushes, [["front", 2000]])


# --- disruptor ---------------------------------------------------------------------

func test_a_bog_lurker_drags_the_farthest_hero_2_hexes_and_roots_them() -> void:
	var fight: CombatSim = _sim([K.at(_still("near"), 2, 2), K.at(_still("far"), 3, 0), K.at(_still("too_far"), 7, 0)] as Array[UnitSetup],
		[K.foe(_kit("bog_lurker"), 3, 4)] as Array[UnitSetup])
	_fill_mana(fight.unit_by_id("bog_lurker"))
	K.step(fight, 10)
	var pulls: Array = K.entries(fight, LogEntry.Kind.PUSH, "bog_lurker").map(func(entry: LogEntry) -> Array: return [entry.target, _moved(entry)])
	assert_eq(pulls, [["far", 2000]], "the farthest within 5 hexes (Drag is a shot from 4 hexes off)")
	assert_eq(_statuses(fight, "bog_lurker", "root").map(func(row: Array) -> Array: return [row[0], row[1]]), [["far", "drag"]])
	var roots: Array[LogEntry] = K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "bog_lurker").filter(func(entry: LogEntry) -> bool: return entry.status == "root")
	assert_eq(roots[0].end_tick - roots[0].tick, 60, "Rooted for 3s")


# --- support -----------------------------------------------------------------------

func test_a_gloam_witch_wards_her_allies_every_third_attack() -> void:
	var fight: CombatSim = _sim([K.at(_still("hero", {"hp": 10000}), 3, 2)] as Array[UnitSetup],
		[K.foe(_kit("gloam_witch"), 3, 5), K.foe(_kit("rift_pup"), 0, 6, "pup")] as Array[UnitSetup])
	_root(fight, fight.units)
	K.step(fight, 200)
	var attacks: int = K.entries(fight, LogEntry.Kind.FIRE, "gloam_witch").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "gloam_bolt").size()
	assert_gte(attacks, 6)
	var wards: Array = K.entries(fight, LogEntry.Kind.SHIELD, "gloam_witch").map(func(entry: LogEntry) -> Array: return [entry.target, entry.source_ability, entry.amount])
	var expected: Array = []
	for i: int in attacks / 3:
		expected.append_array([["gloam_witch", "ward", 30], ["pup", "ward", 30]])
	assert_eq(wards, expected)


func test_a_gloam_witch_silences_the_hero_with_the_most_mana() -> void:
	var fight: CombatSim = _sim([K.at((_content.heroes["brannoc"] as HeroDef).kit, 2, 1), K.at((_content.heroes["vell"] as HeroDef).kit, 4, 0),
		K.at(_still("no_bar"), 3, 2)] as Array[UnitSetup], [K.foe(_kit("gloam_witch"), 3, 5)] as Array[UnitSetup])
	_root(fight, fight.units)
	_fill_mana(fight.unit_by_id("gloam_witch"))
	K.step(fight, 10)
	var hushes: Array = _statuses(fight, "gloam_witch", "silence").map(func(row: Array) -> Array: return [row[0], row[1]])
	assert_eq(hushes, [["brannoc", "hush"]], "Brannoc starts with 30 mana, Vell with 20; the nearest hero has no bar")
