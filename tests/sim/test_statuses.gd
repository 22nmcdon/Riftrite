extends GutTest
## Status mechanics, using items that apply statuses directly.

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT := UnitSetup.Row.FRONT
const BIG_HP: int = 10000000


func _applier(item_id: String, status: String, cooldown_ms: int = 1000, stacks: int = 1) -> ItemDef:
	return K.item(item_id, {"cooldown_ms": cooldown_ms, "effects": [
		{"trigger": "on_fire", "type": "apply_status", "status": status, "stacks": stacks, "target": "enemy_front"},
	]})


func _idle_hero(items: Array) -> UnitSetup:
	return K.unit("hero", BIG_HP, FRONT, items, K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)}))


func _status_entries(result: FightResult, kind: LogEntry.Kind, status: String) -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in result.combat_log.of_kind(kind):
		if entry.status == status:
			found.append(entry)
	return found


# --- damage over time -----------------------------------------------------------------

func test_burn_ticks_twice_a_second_and_fades() -> void:
	var result: FightResult = K.run([_idle_hero([_applier("torch", "burn", 60000)])], [K.dummy("foe", BIG_HP)])
	# The torch fires once, at 60s (tick 1200): 1 stack, 1 damage per stack every 0.5s,
	# then it loses 5% of its stacks, rounded up, so the single stack is gone.
	var damage: Array[LogEntry] = _status_entries(result, LogEntry.Kind.STATUS_DAMAGE, "burn")
	assert_eq([damage[0].tick, damage[0].amount], [1210, 1])
	assert_eq(_status_entries(result, LogEntry.Kind.STATUS_ENDED, "burn")[0].tick, 1210)


func test_burn_stacks_build_up_and_lose_five_percent() -> void:
	var result: FightResult = K.run([_idle_hero([_applier("torch", "burn", 250, 20)])], [K.dummy("foe", BIG_HP)])
	# 20 stacks land at ticks 5, 10, 15, 20. Damage at 15: 40 stacks, then -2 (5%).
	# At 25: 38 + 20 + 20 = 78.
	var damage: Array[LogEntry] = _status_entries(result, LogEntry.Kind.STATUS_DAMAGE, "burn")
	assert_eq([[damage[0].tick, damage[0].amount], [damage[1].tick, damage[1].amount]], [[15, 40], [25, 78]])


func test_damage_over_time_is_credited_to_each_source() -> void:
	var a: UnitSetup = K.unit("a", BIG_HP, FRONT, [_applier("torch", "burn")], K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)}))
	var b: UnitSetup = K.unit("b", BIG_HP, FRONT, [_applier("brand", "burn")], K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)}))
	var result: FightResult = K.run([a, b], [K.dummy("foe", BIG_HP)])
	var at_30: Array[String] = []
	for entry: LogEntry in _status_entries(result, LogEntry.Kind.STATUS_DAMAGE, "burn"):
		if entry.tick == 30:
			at_30.append("%s/%s/%d" % [entry.source_unit, entry.source_item, entry.amount])
	assert_eq(at_30, ["a/torch/1", "b/brand/1"] as Array[String])


func _shielded_foe(amount: int) -> UnitSetup:
	var ward: ItemDef = K.item("ward", {"cooldown_ms": 500, "effects": [{"trigger": "on_fire", "type": "shield", "amount": amount, "target": "self"}]})
	return K.unit("foe", BIG_HP, FRONT, [ward], K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)}))


func test_poison_ignores_shields_and_never_fades() -> void:
	var result: FightResult = K.run([_idle_hero([_applier("vial", "poison", 60000, 5)])], [_shielded_foe(1000)])
	var damage: Array[LogEntry] = _status_entries(result, LogEntry.Kind.STATUS_DAMAGE, "poison")
	assert_eq([damage[0].tick, damage[0].amount, damage[0].absorbed], [1220, 5, 0], "straight to HP despite the shield")
	assert_eq([damage[1].tick, damage[1].amount], [1240, 5], "still 5 stacks")
	assert_eq(_status_entries(result, LogEntry.Kind.STATUS_ENDED, "poison").size(), 0)


