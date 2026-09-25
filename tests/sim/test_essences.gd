extends GutTest
## Each base essence socketed in an item, using the real data/essences.json.

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT := UnitSetup.Row.FRONT
const BACK := UnitSetup.Row.BACK
const BIG_HP: int = 10000000


func _idle() -> ItemDef:
	return K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)})


func _blade(overrides: Dictionary = {}) -> ItemDef:
	var data: Dictionary = {"name": "Blade", "effects": K.damage(10)}
	data.merge(overrides, true)
	return K.item("blade", data)


func _run_with(essence: String, blade: ItemDef = null) -> FightResult:
	var item: ItemDef = blade if blade != null else _blade()
	return K.run([K.unit("hero", BIG_HP, FRONT, [K.equip(item, [essence] as Array[String])], _idle())], [K.dummy("foe", BIG_HP)])


func _first(result: FightResult, kind: LogEntry.Kind, status: String = "") -> LogEntry:
	for entry: LogEntry in result.combat_log.of_kind(kind):
		if status.is_empty() or entry.status == status:
			return entry
	return null


# --- sockets ---------------------------------------------------------------------------

func _setup_errors(items: Array) -> Array[String]:
	return K.run([K.unit("hero", 100, FRONT, items)], [K.dummy("foe", 100)]).errors


func test_small_items_have_one_socket() -> void:
	var errors: Array[String] = _setup_errors([K.equip(_blade(), ["ember", "frost"] as Array[String])])
	assert_true(errors.any(func(e: String) -> bool: return e.contains("has 2 essences but only 1 socket(s)")), str(errors))


func test_two_essences_wait_for_alloys() -> void:
	var errors: Array[String] = _setup_errors([K.equip(_blade({"size": 2}), ["ember", "frost"] as Array[String])])
	assert_true(errors.any(func(e: String) -> bool: return e.contains("which the sim doesn't support yet")), str(errors))


func test_unknown_essence_is_rejected() -> void:
	var errors: Array[String] = _setup_errors([K.equip(_blade(), ["glitter"] as Array[String])])
	assert_true(errors.any(func(e: String) -> bool: return e.contains("unknown essence \"glitter\"")), str(errors))


# --- each essence ---------------------------------------------------------------------

func test_ember_burns_on_hit() -> void:
	var applied: LogEntry = _first(_run_with("ember"), LogEntry.Kind.STATUS_APPLIED, "burn")
	assert_eq(applied.to_text(), "[1.00s] hero · Blade [Ember] applies 1 Burn to foe (1 total)")


func test_frost_slows_on_hit() -> void:
	var applied: LogEntry = _first(_run_with("frost"), LogEntry.Kind.STATUS_APPLIED, "slow")
	assert_eq([applied.tick, applied.source_infusion], [20, "frost"])


func test_storm_shortens_cooldown_and_sometimes_fires_twice() -> void:
	var result: FightResult = _run_with("storm")
	var fires: Array[LogEntry] = K.entries(result, LogEntry.Kind.FIRE, "blade")
	var first_fires: Array[int] = []
	var again: int = 0
	for entry: LogEntry in fires:
		if entry.note.is_empty():
			first_fires.append(entry.tick)
		else:
			again += 1
			assert_eq(entry.note, "again (Storm)")
	assert_eq(first_fires.slice(0, 3), [17, 34, 51] as Array[int], "1s cooldown -15% = 17 ticks")
	assert_between(again, first_fires.size() / 10, first_fires.size() * 3 / 10, "about 20% of fires repeat")


func test_stone_shields_the_owner_from_hits() -> void:
	var shield: LogEntry = _first(_run_with("stone"), LogEntry.Kind.SHIELD)
	assert_eq(shield.to_text(), "[1.00s] hero · Blade [Stone] gives hero 3 shield", "30% of 10")


func test_verdant_heals_the_lowest_percentage_ally() -> void:
	var tank: UnitSetup = K.unit("tank", 1000, FRONT, [], _idle())
	var healer: UnitSetup = K.unit("healer", 100, BACK, [K.equip(_blade(), ["verdant"] as Array[String])], _idle())
	var foe: UnitSetup = K.unit("foe", BIG_HP, FRONT, [K.item("pike", {"effects": K.damage(50, "enemy_back")})], _idle())
	var result: FightResult = K.run([tank, healer], [foe])
	# The pike hits the healer (back row) for 50 at 1s; at 2s the healer is at 50% and the tank at 100%.
	var heals: Array[LogEntry] = K.entries(result, LogEntry.Kind.HEAL, "blade")
	assert_eq([heals[1].tick, heals[1].target, heals[1].amount, heals[1].source_infusion], [40, "healer", 8, "verdant"])


func test_umbral_adds_crit_and_crits_bleed() -> void:
	var sim := CombatSim.new(K.fight([K.unit("hero", BIG_HP, FRONT, [K.equip(_blade(), ["umbral"] as Array[String])], _idle())], [K.dummy("foe", BIG_HP)]), K.content())
	assert_eq(sim.units[0].items[1].crit_chance_bp, 1500, "+15% crit")

	var result: FightResult = _run_with("umbral", _blade({"crit_chance_bp": 10000}))
	var bleed: LogEntry = _first(result, LogEntry.Kind.STATUS_APPLIED, "bleed")
	assert_eq([bleed.tick, bleed.source_infusion], [20, "umbral"])


func test_basic_attack_carries_no_essence_effects() -> void:
	var result: FightResult = K.run([K.unit("hero", BIG_HP, FRONT, [K.equip(K.item("charm", {"effects": [{"trigger": "on_fire", "type": "heal", "amount": 1, "target": "self"}]}), ["ember"] as Array[String])])], [K.dummy("foe", BIG_HP)])
	for entry: LogEntry in result.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED):
		assert_ne(entry.source_item, "basic", "ember sits in the charm, not the basic attack")
	assert_null(_first(result, LogEntry.Kind.STATUS_APPLIED, "burn"), "and the charm never hits, so no burn")
