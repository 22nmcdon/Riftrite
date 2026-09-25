extends GutTest
## Alloys: both essences' normal effects plus the alloy's special, the new
## status types that keep specials off plain Burn/Bleed, and alloy spill.

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT := UnitSetup.Row.FRONT
const BACK := UnitSetup.Row.BACK
const BIG_HP: int = 10000000


func _idle() -> ItemDef:
	return K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)})


## An Epic item, so it has two sockets for an alloy or pure double.
func _big(item_id: String, overrides: Dictionary = {}) -> ItemDef:
	var data: Dictionary = {"name": item_id.capitalize(), "size": 2, "rarity": "epic", "effects": K.damage(100)}
	data.merge(overrides, true)
	return K.item(item_id, data)


func _torch() -> ItemDef:
	return _big("torch", {"effects": [{"trigger": "on_fire", "type": "apply_status", "status": "burn", "stacks": 10, "target": "enemy_front"}]})


func _with(item: ItemDef, essences: Array[String], xp: int = 0) -> ItemSetup:
	return K.equip(item, essences, 0, xp)


func _hero(items: Array, hero_id: String = "hero", row: UnitSetup.Row = FRONT) -> UnitSetup:
	return K.unit(hero_id, BIG_HP, row, items, _idle())


func _applied(result: FightResult, status: String) -> Array[LogEntry]:
	return result.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED).filter(
		func(entry: LogEntry) -> bool: return entry.status == status)


func _sim(heroes: Array[UnitSetup], enemies: Array[UnitSetup]) -> CombatSim:
	return CombatSim.new(K.fight(heroes, enemies), K.content())


# --- content ---------------------------------------------------------------------------

func test_recipes_work_in_either_order() -> void:
	var db: ContentDb = K.content()
	assert_eq(db.alloy_for("storm", "ember").id, "plasma")
	assert_eq(db.alloy_for("ember", "storm").id, "plasma")
	assert_eq(db.alloy_for("ember", "ember").id, "inferno")
	assert_null(db.alloy_for("ember", "frost"), "no named alloy yet")


func test_alloy_file_is_validated() -> void:
	var texts: Dictionary[String, String] = {}
	for file_name: String in ContentDb.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	texts[ContentDb.ALLOYS_FILE] = JSON.stringify([
		{"id": "a", "name": "A", "recipe": ["ember", "glitter"], "heal_echo_bp": 5000},
		{"id": "b", "name": "B", "recipe": ["frost", "ember"], "replaces": {"burn": "scorch"}},
		{"id": "c", "name": "C", "recipe": ["ember", "frost"], "heal_echo_bp": 5000},
		{"id": "d", "name": "D", "recipe": ["wrath", "wrath"]},
	])
	var errors: Array[String] = ContentDb.load_texts(texts).errors
	for expected: String in ["recipe uses unknown essence \"glitter\"", "replaces uses unknown status \"scorch\"",
			"recipe ember+frost is already used by \"b\"", "an alloy needs \"replaces\" or \"heal_echo_bp\""]:
		assert_true(errors.any(func(e: String) -> bool: return e.contains(expected)), "%s in %s" % [expected, errors])


# --- keeping both essences ----------------------------------------------------------

func test_alloy_keeps_both_essences() -> void:
	var sim := _sim([_hero([_with(_big("hex"), ["ember", "storm"] as Array[String])])], [K.dummy("foe", BIG_HP)])
	assert_eq(sim.units[0].items[1].cooldown_ticks, 17, "Storm's -15% cooldown")
	var result: FightResult = K.run([_hero([_with(_big("hex"), ["ember", "storm"] as Array[String])])], [K.dummy("foe", BIG_HP)])
	var first: LogEntry = _applied(result, "plasma")[0]
	assert_eq(first.to_text(), "[0.85s] hero · Hex [Plasma] applies 5 Plasma to foe (5 total)", "Ember's 5% burn, as Plasma")


