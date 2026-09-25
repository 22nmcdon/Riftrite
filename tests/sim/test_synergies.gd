extends GutTest
## The synergy engine (docs/plans/synergies-in-sim.md): data, matching for
## all five layers, charge, transformations, and what shows in the log.

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT := UnitSetup.Row.FRONT
const BACK := UnitSetup.Row.BACK


func before_each() -> void:
	K.clear_synergies()


func _read(data: Dictionary) -> Array:
	var full: Dictionary = {"id": "test_synergy", "name": "Test Synergy"}
	full.merge(data, true)
	var errors: Array[String] = []
	var def: SynergyDef = SynergyDef.read(DataReader.new(full, "synergy", errors))
	return [def, errors]


func _assert_error(errors: Array[String], expected: String) -> void:
	var found: bool = false
	for message: String in errors:
		found = found or message.contains(expected)
	assert_true(found, "expected an error containing '%s', got: %s" % [expected, errors])


func _named(item_id: String, overrides: Dictionary = {}) -> ItemDef:
	var data: Dictionary = {"name": item_id.capitalize()}
	data.merge(overrides, true)
	return K.item(item_id, data)


func _crit_on_matched() -> Array:
	return [{"target": "matched_items", "stat": "crit_chance_bp", "value": 1000}]


func _row_crits(sim: CombatSim, unit_id: String) -> Array[int]:
	var crits: Array[int] = []
	for item: ItemState in sim.unit_by_id(unit_id).row_items():
		crits.append(item.crit_chance_bp)
	return crits


func _step_to(sim: CombatSim, tick: int) -> void:
	while sim.tick < tick and not sim.finished:
		sim.step()


func _fire_ticks(sim: CombatSim, item_id: String, unit_id: String = "a") -> Array[int]:
	var ticks: Array[int] = []
	for entry: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.FIRE):
		if entry.source_item == item_id and entry.source_unit == unit_id:
			ticks.append(entry.tick)
	return ticks


func _synergy_lines(sim: CombatSim) -> Array[String]:
	var lines: Array[String] = []
	for entry: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.SYNERGY):
		lines.append(entry.to_text())
	return lines


func _ember_resonance(counts: Array[int]) -> SynergyDef:
	var tiers: Array = []
	for count: int in counts:
		tiers.append({"count": count, "auras": [{"target": "all_items", "filter": {"essence": "ember"}, "stat": "over_time_bp", "value": 10000 + count * 1000}]})
	return K.synergy("test_res", {"name": "Test Res", "layer": "resonance", "essence": "ember", "tiers": tiers})


# --- data ---------------------------------------------------------------------

func test_reads_each_layer() -> void:
	var pair: Array = _read({"layer": "pair", "items": ["a", "b"], "auras": _crit_on_matched()})
	assert_eq(pair[1], [] as Array[String])
	assert_eq((pair[0] as SynergyDef).layer, SynergyDef.Layer.PAIR)
	var transform: Array = _read({"layer": "transformation", "item": "a", "essence": "ember", "item_effects": K.damage(4, "all_enemies")})
	assert_eq(transform[1], [] as Array[String])
	assert_eq((transform[0] as SynergyDef).item_effects.size(), 1)
	var signature: Array = _read({"layer": "signature", "hero": "vell", "item": "a", "auras": [{"target": "holder", "stat": "def_bp", "value": 11000}]})
	assert_eq(signature[1], [] as Array[String])
	var resonance: Array = _read({"layer": "resonance", "essence": "ember", "tiers": [
		{"count": 3, "auras": [{"target": "all_items", "stat": "damage_bp", "value": 11000}]},
		{"count": 5, "auras": [{"target": "all_items", "stat": "damage_bp", "value": 12000}]}]})
	assert_eq(resonance[1], [] as Array[String])
	var def: SynergyDef = resonance[0]
	assert_null(def.tier_for(2))
	assert_eq(def.tier_for(4).count, 3)
	assert_eq(def.tier_for(9).count, 5)
	assert_eq(def.tier_for(5).bonus.name, "Test Synergy (5)")
	var class_trait: Array = _read({"layer": "class_trait", "class": "warden", "tiers": [{"count": 2, "auras": [{"target": "all_allies", "stat": "def_bp", "value": 11000}]}]})
	assert_eq(class_trait[1], [] as Array[String])


