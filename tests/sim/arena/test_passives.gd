extends GutTest
## Passives (PartDef, Passives; docs/plans/rebuild-phase1-arena-sim.md,
## section 2): auras, ability passives on events, and status swaps.

const K = preload("res://tests/sim/sim_test_kit.gd")


## A standing hero (speed 0, range 2) whose attack lands at once every
## `cooldown_ms` for base damage + 100% ATK, with the given passives.
func _hero(passives: Array, stats: Dictionary = {}, attack: Dictionary = {}, hero_id: String = "hero") -> UnitDef:
	var all_stats: Dictionary = {"hp": 1000, "atk": 10, "speed": 0, "range": 2}
	all_stats.merge(stats, true)
	var basic: Dictionary = {"cooldown_ms": 1000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}
	basic.merge(attack, true)
	return K.kit(hero_id, {"stats": all_stats, "basic_attack": basic, "passives": passives})


func _dummy(attack: Dictionary = {}, extra: Dictionary = {}) -> UnitDef:
	var basic: Dictionary = {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}
	basic.merge(attack, true)
	var data: Dictionary = {"stats": {"hp": 10000, "speed": 0, "range": 2}, "basic_attack": basic}
	data.merge(extra, true)
	return K.kit("dummy", data)


func _aura(part_id: String, target: String, stat: String, value: int, extra: Dictionary = {}) -> Dictionary:
	var aura: Dictionary = {"target": target, "stat": stat, "value": value}
	aura.merge(extra, true)
	return {"id": part_id, "name": part_id.capitalize(), "kind": "aura", "aura": aura}


func _duel(hero: UnitDef, enemy: UnitDef = null) -> CombatSim:
	return K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(enemy if enemy != null else _dummy(), 3, 4)] as Array[UnitSetup]))


func _hits(fight: CombatSim, unit_id: String, ability: String = "") -> Array:
	return K.entries(fight, LogEntry.Kind.DAMAGE, unit_id).filter(func(entry: LogEntry) -> bool: return ability.is_empty() or entry.source_ability == ability).map(func(entry: LogEntry) -> Array: return [entry.tick, entry.amount])


# --- reading ---------------------------------------------------------------------------

func test_reading_passives() -> void:
	var errors: Array[String] = []
	var data: Dictionary = {"id": "x", "name": "X", "kind": "replace_status", "from": "burn", "to": "poison"}
	var swap: PartDef = PartDef.read(DataReader.new(data, "part", errors))
	assert_eq([swap.kind, swap.from_status, swap.to_status], [PartDef.Kind.REPLACE_STATUS, "burn", "poison"])
	var aura: PartDef = PartDef.read(DataReader.new(_aura("fury", "holder", "atk_bp", 15000), "part", errors))
	assert_eq([aura.kind, aura.aura.stat, aura.aura.value], [PartDef.Kind.AURA, AuraDef.Stat.ATK_BP, 15000])
	var spite: PartDef = PartDef.read(DataReader.new({"id": "spite", "name": "Spite", "kind": "ability",
		"effects": [{"trigger": "on_hit_taken", "every": 2, "type": "damage", "amount": 5, "target": "hit_target"}]}, "part", errors))
	assert_eq([spite.ability.id, spite.ability.name, spite.ability.effects[0].every, spite.ability.is_shot(5)], ["spite", "Spite", 2, false], "it never flies")
	assert_eq(errors, [] as Array[String])
	var bad: Array[String] = []
	PartDef.read(DataReader.new({"id": "a", "name": "A", "kind": "ability", "effects": [{"type": "damage", "amount": 5, "target": "target"}]}, "part", bad))
	PartDef.read(DataReader.new({"id": "b", "name": "B", "kind": "ability"}, "part", bad))
	PartDef.read(DataReader.new({"id": "c", "name": "C", "kind": "grant"}, "part", bad))
	PartDef.read(DataReader.new({"id": "d", "name": "D", "kind": "aura"}, "part", bad))
	for expected: String in ["a passive's effects need a passive trigger", "an ability passive needs effects", "kind: unknown value \"grant\"", "missing required key \"aura\""]:
		assert_true(bad.any(func(message: String) -> bool: return message.contains(expected)), "expected '%s' in %s" % [expected, bad])


