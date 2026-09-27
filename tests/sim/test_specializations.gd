extends GutTest
## Rank-B specializations (docs/plans/specializations-in-sim.md): parts by
## deed level (docs/plans/deeds.md), abilities, basic attacks, and the cleanse
## effect. The tests write a track in rank shorthand (K.track_data): "b", "a",
## and "s" parts become levels 1, 2 (its first option), and 3.

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT := UnitSetup.Row.FRONT
const BACK := UnitSetup.Row.BACK


func _read(data: Dictionary) -> Array:
	var full: Dictionary = {"id": "test_spec", "hero": "a", "name": "Test Spec"}
	if data.has("ranks"):
		full.merge(K.track_data(data["ranks"]), true)
		data = data.duplicate()
		data.erase("ranks")
	full.merge(data, true)
	var errors: Array[String] = []
	var def: SpecializationDef = SpecializationDef.read(DataReader.new(full, "spec", errors))
	return [def, errors]


func _spec(ranks: Dictionary, hero: String = "a") -> SpecializationDef:
	var result: Array = _read({"hero": hero, "ranks": ranks})
	assert_eq(result[1], [] as Array[String])
	return result[0]


func _assert_error(errors: Array[String], expected: String) -> void:
	var found: bool = false
	for message: String in errors:
		found = found or message.contains(expected)
	assert_true(found, "expected an error containing '%s', got: %s" % [expected, errors])


## A hero `unit_id` at `rank` with `spec` at deed level `rank` (level 2's
## first option) and `items`.
func _hero(unit_id: String, spec: SpecializationDef, rank: int = 1, items: Array = [], stats: UnitStats = null, row: UnitSetup.Row = FRONT) -> UnitSetup:
	var setup: UnitSetup = K.unit_with(unit_id, stats if stats != null else UnitStats.make(1000, 20, 20, 0), row, items, null, rank)
	return K.with_spec(setup, spec, rank)


func _sim(heroes: Array[UnitSetup], enemies: Array[UnitSetup]) -> CombatSim:
	return CombatSim.new(FightSetup.make(heroes, enemies), K.content())


func _step_to(sim: CombatSim, tick: int) -> void:
	while sim.tick < tick and not sim.finished:
		sim.step()


func _crit_aura(value: int, filter: Dictionary = {}, key: String = "edge") -> Dictionary:
	var part: Dictionary = {"key": key, "kind": "aura", "target": "holder_items", "stat": "crit_chance_bp", "value": value}
	if not filter.is_empty():
		part["filter"] = filter
	return part


# --- data ---------------------------------------------------------------------

func test_parts_unlock_by_level() -> void:
	var spec: SpecializationDef = _spec({
		"b": [_crit_aura(1000), {"key": "tough", "kind": "aura", "target": "holder", "stat": "def_bp", "value": 12000}],
		"a": [_crit_aura(2000)],
		"s": [{"key": "burst", "kind": "ability", "cooldown_ms": 1000, "effects": K.damage(3)}],
	})
	var track: DeedTrackDef = spec.track
	assert_eq(track.parts_at(0, 0).size(), 0, "level 0: nothing")
	var at_1: Array[SpecializationDef.Part] = track.parts_at(1, 0)
	assert_eq([at_1.size(), at_1[0].aura.value], [2, 1000])
	var at_2: Array[SpecializationDef.Part] = track.parts_at(2, 0)
	assert_eq([at_2.size(), at_2[0].aura.value, at_2[0].label], [2, 2000, "Test Spec 2"], "same key: the level-2 part replaces the level-1 part, in its place")
	assert_eq(track.parts_at(2, -1).size(), 2, "level 2 unchosen: it waits, so only level 1's parts")
	assert_eq(track.parts_at(2, 1)[2].key, "pad_second", "the other option")
	var at_3: Array[SpecializationDef.Part] = track.parts_at(3, 0)
	assert_eq(at_3.size(), 3)
	assert_eq(at_3[2].kind, SpecializationDef.Kind.ABILITY)
	assert_eq(at_3[2].item.name, "Test Spec 3", "an ability without a name is named after the specialization")