func test_rejects_bad_synergies() -> void:
	_assert_error(_read({"layer": "pair", "items": ["a", "a"], "auras": _crit_on_matched()})[1], "a pair needs two different items")
	_assert_error(_read({"layer": "transformation", "item": "a", "essence": "ember"})[1], "a transformation needs item_effects")
	_assert_error(_read({"layer": "signature", "hero": "vell", "item": "a"})[1], "a synergy needs auras, grants, or effects")
	_assert_error(_read({"layer": "resonance", "essence": "ember"})[1], "a resonance needs tiers")
	_assert_error(_read({"layer": "class_trait", "class": "warden", "tiers": [
		{"count": 3, "auras": [{"target": "all_items", "stat": "damage_bp", "value": 11000}]},
		{"count": 2, "auras": [{"target": "all_items", "stat": "damage_bp", "value": 12000}]}]})[1], "tier counts must go up (2 after 3)")
	_assert_error(_read({"layer": "resonance", "essence": "ember", "tiers": [{"count": 3, "auras": [{"target": "holder", "stat": "def_bp", "value": 11000}]}]})[1],
		"a synergy tier aura can only target all_items or all_allies")
	_assert_error(_read({"layer": "pair", "items": ["a", "b"], "essence": "ember", "auras": _crit_on_matched()})[1], "unknown key \"essence\"")
	_assert_error(_read({"layer": "combo"})[1], "layer: unknown value \"combo\"")


func test_content_checks_synergy_references() -> void:
	var texts: Dictionary[String, String] = {}
	for file_name: String in ContentDb.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	texts[ContentDb.SYNERGIES_FILE] = JSON.stringify([
		{"id": "odd_pair", "name": "Odd", "layer": "pair", "items": ["hearth_knife", "moon_blade"], "auras": _crit_on_matched()},
		{"id": "odd_sig", "name": "Odd", "layer": "signature", "hero": "nobody", "item": "hearth_knife", "auras": _crit_on_matched()},
		{"id": "odd_res", "name": "Odd", "layer": "resonance", "essence": "glitter", "tiers": [{"count": 3,
			"grants": [{"effect": {"trigger": "on_fire", "type": "charge", "amount_ms": 100, "target": "partner_items"}}]}]},
	])
	var items: Array = JSON.parse_string(texts[ContentDb.ITEMS_FILE])
	items[0]["auras"] = [{"target": "matched_items", "stat": "damage_bp", "value": 12000}]
	texts[ContentDb.ITEMS_FILE] = JSON.stringify(items)
	var errors: Array[String] = ContentDb.load_texts(texts).errors
	_assert_error(errors, "unknown item \"moon_blade\"")
	_assert_error(errors, "unknown hero \"nobody\"")
	_assert_error(errors, "unknown essence \"glitter\"")
	_assert_error(errors, "partner_items only works in a pair synergy's grants")
	_assert_error(errors, "matched_items only works in a synergy")


func test_real_synergies_load() -> void:
	var content: ContentDb = K.content()
	assert_gte(content.synergy_ids.size(), 20)
	var layers: Array[int] = []
	for synergy_id: String in content.synergy_ids:
		if not layers.has(content.synergies[synergy_id].layer):
			layers.append(content.synergies[synergy_id].layer)
	assert_eq(layers.size(), 5, "every layer has at least one synergy")


# --- charge -------------------------------------------------------------------