func test_a_fight_checks_the_statuses_a_kit_names() -> void:
	var hero: UnitDef = _hero([{"id": "embers", "name": "Embers", "kind": "replace_status", "from": "burn", "to": "blight"}],
		{}, {"effects": [{"type": "apply_status", "status": "frost", "target": "target"}]})
	var errors: Array[String] = K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_dummy(), 3, 4)] as Array[UnitSetup]).validate(K.content())
	assert_true(errors.has("hero at (3, 2) names an unknown status \"frost\""), str(errors))
	assert_true(errors.has("hero at (3, 2) names an unknown status \"blight\""), str(errors))


# --- auras -------------------------------------------------------------------------

func test_an_aura_boosts_its_holder() -> void:
	var fight: CombatSim = _duel(_hero([_aura("fury", "holder", "atk_bp", 15000)]))
	var hero: UnitState = fight.units[0]
	assert_eq([hero.base_stats.get_stat(UnitStats.Stat.ATK), hero.stats.get_stat(UnitStats.Stat.ATK)], [10, 15])
	var started: LogEntry = K.entries(fight, LogEntry.Kind.AURA)[0]
	assert_eq(started.to_text(), "[0.00s] hero · Fury aura starts: x1.5 ATK for its holder")
	K.step(fight, 20)
	assert_eq(_hits(fight, "hero"), [[20, 15]])
	assert_eq(fight.units[1].stats.get_stat(UnitStats.Stat.ATK), fight.units[1].base_stats.get_stat(UnitStats.Stat.ATK), "not its enemies")


func test_an_aura_for_all_allies_ends_when_its_holder_falls() -> void:
	var banner: UnitDef = _hero([_aura("banner", "all_allies", "damage_bp", 20000)], {}, {}, "bearer")
	var striker: UnitDef = _hero([], {}, {}, "striker")
	# (4, 4) is in reach of both.
	var fight: CombatSim = K.sim(K.fight([K.at(banner, 3, 2), K.at(striker, 4, 2)] as Array[UnitSetup], [K.foe(_dummy(), 4, 4)] as Array[UnitSetup]))
	K.step(fight, 20)
	assert_eq(_hits(fight, "striker"), [[20, 20]], "x2 damage")
	fight.unit_by_id("bearer").hp = 0
	fight.step()
	var ended: LogEntry = K.entries(fight, LogEntry.Kind.AURA).back()
	assert_eq([ended.tick, ended.note, ended.source_unit], [21, "ends", "bearer"])
	K.step(fight, 19)
	assert_eq(_hits(fight, "striker")[1], [40, 10], "back to x1")


func test_aura_windows() -> void:
	var fight: CombatSim = _duel(_hero([_aura("rush", "holder", "atk_bp", 20000, {"window": {"from_ms": 500, "until_ms": 1000}})]))
	var hero: UnitState = fight.units[0]
	assert_eq(K.entries(fight, LogEntry.Kind.AURA).size(), 0, "not open yet")
	K.step(fight, 9)
	assert_eq(hero.stats.get_stat(UnitStats.Stat.ATK), 10)
	fight.step()
	assert_eq(hero.stats.get_stat(UnitStats.Stat.ATK), 20)
	K.step(fight, 10)
	assert_eq(hero.stats.get_stat(UnitStats.Stat.ATK), 10)
	assert_eq(K.entries(fight, LogEntry.Kind.AURA).map(func(entry: LogEntry) -> Array: return [entry.tick, entry.note]), [[10, "starts: x2 ATK for its holder"], [20, "ends"]])


