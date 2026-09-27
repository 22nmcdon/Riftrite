extends GutTest
## Effect windows (Rush/Stall), area targets, and Linked targets.

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT := UnitSetup.Row.FRONT
const BACK := UnitSetup.Row.BACK
const BIG_HP: int = 10000000


func _idle() -> ItemDef:
	return K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)})


func _hits(result: FightResult, item_id: String) -> Array[String]:
	var hits: Array[String] = []
	for entry: LogEntry in K.entries(result, LogEntry.Kind.DAMAGE, item_id):
		hits.append("%d:%s:%d" % [entry.tick, entry.target, entry.amount])
	return hits


# --- windows -----------------------------------------------------------------------------

func test_rush_item_hits_harder_for_the_first_8_seconds() -> void:
	var dagger: ItemDef = K.item("dagger", {"timing": "rush", "effects": [
		{"trigger": "on_fire", "type": "damage", "amount": 20, "target": "enemy_front", "window": {"until_ms": 8000}},
		{"trigger": "on_fire", "type": "damage", "amount": 10, "target": "enemy_front", "window": {"from_ms": 8000}},
	]})
	var hits: Array[String] = _hits(K.run([K.unit("hero", BIG_HP, FRONT, [dagger], _idle())], [K.dummy("foe", BIG_HP)]), "dagger")
	assert_eq(hits.slice(6, 9), ["140:foe:20", "160:foe:10", "180:foe:10"] as Array[String])


func test_stall_item_sleeps_until_15_seconds() -> void:
	var tome: ItemDef = K.item("tome", {"timing": "stall", "effects": [
		{"trigger": "on_fire", "type": "damage", "amount": 50, "target": "enemy_front", "window": {"from_ms": 15000}},
	]})
	var hits: Array[String] = _hits(K.run([K.unit("hero", BIG_HP, FRONT, [tome], _idle())], [K.dummy("foe", BIG_HP)]), "tome")
	assert_eq(hits[0], "300:foe:50")


func test_window_must_end_after_it_starts() -> void:
	var errors: Array[String] = []
	var data: Dictionary = K.DEFAULT_ITEM.duplicate(true)
	data.merge({"id": "x", "effects": [{"trigger": "on_fire", "type": "damage", "amount": 1, "target": "enemy_front", "window": {"from_ms": 5000, "until_ms": 5000}}]}, true)
	ItemDef.read(DataReader.new(data, "x", errors))
	assert_true(errors.any(func(e: String) -> bool: return e.contains("until_ms must be later than from_ms")), str(errors))


# --- area targets -------------------------------------------------------------------

func test_all_enemies_hits_everyone_standing() -> void:
	var quake: ItemDef = K.item("quake", {"effects": K.damage(5, "all_enemies")})
	var result: FightResult = K.run([K.unit("hero", BIG_HP, FRONT, [quake], _idle())],
		[K.dummy("a", BIG_HP), K.dummy("b", BIG_HP), K.dummy("c", BIG_HP, BACK)])
	assert_eq(_hits(result, "quake").slice(0, 3), ["20:a:5", "20:b:5", "20:c:5"] as Array[String])


func test_all_allies_heals_the_whole_team() -> void:
	var hymn: ItemDef = K.item("hymn", {"effects": [{"trigger": "on_fire", "type": "heal", "amount": 1, "target": "all_allies"}]})
	var result: FightResult = K.run([K.unit("hero", BIG_HP, FRONT, [hymn], _idle()), K.dummy("ally", BIG_HP, BACK)], [K.dummy("foe", BIG_HP)])
	assert_eq(K.targets_of(K.entries(result, LogEntry.Kind.HEAL, "hymn")).slice(0, 2), ["hero", "ally"] as Array[String])


# --- row allies ----------------------------------------------------------------------

func _row_heals(holder_column: int) -> Array[String]:
	var mend: ItemDef = K.item("mend", {"effects": [{"trigger": "on_fire", "type": "heal", "amount": 1, "target": "row_allies"}]})
	var heroes: Array[UnitSetup] = []
	for i: int in 4:
		if i == holder_column:
			heroes.append(K.unit("h%d" % i, BIG_HP, FRONT, [mend], _idle()))
		else:
			heroes.append(K.dummy("h%d" % i, BIG_HP))
	heroes.append(K.dummy("back", BIG_HP, BACK))
	var result: FightResult = K.run(heroes, [K.dummy("foe", BIG_HP)])
	var first: Array[String] = []
	for entry: LogEntry in K.entries(result, LogEntry.Kind.HEAL, "mend"):
		if entry.tick == 20:
			first.append(entry.target)
	return first


func test_row_allies_is_the_whole_row() -> void:
	assert_eq(_row_heals(1), ["h0", "h2", "h3"] as Array[String], "the whole row, not the back row")
	assert_eq(_row_heals(0), ["h1", "h2", "h3"] as Array[String], "wherever the holder stands")