func test_rejects_bad_specializations() -> void:
	_assert_error(_read({"ranks": {"b": []}})[1], "a level needs parts")
	_assert_error(_read({"ranks": {"b": [_crit_aura(1000), _crit_aura(2000)]}})[1], "key \"edge\" is used twice in one level")
	_assert_error(_read({"ranks": {"b": [{"key": "k", "kind": "lore"}]}})[1], "kind: unknown value \"lore\"")
	_assert_error(_read({"ranks": {"b": [{"key": "k", "kind": "aura", "target": "self_item", "stat": "damage_bp", "value": 12000}]}})[1],
		"a specialization aura can't target self_item")
	_assert_error(_read({"ranks": {"b": [{"key": "k", "kind": "aura", "when": "benched", "target": "row_allies", "stat": "def_bp", "value": 12000}]}})[1],
		"unknown key \"when\"")
	_assert_error(_read({"ranks": {"b": [{"key": "k", "kind": "ability", "cooldown_ms": 1000, "effects": [
		{"trigger": "on_fire", "type": "damage", "amount": 3, "target": "hit_target"}]}]}})[1], "an ability has no hit, so it can't use hit_target")
	_assert_error(_read({"ranks": {"b": [{"key": "k", "kind": "ability", "effects": K.damage(3)}]}})[1], "missing required key \"cooldown_ms\"")


func test_basic_attack_needs_an_auto_attack_part() -> void:
	var attack: Dictionary = {"key": "blow", "kind": "basic_attack", "basic_attack": {"id": "blow", "name": "Blow", "cooldown_ms": 1000, "effects": K.damage(5)}}
	_assert_error(_read({"ranks": {"b": [attack]}})[1], "level 1 replaces the basic attack, so it needs a part for basic-attack items too")
	var covered: Dictionary = _crit_aura(500, {"auto_attack": true}, "keen")
	assert_eq(_read({"ranks": {"b": [attack, covered]}})[1], [] as Array[String])


func test_real_specializations_load() -> void:
	var content: ContentDb = K.content()
	assert_eq(content.specialization_ids.size(), 24)
	for hero_id: String in content.hero_ids:
		var count: int = 0
		for spec_id: String in content.specialization_ids:
			if content.specializations[spec_id].hero == hero_id:
				count += 1
		assert_eq(count, 3, "%s has three specializations" % hero_id)


func test_content_checks_specializations() -> void:
	var texts: Dictionary[String, String] = {}
	for file_name: String in ContentDb.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	var specs: Array = JSON.parse_string(texts[ContentDb.SPECIALIZATIONS_FILE])
	var ghost: Dictionary = {"id": "ghost_spec", "hero": "nobody", "name": "Ghost"}
	ghost.merge(K.track_data({"b": [{"key": "odd", "kind": "replace_status", "from": "burn", "to": "moonfire"}]}))
	var fourth: Dictionary = {"id": "brannoc_fourth", "hero": "brannoc", "name": "Fourth"}
	fourth.merge(K.track_data({"b": [_crit_aura(100)]}, {"text": "Deal damage", "counts": "stacks", "filter": {"statuses": ["glitter"]}, "goals": [1, 2, 3]}))
	var clash: Dictionary = {"id": "wren_clash", "hero": "wren", "name": "Clash"}
	clash.merge(K.track_data({"b": [_crit_aura(100, {}, "flurry")]}))
	specs.append_array([ghost, fourth, clash])
	texts[ContentDb.SPECIALIZATIONS_FILE] = JSON.stringify(specs)
	var errors: Array[String] = ContentDb.load_texts(texts).errors
	_assert_error(errors, "unknown hero \"nobody\"")
	_assert_error(errors, "unknown status \"moonfire\"")
	_assert_error(errors, "brannoc has 4 specializations; the limit is 3")
	_assert_error(errors, "(brannoc_fourth).deed: unknown status \"glitter\"")
	_assert_error(errors, "key \"flurry\" is also used by wren's innate or calling")


func test_setup_checks_rank_and_hero() -> void:
	var spec: SpecializationDef = _spec({"b": [_crit_aura(1000)]})
	var errors: Array[String] = FightSetup.make([_hero("a", spec, 0), _hero("c", spec, 1)] as Array[UnitSetup], [K.dummy("b", 100)] as Array[UnitSetup]).validate(K.content())
	_assert_error(errors, "a: a rank-C hero has no specialization")
	_assert_error(errors, "c: specialization \"test_spec\" belongs to a")


func test_setup_builder_takes_a_specialization() -> void:
	var content: ContentDb = K.content()
	var brannoc: UnitSetup = SetupBuilder.hero(content, "brannoc", 1, FRONT, [], "brannoc_hearthwall")
	assert_eq(brannoc.specialization.name, "Hearthwall")


# --- auras, grants, status replacement ----------------------------------------