func test_unnamed_pair_keeps_both_essences() -> void:
	var result: FightResult = K.run([_hero([_with(_big("blade"), ["ember", "frost"] as Array[String])])], [K.dummy("foe", BIG_HP)])
	assert_eq(_applied(result, "burn")[0].source_infusion_name, "Ember + Frost")
	assert_gt(_applied(result, "slow").size(), 0)


# --- Inferno ---------------------------------------------------------------------------

func test_inferno_burns_golden_and_never_fades() -> void:
	var result: FightResult = K.run([_hero([_with(_big("blade"), ["ember", "ember"] as Array[String])])], [K.dummy("foe", BIG_HP)])
	var flames: Array[LogEntry] = _applied(result, "golden_flame")
	assert_eq([flames[0].amount, flames[1].amount], [5, 5], "both Embers' 5%")
	assert_eq(_applied(result, "burn").size(), 0, "no plain Burn")
	assert_eq(result.combat_log.of_kind(LogEntry.Kind.STATUS_ENDED).filter(
		func(entry: LogEntry) -> bool: return entry.status == "golden_flame").size(), 0)


func test_inferno_turns_the_items_own_burn_golden() -> void:
	var sim := _sim([_hero([_with(_torch(), ["ember", "ember"] as Array[String])])], [K.dummy("foe", BIG_HP)])
	assert_eq(sim.units[0].items[1].describe_values(), PackedStringArray(["burn stacks: 23 (base 10, x1.5 Inferno, x1.5 Inferno)"]))
	var result: FightResult = K.run([_hero([_with(_torch(), ["ember", "ember"] as Array[String])])], [K.dummy("foe", BIG_HP)])
	assert_eq(_applied(result, "golden_flame")[0].amount, 23)
	assert_eq(_applied(result, "burn").size(), 0)


func test_inferno_leaves_other_items_burn_alone() -> void:
	var result: FightResult = K.run([
		_hero([_with(_big("blade"), ["ember", "ember"] as Array[String])]),
		_hero([_with(K.item("sword", {"effects": K.damage(100)}), ["ember"] as Array[String])], "ally")], [K.dummy("foe", BIG_HP)])
	assert_eq(_applied(result, "burn")[0].source_unit, "ally")


func test_golden_flame_resists_heals() -> void:
	var sim := _sim([K.dummy("hero", 100)], [K.dummy("foe", 1000)])
	var foe: UnitState = sim.units[1]
	Statuses.apply(sim, foe, "golden_flame", 1000, EffectSource.make("hero", "blade", "Blade"))
	foe.hp = 500
	EffectRunner.heal(sim, foe, 1, EffectSource.make("foe", "salve", "Salve"))
	assert_eq(sim.combat_log.of_kind(LogEntry.Kind.STATUS_REDUCED)[0].amount, 75, "10% x 75%")


# --- Plasma ----------------------------------------------------------------------------

func test_plasma_jumps_to_the_nearest_other_enemy() -> void:
	var result: FightResult = K.run([_hero([_with(_big("hex"), ["ember", "storm"] as Array[String])])],
		[K.dummy("foe_a", BIG_HP), K.dummy("foe_b", BIG_HP), K.dummy("foe_c", BIG_HP, BACK)])
	var jump: LogEntry = result.combat_log.of_kind(LogEntry.Kind.STATUS_JUMPED)[0]
	# 5 Plasma lands at 0.85s; it ticks at 1.35s (5 damage, loses 1) and jumps.
	assert_eq(jump.to_text(), "[1.35s] Plasma jumps from foe_a to foe_b (4 stacks)")


func test_plasma_stays_put_with_nobody_to_jump_to() -> void:
	var result: FightResult = K.run([_hero([_with(_big("hex"), ["ember", "storm"] as Array[String])])], [K.dummy("foe", BIG_HP)])
	assert_eq(result.combat_log.of_kind(LogEntry.Kind.STATUS_JUMPED).size(), 0)


