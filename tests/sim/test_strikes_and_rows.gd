extends GutTest
## Multi-strike damage effects and whole-row targets
## (docs/plans/items-and-clarity.md, section 1).

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT: UnitSetup.Row = UnitSetup.Row.FRONT
const BACK: UnitSetup.Row = UnitSetup.Row.BACK
const BIG_HP: int = 100000


## An ability that fires every 5s: `hits` strikes of 10, 200ms apart.
func _flurry(hits: int = 3, target: String = "enemy_front", extra: Array = []) -> ItemDef:
	var effects: Array = [{"trigger": "on_fire", "type": "damage", "amount": 10, "target": target, "hits": hits, "hit_interval_ms": 200}]
	effects.append_array(extra)
	return K.item("flurry", {"name": "Flurry", "cooldown_ms": 5000, "effects": effects})


## A hero who only uses `item` (its basic attack never matters).
func _hero(item: ItemDef, hp: int = BIG_HP) -> UnitSetup:
	return K.unit("hero", hp, FRONT, [item], K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)}))


func _entries(sim: CombatSim, kind: LogEntry.Kind, item_id: String = "flurry") -> Array[LogEntry]:
	return sim.combat_log.entries.filter(func(entry: LogEntry) -> bool: return entry.kind == kind and entry.source_item == item_id)


func _run_ticks(sim: CombatSim, ticks: int) -> void:
	for i: int in ticks:
		sim.step()


func test_a_fire_lands_its_strikes_spaced_out() -> void:
	var sim := CombatSim.new(K.fight([_hero(_flurry())], [K.dummy("foe", BIG_HP)]), K.content())
	_run_ticks(sim, 130)
	var fires: Array[LogEntry] = _entries(sim, LogEntry.Kind.FIRE)
	var hits: Array[LogEntry] = _entries(sim, LogEntry.Kind.DAMAGE)
	assert_eq(fires.size(), 1, "one fire")
	assert_eq(hits.size(), 3, "three strikes")
	var ticks: Array[int] = []
	for hit: LogEntry in hits:
		ticks.append(hit.tick)
	assert_eq(ticks, [fires[0].tick, fires[0].tick + 4, fires[0].tick + 8] as Array[int], "200ms (4 ticks) apart, the first as it fires")
	for hit: LogEntry in hits:
		assert_eq([hit.target, hit.amount], ["foe", 10])
	assert_eq(sim.pending_strikes.size(), 0, "nothing left waiting")


func test_each_strike_is_a_hit_and_aims_again() -> void:
	var bleed: Array = [{"trigger": "on_hit", "type": "apply_status", "status": "bleed", "stacks": 1, "target": "hit_target"}]
	var sim := CombatSim.new(K.fight([_hero(_flurry(3, "enemy_front", bleed))], [K.dummy("weak", 15, FRONT), K.dummy("back", BIG_HP, BACK)]), K.content())
	_run_ticks(sim, 130)
	var hits: Array[LogEntry] = _entries(sim, LogEntry.Kind.DAMAGE)
	var targets: Array[String] = []
	for hit: LogEntry in hits:
		targets.append(hit.target)
	assert_eq(targets, ["weak", "weak", "back"] as Array[String], "once the front falls, the next strike finds the back row")
	var sturdy := CombatSim.new(K.fight([_hero(_flurry(3, "enemy_front", bleed))], [K.dummy("foe", BIG_HP)]), K.content())
	_run_ticks(sturdy, 130)
	assert_eq(_entries(sturdy, LogEntry.Kind.STATUS_APPLIED).size(), 3, "every strike sets off on_hit")


func test_strikes_stop_when_the_holder_falls() -> void:
	var sim := CombatSim.new(K.fight([_hero(_flurry(4))], [K.dummy("foe", BIG_HP)]), K.content())
	while _entries(sim, LogEntry.Kind.FIRE).is_empty():
		sim.step()
	assert_eq(sim.pending_strikes.size(), 3, "three more strikes queued")
	sim.unit_by_id("hero").hp = 0
	sim.step()
	_run_ticks(sim, 20)
	assert_eq(_entries(sim, LogEntry.Kind.DAMAGE).size(), 1, "only the first strike landed")