func test_charge_reads_and_rejects() -> void:
	var errors: Array[String] = []
	var effect: EffectDef = EffectDef.read(DataReader.new({"trigger": "on_fire", "type": "charge", "amount_ms": 250, "target": "adjacent_items"}, "effect", errors))
	assert_eq(errors, [] as Array[String])
	assert_eq(effect.amount, 5)
	assert_eq(effect.item_target, EffectDef.ItemTarget.ADJACENT_ITEMS)
	errors.clear()
	EffectDef.read(DataReader.new({"trigger": "on_fire", "type": "charge", "amount_ms": 250, "target": "enemy_front"}, "effect", errors))
	_assert_error(errors, "target: unknown value \"enemy_front\"")
	errors.clear()
	EffectDef.read(DataReader.new({"trigger": "on_fight_start", "type": "charge", "amount_ms": 250, "target": "self_item"}, "effect", errors), true)
	_assert_error(errors, "a relic holds no item, so its effects can't charge")


func test_charge_advances_a_neighbor() -> void:
	var blade: ItemDef = _named("blade")
	var stone: ItemDef = _named("stone", {"cooldown_ms": 3000, "effects": [{"trigger": "on_fire", "type": "charge", "amount_ms": 250, "target": "left_item"}]})
	var sim: CombatSim = K.synergy_sim([K.unit("a", 100, FRONT, [blade, stone])], [K.dummy("b", 100000)])
	_step_to(sim, 100)
	assert_eq(_fire_ticks(sim, "blade"), [20, 40, 60, 75, 95] as Array[int], "charged 5 ticks at 60")
	var charges: Array[LogEntry] = sim.combat_log.of_kind(LogEntry.Kind.CHARGE)
	assert_eq(charges[0].to_text(), "[3.00s] a · Stone charges Blade by 0.25s")


func test_charge_never_banks_a_second_fire() -> void:
	var blade: ItemDef = _named("blade")
	var stone: ItemDef = _named("stone", {"cooldown_ms": 3000, "effects": [{"trigger": "on_fire", "type": "charge", "amount_ms": 2000, "target": "left_item"}]})
	var sim: CombatSim = K.synergy_sim([K.unit("a", 100, FRONT, [blade, stone])], [K.dummy("b", 100000)])
	_step_to(sim, 81)
	assert_eq(_fire_ticks(sim, "blade"), [20, 40, 60, 61, 80] as Array[int])


# --- pairs --------------------------------------------------------------------

func _paper_cuts() -> SynergyDef:
	return K.synergy("test_cuts", {"name": "Test Cuts", "layer": "pair", "items": ["p_whet", "p_dagger"],
		"grants": [{"filter": {"item": "p_dagger"}, "effect": {"trigger": "on_hit", "type": "charge", "amount_ms": 200, "target": "partner_items"}}]})


func test_pair_grant_charges_the_partner() -> void:
	_paper_cuts()
	var whet: ItemDef = _named("p_whet", {"cooldown_ms": 3000, "effects": K.damage(1)})
	var dagger: ItemDef = _named("p_dagger")
	var sim: CombatSim = K.synergy_sim([K.unit("a", 100, FRONT, [whet, dagger]), K.unit("c", 100, BACK, [whet])], [K.dummy("b", 100000)])
	assert_eq(_synergy_lines(sim), ["[0.00s] Test Cuts: a · P Whet + P Dagger"] as Array[String])
	_step_to(sim, 60)
	assert_eq(_fire_ticks(sim, "p_whet")[0], 52, "two dagger hits by 2s: 60 - 8 ticks")
	assert_eq(_fire_ticks(sim, "p_dagger"), [20, 40, 60] as Array[int], "the dagger doesn't charge itself")
	assert_eq(_fire_ticks(sim, "p_whet", "c")[0], 60, "another hero's copy isn't charged")
	assert_eq(sim.combat_log.of_kind(LogEntry.Kind.CHARGE)[0].to_text(), "[1.00s] a · P Dagger (Test Cuts) charges P Whet by 0.20s")


