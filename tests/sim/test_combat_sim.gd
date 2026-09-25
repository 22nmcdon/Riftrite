extends GutTest

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT := UnitSetup.Row.FRONT
const BACK := UnitSetup.Row.BACK
const BIG_HP: int = 10000000


# --- cooldowns and auto-attacks --------------------------------------------------

func test_item_fires_every_cooldown() -> void:
	var hook: ItemDef = K.item("hook", {"cooldown_ms": 3000, "effects": K.damage(1)})
	var result: FightResult = K.run([K.unit("hero", BIG_HP, FRONT, [hook])], [K.dummy("foe", BIG_HP)])
	var fires: Array[int] = K.ticks_of(K.entries(result, LogEntry.Kind.FIRE, "hook"))
	assert_eq(fires.slice(0, 3), [60, 120, 180] as Array[int], "3000ms = 60 ticks; first fire one cooldown in")


func test_basic_attack_fires_without_auto_attack_item() -> void:
	var result: FightResult = K.run([K.unit("hero", BIG_HP, FRONT, [K.item("charm", {"effects": K.damage(1)})])], [K.dummy("foe", BIG_HP)])
	assert_gt(K.entries(result, LogEntry.Kind.FIRE, "basic").size(), 0)


func test_auto_attack_item_replaces_basic_attack() -> void:
	var blade: ItemDef = K.item("blade", {"auto_attack": true, "effects": K.damage(1)})
	var result: FightResult = K.run([K.unit("hero", BIG_HP, FRONT, [blade])], [K.dummy("foe", BIG_HP)])
	assert_eq(K.entries(result, LogEntry.Kind.FIRE, "basic").size(), 0, "basic attack doesn't fire")
	assert_gt(K.entries(result, LogEntry.Kind.FIRE, "blade").size(), 0)


# --- setup validation ---------------------------------------------------------

func _assert_setup_error(heroes: Array[UnitSetup], enemies: Array[UnitSetup], expected: String) -> void:
	var result: FightResult = K.run(heroes, enemies)
	var found: bool = false
	for message: String in result.errors:
		found = found or message.contains(expected)
	assert_true(found, "expected a setup error containing '%s', got: %s" % [expected, result.errors])
	assert_false(result.guild_won())
	assert_eq(result.combat_log.entries.size(), 0, "an invalid fight doesn't run")


func test_rejects_two_auto_attack_items() -> void:
	var a: ItemDef = K.item("a", {"auto_attack": true})
	var b: ItemDef = K.item("b", {"auto_attack": true})
	_assert_setup_error([K.unit("hero", 100, FRONT, [a, b])], [K.dummy("foe", 100)], "the limit is one")


func test_rejects_items_over_slot_count() -> void:
	var large: ItemDef = K.item("large", {"size": 3})
	var items: Array[ItemDef] = [large, large, large]
	_assert_setup_error([K.unit("hero", 100, FRONT, items)], [K.dummy("foe", 100)], "items take 9 slots but the unit has 7")


func test_rejects_duplicate_unit_ids() -> void:
	_assert_setup_error([K.dummy("same", 100)], [K.dummy("same", 100)], "unit id \"same\" is used twice")


func test_rejects_unknown_status_on_an_item() -> void:
	var hex: ItemDef = K.item("hex", {"effects": [{"trigger": "on_fire", "type": "apply_status", "status": "doom", "stacks": 1, "target": "enemy_front"}]})
	_assert_setup_error([K.unit("hero", 100, FRONT, [hex])], [K.dummy("foe", 100)], "applies unknown status \"doom\"")


func test_rejects_empty_side() -> void:
	_assert_setup_error([K.dummy("hero", 100)], [], "fight has no enemies")


# --- targeting ---------------------------------------------------------------------

func test_attacks_hit_the_enemy_directly_across() -> void:
	var jab: ItemDef = K.item("jab", {"effects": K.damage(1)})
	var result: FightResult = K.run(
		[K.dummy("h0", BIG_HP), K.unit("h1", BIG_HP, FRONT, [jab])],
		[K.dummy("f0", BIG_HP), K.dummy("f1", BIG_HP), K.dummy("b0", BIG_HP, BACK)])
	var targets: Array[String] = K.targets_of(K.entries(result, LogEntry.Kind.DAMAGE, "jab"))
	assert_eq(targets.slice(0, 3), ["f1", "f1", "f1"] as Array[String], "column 1 hits column 1")