func test_burn_is_half_as_effective_against_shields() -> void:
	var sim := CombatSim.new(K.fight([K.dummy("hero", 100)], [K.dummy("foe", 100)]), K.content())
	var unit: UnitState = sim.units[1]
	unit.shield = 10
	var absorbed: int = sim.apply_damage_vs_shield(unit, 30, 5000)
	assert_eq([absorbed, unit.shield, unit.hp], [20, 0, 90], "10 shield soaks 20 burn; the other 10 hits HP")
	unit.shield = 100
	assert_eq([sim.apply_damage_vs_shield(unit, 30, 5000), unit.shield, unit.hp], [30, 85, 90])


func test_bleed_lowers_defense() -> void:
	var gash: ItemDef = _applier("gash", "bleed", 1000, 50)
	var club: ItemDef = K.item("club", {"effects": K.damage(100)})
	var foe: UnitSetup = K.unit_with("foe", UnitStats.make(BIG_HP, 0, 0, 100), FRONT, [], K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)}))
	var result: FightResult = K.run([_idle_hero([gash, club])], [foe])
	var hit: LogEntry = K.entries(result, LogEntry.Kind.DAMAGE, "club")[0]
	assert_eq(hit.amount, 67, "50 Bleed takes DEF 100 down to 50: 100 x 100/150")
	assert_eq(_status_entries(result, LogEntry.Kind.STATUS_ENDED, "bleed").size(), 0, "bleed never fades")


func test_heals_weaken_damage_over_time() -> void:
	var salve: ItemDef = K.item("salve", {"effects": [{"trigger": "on_fire", "type": "heal", "amount": 10, "target": "self"}]})
	var foe: UnitSetup = K.unit("foe", BIG_HP, FRONT, [salve], K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)}))
	var hero: UnitSetup = K.unit("hero", BIG_HP, FRONT, [_applier("vial", "poison", 1000, 50)])
	var result: FightResult = K.run([hero], [foe])
	# Tick 20: the hero's basic attack hits (5), the vial adds 50 poison, then the
	# foe's salve heals 5 HP back, which strips 10% of the poison.
	var reduced: LogEntry = _status_entries(result, LogEntry.Kind.STATUS_REDUCED, "poison")[0]
	assert_eq([reduced.tick, reduced.amount], [20, 5])
	assert_eq(reduced.to_text(), "[1.00s] Poison on foe loses 5 stacks (healed)")


func test_status_damage_hits_shield_first() -> void:
	var ward: ItemDef = K.item("ward", {"effects": [{"trigger": "on_fire", "type": "shield", "amount": 100, "target": "self"}]})
	var foe: UnitSetup = K.unit("foe", BIG_HP, FRONT, [ward], K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)}))
	var result: FightResult = K.run([_idle_hero([_applier("torch", "burn")])], [foe])
	var first: LogEntry = _status_entries(result, LogEntry.Kind.STATUS_DAMAGE, "burn")[0]
	assert_eq(first.absorbed, first.amount)


# --- slow, freeze, blind -----------------------------------------------------------------

func test_slow_then_freeze_changes_when_items_fire() -> void:
	var claw: ItemDef = K.item("claw", {"effects": K.damage(1)})
	var foe: UnitSetup = K.unit("foe", BIG_HP, FRONT, [claw], K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)}))
	var result: FightResult = K.run([_idle_hero([_applier("chill", "slow")])], [foe])
	# Slow lands at 20, 40, 60 (10% per stack); the 3rd stack turns into a 1s Freeze.
	# claw: fires at 20; 20 ticks at 90% + 3 at 80% -> 43; then 17 at 80%, frozen
	# for ticks 61-79, full speed at 80, 90% after -> 86.
	var fires: Array[int] = K.ticks_of(K.entries(result, LogEntry.Kind.FIRE, "claw"))
	assert_eq(fires.slice(0, 3), [20, 43, 86] as Array[int])

	var freeze: LogEntry = _status_entries(result, LogEntry.Kind.STATUS_APPLIED, "freeze")[0]
	assert_eq(freeze.tick, 60)
	assert_eq(freeze.note, "(from 3 Slow)")
	assert_eq(freeze.source_item, "chill", "the stack that triggered it gets the credit")
	assert_eq(_status_entries(result, LogEntry.Kind.STATUS_ENDED, "slow")[0].tick, 60, "slow is used up")
	assert_eq(_status_entries(result, LogEntry.Kind.STATUS_ENDED, "freeze")[0].tick, 80)