func test_pair_needs_both_items_on_one_fielded_hero() -> void:
	_paper_cuts()
	var whet: ItemDef = _named("p_whet")
	var dagger: ItemDef = _named("p_dagger")
	var split: FightResult = K.synergy_run([K.unit("a", 100, FRONT, [whet]), K.unit("c", 100, FRONT, [dagger])], [K.dummy("b", 100)])
	assert_eq(split.synergies.size(), 0)
	var backup: Dictionary = {"rarity": "uncommon", "backup": {"cooldown_ms": 3000, "effects": K.damage(1, "enemy_random")}}
	var benched: UnitSetup = K.unit("v", 100, BACK, [_named("p_whet", backup), _named("p_dagger", backup)])
	var bench_result: FightResult = K.synergy_run([K.unit("a", 100)], [K.dummy("b", 100)], [benched])
	assert_eq(bench_result.synergies.size(), 0, "pairs need the hero on the field")
	var paired: FightResult = K.synergy_run([K.unit("a", 100, FRONT, [dagger, whet])], [K.dummy("b", 100)])
	assert_eq(paired.synergies.size(), 1)
	assert_eq([paired.synergies[0].synergy_id, paired.synergies[0].unit_id], ["test_cuts", "a"])


func test_matched_items_aura_reaches_only_the_pair() -> void:
	K.synergy("crit_pair", {"layer": "pair", "items": ["m_one", "m_two"], "auras": _crit_on_matched()})
	var sim: CombatSim = K.synergy_sim([K.unit("a", 100, FRONT, [_named("m_one"), _named("m_other"), _named("m_two")])], [K.dummy("b", 100)])
	assert_eq(_row_crits(sim, "a"), [1000, 0, 1000] as Array[int])
	var aura: LogEntry = sim.combat_log.of_kind(LogEntry.Kind.AURA)[0]
	assert_eq(aura.to_text(), "[0.00s] synergy · Crit Pair aura starts: +10% crit chance for matched items")


# --- signatures ---------------------------------------------------------------

func test_item_layer_grants_reach_only_matched_items() -> void:
	K.synergy("lamp_grant", {"layer": "signature", "hero": "vell", "item": "s_lamp",
		"grants": [{"effect": {"trigger": "on_fire", "type": "shield", "amount": 8, "target": "self"}}]})
	var sim: CombatSim = K.synergy_sim([K.unit("vell", 100, FRONT, [_named("s_lamp"), _named("s_other")])], [K.dummy("b", 100)])
	var row: Array[ItemState] = sim.unit_by_id("vell").row_items()
	assert_eq(row[0].effects.size(), 2, "the lamp gains the grant")
	assert_eq(row[1].effects.size(), 1, "the other item doesn't")
	assert_eq(sim.unit_by_id("vell").items[0].effects.size(), 1, "nor does the basic attack")


func test_signature_needs_its_hero() -> void:
	K.synergy("vells_own", {"layer": "signature", "hero": "vell", "item": "s_lamp", "auras": [{"target": "holder", "stat": "def_bp", "value": 15000}]})
	var vell: UnitSetup = K.unit_with("vell", UnitStats.make(100, 0, 0, 100), FRONT, [_named("s_lamp")])
	var other: UnitSetup = K.unit_with("other", UnitStats.make(100, 0, 0, 100), FRONT, [_named("s_lamp")])
	var sim: CombatSim = K.synergy_sim([vell, other], [K.dummy("b", 100)])
	assert_eq(sim.unit_by_id("vell").stats.get_stat(UnitStats.Stat.DEF), 150)
	assert_eq(sim.unit_by_id("other").stats.get_stat(UnitStats.Stat.DEF), 100)
	assert_eq(sim.synergies.size(), 1)


# --- transformations ----------------------------------------------------------

func _transform_torch() -> SynergyDef:
	return K.synergy("test_blaze", {"name": "Test Blaze", "layer": "transformation", "item": "t_torch", "essence": "ember",
		"item_effects": K.damage(4, "all_enemies")})