func test_nearest_target_with_ties_going_left() -> void:
	var smash: ItemDef = K.item("smash", {"effects": K.damage(100)})
	var result: FightResult = K.run(
		[K.dummy("h0", BIG_HP), K.unit("h1", BIG_HP, FRONT, [smash])],
		[K.dummy("a", BIG_HP), K.dummy("b", 100), K.dummy("c", BIG_HP)])
	var targets: Array[String] = K.targets_of(K.entries(result, LogEntry.Kind.DAMAGE, "smash"))
	assert_eq(targets.slice(0, 3), ["b", "a", "a"] as Array[String], "b falls; a and c are both 1 away, left wins")


func test_back_row_only_once_front_row_is_down() -> void:
	var smash: ItemDef = K.item("smash", {"effects": K.damage(100)})
	var result: FightResult = K.run(
		[K.unit("hero", BIG_HP, FRONT, [smash])],
		[K.dummy("front", 250), K.dummy("back", BIG_HP, BACK)])
	var targets: Array[String] = K.targets_of(K.entries(result, LogEntry.Kind.DAMAGE, "smash"))
	assert_eq(targets.slice(0, 5), ["front", "front", "front", "back", "back"] as Array[String])


func test_enemy_back_reaches_the_back_row() -> void:
	var dart: ItemDef = K.item("dart", {"effects": K.damage(1, "enemy_back")})
	var result: FightResult = K.run(
		[K.unit("hero", BIG_HP, FRONT, [dart])],
		[K.dummy("front", BIG_HP), K.dummy("back", BIG_HP, BACK)])
	assert_eq(K.entries(result, LogEntry.Kind.DAMAGE, "dart")[0].target, "back")


func test_a_downed_unit_is_not_targeted_in_the_same_tick() -> void:
	# Two items fire on the same tick; the first drops the target, so the
	# second moves on instead of wasting its hit.
	var first: ItemDef = K.item("first", {"effects": K.damage(100)})
	var second: ItemDef = K.item("second", {"effects": K.damage(100)})
	var result: FightResult = K.run(
		[K.unit("hero", BIG_HP, FRONT, [first, second])],
		[K.dummy("weak", 100), K.dummy("strong", BIG_HP)])
	var hits: Array[LogEntry] = K.entries(result, LogEntry.Kind.DAMAGE, "second")
	assert_eq(hits[0].tick, 20)
	assert_eq(hits[0].target, "strong")


func _unit_state(unit_id: String, hp: int, max_hp: int) -> UnitState:
	var state := UnitState.new()
	state.id = unit_id
	state.hp = hp
	state.max_hp = max_hp
	return state


func test_lowest_hp_means_lowest_percentage() -> void:
	var tank: UnitState = _unit_state("tank", 300, 1000)
	var mender: UnitState = _unit_state("mender", 150, 200)
	assert_eq(Targeting._lowest_hp([mender, tank] as Array[UnitState]).id, "tank", "30% beats 75%, even with more raw HP")
	var even: UnitState = _unit_state("even", 100, 200)
	var half: UnitState = _unit_state("half", 500, 1000)
	assert_eq(Targeting._lowest_hp([even, half] as Array[UnitState]).id, "even", "ties go to the first in order")


# --- damage, shields, crits, heals ------------------------------------------------

func test_shield_absorbs_before_hp() -> void:
	var ward: ItemDef = K.item("ward", {"effects": [{"trigger": "on_fire", "type": "shield", "amount": 30, "target": "self"}]})
	var result: FightResult = K.run([K.unit("hero", 1000, FRONT, [ward])], [K.unit("foe", BIG_HP, FRONT)])
	var foe_hits: Array[LogEntry] = K.entries(result, LogEntry.Kind.DAMAGE, "basic").filter(
		func(entry: LogEntry) -> bool: return entry.source_unit == "foe")
	assert_eq([foe_hits[0].tick, foe_hits[0].amount, foe_hits[0].absorbed], [20, 5, 5], "heroes resolve first, so the shield is up in time")


func test_guaranteed_crit_deals_crit_damage() -> void:
	var crit: ItemDef = K.item("crit", {"crit_chance_bp": 10000, "effects": K.damage(10)})
	var result: FightResult = K.run([K.unit("hero", BIG_HP, FRONT, [crit])], [K.dummy("foe", BIG_HP)])
	var hit: LogEntry = K.entries(result, LogEntry.Kind.DAMAGE, "crit")[0]
	assert_true(hit.crit)
	assert_eq(hit.amount, 15, "150% crit damage")