func test_slow_wears_off_after_its_duration() -> void:
	var result: FightResult = K.run([_idle_hero([_applier("chill", "slow", 5000)])], [K.dummy("foe", BIG_HP)])
	assert_eq(_status_entries(result, LogEntry.Kind.STATUS_APPLIED, "slow")[0].tick, 100)
	assert_eq(_status_entries(result, LogEntry.Kind.STATUS_ENDED, "slow")[0].tick, 160, "3s later")


func test_max_stacks_caps_a_status() -> void:
	var result: FightResult = K.run([_idle_hero([_applier("glare", "freeze", 1000, 3)])], [K.dummy("foe", BIG_HP)])
	assert_eq(_status_entries(result, LogEntry.Kind.STATUS_APPLIED, "freeze")[0].stacks, 1, "freeze holds 1 stack")


func test_blind_makes_the_next_hit_miss() -> void:
	var thorn: ItemDef = K.item("thorn", {"effects": [
		{"trigger": "on_fire", "type": "damage", "amount": 4, "target": "enemy_front"},
		{"trigger": "on_hit", "type": "heal", "amount": 1, "target": "self"},
	]})
	var foe: UnitSetup = K.unit("foe", BIG_HP, FRONT, [thorn], K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)}))
	var result: FightResult = K.run([_idle_hero([_applier("dazzle", "blind", 2000)])], [foe])
	# dazzle blinds at 40; the foe's thorn (every 1s) misses at 40, then hits at 60.
	var misses: Array[LogEntry] = result.combat_log.of_kind(LogEntry.Kind.MISS)
	assert_eq(K.ticks_of(misses).slice(0, 1), [40] as Array[int])
	assert_eq(misses[0].to_text(), "[2.00s] foe · Test Item misses hero (Blind)")
	var thorn_hits: Array[int] = K.ticks_of(K.entries(result, LogEntry.Kind.DAMAGE, "thorn"))
	assert_false(40 in thorn_hits, "no damage on the missed hit")
	assert_true(60 in thorn_hits)
	var heals_at_40: Array[LogEntry] = K.entries(result, LogEntry.Kind.HEAL, "thorn").filter(
		func(entry: LogEntry) -> bool: return entry.tick == 40)
	assert_eq(heals_at_40.size(), 0, "a miss triggers no on_hit effects")


func test_status_log_lines_name_their_source() -> void:
	var result: FightResult = K.run([_idle_hero([_applier("torch", "burn", 60000)])], [K.dummy("foe", BIG_HP)])
	var applied: LogEntry = _status_entries(result, LogEntry.Kind.STATUS_APPLIED, "burn")[0]
	assert_eq(applied.to_text(), "[60.00s] hero · Test Item applies 1 Burn to foe (1 total)")
	var damage: LogEntry = _status_entries(result, LogEntry.Kind.STATUS_DAMAGE, "burn")[0]
	assert_eq(damage.to_text(), "[60.50s] Burn (hero · Test Item) hits foe for 1")


func test_death_by_status_names_the_status() -> void:
	var torch: ItemDef = _applier("torch", "burn", 50, 5)
	var result: FightResult = K.run([_idle_hero([torch])], [K.dummy("foe", 40)])
	var death: LogEntry = result.combat_log.of_kind(LogEntry.Kind.DEATH)[0]
	assert_true(death.note.begins_with("last hit: Burn from hero · Test Item"), death.note)


# --- content checks ---------------------------------------------------------------

func test_threshold_loops_are_rejected() -> void:
	var statuses: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/statuses.json"))
	for status: Dictionary in statuses:
		if status["id"] == "freeze":
			status.merge({"kind": "slow", "slow_bp_per_stack": 1000, "threshold": {"stacks": 2, "apply_status": "slow"}}, true)
	var texts: Dictionary[String, String] = {}
	for file_name: String in ContentDb.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	texts[ContentDb.STATUSES_FILE] = JSON.stringify(statuses)
	var errors: Array[String] = ContentDb.load_texts(texts).errors
	assert_true(errors.any(func(message: String) -> bool: return message.contains("threshold chain loops")), str(errors))