func test_transformation_replaces_the_items_effects() -> void:
	_transform_torch()
	var torch: ItemDef = _named("t_torch")
	var sim: CombatSim = K.synergy_sim([K.unit("a", 100, FRONT, [K.equip(torch, ["ember"] as Array[String])])], [K.dummy("b", 100000), K.dummy("c", 100000)])
	var item: ItemState = sim.unit_by_id("a").row_items()[0]
	assert_eq(item.effects.size(), 1)
	assert_eq(item.effects[0].effect.target, EffectDef.Target.ALL_ENEMIES)
	assert_eq(item.conversions.size(), 0, "Ember's own conversion (damage -> Burn) doesn't apply")
	_step_to(sim, 20)
	var hits: Array[LogEntry] = []
	for entry: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.DAMAGE):
		if entry.source_item == "t_torch":
			hits.append(entry)
	assert_eq(K.targets_of(hits), ["b", "c"] as Array[String])
	assert_eq(hits[0].to_text(), "[1.00s] a · T Torch (Test Blaze) hits b for 4")
	assert_eq(item.describe_values()[0].begins_with("damage (Test Blaze):"), true)


func test_untransformed_items_keep_their_effects() -> void:
	_transform_torch()
	var torch: ItemDef = _named("t_torch")
	var sim: CombatSim = K.synergy_sim([K.unit("a", 100, FRONT, [K.equip(torch, ["frost"] as Array[String])])], [K.dummy("b", 100)])
	assert_eq(sim.synergies.size(), 0)
	assert_eq(sim.unit_by_id("a").row_items()[0].effects[0].effect.target, EffectDef.Target.ENEMY_FRONT)


func test_transformation_levels_up_and_never_spills() -> void:
	_transform_torch()
	var torch: ItemDef = _named("t_torch")
	var sim: CombatSim = K.synergy_sim([K.unit("a", 100, FRONT, [K.equip(torch, ["ember"] as Array[String], 0, 300), _named("t_next")])], [K.dummy("b", 100)])
	var row: Array[ItemState] = sim.unit_by_id("a").row_items()
	assert_eq(row[0].infusion_level, Infusions.Level.RESONANT)
	assert_eq(row[0].effects[0].final_amount(), 8, "Resonant: x2")
	assert_eq(row[1].spills_received.size(), 0, "a transformed item never spills")


func test_other_essence_works_as_a_plain_single() -> void:
	_transform_torch()
	var torch: ItemDef = _named("t_torch", {"rarity": "epic"})
	var sim: CombatSim = K.synergy_sim([K.unit("a", 100, FRONT, [K.equip(torch, ["ember", "ember"] as Array[String])])], [K.dummy("b", 100)])
	var item: ItemState = sim.unit_by_id("a").row_items()[0]
	assert_null(item.alloy, "no pure-double special")
	assert_eq(item.conversions.size(), 1, "the second Ember converts as a plain single")
	var mixed: CombatSim = K.synergy_sim([K.unit("a", 100, FRONT, [K.equip(torch, ["frost", "ember"] as Array[String])])], [K.dummy("b", 100)])
	var mixed_item: ItemState = mixed.unit_by_id("a").row_items()[0]
	var sources: Array[String] = []
	for sourced: SourcedEffect in mixed_item.effects:
		sources.append(sourced.infusion_id)
	assert_eq(sources, ["", "frost"] as Array[String], "the transformed effect, then Frost's Slow")


# --- resonance and class traits -------------------------------------------------

func test_resonance_counts_essences_across_the_guild() -> void:
	_ember_resonance([3, 5] as Array[int])
	var epic: ItemDef = _named("r_epic", {"rarity": "epic"})
	var single: ItemSetup = K.equip(_named("r_one"), ["ember"] as Array[String])
	var double: ItemSetup = K.equip(epic, ["ember", "ember"] as Array[String])
	var two: FightResult = K.synergy_run([K.unit("a", 100, FRONT, [double])], [K.dummy("b", 100)])
	assert_eq(two.synergies.size(), 0, "2 Ember: no tier yet")
	var three: FightResult = K.synergy_run([K.unit("a", 100, FRONT, [single, double])], [K.dummy("b", 100)])
	assert_eq([three.synergies[0].synergy_id, three.synergies[0].count], ["test_res", 3])
	var bench: UnitSetup = K.unit("v", 100, BACK, [K.equip(_named("r_alloy", {"rarity": "epic"}), ["frost", "ember"] as Array[String]), K.equip(_named("r_two"), ["ember"] as Array[String])])
	var sim: CombatSim = K.synergy_sim([K.unit("a", 100, FRONT, [single, double])], [K.dummy("b", 100)], [bench])
	assert_eq(sim.synergies[0].count, 5, "backup heroes count; an alloy counts its half")
	assert_eq(_synergy_lines(sim), ["[0.00s] Test Res (5): 5 Ember"] as Array[String])
	assert_eq(sim.synergies[0].def.name, "Test Res (5)", "only the highest tier applies")
	var aura: LogEntry = sim.combat_log.of_kind(LogEntry.Kind.AURA)[0]
	assert_string_contains(aura.to_text(), "synergy · Test Res (5) aura starts: x1.5 damage over time for all items (ember)")