func test_output_and_rate_auras() -> void:
	var healer: UnitDef = _hero([_aura("glow", "holder", "heal_bp", 15000), _aura("ward", "holder", "shield_bp", 20000), _aura("rot", "holder", "over_time_bp", 30000)],
		{}, {"effects": [{"type": "heal", "amount": 10, "target": "self"}, {"type": "shield", "amount": 10, "target": "self"}, {"type": "apply_status", "status": "poison", "stacks": 2, "target": "target"}]})
	var fight: CombatSim = _duel(healer)
	fight.units[0].hp = 500
	K.step(fight, 20)
	assert_eq(fight.units[0].hp, 515, "x1.5 healing")
	assert_eq(fight.units[0].shield, 20, "x2 shields")
	assert_eq(Statuses.find(fight.units[1], "poison").total_stacks(), 6, "x3 damage-over-time stacks")
	var quick: CombatSim = _duel(_hero([_aura("haste", "holder", "cooldown_bp", -5000), _aura("eye", "holder", "crit_chance_bp", 10000)]))
	K.step(quick, 10)
	var hit: LogEntry = K.entries(quick, LogEntry.Kind.DAMAGE, "hero")[0]
	assert_eq([hit.tick, hit.crit], [10, true], "half the cooldown, and +100% crit chance")
	var stacked: CombatSim = _duel(_hero([_aura("one", "holder", "atk_bp", 15000), _aura("two", "holder", "atk_bp", 20000)]))
	assert_eq(stacked.units[0].stats.get_stat(UnitStats.Stat.ATK), 30, "auras on one stat multiply")
	var added: CombatSim = _duel(_hero([_aura("one", "holder", "cooldown_bp", -2500), _aura("two", "holder", "cooldown_bp", -2500)]))
	K.step(added, 10)
	assert_eq(_hits(added, "hero"), [[10, 10]], "cooldown and crit chance auras add: -25% twice is -50%")
	# ATSP 100 attacks twice as fast (1 s cooldown in 10 ticks); x2 ATSP, three times as fast.
	var hasted: CombatSim = _duel(_hero([_aura("rush", "holder", "atsp_bp", 20000)], {"atsp": 100}))
	K.step(hasted, 7)
	assert_eq(_hits(hasted, "hero"), [[7, 10]], "an ATSP aura speeds its attack")


# --- ability passives ----------------------------------------------------------------

func test_an_ability_passive_answers_its_events() -> void:
	var biter: UnitDef = _dummy({"cooldown_ms": 50, "effects": [{"type": "damage", "amount": 10, "target": "target"}]},
		{"signature": {"id": "grudge", "name": "Grudge", "trigger": {"kind": "count", "event": "on_hit_taken"}, "targeting": "self", "effects": [{"type": "shield", "amount": 1, "target": "target"}]}})
	var hero: UnitDef = _hero([{"id": "spite", "name": "Spite", "kind": "ability", "effects": [
		{"trigger": "on_hit_taken", "every": 2, "type": "damage", "amount": 7, "target": "hit_target"},
		{"trigger": "on_hit_taken", "type": "shield", "amount_bp_of_damage": 5000, "target": "self"}]}], {}, {"cooldown_ms": 60000})
	var fight: CombatSim = _duel(hero, biter)
	K.step(fight, 6)
	assert_eq(_hits(fight, "hero", "spite"), [[2, 7], [4, 7], [6, 7]], "every 2nd hit it takes, read at the end of the tick")
	var spite: LogEntry = K.entries(fight, LogEntry.Kind.DAMAGE, "hero")[0]
	assert_eq(spite.target, "dummy")
	assert_true(spite.from_event)
	assert_eq(fight.units[0].shield, 6 * 5 - 5 * 6 + 5, "half of each 10-damage hit as Shield (each soaked by the next)")
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE, "dummy").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "grudge").size(), 0, "what an event effect does sets off no events")