func test_holder_items_aura_by_level() -> void:
	var spec: SpecializationDef = _spec({
		"b": [_crit_aura(1000, {"tag": "weapon"})],
		"a": [_crit_aura(2000, {"tag": "weapon"})],
		"s": [{"key": "tough", "kind": "aura", "target": "holder", "stat": "def_bp", "value": 15000}],
	})
	var sword: ItemDef = K.item("sp_sword", {"tags": ["weapon"]})
	var charm: ItemDef = K.item("sp_charm", {"tags": ["charm"]})
	# DEF 100 grows 25% per rank (B 125, A 156, S 195), and the S part adds x1.5.
	var expected: Array = [[1, 1000, 125], [2, 2000, 156], [3, 2000, 293]]
	for case: Array in expected:
		var sim: CombatSim = _sim([_hero("a", spec, case[0], [sword, charm], UnitStats.make(1000, 0, 0, 100))], [K.dummy("b", 100)])
		var hero: UnitState = sim.unit_by_id("a")
		assert_eq([hero.loadout_items()[0].crit_chance_bp, hero.loadout_items()[1].crit_chance_bp, hero.items[0].crit_chance_bp], [case[1], 0, 0], "rank %d" % case[0])
		assert_eq(hero.stats.get_stat(UnitStats.Stat.DEF), case[2], "rank %d" % case[0])


func test_spec_auras_are_logged_with_the_level() -> void:
	var spec: SpecializationDef = _spec({"b": [_crit_aura(1000, {"tag": "weapon"})]})
	var sim: CombatSim = _sim([_hero("a", spec)], [K.dummy("b", 100)])
	assert_eq(sim.combat_log.of_kind(LogEntry.Kind.AURA)[0].to_text(), "[0.00s] a · Test Spec 1 aura starts: +10% crit chance for the holder's items (weapon)")


func test_grants_scale_from_the_hero_not_the_tier() -> void:
	var spec: SpecializationDef = _spec({"b": [{"key": "zap", "kind": "grant", "filter": {"tag": "weapon"},
		"effect": {"trigger": "on_fire", "type": "damage", "amount": 2, "scaling": {"atk": 5000}, "target": "enemy_front"}}]})
	var sword: ItemDef = K.item("sp_sword", {"tags": ["weapon"]})
	var sim: CombatSim = _sim([_hero("a", spec, 1, [K.equip(sword, [], 3)], UnitStats.make(1000, 20))], [K.dummy("b", 100)])
	var item: ItemState = sim.unit_by_id("a").loadout_items()[0]
	assert_eq(item.effects[1].granted_by, "Test Spec 1")
	assert_eq(item.effects[1].final_amount(), 15, "2 + 50% of 25 ATK (20 at rank B); no S-tier x3")
	assert_eq(item.effects[0].final_amount(), 30, "the item's own damage still gets its tier")


func test_replace_status_turns_burn_into_golden_flame() -> void:
	var spec: SpecializationDef = _spec({"b": [{"key": "gild", "kind": "replace_status", "from": "burn", "to": "golden_flame"}]})
	var torch: ItemDef = K.item("sp_torch", {"effects": [{"trigger": "on_fire", "type": "apply_status", "status": "burn", "stacks": 2, "target": "enemy_front"}]})
	var sim: CombatSim = _sim([_hero("a", spec, 1, [torch]), K.unit("c", 1000, BACK, [torch])], [K.dummy("b", 100000)])
	_step_to(sim, 20)
	var applied: Array[String] = []
	for entry: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED):
		applied.append("%s %s" % [entry.source_unit, entry.status])
	assert_eq(applied, ["a golden_flame", "c burn"] as Array[String], "only the specialized hero's items change")


# --- abilities ----------------------------------------------------------------

func test_ability_fires_on_its_cooldown_from_the_heros_stats() -> void:
	var spec: SpecializationDef = _spec({"b": [{"key": "jab", "kind": "ability", "cooldown_ms": 1000, "effects": [
		{"trigger": "on_fire", "type": "damage", "amount": 3, "scaling": {"atk": 5000}, "target": "enemy_front"}]}]})
	var sim: CombatSim = _sim([_hero("a", spec, 1, [], UnitStats.make(1000, 20))], [K.dummy("b", 100000)])
	var hero: UnitState = sim.unit_by_id("a")
	assert_eq(hero.loadout_items().size(), 0, "abilities take no slot")
	_step_to(sim, 20)
	var hits: Array[String] = []
	for entry: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.DAMAGE):
		if entry.source_item == "test_spec_1_jab":
			hits.append(entry.to_text())
	assert_eq(hits, ["[1.00s] a · Test Spec 1 hits b for 16"] as Array[String], "3 + 50% of 25 ATK (20 at rank B)")