# --- Blight ----------------------------------------------------------------------------

func test_blight_turns_crit_bleed_into_blight() -> void:
	var knife: ItemDef = _big("knife", {"crit_chance_bp": 10000})
	var result: FightResult = K.run([_hero([_with(knife, ["umbral", "verdant"] as Array[String])])], [K.dummy("foe", BIG_HP)])
	assert_eq(_applied(result, "blight")[0].amount, 7, "5% of the 150 crit")
	assert_eq(_applied(result, "bleed").size(), 0)


func test_blight_damage_heals_the_appliers_team() -> void:
	var sim := _sim([K.dummy("hero", 1000), K.dummy("ally", 1000, BACK)], [K.dummy("foe", 1000)])
	sim.units[0].hp = 500
	sim.units[1].hp = 500
	Statuses.apply(sim, sim.units[2], "blight", 7, EffectSource.make("hero", "knife", "Knife", "umbral", "Blight"))
	for i: int in 20:
		sim.tick += 1
		Statuses.tick_all(sim)
	var heals: Array[String] = []
	for entry: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.HEAL):
		heals.append("%s %d" % [entry.target, entry.amount])
	assert_eq(heals, ["hero 4", "ally 3"] as Array[String], "7 damage split across the team")


# --- Bloom -------------------------------------------------------------------------------

func test_bloom_echoes_heals_onto_another_ally() -> void:
	var charm: ItemDef = _big("charm", {"effects": [{"trigger": "on_fire", "type": "heal", "amount": 100, "target": "self"}]})
	var sim := _sim([_hero([_with(charm, ["verdant", "storm"] as Array[String])]), K.dummy("ally", 1000, BACK)], [K.dummy("foe", BIG_HP)])
	sim.units[0].hp = 10
	sim.units[1].hp = 10
	var item: ItemState = sim.units[0].items[1]
	EffectRunner.heal(sim, sim.units[0], 100, EffectSource.make("hero", "charm", "Charm", "verdant", "Bloom"), item)
	var heals: Array[String] = []
	for entry: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.HEAL):
		heals.append("%s %d [%s]" % [entry.target, entry.amount, entry.source_infusion_name])
	assert_eq(heals, ["hero 100 [Bloom]", "ally 50 [Bloom echo]"] as Array[String])


# --- spill -------------------------------------------------------------------------------

func _row(essences: Array[String]) -> Array:
	return [K.item("left", {"name": "Left", "effects": K.damage(100)}), _with(_big("mid"), essences, 300), K.item("right", {"name": "Right", "effects": K.damage(100)})]


func test_alloy_spills_first_essence_left_and_second_right() -> void:
	var sim := _sim([_hero(_row(["ember", "storm"] as Array[String]))], [K.dummy("foe", BIG_HP)])
	assert_eq(sim.units[0].items[3].cooldown_ticks, 18, "right gets Storm: -15% x 0.6 = -9%")
	assert_eq(sim.units[0].items[1].cooldown_ticks, 20, "left gets no Storm")
	var result: FightResult = K.run([_hero(_row(["ember", "storm"] as Array[String]))], [K.dummy("foe", BIG_HP)])
	var left_burn: LogEntry = _applied(result, "burn").filter(func(entry: LogEntry) -> bool: return entry.source_item == "left")[0]
	assert_eq([left_burn.amount, left_burn.source_infusion_name], [3, "Ember spill from Mid"], "plain Burn: the Plasma special doesn't spill")


func test_pure_double_spills_its_essence_both_ways() -> void:
	var result: FightResult = K.run([_hero(_row(["ember", "ember"] as Array[String]))], [K.dummy("foe", BIG_HP)])
	var spilled: Array[String] = []
	for entry: LogEntry in _applied(result, "burn"):
		if entry.tick == 20:
			spilled.append("%s %d" % [entry.source_item, entry.amount])
	assert_eq(spilled, ["left 3", "right 3"] as Array[String], "one Ember spill per side, as plain Burn")
