extends GutTest
## The damage rule (docs/plans/rebuild-phase5c-combos.md, step 1): bonuses of
## one kind add, the kinds multiply, and the number is rounded once.

const K = preload("res://tests/sim/sim_test_kit.gd")


func _hero(passives: Array = [], attack: Dictionary = {}) -> UnitDef:
	var basic: Dictionary = {"cooldown_ms": 1000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}
	basic.merge(attack, true)
	return K.kit("hero", {"stats": {"hp": 1000, "atk": 100, "speed": 0, "range": 2}, "basic_attack": basic, "passives": passives})


func _dummy() -> UnitDef:
	return K.kit("dummy", {"stats": {"hp": 100000, "speed": 0, "range": 2}, "basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


func _aura(part_id: String, stat: String, value: int) -> Dictionary:
	return {"id": part_id, "name": part_id.capitalize(), "kind": "aura", "aura": {"target": "holder", "stat": stat, "value": value}}


func _duel(hero: UnitDef) -> CombatSim:
	return K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_dummy(), 3, 4)] as Array[UnitSetup]))


func _source() -> EffectSource:
	return EffectSource.make("hero", "hero_attack", "Strike")


func test_the_rule_by_itself() -> void:
	assert_eq(DamageRule.apply(1000, 0), 1000, "no bonus, no change")
	assert_eq(DamageRule.apply(1000, 1500 + 2000), 1350, "one kind: +15% and +20% add")
	assert_eq(DamageRule.apply(1000, 2000, 0, 1500), 1380, "two kinds multiply: x1.2 x1.15")
	assert_eq(DamageRule.apply(1000, 0, 5000, 1500, 1000), 1898, "crit, vulnerability, and relic: x1.5 x1.15 x1.1")
	assert_eq(DamageRule.apply(1000, -200 + 2000), 1180, "a cost is a bonus of its kind: -2% and +20% make +18%")
	assert_eq(DamageRule.apply(1000, -20000), 100, "a kind never takes more than 90% off")
	assert_eq(DamageRule.apply(7, 0, 5000, 1500), 12, "rounded once: 7 x 1.725 is 12.075 (step by step it was 11, then 13)")


func test_a_hit_takes_its_power_its_crit_and_the_mark() -> void:
	var fight: CombatSim = _duel(_hero())
	var dummy: UnitState = fight.units[1]
	var plain: int = EffectRunner.deal_hit(fight, _source(), dummy, 1000, false)
	assert_eq(plain, 1000)
	Statuses.apply(fight, dummy, "marked", 1, 0, _source())
	assert_eq(EffectRunner.deal_hit(fight, _source(), dummy, 1000, false), 1150, "Marked: +15%")
	assert_eq(EffectRunner.deal_hit(fight, _source(), dummy, 1000, false, 2000), 1380, "+20% power, times the Mark")
	assert_eq(EffectRunner.deal_hit(fight, _source(), dummy, 1000, true, 2000), 2070, "and a crit: x1.2 x1.5 x1.15")


func test_power_from_auras_and_kit_mods_adds_up() -> void:
	var boost: KitMod = KitMod.read(DataReader.new({"on": [{"slot": "basic_attack", "amount_bp": 12000}]}, "mod", [] as Array[String]))
	var hero: UnitDef = boost.apply(_hero([_aura("fury", "damage_bp", 11000), _aura("cost", "damage_bp", 9800)]))
	assert_eq(hero.basic_attack.effects[0].power_bp, 2000, "the mod is power on the effect, not a bigger number")
	assert_eq(hero.basic_attack.effects[0].scaling[UnitStats.Stat.ATK], 10000)
	var fight: CombatSim = _duel(hero)
	K.step(fight, 20)
	var hit: LogEntry = K.entries(fight, LogEntry.Kind.DAMAGE, "hero")[0]
	assert_eq(hit.amount, 128, "100 ATK x (1 + 10% - 2% + 20%): one kind, added")


func test_two_stat_auras_add() -> void:
	var fight: CombatSim = _duel(_hero([_aura("one", "atk_bp", 11000), _aura("two", "atk_bp", 11000)]))
	K.step(fight, 1)
	assert_eq(fight.units[0].stats.get_stat(UnitStats.Stat.ATK), 120, "+10% and +10% ATK make +20%")


func test_heals_and_shields_take_power_and_healing_taken() -> void:
	var healer: UnitDef = _hero([_aura("glow", "heal_bp", 12000), _aura("open", "healing_taken_bp", 15000), _aura("ward", "shield_bp", 13000)],
		{"effects": [{"type": "heal", "amount": 100, "target": "self"}, {"type": "shield", "amount": 100, "target": "self"}]})
	var fight: CombatSim = _duel(healer)
	fight.units[0].hp = 500
	K.step(fight, 20)
	assert_eq(fight.units[0].hp, 680, "100 x1.2 (power) x1.5 (healing taken)")
	assert_eq(fight.units[0].shield, 130, "100 x1.3 (power)")


func test_damage_over_time_on_a_marked_unit() -> void:
	var fight: CombatSim = _duel(_hero())
	var dummy: UnitState = fight.units[1]
	Statuses.apply(fight, dummy, "marked", 1, 0, _source())
	Statuses.apply(fight, dummy, "poison", 10, 0, _source())
	var hp: int = dummy.hp
	K.step(fight, FixedMath.TICKS_PER_SECOND)
	var ticks: Array[LogEntry] = K.entries(fight, LogEntry.Kind.STATUS_DAMAGE)
	assert_gt(ticks.size(), 0)
	var per_stack: int = fight.content.statuses["poison"].damage_per_stack
	assert_eq(ticks[0].amount, DamageRule.apply(10 * per_stack, 0, 0, 1500), "the Mark is the target's side")
	assert_lt(dummy.hp, hp)