func test_triggered_abilities() -> void:
	var spec: SpecializationDef = _spec({"b": [{"key": "rally", "kind": "ability", "name": "Rally", "effects": [
		{"trigger": "on_fight_start", "type": "shield", "amount": 5, "scaling": {"def": 10000}, "target": "self"},
		{"trigger": "on_ally_below_hp", "threshold_bp": 3000, "type": "heal", "amount": 7, "target": "trigger_ally"}]}]})
	var slam: ItemDef = K.item("sp_slam", {"cooldown_ms": 1000, "effects": K.damage(80, "all_enemies")})
	var sim: CombatSim = _sim([_hero("a", spec, 1, [], UnitStats.make(1000, 0, 0, 10)), K.dummy("c", 100, BACK)],
		[K.unit("b", 1000, FRONT, [slam], K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)}))])
	var shields: Array[LogEntry] = sim.combat_log.of_kind(LogEntry.Kind.SHIELD)
	assert_eq([shields[0].tick, shields[0].amount, shields[0].source_text()], [0, 18, "a · Rally (Test Spec 1)"], "5 + 100% of 13 DEF (10 at rank B)")
	_step_to(sim, 45)
	var heals: Array[String] = []
	for entry: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.HEAL):
		heals.append("%d %s %d" % [entry.tick, entry.target, entry.amount])
	assert_eq(heals, ["20 c 7"] as Array[String], "c dropped to 20% at 1s; a (hit for 80 of 1000) never did")
	assert_eq(sim.combat_log.of_kind(LogEntry.Kind.FIRE).filter(func(e: LogEntry) -> bool: return e.source_item == "test_spec_1_rally").size(), 0,
		"a trigger-only ability never fires on a cooldown")


# --- basic attacks --------------------------------------------------------------

func _brand_spec() -> SpecializationDef:
	return _spec({"b": [
		{"key": "blow", "kind": "basic_attack", "basic_attack": {"id": "sp_blow", "name": "Blow", "cooldown_ms": 1000, "effects": K.damage(9)}},
		{"key": "keen", "kind": "grant", "filter": {"auto_attack": true}, "effect": {"trigger": "on_hit", "type": "apply_status", "status": "bleed", "stacks": 1, "target": "hit_target"}},
	]})


func test_new_basic_attack_and_its_auto_attack_item_fallback() -> void:
	var spec: SpecializationDef = _brand_spec()
	var plain: CombatSim = _sim([_hero("a", spec)], [K.dummy("b", 100)])
	var basic: ItemState = plain.unit_by_id("a").items[0]
	assert_eq([basic.def.id, basic.effects.size()], ["sp_blow", 2], "the new basic attack, plus the auto-attack grant")
	var claw: ItemDef = K.item("sp_claw", {"slot": "basic_attack"})
	var with_item: CombatSim = _sim([_hero("a", spec, 1, [claw, K.item("sp_plain")])], [K.dummy("b", 100)])
	var items: Array[ItemState] = with_item.unit_by_id("a").items
	assert_eq(items.size(), 2, "the auto-attack item replaces the basic attack")
	assert_eq(items[1].effects.size(), 1, "a plain item doesn't get the auto-attack part")
	assert_eq([items[0].def.id, items[0].effects.size(), items[0].effects[1].granted_by], ["sp_claw", 2, "Test Spec 1"], "and gets the auto-attack part")


# --- cleanse ------------------------------------------------------------------

func test_cleanse_strips_damage_over_time() -> void:
	var errors: Array[String] = []
	var effect: EffectDef = EffectDef.read(DataReader.new({"trigger": "on_fire", "type": "cleanse", "amount_bp": 5000, "target": "ally_lowest_hp"}, "effect", errors))
	assert_eq([errors, effect.amount], [[] as Array[String], 5000])
	var wash: ItemDef = K.item("sp_wash", {"name": "Wash", "cooldown_ms": 1000, "effects": [{"trigger": "on_fire", "type": "cleanse", "amount_bp": 5000, "target": "self"}]})
	var sim: CombatSim = _sim([K.unit("a", 1000, FRONT, [wash])], [K.dummy("b", 1000)])
	Statuses.apply(sim, sim.unit_by_id("a"), "poison", 10, EffectSource.make("b", "x", "X"))
	Statuses.apply(sim, sim.unit_by_id("a"), "golden_flame", 10, EffectSource.make("b", "y", "Y"))
	_step_to(sim, 20)
	var reduced: Array[String] = []
	for entry: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.STATUS_REDUCED):
		reduced.append(entry.to_text())
	assert_eq(reduced.size(), 2)
	assert_string_contains(reduced[0], "Poison on a loses 5 stacks (cleansed by a · Wash)")
	assert_true(reduced[1].contains("Golden Flame on a loses 4 stacks (cleansed by a · Wash)"), "Golden Flame resists cleansing (75%%): %s" % reduced[1])