func test_an_event_effect_keeps_to_its_window() -> void:
	var biter: UnitDef = _dummy({"cooldown_ms": 50, "effects": [{"type": "damage", "amount": 1, "target": "target"}]})
	var hero: UnitDef = _hero([{"id": "spite", "name": "Spite", "kind": "ability", "effects": [
		{"trigger": "on_hit_taken", "type": "damage", "amount": 7, "target": "hit_target", "window": {"until_ms": 150}}]}], {}, {"cooldown_ms": 60000})
	var fight: CombatSim = _duel(hero, biter)
	K.step(fight, 6)
	assert_eq(_hits(fight, "hero", "spite"), [[1, 7], [2, 7]], "only in its first 0.15s")


func test_the_other_events() -> void:
	var hero: UnitDef = _hero([{"id": "kit", "name": "Kit", "kind": "ability", "effects": [
		{"trigger": "on_basic_attack", "every": 2, "type": "heal", "amount": 1, "target": "self"},
		{"trigger": "on_status", "statuses": ["slow"], "type": "damage", "amount": 3, "target": "hit_target"},
		{"trigger": "on_holder_crit", "type": "shield", "amount": 1, "target": "self"},
		{"trigger": "on_kill", "type": "shield", "amount": 100, "target": "self"}]}],
		{"crit": 100}, {"cooldown_ms": 500, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}},
			{"type": "apply_status", "status": "burn", "target": "target"}, {"type": "apply_status", "status": "slow", "target": "target"}]})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_dummy(), 3, 4), K.foe(_dummy(), 7, 6, "far")] as Array[UnitSetup]))
	fight.units[0].hp = 500
	K.step(fight, 20)
	assert_eq(K.entries(fight, LogEntry.Kind.HEAL, "hero").size(), 1, "every 2nd basic attack")
	assert_eq(_hits(fight, "hero", "kit"), [[10, 5], [20, 5]], "on Slow, not on Burn (and it crits: 3 x1.5)")
	assert_eq(fight.units[0].shield, 2, "each crit")
	fight.units[1].hp = 1
	K.step(fight, 10)
	assert_eq(fight.units[0].shield, 3 + 100, "and a kill")


func test_on_heal_on_shielded_and_on_ability() -> void:
	var hero: UnitDef = _hero([{"id": "kit", "name": "Kit", "kind": "ability", "effects": [
		{"trigger": "on_heal", "type": "damage", "amount": 2, "target": "target"},
		{"trigger": "on_shielded", "type": "damage", "amount": 4, "target": "target"},
		{"trigger": "on_ability", "type": "damage", "amount": 8, "target": "target"}]}],
		{}, {"cooldown_ms": 60000})
	var data: Dictionary = {"stats": {"hp": 1000, "atk": 10, "speed": 0, "range": 2}, "passives": [], "signature": {"id": "rally", "name": "Rally", "trigger": {"kind": "fight_start"}, "targeting": "self",
		"effects": [{"type": "heal", "amount": 5, "target": "target"}, {"type": "shield", "amount": 5, "target": "target"}]}}
	hero.signature = K.kit("tmp", data).signature
	var fight: CombatSim = _duel(hero)
	fight.units[0].hp = 500
	K.step(fight, 2)
	assert_eq(_hits(fight, "hero", "kit").map(func(hit: Array) -> int: return hit[1]), [8, 2, 4], "its signature firing, then its heal and its Shield (log order), each at its target")
	var full: CombatSim = _duel(hero)
	K.step(full, 2)
	assert_eq(_hits(full, "hero", "kit").map(func(hit: Array) -> int: return hit[1]), [8, 4], "a heal at full HP heals nothing, so it's no on_heal")


func test_replace_status() -> void:
	var hero: UnitDef = _hero([{"id": "venom", "name": "Venom", "kind": "replace_status", "from": "burn", "to": "poison"}],
		{}, {"effects": [{"type": "apply_status", "status": "burn", "stacks": 4, "target": "target"}]})
	var fight: CombatSim = _duel(hero)
	K.step(fight, 20)
	assert_null(Statuses.find(fight.units[1], "burn"))
	assert_eq(Statuses.find(fight.units[1], "poison").total_stacks(), 4)
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "hero")[0].status, "poison")