func test_transformations_count_for_resonance() -> void:
	_transform_torch()
	_ember_resonance([1] as Array[int])
	var result: FightResult = K.synergy_run([K.unit("a", 100, FRONT, [K.equip(_named("t_torch"), ["ember"] as Array[String])])], [K.dummy("b", 100)])
	var ids: Array[String] = []
	for found: FightResult.SynergyResult in result.synergies:
		ids.append(found.synergy_id)
	assert_eq(ids, ["test_blaze", "test_res"] as Array[String])


func test_class_trait_counts_fielded_heroes() -> void:
	K.synergy("test_wardens", {"name": "Test Wardens", "layer": "class_trait", "class": "warden", "tiers": [
		{"count": 2, "auras": [{"target": "all_allies", "stat": "def_bp", "value": 11000}]},
		{"count": 3, "auras": [{"target": "all_allies", "stat": "def_bp", "value": 12000}]}]})
	var heroes: Array[UnitSetup] = []
	for unit_id: String in ["w1", "w2", "x"]:
		var unit: UnitSetup = K.unit_with(unit_id, UnitStats.make(100, 0, 0, 100))
		unit.unit_class = "warden" if unit_id != "x" else "striker"
		heroes.append(unit)
	var benched: UnitSetup = K.unit("w3", 100, BACK)
	benched.unit_class = "warden"
	var sim: CombatSim = K.synergy_sim(heroes, [K.dummy("b", 100)], [benched])
	assert_eq(sim.synergies.size(), 1)
	assert_eq(sim.synergies[0].count, 2, "the benched Warden doesn't count")
	assert_eq(sim.unit_by_id("x").stats.get_stat(UnitStats.Stat.DEF), 110, "the tier's aura reaches all allies")
	assert_eq(_synergy_lines(sim), ["[0.00s] Test Wardens (2): 2 heroes"] as Array[String])


func test_enemies_get_no_synergies() -> void:
	_ember_resonance([1] as Array[int])
	var result: FightResult = K.synergy_run([K.unit("a", 100)], [K.unit("b", 100, FRONT, [K.equip(_named("e_one"), ["ember"] as Array[String])])])
	assert_eq(result.synergies.size(), 0)


# --- real content -------------------------------------------------------------

func test_real_synergies_show_up_in_a_real_fight() -> void:
	var content: ContentDb = K.content()
	var entries: Array[LoadoutEntry] = []
	for item_id: String in ["whetstone", "twin_daggers", "tallow_torch"]:
		var entry := LoadoutEntry.new()
		entry.item_id = item_id
		if item_id == "tallow_torch":
			entry.essence_ids = ["ember"] as Array[String]
		entries.append(entry)
	var wren: UnitSetup = SetupBuilder.hero(content, "wren", 1, FRONT, entries)
	var result: FightResult = CombatSim.run(FightSetup.make([wren] as Array[UnitSetup], SetupBuilder.encounter_units(content, "hound_pack"), 4), content)
	assert_eq(result.errors, [] as Array[String])
	var text: String = result.combat_log.to_text()
	assert_string_contains(text, "Paper Cuts: wren · Whetstone + Twin Daggers")
	assert_string_contains(text, "Wildfire Torch: wren · Tallow Torch + Ember")
	assert_string_contains(text, "wren · Twin Daggers (Paper Cuts) charges Whetstone")