func test_zero_crit_chance_never_crits() -> void:
	var plain: ItemDef = K.item("plain", {"effects": K.damage(10)})
	var result: FightResult = K.run([K.unit("hero", BIG_HP, FRONT, [plain])], [K.dummy("foe", BIG_HP)])
	for hit: LogEntry in K.entries(result, LogEntry.Kind.DAMAGE, "plain"):
		assert_false(hit.crit)


func test_heal_goes_to_lowest_hp_ally_and_is_capped() -> void:
	var mend: ItemDef = K.item("mend", {"effects": [{"trigger": "on_fire", "type": "heal", "amount": 50, "target": "ally_lowest_hp"}]})
	var result: FightResult = K.run(
		[K.dummy("tank", 100), K.unit("healer", 1000, BACK, [mend], K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)}))],
		[K.unit("foe", BIG_HP)])
	var heals: Array[LogEntry] = K.entries(result, LogEntry.Kind.HEAL, "mend")
	assert_eq(heals[0].target, "tank")
	assert_eq(heals[0].amount, 0, "tank is still full when the first heal lands")
	assert_eq(heals[1].amount, 5, "only the 5 missing HP")


func test_on_hit_and_on_crit_triggers() -> void:
	var leech: ItemDef = K.item("leech", {"crit_chance_bp": 10000, "effects": [
		{"trigger": "on_fire", "type": "damage", "amount": 10, "target": "enemy_front"},
		{"trigger": "on_hit", "type": "shield", "amount_bp_of_damage": 5000, "target": "self"},
		{"trigger": "on_crit", "type": "damage", "amount": 3, "target": "hit_target"},
	]})
	var result: FightResult = K.run([K.unit("hero", BIG_HP, FRONT, [leech])], [K.dummy("foe", BIG_HP)])
	var first_tick: Array[LogEntry] = []
	for entry: LogEntry in result.combat_log.entries:
		if entry.tick == 20 and entry.source_item == "leech":
			first_tick.append(entry)
	var kinds: Array[LogEntry.Kind] = []
	for entry: LogEntry in first_tick:
		kinds.append(entry.kind)
	assert_eq(kinds, [LogEntry.Kind.FIRE, LogEntry.Kind.DAMAGE, LogEntry.Kind.SHIELD, LogEntry.Kind.DAMAGE] as Array[LogEntry.Kind],
		"fire, hit, on_hit shield, on_crit bonus hit; the bonus hit triggers nothing further")
	assert_eq(first_tick[2].amount, 8, "50% of the 15-damage crit, rounded")
	assert_eq(first_tick[3].target, "foe")


# --- deaths and outcomes ------------------------------------------------------------

func test_units_that_fall_together_still_fire_and_tie() -> void:
	var result: FightResult = K.run(
		[K.unit("hero", 5, FRONT)],
		[K.unit("foe", 5, FRONT)])
	assert_eq(K.entries(result, LogEntry.Kind.DAMAGE).size(), 2, "both hit on tick 20")
	assert_eq(K.targets_of(result.combat_log.of_kind(LogEntry.Kind.DEATH)), ["hero", "foe"] as Array[String])
	assert_eq(result.outcome, FightResult.Outcome.TIE)
	assert_eq(result.end_tick, 20)
	assert_true(result.guild_won(), "a tie counts as a victory")


func test_victory_and_defeat() -> void:
	var strong: ItemDef = K.item("strong", {"effects": K.damage(1000)})
	var win: FightResult = K.run([K.unit("hero", 100, FRONT, [strong])], [K.dummy("foe", 50)])
	assert_eq(win.outcome, FightResult.Outcome.VICTORY)
	assert_true(win.guild_won())
	var loss: FightResult = K.run([K.dummy("hero", 50)], [K.unit("foe", 100, FRONT, [strong])])
	assert_eq(loss.outcome, FightResult.Outcome.DEFEAT)
	assert_false(loss.guild_won())


func test_death_names_the_last_hit() -> void:
	var strong: ItemDef = K.item("strong", {"name": "Grave Maul", "effects": K.damage(1000)})
	var result: FightResult = K.run([K.unit("hero", 100, FRONT, [strong])], [K.dummy("foe", 50)])
	var death: LogEntry = result.combat_log.of_kind(LogEntry.Kind.DEATH)[0]
	assert_eq(death.to_text(), "[1.00s] foe falls (last hit: hero · Grave Maul)")


# --- Rift Collapse and the tie time --------------------------------------------------

func _collapse_sim(act: int) -> CombatSim:
	return CombatSim.new(K.fight([K.dummy("hero", BIG_HP)], [K.dummy("foe", BIG_HP)], 1, act), K.content())


