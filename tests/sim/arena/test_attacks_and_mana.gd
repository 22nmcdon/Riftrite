extends GutTest
## Mana (docs/plans/rebuild-phase1-arena-sim.md, section 5): its sources,
## the cap, Silence, Stun, and drains.

const K = preload("res://tests/sim/sim_test_kit.gd")


## A unit that stands still with a mana bar and a signature too dear to fire
## during these tests (max 100 unless given).
func _caster(mana: Dictionary, stats: Dictionary = {}) -> UnitDef:
	var bar: Dictionary = {"max": 100}
	bar.merge(mana, true)
	var all_stats: Dictionary = {"hp": 1000, "speed": 0, "range": 2}
	all_stats.merge(stats, true)
	return K.kit("caster", {"stats": all_stats, "mana": bar,
		"signature": {"id": "burst", "name": "Burst", "trigger": {"kind": "mana"}, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}})


func _dummy(extra: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 10000, "speed": 0}, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}
	data.merge(extra, true)
	return K.kit("dummy", data)


func _duel(hero: UnitDef, enemy: UnitDef = null) -> CombatSim:
	return K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(enemy if enemy != null else _dummy(), 3, 4)] as Array[UnitSetup]))


func _source() -> EffectSource:
	return EffectSource.make("tester", "test", "Test")


func test_start_regen_and_attacks() -> void:
	var fight: CombatSim = _duel(_caster({"start": 20, "per_attack": 10, "regen_per_s": 2}))
	var caster: UnitState = fight.units[0]
	assert_eq(caster.mana, 2000, "starts with 20, kept in hundredths")
	K.step(fight, 19)
	assert_eq(caster.mana, 2000 + 19 * 10, "2 a second is 0.1 a tick")
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE, "caster").size(), 1)
	assert_eq(caster.mana, 2000 + 20 * 10 + 1000, "+10 for the attack that fired")


func test_damage_taken_counts_shield_too() -> void:
	var fight: CombatSim = _duel(_caster({"per_10_damage_taken": 1}))
	var caster: UnitState = fight.units[0]
	fight.apply_damage(caster, 25)
	assert_eq(caster.mana, 250, "1 per 10 damage: 2.5 for 25")
	caster.shield = 100
	fight.apply_damage_vs_shield(caster, 30, 5000)
	assert_eq(caster.mana, 250 + 300, "all 30 count, though the Shield soaked it")
	Statuses.apply(fight, caster, "poison", 20, 0, _source())
	K.step(fight, 20)
	assert_eq(caster.mana, 550 + 200, "damage over time counts too")


func test_the_bar_stops_at_full() -> void:
	var fight: CombatSim = _duel(_caster({"start": 95}))
	Mana.gain(fight, fight.units[0], 5000)
	assert_eq(fight.units[0].mana, 10000)
	assert_true(Mana.is_full(fight.units[0]))


func test_silence_blocks_gains_but_stun_doesnt() -> void:
	var fight: CombatSim = _duel(_caster({"per_attack": 10, "per_10_damage_taken": 1, "regen_per_s": 2}))
	var caster: UnitState = fight.units[0]
	Statuses.apply(fight, caster, "silence", 1, 0, _source())
	K.step(fight, 20)
	fight.apply_damage(caster, 50)
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE, "caster").size(), 1, "it still attacks")
	assert_eq(caster.mana, 0, "no regen, no mana from its attack or from damage")
	var stunned: CombatSim = _duel(_caster({"regen_per_s": 2, "per_10_damage_taken": 1}))
	Statuses.apply(stunned, stunned.units[0], "stun", 1, 0, _source())
	K.step(stunned, 10)
	stunned.apply_damage(stunned.units[0], 10)
	assert_eq(stunned.units[0].mana, 10 * 10 + 100, "Stunned, it still regenerates and gains from hits")


func test_units_without_mana_ignore_it() -> void:
	var fight: CombatSim = _duel(K.kit("plain", {"stats": {"hp": 1000, "speed": 0, "range": 2}}))
	var plain: UnitState = fight.units[0]
	K.step(fight, 20)
	fight.apply_damage(plain, 50)
	assert_eq(plain.mana, 0)
	assert_false(Mana.is_full(plain))
	Mana.drain(fight, plain, 10, _source())
	var drained: LogEntry = K.entries(fight, LogEntry.Kind.MANA_DRAIN)[0]
	assert_eq([drained.amount, drained.note], [0, "no mana"])


func test_mana_drain() -> void:
	var witch: UnitDef = _dummy({"basic_attack": {"cooldown_ms": 1000, "effects": [{"type": "mana_drain", "amount": 5, "target": "target"}]}, "stats": {"hp": 10000, "speed": 0, "range": 2}})
	var fight: CombatSim = _duel(_caster({"start": 12}), witch)
	K.step(fight, 22)
	var drained: LogEntry = K.entries(fight, LogEntry.Kind.MANA_DRAIN, "dummy")[0]
	assert_eq(drained.amount, 500)
	assert_eq(fight.units[0].mana, 700)
	assert_string_contains(drained.to_text(), "dummy · Strike drains 5 mana from caster")
	fight.units[0].mana = 250
	Mana.drain(fight, fight.units[0], 5, _source())
	assert_eq([fight.units[0].mana, K.entries(fight, LogEntry.Kind.MANA_DRAIN).back().amount], [0, 250], "it takes what there is")
	assert_eq(Mana.text(250), "2.5")
	assert_eq(Mana.text(1205), "12.05")
