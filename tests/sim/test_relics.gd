extends GutTest
## Relics in the sim (docs/plans/relics-in-sim.md): data, filters, side-wide
## boosts, grants, triggers, and enemy relics.

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT := UnitSetup.Row.FRONT
const BACK := UnitSetup.Row.BACK


func _read(data: Dictionary) -> Array:
	var full: Dictionary = {"id": "test_relic", "name": "Test Relic", "rarity": "rare"}
	full.merge(data, true)
	var errors: Array[String] = []
	var def: RelicDef = RelicDef.read(DataReader.new(full, "relic", errors))
	return [def, errors]


func _assert_error(errors: Array[String], expected: String) -> void:
	var found: bool = false
	for message: String in errors:
		found = found or message.contains(expected)
	assert_true(found, "expected an error containing '%s', got: %s" % [expected, errors])


func _crit_aura(filter: Dictionary) -> Array:
	return [{"target": "all_items", "filter": filter, "stat": "crit_chance_bp", "value": 1000}]


## The unit's row items' crit chances, left to right.
func _row_crits(sim: CombatSim, unit_id: String) -> Array[int]:
	var crits: Array[int] = []
	for item: ItemState in sim.unit_by_id(unit_id).row_items():
		crits.append(item.crit_chance_bp)
	return crits


func _basic_crit(sim: CombatSim, unit_id: String) -> int:
	return sim.unit_by_id(unit_id).items[0].crit_chance_bp


func _step_to(sim: CombatSim, tick: int) -> void:
	while sim.tick < tick and not sim.finished:
		sim.step()


func _relic_entries(sim: CombatSim, kind: LogEntry.Kind, relic_id: String) -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in sim.combat_log.of_kind(kind):
		if entry.source_relic_side >= 0 and entry.source_item == relic_id:
			found.append(entry)
	return found


# --- data ---------------------------------------------------------------------

func test_reads_relic() -> void:
	var result: Array = _read({
		"cooldown_ms": 8000,
		"auras": [{"target": "all_allies", "filter": {"row": "front"}, "stat": "def_bp", "value": 12000}],
		"grants": [{"filter": {"tag": "weapon"}, "effect": {"trigger": "on_hit", "type": "apply_status", "status": "burn", "stacks": 1, "target": "hit_target"}}],
		"effects": [
			{"trigger": "on_fire", "type": "heal", "amount": 30, "target": "ally_lowest_hp"},
			{"trigger": "on_ally_below_hp", "threshold_bp": 3000, "once": true, "type": "shield", "amount": 80, "target": "trigger_ally"},
			{"trigger": "at_time", "at_ms": 20000, "type": "apply_status", "status": "slow", "stacks": 2, "target": "all_enemies"},
		],
	})
	var def: RelicDef = result[0]
	assert_eq(result[1], [] as Array[String])
	assert_eq(def.cooldown_ticks, 160)
	assert_eq(def.auras[0].filter.row, UnitSetup.Row.FRONT)
	assert_eq(def.grants[0].filter.tag, "weapon")
	assert_eq(def.effects[1].trigger, EffectDef.Trigger.ON_ALLY_BELOW_HP)
	assert_eq(def.effects[1].threshold_bp, 3000)
	assert_true(def.effects[1].once)
	assert_eq(def.effects[1].target, EffectDef.Target.TRIGGER_ALLY)
	assert_eq(def.effects[2].at_ticks, 400)


func test_rejects_empty_relic() -> void:
	_assert_error(_read({})[1], "a relic needs auras, grants, or effects")


func test_rejects_targets_that_need_a_holder() -> void:
	for target: String in ["self", "linked_ally", "row_allies"]:
		var errors: Array[String] = _read({"effects": [{"trigger": "on_fight_start", "type": "shield", "amount": 5, "target": target}]})[1]
		_assert_error(errors, "\"%s\" needs a spot on the field, so a relic can't use it" % target)


