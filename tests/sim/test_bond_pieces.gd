extends GutTest
## The bond relics' pieces (docs/plans/rebuild-phase5c-combos.md, step 5d,
## section 13.3), each in a small fight: an aura behind an allied wall,
## on_knockback, and on_guard with its cooldown for each ally.

const K = preload("res://tests/sim/sim_test_kit.gd")


func _hero(passives: Array = [], attack: Dictionary = {}, hero_id: String = "hero", extra: Dictionary = {}) -> UnitDef:
	var basic: Dictionary = {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}
	basic.merge(attack, true)
	var kit: Dictionary = {"stats": {"hp": 1000, "atk": 10, "speed": 0, "range": 2}, "basic_attack": basic, "passives": passives}
	kit.merge(extra, true)
	return K.kit(hero_id, kit)


func _dummy(dummy_id: String = "dummy") -> UnitDef:
	return K.kit(dummy_id, {"stats": {"hp": 100000, "speed": 0, "range": 2},
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


func _from(unit_id: String) -> EffectSource:
	return EffectSource.make(unit_id, unit_id + "_attack", "Strike")


func _read(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	PartDef.read(DataReader.new({"id": "p", "name": "P", "kind": "ability", "effects": [data]}, "part", errors))
	return errors


func test_reading_the_bond_pieces() -> void:
	assert_eq(_read({"trigger": "on_knockback", "type": "apply_status", "status": "root", "target": "hit_target"}), [] as Array[String])
	assert_eq(_read({"trigger": "on_guard", "cooldown_per_unit_ms": 2000, "type": "shield", "amount_bp_of_max_hp": 500, "target": "hit_target"}), [] as Array[String])
	assert_false(_read({"trigger": "on_basic_attack", "cooldown_per_unit_ms": 2000, "type": "shield", "amount": 1, "target": "self"}).is_empty(),
		"a trigger that names no unit takes no cooldown per unit")
	var errors: Array[String] = []
	AuraDef.read(DataReader.new({"target": "holder", "stat": "range", "value": 1, "while": "behind_wall", "within_hexes": 3}, "aura", errors))
	assert_eq(errors, [] as Array[String])


# --- behind an allied wall (The Watchtower Stone) -------------------------------------------

func test_an_aura_behind_an_allied_wall() -> void:
	var watch: Array = [{"id": "watch", "name": "Watch", "kind": "aura", "aura": {"target": "holder", "stat": "range", "value": 1, "while": "behind_wall", "within_hexes": 3}}]
	var fight: CombatSim = K.sim(K.fight([K.at(_hero(watch), 3, 2)] as Array[UnitSetup], [K.foe(_dummy(), 3, 5)] as Array[UnitSetup]))
	var hero: UnitState = fight.unit_by_id("hero")
	var range: int = hero.stats.get_stat(UnitStats.Stat.RANGE)
	var line: Vector2i = hero.pos + Vector2i(0, 1000)
	var wall := Walls.Wall.new()
	wall.side = EffectSource.Team.HEROES
	wall.a = line + Vector2i(-1000, 0)
	wall.b = line + Vector2i(1000, 0)
	wall.back = hero.pos
	wall.until_tick = 20
	fight.walls.append(wall)
	fight.step()
	assert_eq(hero.stats.get_stat(UnitStats.Stat.RANGE), range + 1, "behind it: on its raiser's side, between its ends, within 3 hexes")
	hero.pos = line + Vector2i(0, 500)
	fight.step()
	assert_eq(hero.stats.get_stat(UnitStats.Stat.RANGE), range, "in front of it: off")
	hero.pos = line + Vector2i(3000, -500)
	fight.step()
	assert_eq(hero.stats.get_stat(UnitStats.Stat.RANGE), range, "past its end: off")
	hero.pos = line + Vector2i(0, -500)
	fight.step()
	assert_eq(hero.stats.get_stat(UnitStats.Stat.RANGE), range + 1)
	K.step(fight, 20)
	assert_eq(hero.stats.get_stat(UnitStats.Stat.RANGE), range, "the wall fell")
	wall.side = EffectSource.Team.ENEMIES
	wall.until_tick = 1000
	fight.step()
	assert_eq(hero.stats.get_stat(UnitStats.Stat.RANGE), range, "an enemy's wall is no cover")


# --- on_knockback (The Hunter's Anvil) ---------------------------------------------------

func test_on_knockback_names_the_enemy_knocked_back() -> void:
	var anvil: Array = [{"id": "anvil", "name": "Anvil", "kind": "ability",
		"effects": [{"trigger": "on_knockback", "type": "apply_status", "status": "root", "duration_ms": 1000, "target": "hit_target"}]}]
	var hero: UnitDef = _hero(anvil, {"cooldown_ms": 50, "effects": [{"type": "knockback", "hexes": 1, "target": "target"}]})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_dummy(), 3, 4)] as Array[UnitSetup]))
	K.step(fight, 1)
	var rooted: Array[LogEntry] = K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "hero")
	assert_eq(rooted.map(func(entry: LogEntry) -> Array: return [entry.target, entry.status]), [["dummy", "root"]], "Rooted where it landed")
	var puller: UnitDef = _hero(anvil, {"cooldown_ms": 50, "effects": [{"type": "pull", "hexes": 1, "target": "target"}]})
	var pulled: CombatSim = K.sim(K.fight([K.at(puller, 3, 1)] as Array[UnitSetup], [K.foe(_dummy(), 3, 4)] as Array[UnitSetup]))
	K.step(pulled, 1)
	assert_eq(K.entries(pulled, LogEntry.Kind.STATUS_APPLIED).size(), 0, "a pull isn't a knockback")


# --- on_guard and its cooldown (The Hearth-Woven Mail) --------------------------------------

func test_on_guard_names_the_ally_once_every_while() -> void:
	var mail: Array = [{"id": "guard", "name": "Guard", "kind": "guard", "share_pct": 30, "within_hexes": 2, "covers": "all"},
		{"id": "mail", "name": "Mail", "kind": "ability",
		"effects": [{"trigger": "on_guard", "cooldown_per_unit_ms": 2000, "type": "shield", "amount_bp_of_max_hp": 500, "target": "hit_target"}]}]
	var fight: CombatSim = K.sim(K.fight([K.at(_hero(mail, {}, "warden"), 3, 2, "warden"), K.at(_hero([], {}, "ward"), 3, 1, "ward")] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 5)] as Array[UnitSetup]))
	var ward: UnitState = fight.unit_by_id("ward")
	EffectRunner.deal_hit(fight, _from("dummy"), ward, 100, false)
	fight.step()
	assert_eq(ward.shield, 50, "5% of the ally's 1000 max HP")
	EffectRunner.deal_hit(fight, _from("dummy"), ward, 100, false)
	K.step(fight, 10)
	assert_eq(K.entries(fight, LogEntry.Kind.SHIELD).size(), 1, "not again within 2s")
	K.step(fight, 30)
	EffectRunner.deal_hit(fight, _from("dummy"), ward, 100, false)
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.SHIELD).size(), 2, "again after 2s")