func test_collapse_damage_matches_the_plan_table() -> void:
	var sim: CombatSim = _collapse_sim(1)
	assert_eq(sim.collapse_damage_at(899), 0, "nothing before 45s")
	assert_eq(sim.collapse_damage_at(900), 10, "45s")
	assert_eq(sim.collapse_damage_at(901), 0, "once per second")
	assert_eq(sim.collapse_damage_at(1200), 160, "60s")
	assert_eq(sim.collapse_damage_at(1800), 460, "90s")
	assert_eq(sim.collapse_damage_at(1820), 472, "91s: growth rises by 2")
	assert_eq(sim.collapse_damage_at(1840), 486, "92s: then by 4")
	assert_eq(sim.collapse_damage_at(3600), 9550, "180s")


func test_collapse_totals_match_the_plan_table() -> void:
	var sim: CombatSim = _collapse_sim(1)
	var totals: Dictionary[int, int] = {}
	var running: int = 0
	for at_tick: int in range(1, 3601):
		running += sim.collapse_damage_at(at_tick)
		if at_tick in [1200, 1800, 2400, 3000, 3600]:
			totals[at_tick] = running
	assert_eq(totals, {1200: 1360, 1800: 10810, 2400: 39180, 3000: 132350, 3600: 344320} as Dictionary[int, int])


func test_act_two_doubles_collapse() -> void:
	var sim: CombatSim = _collapse_sim(2)
	assert_eq(sim.collapse_damage_at(900), 20)
	assert_eq(sim.collapse_damage_at(1800), 920)
	assert_eq(sim.collapse_damage_at(3600), 19100)


func test_collapse_hits_both_sides_and_shield_first() -> void:
	var ward: ItemDef = K.item("ward", {"effects": [{"trigger": "on_fire", "type": "shield", "amount": 1000, "target": "self"}]})
	var result: FightResult = K.run([K.unit("hero", BIG_HP, FRONT, [ward], K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)}))], [K.dummy("foe", BIG_HP)])
	var first: Array[LogEntry] = []
	for entry: LogEntry in result.combat_log.of_kind(LogEntry.Kind.COLLAPSE):
		if entry.tick == 900:
			first.append(entry)
	assert_eq(K.targets_of(first), ["hero", "foe"] as Array[String])
	assert_eq([first[0].amount, first[0].absorbed], [10, 10], "the hero's shield soaks it")
	assert_eq(first[1].absorbed, 0)


func test_tie_at_three_minutes() -> void:
	var result: FightResult = K.run([K.dummy("hero", BIG_HP)], [K.dummy("foe", BIG_HP)])
	assert_eq(result.outcome, FightResult.Outcome.TIE)
	assert_eq(result.end_tick, 3600, "180s")
	assert_true(result.guild_won())
	var last: LogEntry = result.combat_log.entries[-1]
	assert_eq(last.to_text(), "[180.00s] Tie: both sides outlasted the rift (counts as a victory)")


func test_collapse_ends_a_stalemate() -> void:
	var result: FightResult = K.run([K.dummy("hero", 800)], [K.dummy("foe", 300)])
	assert_eq(result.outcome, FightResult.Outcome.VICTORY)
	assert_eq(result.end_tick, 1040, "300 HP falls to collapse at 52s")


# --- the log ---------------------------------------------------------------------------

func test_every_effect_names_its_source() -> void:
	var mend: ItemDef = K.item("mend", {"effects": [{"trigger": "on_fire", "type": "heal", "amount": 5, "target": "ally_lowest_hp"}]})
	var ward: ItemDef = K.item("ward", {"effects": [{"trigger": "on_fire", "type": "shield", "amount": 5, "target": "self"}]})
	var result: FightResult = K.run([K.unit("hero", 500, FRONT, [mend, ward])], [K.unit("foe", 500)])
	var checked: int = 0
	for entry: LogEntry in result.combat_log.entries:
		match entry.kind:
			LogEntry.Kind.DAMAGE, LogEntry.Kind.HEAL, LogEntry.Kind.SHIELD, LogEntry.Kind.FIRE:
				assert_false(entry.source_unit.is_empty(), entry.to_text())
				assert_false(entry.source_item.is_empty(), entry.to_text())
				checked += 1
			LogEntry.Kind.COLLAPSE:
				assert_eq(entry.source_item, LogEntry.COLLAPSE_SOURCE)
	assert_gt(checked, 10)