func test_relics_and_items_keep_their_own_triggers() -> void:
	var relic_errors: Array[String] = _read({"effects": [{"trigger": "on_hit", "type": "damage", "amount": 5, "target": "enemy_front"}]})[1]
	_assert_error(relic_errors, "relic effects can't use the trigger \"on_hit\"")
	var item: Dictionary = K.DEFAULT_ITEM.duplicate(true)
	item["id"] = "early"
	item["effects"] = [{"trigger": "on_fight_start", "type": "damage", "amount": 5, "target": "enemy_front"}]
	var item_errors: Array[String] = []
	ItemDef.read(DataReader.new(item, "item", item_errors))
	_assert_error(item_errors, "item effects can't use the trigger \"on_fight_start\"")


func test_relic_numbers_are_flat() -> void:
	var errors: Array[String] = _read({
		"effects": [{"trigger": "on_fight_start", "type": "shield", "amount": 5, "scaling": {"def": 5000}, "target": "all_allies"}],
		"grants": [{"effect": {"trigger": "on_fire", "type": "damage", "amount": 5, "scaling": {"atk": 5000}, "target": "enemy_front"}}],
	})[1]
	_assert_error(errors, "relic numbers are flat, so relic effects can't have \"scaling\"")
	_assert_error(errors, "relic numbers are flat, so a grant can't have \"scaling\"")


func test_cooldown_goes_with_on_fire() -> void:
	_assert_error(_read({"effects": [{"trigger": "on_fire", "type": "heal", "amount": 5, "target": "all_allies"}]})[1], "missing required key \"cooldown_ms\"")
	_assert_error(_read({"cooldown_ms": 1000, "effects": [{"trigger": "on_fight_start", "type": "heal", "amount": 5, "target": "all_allies"}]})[1], "cooldown_ms only matters for on_fire effects")


func test_trigger_ally_needs_its_trigger() -> void:
	var errors: Array[String] = _read({"effects": [{"trigger": "at_time", "at_ms": 1000, "type": "heal", "amount": 5, "target": "trigger_ally"}]})[1]
	_assert_error(errors, "\"trigger_ally\" only works with the on_ally_below_hp trigger")


func test_relic_auras_reach_the_whole_side() -> void:
	var errors: Array[String] = _read({"auras": [{"target": "holder", "stat": "def_bp", "value": 12000}]})[1]
	_assert_error(errors, "a relic aura can only target all_items or all_allies")


func test_filters_are_checked() -> void:
	_assert_error(_read({"auras": _crit_aura({"row": "front"})})[1], "\"row\" filters units, but this reaches items")
	_assert_error(_read({"auras": _crit_aura({"colour": "red"})})[1], "unknown filter \"colour\"")
	_assert_error(_read({"auras": _crit_aura({})})[1], "a filter needs at least one of")
	_assert_error(_read({"auras": [{"target": "all_allies", "filter": {"tag": "weapon"}, "stat": "def_bp", "value": 12000}]})[1], "\"tag\" filters items, but this reaches units")


func test_real_relics_load() -> void:
	var content: ContentDb = K.content()
	assert_gte(content.relic_ids.size(), 8)
	assert_true(content.relics["gloam_totem"].enemy_only)
	assert_eq(content.encounters["witch_coven"].relics, ["gloam_totem"] as Array[String])


func test_content_checks_relic_references() -> void:
	var texts: Dictionary[String, String] = {}
	for file_name: String in ContentDb.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	texts[ContentDb.RELICS_FILE] = JSON.stringify([
		{"id": "odd_relic", "name": "Odd", "rarity": "rare", "auras": [{"target": "all_items", "filter": {"applies": "mystery", "essence": "glitter"}, "stat": "damage_bp", "value": 12000}]},
	])
	var encounters: Array = JSON.parse_string(texts[ContentDb.ENCOUNTERS_FILE])
	encounters[0]["relics"] = ["no_such_relic"]
	texts[ContentDb.ENCOUNTERS_FILE] = JSON.stringify(encounters)
	var errors: Array[String] = ContentDb.load_texts(texts).errors
	_assert_error(errors, "unknown status \"mystery\"")
	_assert_error(errors, "unknown essence \"glitter\"")
	_assert_error(errors, "unknown relic \"no_such_relic\"")