func test_strikes_replay_identically() -> void:
	var logs: Array[String] = []
	for i: int in 2:
		var crit: ItemDef = K.item("flurry", {"name": "Flurry", "cooldown_ms": 3000, "crit_chance_bp": 5000,
			"effects": [{"trigger": "on_fire", "type": "damage", "amount": 7, "target": "enemy_random", "hits": 5, "hit_interval_ms": 150}]})
		logs.append(CombatSim.run(K.fight([_hero(crit)], [K.dummy("a", 400), K.dummy("b", 400)], 9), K.content()).combat_log.to_text())
	assert_eq(logs[0], logs[1])


func test_strike_fields_are_checked() -> void:
	var cases: Dictionary = {
		"only damage effects can land several \"hits\"": {"trigger": "on_fire", "type": "heal", "amount": 5, "target": "self", "hits": 2, "hit_interval_ms": 100},
		"several \"hits\" only work on on_fire effects": {"trigger": "on_hit", "type": "damage", "amount": 5, "target": "hit_target", "hits": 2, "hit_interval_ms": 100},
		"missing required key \"hit_interval_ms\"": {"trigger": "on_fire", "type": "damage", "amount": 5, "target": "enemy_front", "hits": 2},
		"hits: 13 is out of range (1 to 12)": {"trigger": "on_fire", "type": "damage", "amount": 5, "target": "enemy_front", "hits": 13, "hit_interval_ms": 100},
	}
	for expected: String in cases:
		var errors: Array[String] = []
		EffectDef.read(DataReader.new(cases[expected], "effect", errors))
		assert_true(errors.any(func(message: String) -> bool: return message.contains(expected)), "%s: %s" % [expected, str(errors)])
	var good: Array[String] = []
	var def: EffectDef = EffectDef.read(DataReader.new({"trigger": "on_fire", "type": "damage", "amount": 5, "target": "enemy_front", "hits": 6, "hit_interval_ms": 150}, "effect", good))
	assert_eq(good, [] as Array[String])
	assert_eq([def.hits, def.hit_interval_ticks], [6, 3])


# --- whole-row targets ------------------------------------------------------------

func test_row_targets_hit_every_enemy_in_that_row() -> void:
	var enemies: Array[UnitSetup] = [K.dummy("f1", BIG_HP, FRONT), K.dummy("f2", BIG_HP, FRONT), K.dummy("b1", BIG_HP, BACK)]
	for case: Array in [["enemy_front_row", ["f1", "f2"]], ["enemy_back_row", ["b1"]]]:
		var sweep: ItemDef = K.item("flurry", {"name": "Sweep", "cooldown_ms": 1000, "effects": K.damage(3, case[0])})
		var sim := CombatSim.new(K.fight([_hero(sweep)], enemies), K.content())
		_run_ticks(sim, 21)
		var targets: Array[String] = []
		for hit: LogEntry in _entries(sim, LogEntry.Kind.DAMAGE):
			targets.append(hit.target)
		assert_eq(targets, case[1] as Array[String], case[0])


func test_a_row_target_moves_to_the_other_row_once_its_row_is_empty() -> void:
	var sweep: ItemDef = K.item("flurry", {"name": "Sweep", "cooldown_ms": 1000, "effects": K.damage(3, "enemy_front_row")})
	var sim := CombatSim.new(K.fight([_hero(sweep)], [K.dummy("f1", 2, FRONT), K.dummy("b1", BIG_HP, BACK), K.dummy("b2", BIG_HP, BACK)]), K.content())
	_run_ticks(sim, 41)
	var targets: Array[String] = []
	for hit: LogEntry in _entries(sim, LogEntry.Kind.DAMAGE):
		targets.append(hit.target)
	assert_eq(targets, ["f1", "b1", "b2"] as Array[String], "the front falls, then the sweep takes the back row")
	var back: ItemDef = K.item("flurry", {"name": "Volley", "cooldown_ms": 1000, "effects": K.damage(3, "enemy_back_row")})
	var front_only := CombatSim.new(K.fight([_hero(back)], [K.dummy("f1", BIG_HP, FRONT)]), K.content())
	_run_ticks(front_only, 21)
	assert_eq(_entries(front_only, LogEntry.Kind.DAMAGE)[0].target, "f1", "no back row: the front row")
