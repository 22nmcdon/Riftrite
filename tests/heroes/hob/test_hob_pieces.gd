extends GutTest
## The fight pieces Hob's kit added (phase 8 part 6, docs/plans/
## rebuild-phase8-last-heroes.md section 8, 8f-5), each in a small fight:
## shards held as power (an aura per shards held with a cap, damage per
## shard, held shards worth more for a boost's stacks, ATK in points), the
## toughest enemies (with "only" and "without"), a Bounty that passes to the
## next toughest, and a kills deed counting a side's kills of a Bounty.

const K = preload("res://tests/sim/sim_test_kit.gd")


func _dummy(dummy_id: String, hp: int = 5000) -> UnitDef:
	return K.kit(dummy_id, {"stats": {"hp": hp, "speed": 0, "range": 1, "def": 0},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


func _hoarder(passives: Array, extra: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 400, "atk": 100, "def": 10, "speed": 0, "range": 2},
		"basic_attack": {"id": "sling", "name": "Sling", "cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]},
		"passives": passives}
	data.merge(extra, true)
	return K.kit("hoarder", data)


func _fight(hero: UnitDef, shards: int, foes: Array[UnitSetup] = []) -> CombatSim:
	if foes.is_empty():
		foes = [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]
	var setup: FightSetup = K.fight([K.at(hero, 3, 2), K.at(_dummy("pal"), 5, 1)] as Array[UnitSetup], foes)
	setup.shards = shards
	return K.sim(setup)


func _read_aura(aura: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	AuraDef.read(DataReader.new(aura, "aura", errors))
	return errors


func test_reading_an_aura_per_shards() -> void:
	assert_eq(_read_aura({"target": "holder", "stat": "atk_bp", "value": 10100, "per_shards": 10, "per_shards_max": 10}), [] as Array[String])
	assert_eq(_read_aura({"target": "holder", "stat": "atk", "value": 2, "per_shards": 1}), [] as Array[String])
	assert_ne(_read_aura({"target": "holder", "stat": "atk_bp", "value": 10100, "per_shards_max": 10}), [] as Array[String], "a cap needs per_shards")
	assert_ne(_read_aura({"target": "holder", "stat": "atk_bp", "value": 10100, "per_shards": 0}), [] as Array[String])


func test_an_aura_per_shards_held_up_to_its_cap() -> void:
	var nest: Dictionary = {"id": "nest_egg", "name": "Nest Egg", "kind": "aura", "aura": {"target": "holder", "stat": "atk_bp", "value": 10100, "per_shards": 10, "per_shards_max": 10}}
	var half: Dictionary = {"id": "shared", "name": "Shared", "kind": "aura", "aura": {"target": "all_allies", "only": {"others": true}, "stat": "def_bp", "value": 10050, "per_shards": 5}}
	for case: Array in [[0, 100], [39, 103], [50, 105], [200, 110]]:
		var fight: CombatSim = _fight(_hoarder([nest]), case[0])
		assert_eq(fight.unit_by_id("hoarder").stats.get_stat(UnitStats.Stat.ATK), case[1], "%d shards: +1%% a 10, at most +10%%" % case[0])
	var fight: CombatSim = _fight(_hoarder([half], {"stats": {"hp": 400, "atk": 100, "def": 100, "speed": 0, "range": 2}}), 100)
	assert_eq(fight.unit_by_id("hoarder").stats.get_stat(UnitStats.Stat.DEF), 100, "only the others")
	assert_eq(fight.unit_by_id("pal").stats.get_stat(UnitStats.Stat.DEF), 0, "the pal's 0 DEF stays 0")
	assert_true(nest.aura is Dictionary and AuraDef.read(DataReader.new(nest.aura, "a", [] as Array[String])).describe().contains("for every 10 shards held (up to 10 times)"))


func test_damage_per_shard_held() -> void:
	var purse: UnitDef = _hoarder([], {"basic_attack": {"id": "purse", "name": "Purse", "cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}, "plus_per_shard_bp": 20000}]}})
	var fight: CombatSim = _fight(purse, 30)
	K.step(fight, 40)
	var hits: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "hoarder")
	assert_true(hits[0].amount == 100 + 60 or hits[0].amount == (100 + 60) * 3 / 2, "his ATK and 2 a shard held (a crit's half more): %d" % hits[0].amount)


func test_held_shards_count_more_for_a_boosts_stacks_and_atk_in_points() -> void:
	var idol: Dictionary = {"id": "idol", "name": "Idol", "kind": "aura", "aura": {"target": "holder", "stat": "atk", "value": 2, "per_shards": 1}}
	var fight: CombatSim = _fight(_hoarder([idol]), 10)
	var hob: UnitState = fight.unit_by_id("hoarder")
	assert_eq(hob.stats.get_stat(UnitStats.Stat.ATK), 120, "+2 ATK a shard: 100 + 20")
	assert_eq(fight.shards_held(hob), 10)
	Statuses.apply(fight, hob, "compounding", 1, 0, EffectSource.make("hoarder", "recast", "Recast"))
	Statuses.apply(fight, hob, "compounding", 1, 0, EffectSource.make("hoarder", "recast", "Recast"))
	assert_eq(fight.shards_held(hob), 12, "each stack makes them count 10% more")
	assert_eq(hob.stats.get_stat(UnitStats.Stat.ATK), 124, "and what reads them follows")


func test_the_toughest_enemies() -> void:
	var mark: Dictionary = {"id": "price", "name": "Price", "kind": "ability", "effects": [
		{"trigger": "on_fight_start", "type": "apply_status", "status": "bounty", "target": "toughest_enemies", "count": 2}]}
	var foes: Array[UnitSetup] = [K.foe(_dummy("small", 300), 2, 4), K.foe(_dummy("big", 900), 3, 4), K.foe(_dummy("big_too", 900), 4, 4), K.foe(_dummy("mid", 600), 5, 4)]
	var fight: CombatSim = _fight(_hoarder([mark]), 0, foes)
	K.step(fight, 2)
	var marked: Array = K.entries(fight, LogEntry.Kind.STATUS_APPLIED).filter(func(entry: LogEntry) -> bool: return entry.status == "bounty").map(func(entry: LogEntry) -> String: return entry.target)
	assert_eq(marked, ["big", "big_too"], "most max HP, the fight's order on a tie")


func test_a_bounty_passes_to_the_next_toughest_and_a_side_collects_it() -> void:
	var bounty: Dictionary = {"id": "bounty_hunt", "name": "Bounty", "kind": "ability", "effects": [
		{"trigger": "on_fight_start", "type": "apply_status", "status": "bounty", "duration_ms": 180000, "target": "toughest_enemies", "count": 2},
		{"trigger": "on_enemy_fell", "vs": {"statuses": ["bounty"]}, "type": "apply_status", "status": "bounty", "duration_ms": 180000, "target": "toughest_enemies", "only": {"without": ["bounty"]}},
		{"trigger": "on_enemy_fell", "vs": {"statuses": ["bounty"]}, "type": "shards", "amount": 3, "target": "self"}]}
	var hunter: UnitDef = _hoarder([bounty])
	var foes: Array[UnitSetup] = [K.foe(_dummy("small", 300), 2, 4), K.foe(_dummy("big", 900), 3, 4), K.foe(_dummy("mid", 600), 5, 4), K.foe(_dummy("least", 100), 6, 4)]
	var fight: CombatSim = _fight(hunter, 0, foes)
	K.step(fight, 2)
	var big: UnitState = fight.unit_by_id("big")
	assert_not_null(Statuses.find(big, "bounty"))
	assert_not_null(Statuses.find(fight.unit_by_id("mid"), "bounty"), "two Bounties: the two toughest")
	big.last_attacker = "pal"
	big.hp = 0
	K.step(fight, 2)
	assert_not_null(Statuses.find(fight.unit_by_id("small"), "bounty"), "the next toughest without one is the Bounty")
	assert_null(Statuses.find(fight.unit_by_id("least"), "bounty"))
	assert_eq(K.entries(fight, LogEntry.Kind.SHARDS, "hoarder").map(func(entry: LogEntry) -> int: return entry.amount), [3], "it pays, whoever killed it")
	fight.unit_by_id("least").last_attacker = "pal"
	fight.unit_by_id("least").hp = 0
	K.step(fight, 2)
	assert_eq(K.entries(fight, LogEntry.Kind.SHARDS, "hoarder").size(), 1, "an enemy that wasn't a Bounty pays nothing")


func test_a_kills_deed_counts_a_sides_kills_of_a_bounty() -> void:
	var errors: Array[String] = []
	var deed: DeedDef = DeedDef.read(DataReader.new({"text": "Bounties collected", "counts": "kills", "by_allies": true, "statuses": ["bounty"], "threshold": 1}, "deed", errors))
	assert_eq(errors, [] as Array[String])
	var bounty: Dictionary = {"id": "bounty_hunt", "name": "Bounty", "kind": "ability", "effects": [
		{"trigger": "on_fight_start", "type": "apply_status", "status": "bounty", "target": "toughest_enemies"}]}
	var setup: FightSetup = K.fight([K.at(_hoarder([bounty]), 3, 2), K.at(_dummy("pal"), 5, 1)] as Array[UnitSetup],
		[K.foe(_dummy("big", 900), 3, 4), K.foe(_dummy("small", 300), 5, 4)] as Array[UnitSetup])
	setup.heroes[0].tally_keys = ["bounties"] as Array[String]
	setup.heroes[0].tally_counts = [deed] as Array[DeedDef]
	var fight: CombatSim = K.sim(setup)
	K.step(fight, 2)
	for foe_id: String in ["small", "big"]:
		fight.unit_by_id(foe_id).last_attacker = "pal"
		fight.unit_by_id(foe_id).hp = 0
		K.step(fight, 2)
	assert_eq(fight.unit_by_id("hoarder").deeds.amounts, [1], "the pal's kill of the Bounty counts for him; the other kill doesn't")