func test_heroes_cant_hold_enemy_only_relics_from_content() -> void:
	var checker := ContentDb.new()
	checker.relics = K.content().relics
	checker.check_relics(["gloam_totem", "warding_knot", "warding_knot"] as Array[String], "party", false)
	_assert_error(checker.errors, "\"gloam_totem\" is enemy-only")
	_assert_error(checker.errors, "\"warding_knot\" is listed twice")


func test_fight_setup_checks_relics() -> void:
	var knot: RelicDef = K.relic("setup_knot", {"auras": _crit_aura({"tag": "weapon"})})
	var setup := FightSetup.make([K.dummy("a", 100)] as Array[UnitSetup], [K.dummy("b", 100)] as Array[UnitSetup], 1, 1, [] as Array[UnitSetup], ["missing_relic", knot.id, knot.id] as Array[String])
	var errors: Array[String] = setup.validate(K.relic_content())
	_assert_error(errors, "guild relic \"missing_relic\" doesn't exist")
	_assert_error(errors, "guild relic \"setup_knot\" is held twice")


# --- auras and filters --------------------------------------------------------

func test_item_filters() -> void:
	var sword: ItemDef = K.item("f_sword", {"tags": ["weapon"], "size": 2})
	var charm: ItemDef = K.item("f_charm", {"tags": ["charm"]})
	var brand: ItemDef = K.item("f_brand", {"effects": [{"trigger": "on_fire", "type": "apply_status", "status": "burn", "stacks": 1, "target": "enemy_front"}]})
	var heroes: Array[UnitSetup] = [K.unit("a", 100, FRONT, [sword, charm, brand, K.equip(K.item("f_plain"), ["ember"] as Array[String]), K.equip(K.item("f_cold"), ["frost"] as Array[String])])]
	var cases: Dictionary = {
		"tag": [{"tag": "weapon"}, [1000, 0, 0, 0, 0]],
		"size": [{"size": 1}, [0, 1000, 1000, 1000, 1000]],
		"applies": [{"applies": "burn"}, [0, 0, 1000, 1000, 0]],
		"essence": [{"essence": "frost"}, [0, 0, 0, 0, 1000]],
		"item": [{"item": "f_charm"}, [0, 1000, 0, 0, 0]],
	}
	for label: String in ["tag", "size", "applies", "essence", "item"]:
		var relic: RelicDef = K.relic("filter_%s" % label, {"auras": _crit_aura(cases[label][0])})
		var sim: CombatSim = K.relic_sim(heroes, [K.dummy("b", 100)], [relic])
		assert_eq(_row_crits(sim, "a"), cases[label][1] as Array[int], "filter by %s" % label)
		assert_eq(_basic_crit(sim, "a"), 0, "the basic attack has no tags, size, or infusion")


func test_unfiltered_all_items_reaches_the_basic_attack_too() -> void:
	var relic: RelicDef = K.relic("all_crit", {"auras": [{"target": "all_items", "stat": "crit_chance_bp", "value": 1000}]})
	var sim: CombatSim = K.relic_sim([K.unit("a", 100, FRONT, [K.item("u_one")]), K.unit("c", 100, BACK)], [K.dummy("b", 100)], [relic])
	assert_eq(_basic_crit(sim, "c"), 1000)
	assert_eq(_row_crits(sim, "a"), [1000] as Array[int])
	assert_eq(_basic_crit(sim, "b"), 0, "enemies aren't affected")