# --- the slice's heroes (docs/plans/slice-content.md) ---------------------------

func test_every_hero_is_complete() -> void:
	var content: ContentDb = K.content()
	assert_eq(content.hero_ids.size(), 8)
	var classes: Array[String] = []
	for hero_id: String in content.hero_ids:
		var hero: HeroDef = content.heroes[hero_id]
		assert_false(hero.innate.is_empty(), "%s has an innate" % hero_id)
		assert_false(hero.basic_attack.effects.is_empty(), "%s has a basic attack" % hero_id)
		var signatures: Array[String] = []
		for synergy_id: String in content.synergy_ids:
			var synergy: SynergyDef = content.synergies[synergy_id]
			if synergy.layer == SynergyDef.Layer.SIGNATURE and synergy.hero == hero_id:
				signatures.append(synergy_id)
		assert_eq(signatures.size(), 1, "%s has a signature item" % hero_id)
		if not classes.has(hero.hero_class):
			classes.append(hero.hero_class)
	for keyword_id: String in content.keyword_ids:
		var affinities: int = 0
		for synergy_id: String in content.synergy_ids:
			if content.synergies[synergy_id].layer == SynergyDef.Layer.AFFINITY and content.synergies[synergy_id].keyword == keyword_id:
				affinities += 1
		assert_eq(affinities, 1, "the %s keyword has an affinity synergy" % keyword_id)
	assert_eq(classes.size(), 6, "all six classes are in the slice")


func test_two_heroes_sharing_an_affinity_reach_its_synergy() -> void:
	var content: ContentDb = K.content()
	assert_true(content.heroes["brannoc"].affinities.has("ward") and content.heroes["hesk"].affinities.has("ward"))
	var heroes: Array[UnitSetup] = [
		SetupBuilder.hero(content, "brannoc", 0, FRONT, [] as Array[LoadoutEntry]),
		SetupBuilder.hero(content, "hesk", 0, FRONT, [] as Array[LoadoutEntry]),
	]
	var result: FightResult = CombatSim.run(FightSetup.make(heroes, SetupBuilder.encounter_units(content, "pup_litter")), content)
	assert_string_contains(result.combat_log.to_text(), "Shieldwall (2): 2 heroes")
	assert_string_contains(result.combat_log.to_text(), "Twin Walls: brannoc + hesk", "and their duo bond")


func test_old_hesk_hits_from_his_hp() -> void:
	var content: ContentDb = K.content()
	var hesk: UnitSetup = SetupBuilder.hero(content, "hesk", 0, FRONT, [] as Array[LoadoutEntry])
	var state: ItemState = ItemState.make(hesk.basic_attack, 0, hesk.stats, content)
	assert_eq(state.effects[0].value.final, 3 + 460 * 200 / FixedMath.BP_ONE, "3 + 2% of 460 HP")


func test_each_hero_gets_their_affinity_perks() -> void:
	var content: ContentDb = K.content()
	for hero_id: String in content.hero_ids:
		assert_eq(content.heroes[hero_id].affinities.size(), 2, hero_id)
	var knife: LoadoutEntry = LoadoutEntry.new()
	knife.item_id = "hearth_knife"
	var wren: UnitSetup = SetupBuilder.hero(content, "wren", 0, FRONT, [knife] as Array[LoadoutEntry])
	assert_eq(wren.affinities, ["blade", "bleed"] as Array[String])
	var keys: Array[String] = []
	for part: SpecializationDef.Part in wren.innate:
		keys.append(part.key)
	assert_true(keys.has("affinity_blade_perk") and keys.has("affinity_bleed_perk"), str(keys))
	assert_eq(content.heroes["wren"].innate.size() + 2, wren.innate.size(), "the innate's own parts are untouched")
	var sim := CombatSim.new(FightSetup.make([wren], SetupBuilder.encounter_units(content, "pup_litter")), content)
	var held: ItemState = sim.units[0].loadout_items()[0]
	assert_true(content.items["hearth_knife"].keywords.has("blade"))
	var plain: ItemState = ItemState.make(content.items["hearth_knife"], 0, sim.units[0].stats, content)
	assert_eq(held.crit_chance_bp, plain.crit_chance_bp + 1000, "Blade affinity: +10% crit on Blade items")
	var auras: String = sim.combat_log.to_text()
	assert_string_contains(auras, "wren · Blade affinity aura starts")
