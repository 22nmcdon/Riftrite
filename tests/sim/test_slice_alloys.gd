extends GutTest
## The slice's six new alloys (docs/plans/slice-content.md): each turns the
## item's own status into its own status type, so plain Poison, Slow, Burn,
## and Bleed on other items are untouched.

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT := UnitSetup.Row.FRONT
const BIG_HP: int = 10000000


## An Epic item (two sockets) that applies `stacks` of `status` to the front.
func _applier(status: String, stacks: int) -> ItemDef:
	return K.item("applier", {"name": "Applier", "size": 2, "rarity": "epic",
		"effects": [{"trigger": "on_fire", "type": "apply_status", "status": status, "stacks": stacks, "target": "enemy_front"}]})


func _fight(status: String, stacks: int, essences: Array[String]) -> FightResult:
	var hero: UnitSetup = K.unit("hero", BIG_HP, FRONT, [K.equip(_applier(status, stacks), essences, 0, 0)],
		K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)}))
	return K.run([hero], [K.dummy("foe", BIG_HP)])


func _applied(result: FightResult, status: String) -> Array[LogEntry]:
	return result.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED).filter(
		func(entry: LogEntry) -> bool: return entry.status == status)


func test_each_alloy_uses_its_own_status() -> void:
	var cases: Array[Array] = [
		["poison", ["venom", "venom"], "deathcap"],
		["slow", ["frost", "frost"], "rime"],
		["burn", ["ember", "wrath"], "searfire"],
		["poison", ["ember", "venom"], "caustic"],
		["bleed", ["venom", "umbral"], "nightshade"],
		["bleed", ["umbral", "umbral"], "hemorrhage"],
	]
	for case: Array in cases:
		var essences: Array[String] = []
		essences.assign(case[1])
		var result: FightResult = _fight(case[0], 10, essences)
		assert_gt(_applied(result, case[2]).size(), 0, "%s makes %s" % [essences, case[2]])
		assert_eq(_applied(result, case[0]).size(), 0, "%s: no plain %s from this item" % [essences, case[0]])


func test_recipes_find_the_new_alloys() -> void:
	var db: ContentDb = K.content()
	assert_eq(db.alloy_for("wrath", "ember").id, "searfire")
	assert_eq(db.alloy_for("umbral", "venom").id, "nightshade")
	assert_eq(db.alloy_for("frost", "frost").id, "deep_freeze")


func test_hemorrhage_hits_twice_as_hard_per_stack() -> void:
	var plain: LogEntry = _first_tick(_fight("bleed", 10, [] as Array[String]), "bleed")
	var hemorrhage: LogEntry = _first_tick(_fight("bleed", 10, ["umbral", "umbral"] as Array[String]), "hemorrhage")
	assert_eq(hemorrhage.amount, plain.amount * 2)


func test_deathcap_and_nightshade_ignore_shields_and_lower_defense() -> void:
	var db: ContentDb = K.content()
	assert_eq([db.statuses["deathcap"].vs_shield_bp, db.statuses["deathcap"].defense_shred_per_stack], [0, 1])
	assert_eq([db.statuses["nightshade"].vs_shield_bp, db.statuses["nightshade"].defense_shred_per_stack], [0, 2])
	assert_eq(db.statuses["searfire"].vs_shield_bp, FixedMath.BP_ONE, "Searfire is full strength against shields, unlike Burn")
	assert_lt(db.statuses["burn"].vs_shield_bp, FixedMath.BP_ONE)
	assert_gt(db.statuses["rime"].slow_bp_per_stack, db.statuses["slow"].slow_bp_per_stack)


func _first_tick(result: FightResult, status: String) -> LogEntry:
	var ticks: Array[LogEntry] = result.combat_log.of_kind(LogEntry.Kind.STATUS_DAMAGE).filter(
		func(entry: LogEntry) -> bool: return entry.status == status)
	assert_gt(ticks.size(), 0, "%s ticks" % status)
	return ticks[0]