func test_unit_filters() -> void:
	var front: UnitSetup = K.unit_with("front", UnitStats.make(100, 0, 0, 100))
	var back: UnitSetup = K.unit_with("back", UnitStats.make(100, 0, 0, 100), BACK)
	var warden: UnitSetup = K.unit_with("warden", UnitStats.make(100, 0, 0, 100), BACK)
	warden.unit_class = "warden"
	var banner: RelicDef = K.relic("row_banner", {"auras": [{"target": "all_allies", "filter": {"row": "front"}, "stat": "def_bp", "value": 12000}]})
	var oath: RelicDef = K.relic("class_oath", {"auras": [{"target": "all_allies", "filter": {"class": "warden"}, "stat": "def_bp", "value": 15000}]})
	var sim: CombatSim = K.relic_sim([front, back, warden], [K.dummy("b", 100)], [banner, oath])
	assert_eq(sim.unit_by_id("front").stats.get_stat(UnitStats.Stat.DEF), 120)
	assert_eq(sim.unit_by_id("back").stats.get_stat(UnitStats.Stat.DEF), 100)
	assert_eq(sim.unit_by_id("warden").stats.get_stat(UnitStats.Stat.DEF), 150)


func test_real_heroes_carry_their_class() -> void:
	var content: ContentDb = K.content()
	var brannoc: UnitSetup = SetupBuilder.hero(content, "brannoc", 0, FRONT, [])
	assert_eq(brannoc.unit_class, "warden")


func test_relic_auras_reach_backup_heroes() -> void:
	var benched: UnitSetup = K.unit("vell", 100, BACK)
	benched.backup = K.backup({"cooldown_ms": 3000, "effects": [{"trigger": "on_fire", "type": "heal", "amount": 5, "target": "all_allies"}]})
	var relic: RelicDef = K.relic("bench_crit", {"auras": [{"target": "all_items", "stat": "crit_chance_bp", "value": 1000}]})
	var sim: CombatSim = K.relic_sim([K.unit("a", 100)], [K.dummy("b", 100)], [relic], [], [benched])
	assert_eq(sim.bench[0].items[0].crit_chance_bp, 1000)


func test_relic_auras_are_logged() -> void:
	var relic: RelicDef = K.relic("logged_aura", {"name": "Logged Aura", "auras": _crit_aura({"tag": "weapon"})})
	var sim: CombatSim = K.relic_sim([K.unit("a", 100)], [K.dummy("b", 100)], [relic])
	var auras: Array[LogEntry] = _relic_entries(sim, LogEntry.Kind.AURA, "logged_aura")
	assert_eq(auras.size(), 1)
	assert_eq(auras[0].to_text(), "[0.00s] relic · Logged Aura aura starts: +10% crit chance for all items (weapon)")


func test_enemy_relics_boost_the_enemy_side() -> void:
	var totem: RelicDef = K.relic("enemy_totem", {"name": "Enemy Totem", "enemy_only": true, "auras": [{"target": "all_allies", "stat": "mgk_bp", "value": 12000}]})
	var sim: CombatSim = K.relic_sim([K.unit_with("a", UnitStats.make(100, 0, 50))], [K.unit_with("b", UnitStats.make(100, 0, 50))], [], [totem])
	assert_eq(sim.unit_by_id("a").stats.get_stat(UnitStats.Stat.MGK), 50)
	assert_eq(sim.unit_by_id("b").stats.get_stat(UnitStats.Stat.MGK), 60)
	assert_eq(_relic_entries(sim, LogEntry.Kind.AURA, "enemy_totem")[0].source_text(), "enemy relic · Enemy Totem")


# --- flat numbers and side-wide boosts ----------------------------------------

func test_only_side_wide_boosts_reach_relic_numbers() -> void:
	var wall: RelicDef = K.relic("start_wall", {"effects": [{"trigger": "on_fight_start", "type": "shield", "amount": 40, "target": "all_allies"}]})
	var all_shields: RelicDef = K.relic("all_shields", {"auras": [{"target": "all_items", "stat": "shield_bp", "value": 15000}]})
	var weapon_shields: RelicDef = K.relic("weapon_shields", {"auras": [{"target": "all_items", "filter": {"tag": "weapon"}, "stat": "shield_bp", "value": 20000}]})
	var guard: ItemDef = K.item("s_guard", {"cooldown_ms": 60000, "effects": [{"trigger": "on_fire", "type": "shield", "amount": 10, "target": "self"}]})
	var sim: CombatSim = K.relic_sim([K.unit("a", 100, FRONT, [K.equip(guard, [], 3)])], [K.dummy("b", 100)], [wall, all_shields, weapon_shields])
	var shields: Array[LogEntry] = _relic_entries(sim, LogEntry.Kind.SHIELD, "start_wall")
	assert_eq(shields.size(), 1)
	assert_eq(shields[0].tick, 0)
	assert_eq(shields[0].amount, 60, "40 x1.5 from the unfiltered aura; the weapon-only one doesn't apply")
	assert_eq(shields[0].to_text(), "[0.00s] relic · Start Wall gives a 60 shield")
	# The item's own shield still gets its tier (S x3) and the side-wide boost.
	assert_eq(sim.unit_by_id("a").row_items()[0].effects[0].final_amount(), 45)


func test_item_auras_over_everything_also_boost_relics() -> void:
	var wall: RelicDef = K.relic("start_wall_2", {"effects": [{"trigger": "on_fight_start", "type": "shield", "amount": 40, "target": "all_allies"}]})
	var banner: ItemDef = K.item("s_banner", {"effects": [], "auras": [{"target": "all_items", "stat": "shield_bp", "value": 15000}]})
	var sim: CombatSim = K.relic_sim([K.unit("a", 100, FRONT, [banner])], [K.dummy("b", 100)], [wall])
	assert_eq(_relic_entries(sim, LogEntry.Kind.SHIELD, "start_wall_2")[0].amount, 60)


# --- grants -------------------------------------------------------------------

func test_grants_add_a_flat_effect_to_matching_items() -> void:
	var crown: RelicDef = K.relic("test_crown", {"name": "Test Crown", "grants": [
		{"filter": {"tag": "weapon"}, "effect": {"trigger": "on_hit", "type": "apply_status", "status": "poison", "stacks": 1, "target": "hit_target"}}]})
	var blade: ItemDef = K.item("g_blade", {"tags": ["weapon"], "cooldown_ms": 1000, "effects": K.damage(10)})
	var trinket: ItemDef = K.item("g_trinket", {"tags": ["charm"], "cooldown_ms": 1000, "effects": K.damage(10)})
	var sim: CombatSim = K.relic_sim([K.unit("a", 500, FRONT, [K.equip(blade, [], 3), trinket])], [K.dummy("b", 5000)], [crown])
	_step_to(sim, 40)
	var applied: Array[LogEntry] = []
	for entry: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED):
		applied.append(entry)
	assert_eq(applied.size(), 2, "only the weapon applies it, once per hit")
	assert_eq(applied[0].source_item, "g_blade")
	assert_eq(applied[0].source_granted_by, "Test Crown")
	assert_eq(applied[0].amount, 1, "flat: the S tier doesn't multiply it")
	assert_string_contains(applied[0].to_text(), "a · Test Item (Test Crown) applies 1 Poison to b")


func test_grants_get_side_wide_boosts_only() -> void:
	var crown: RelicDef = K.relic("boost_crown", {"grants": [{"effect": {"trigger": "on_fire", "type": "damage", "amount": 10, "target": "enemy_front"}}]})
	var all_damage: RelicDef = K.relic("all_damage", {"auras": [{"target": "all_items", "stat": "damage_bp", "value": 15000}]})
	var weapon_damage: RelicDef = K.relic("weapon_damage", {"auras": [{"target": "all_items", "filter": {"size": 1}, "stat": "damage_bp", "value": 20000}]})
	var sim: CombatSim = K.relic_sim([K.unit("a", 100, FRONT, [K.equip(K.item("g_small"), [], 2)])], [K.dummy("b", 100)], [crown, all_damage, weapon_damage])
	var small: ItemState = sim.unit_by_id("a").row_items()[0]
	var granted: SourcedEffect = small.effects[1]
	assert_eq(granted.granted_by, "Boost Crown")
	assert_eq(granted.final_amount(), 15, "10 x1.5 (side-wide); not the tier or the size-filtered aura")
	assert_eq(small.effects[0].final_amount(), 60, "the item's own damage: 10 x2 tier A x1.5 x2")
	assert_true(small.describe_values()[1].begins_with("damage (Boost Crown):"))


# --- triggers -----------------------------------------------------------------

func test_at_time_fires_once_at_its_tick() -> void:
	var bell: RelicDef = K.relic("toll", {"effects": [{"trigger": "at_time", "at_ms": 2000, "type": "damage", "amount": 7, "target": "all_enemies"}]})
	var sim: CombatSim = K.relic_sim([K.dummy("a", 100)], [K.dummy("b", 1000), K.dummy("c", 1000)], [bell])
	_step_to(sim, 100)
	var hits: Array[LogEntry] = _relic_entries(sim, LogEntry.Kind.DAMAGE, "toll")
	assert_eq(K.ticks_of(hits), [40, 40] as Array[int])
	assert_eq(K.targets_of(hits), ["b", "c"] as Array[String])
	assert_eq(hits[0].amount, 7)


func test_cooldown_relic_fires_on_schedule() -> void:
	var flask: RelicDef = K.relic("flask", {"cooldown_ms": 1000, "effects": [{"trigger": "on_fire", "type": "damage", "amount": 1, "target": "enemy_front"}]})
	var sim: CombatSim = K.relic_sim([K.dummy("a", 100)], [K.dummy("b", 1000)], [flask])
	_step_to(sim, 70)
	assert_eq(K.ticks_of(_relic_entries(sim, LogEntry.Kind.FIRE, "flask")), [20, 40, 60] as Array[int])
	assert_eq(K.ticks_of(_relic_entries(sim, LogEntry.Kind.DAMAGE, "flask")), [20, 40, 60] as Array[int])


func test_relics_act_after_their_side() -> void:
	var flask: RelicDef = K.relic("order_flask", {"cooldown_ms": 1000, "effects": [{"trigger": "on_fire", "type": "damage", "amount": 1, "target": "enemy_front"}]})
	var sim: CombatSim = K.relic_sim([K.unit("a", 100)], [K.unit("b", 1000)], [flask])
	_step_to(sim, 20)
	var sources: Array[String] = []
	for entry: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.FIRE):
		sources.append(entry.source_text())
	assert_eq(sources, ["a · Basic Attack", "relic · Order Flask", "b · Basic Attack"] as Array[String])


func _below_hp_fight(relic: RelicDef, blow: int) -> CombatSim:
	var slam: ItemDef = K.item("slam", {"cooldown_ms": 1000, "effects": K.damage(blow, "all_enemies")})
	var sim: CombatSim = K.relic_sim([K.dummy("a", 100), K.dummy("c", 100, BACK)], [K.unit("b", 1000, FRONT, [slam], K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)}))], [relic])
	_step_to(sim, 45)
	return sim


func test_below_hp_once_shields_only_the_first_ally() -> void:
	var knot: RelicDef = K.relic("knot_once", {"effects": [{"trigger": "on_ally_below_hp", "threshold_bp": 3000, "once": true, "type": "shield", "amount": 80, "target": "trigger_ally"}]})
	var shields: Array[LogEntry] = _relic_entries(_below_hp_fight(knot, 80), LogEntry.Kind.SHIELD, "knot_once")
	assert_eq(K.targets_of(shields), ["a"] as Array[String])
	assert_eq(K.ticks_of(shields), [20] as Array[int], "checked the same tick the blow lands")


func test_below_hp_without_once_triggers_per_ally() -> void:
	var knot: RelicDef = K.relic("knot_each", {"effects": [{"trigger": "on_ally_below_hp", "threshold_bp": 3000, "type": "shield", "amount": 80, "target": "trigger_ally"}]})
	var shields: Array[LogEntry] = _relic_entries(_below_hp_fight(knot, 80), LogEntry.Kind.SHIELD, "knot_each")
	assert_eq(K.targets_of(shields), ["a", "c"] as Array[String], "each ally once, not again at the next blow")


func test_below_hp_ignores_allies_killed_outright() -> void:
	var knot: RelicDef = K.relic("knot_late", {"effects": [{"trigger": "on_ally_below_hp", "threshold_bp": 3000, "type": "shield", "amount": 80, "target": "trigger_ally"}]})
	assert_eq(_relic_entries(_below_hp_fight(knot, 150), LogEntry.Kind.SHIELD, "knot_late").size(), 0)


func test_relic_blight_heals_the_relic_side() -> void:
	var rot: RelicDef = K.relic("rot", {"effects": [{"trigger": "on_fight_start", "type": "apply_status", "status": "blight", "stacks": 5, "target": "all_enemies"}]})
	var hurt: UnitSetup = K.dummy("a", 200)
	var sim: CombatSim = K.relic_sim([hurt], [K.dummy("b", 1000)], [rot])
	sim.unit_by_id("a").hp = 100
	_step_to(sim, 40)
	var heals: Array[LogEntry] = _relic_entries(sim, LogEntry.Kind.HEAL, "rot")
	assert_gt(heals.size(), 0, "Blight from a relic heals the relic's side")
	assert_eq(heals[0].target, "a")


func test_relic_output_shows_in_the_damage_meter() -> void:
	var toll: RelicDef = K.relic("meter_toll", {"name": "Meter Toll", "effects": [{"trigger": "at_time", "at_ms": 1000, "type": "damage", "amount": 7, "target": "enemy_front"}]})
	var sim: CombatSim = K.relic_sim([K.dummy("a", 100)], [K.dummy("b", 1000)], [toll])
	_step_to(sim, 30)
	var meter: DamageMeter = DamageMeter.from_log(sim.combat_log, ["a"] as Array[String])
	var found: bool = false
	for row: DamageMeter.Row in meter.rows:
		if row.item_id == "meter_toll":
			found = true
			assert_eq(row.side, UnitSetup.Side.HEROES)
			assert_eq(row.damage, 7)
			assert_eq(row.item_name, "Meter Toll")
	assert_true(found)


func test_relic_fights_are_deterministic() -> void:
	var relics: Array[String] = ["warding_knot", "tinkers_loupe", "cinder_crown", "pilgrims_flask", "hourglass"]
	var setups: Array[FightSetup] = []
	for i: int in 2:
		var party: Array[UnitSetup] = []
		for hero_id: String in ["brannoc", "wren", "odo"]:
			var entries: Array[LoadoutEntry] = []
			var item_id: String = "rusted_cleaver" if hero_id == "brannoc" else ("hearth_knife" if hero_id == "wren" else "tallow_torch")
			var entry := LoadoutEntry.new()
			entry.item_id = item_id
			entries.append(entry)
			party.append(SetupBuilder.hero(K.content(), hero_id, 0, FRONT if hero_id != "odo" else BACK, entries))
		setups.append(FightSetup.make(party, SetupBuilder.encounter_units(K.content(), "witch_coven"), 3, 1, [] as Array[UnitSetup], relics, SetupBuilder.encounter_relics(K.content(), "witch_coven")))
	var first: FightResult = CombatSim.run(setups[0], K.content())
	var second: FightResult = CombatSim.run(setups[1], K.content())
	assert_eq(first.errors, [] as Array[String])
	assert_eq(first.combat_log.to_text(), second.combat_log.to_text())
	assert_string_contains(first.combat_log.to_text(), "(Cinder Crown) applies")
	assert_string_contains(first.combat_log.to_text(), "enemy relic · Gloam Totem aura starts")
