extends GutTest
## The upgrade pools' small knobs (docs/plans/rebuild-phase5c-combos.md, step
## 7b, section 15.7), each on the real card that uses it or in a small
## fight: every_add and "at", times_add, max_standing_add, value_add,
## overheal_shield_add_bp, the Guard knobs, add_to_areas, a line's width,
## plant_add_ms, a signature's prefer, engage's break_free_add_ms, and
## mana's taken_bp.

const K = preload("res://tests/sim/sim_test_kit.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func _kit(path_id: String, card: String, transformed: bool = false) -> UnitDef:
	var path: PathDef = _run.content.paths[path_id]
	var problems: Array[String] = []
	var kit: UnitDef = _run.upgrades[card].mod_for(transformed).apply(path.transformed_kit if transformed else path.vowed_kit, problems)
	assert_eq(problems, [] as Array[String])
	return kit


func _part(kit: UnitDef, part_id: String) -> PartDef:
	for part: PartDef in kit.passives:
		if part.id == part_id:
			return part
	return null


func _mod(data: Dictionary) -> KitMod:
	var errors: Array[String] = []
	var mod: KitMod = KitMod.read(DataReader.new(data, "mod", errors))
	assert_eq(errors, [] as Array[String])
	return mod


func _dummy(dummy_id: String = "dummy", overrides: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 100000, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}
	data.merge(overrides, true)
	return K.kit(dummy_id, data)


func test_every_add_only_where_at_says() -> void:
	var volley: UnitDef = _kit("volley", "quick_split")
	assert_eq([volley.basic_attack.effects[0].every, volley.basic_attack.effects[1].every], [1, 3], "the split every 3rd, not the shot")
	var storm: UnitDef = _kit("volley", "quick_split", true)
	assert_eq([storm.basic_attack.effects[0].power_bp, storm.basic_attack.effects[1].power_bp], [0, 2500], "transformed: only the split arrow")
	var keeper: UnitDef = _kit("vigil_keeper", "swift_judgment")
	assert_eq(keeper.signature.effects[1].every, 1, "every Mend smites")
	var mend: PartDef = _part(_kit("vigil_keeper", "swift_judgment", true), "mend")
	assert_true(mend.ability.effects.all(func(effect: EffectDef) -> bool: return effect.every == 3), "transformed: Mend every 3rd Glow")


func test_times_add_on_an_interval_and_an_ally_below() -> void:
	var twice: KitMod = _mod({"on": [{"slot": "passive:pulse", "times_add": 1}]})
	var pulse: Array = [{"id": "pulse", "name": "Pulse", "kind": "ability", "effects": [
		{"trigger": "on_interval", "interval_ms": 500, "once": true, "type": "shield", "amount": 5, "target": "self"}]}]
	for mod: KitMod in [null, twice]:
		var hero: UnitDef = K.kit("hero", {"stats": {"hp": 1000, "speed": 0, "range": 1}, "passives": pulse})
		if mod != null:
			hero = mod.apply(hero)
		var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_dummy(), 3, 5)] as Array[UnitSetup]))
		K.step(fight, 60)
		assert_eq(K.entries(fight, LogEntry.Kind.SHIELD).size(), 1 if mod == null else 2, "once, or twice with times_add")
	# Twice Guarded: Hearthguard for the first two allies to fall low.
	var brannoc: UnitDef = _kit("hearthwall", "twice_guarded")
	var fight: CombatSim = K.sim(K.fight([UnitSetup.make(brannoc, K.HEROES, 3, 2, "brannoc"), K.at(_dummy("a"), 2, 1, "a"), K.at(_dummy("b"), 4, 1, "b"),
		K.at(_dummy("c"), 3, 0, "c")] as Array[UnitSetup], [K.foe(_dummy("foe"), 3, 5, "foe")] as Array[UnitSetup]))
	fight.step()
	for ally_id: String in ["a", "b", "c"]:
		fight.unit_by_id(ally_id).hp = 1000
		fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.SHIELD).map(func(entry: LogEntry) -> String: return entry.target), ["a", "b"], "the first two, not the third")


func test_the_snares_and_the_aura() -> void:
	assert_eq(Snares.placed_effect(_kit("trapper", "second_snare", true)).max_standing, 4, "Bramble Field: 4 at once")
	assert_eq(_part(_kit("trapper", "second_snare"), "snare").ability.effects[0].times, 2, "the vowed Snare twice")
	assert_eq(_part(_kit("deadeye", "eyes_up"), "steady_aim").aura.value, 1500, "Steady Aim +5 more")
	assert_eq(_part(_kit("deadeye", "eyes_up", true), "sure_aim").aura.value, 1000, "Sure Aim +5 more")
	assert_eq(_kit("wardweaver", "thick_thread").signature.effects[0].overheal_shield_bp, 4000)
	assert_eq(_kit("deadeye", "quick_plant", true).plant_ticks, 15, "planted in 0.75s")


func test_the_guard_knobs() -> void:
	assert_eq(_part(_kit("hearthwall", "broad_guard"), "guard").share_bp, 1500)
	assert_eq(_part(_kit("hearthwall", "broad_guard", true), "guard").share_bp, 3500)
	assert_eq(_part(_kit("hearthwall", "wide_guard", true), "guard").guard_range, 3 * HexGrid.HEX)
	# Wide Guard: an ally beside him is covered, not only one behind.
	for card: String in ["", "wide_guard"]:
		var brannoc: UnitDef = _run.content.paths["hearthwall"].vowed_kit if card.is_empty() else _kit("hearthwall", card)
		var fight: CombatSim = K.sim(K.fight([UnitSetup.make(brannoc, K.HEROES, 3, 2, "brannoc"), K.at(_dummy("ally"), 5, 2, "ally")] as Array[UnitSetup],
			[K.foe(_dummy("foe"), 3, 4, "foe")] as Array[UnitSetup]))
		fight.step()
		var at: Vector2i = fight.unit_by_id("brannoc").pos
		fight.unit_by_id("foe").pos = at + Vector2i(0, 2000)
		fight.unit_by_id("ally").pos = at + Vector2i(1500, 0)
		fight.unit_by_id("brannoc").target = fight.unit_by_id("foe")
		var guard: UnitState = Guards.covering(fight, EffectSource.make("foe", "foe_attack", "Strike"), fight.unit_by_id("ally"))
		assert_eq(guard != null, not card.is_empty(), "beside him: covered only with Wide Guard")


func test_add_to_areas_and_a_wider_line() -> void:
	var storm: UnitDef = _kit("volley", "harrying_storm", true)
	assert_true(storm.signature.effects[0].area_effects.any(func(effect: EffectDef) -> bool: return effect.status_id == "hobbled"), "inside the storm")
	var heart: UnitDef = _kit("deadeye", "seekers_mark", true)
	assert_true(heart.signature.effects[0].area_effects.any(func(effect: EffectDef) -> bool: return effect.status_id == "marked"), "inside the line")
	var sunfall: ShapeDef = _kit("vigil_keeper", "wide_sunfall", true).signature.effects[0].shape
	assert_eq([sunfall.width, sunfall.describe()], [2, "line 4 2"])
	var aside := Vector2i(1500, 800)
	assert_false(_run.content.paths["vigil_keeper"].transformed_kit.signature.effects[0].shape.contains(Vector2i.ZERO, Vector2i(ArenaPlane.DIR, 0), aside), "0.8 hex aside: outside a 1-hex line")
	assert_true(sunfall.contains(Vector2i.ZERO, Vector2i(ArenaPlane.DIR, 0), aside), "inside a 2-hex one")
	# In a fight: Harrying Storm Hobbles what it rains on.
	var fight: CombatSim = K.sim(K.fight([UnitSetup.make(storm, K.HEROES, 3, 2, "maren")] as Array[UnitSetup], [K.foe(_dummy(), 3, 4)] as Array[UnitSetup]))
	var maren: UnitState = fight.unit_by_id("maren")
	fight.step()
	maren.mana = maren.mana_cap
	K.step(fight, 40)
	assert_false(K.entries(fight, LogEntry.Kind.STATUS_APPLIED).filter(func(entry: LogEntry) -> bool: return entry.status == "hobbled").is_empty())


func test_a_signature_prefers() -> void:
	var slam: UnitDef = _kit("ironbrand", "brand_the_marked", true)
	assert_not_null(slam.signature.prefer)
	var fight: CombatSim = K.sim(K.fight([UnitSetup.make(slam, K.HEROES, 3, 2, "brannoc")] as Array[UnitSetup],
		[K.foe(_dummy("near"), 3, 4, "near"), K.foe(_dummy("far"), 5, 4, "far")] as Array[UnitSetup]))
	fight.step()
	var brannoc: UnitState = fight.unit_by_id("brannoc")
	fight.unit_by_id("near").pos = brannoc.pos + Vector2i(0, 1200)
	fight.unit_by_id("far").pos = brannoc.pos + Vector2i(1600, 0)
	assert_eq(Targeting.pick(fight, brannoc, "nearest", -1).id, "near")
	Statuses.apply(fight, fight.unit_by_id("far"), "marked", 1, 80, EffectSource.make("brannoc", "x", "X"))
	assert_eq(Targeting.pick(fight, brannoc, "nearest", -1, slam.signature.prefer).id, "far", "the Marked one first")
	assert_eq(Signatures.pick_target(fight, brannoc).id, "far")


func test_hard_to_pass_holds_longer() -> void:
	var ticks: Array[int] = []
	for card: String in ["", "hard_to_pass"]:
		var tank: UnitDef = K.kit("tank", {"stats": {"hp": 5000, "speed": 0, "range": 1}, "traits": ["engage"]})
		if not card.is_empty():
			tank = _run.upgrades[card].mod.apply(tank)
		var runner: UnitDef = _dummy("runner", {"stats": {"hp": 100000, "speed": 2, "range": 1}, "targeting": "farthest"})
		var fight: CombatSim = K.sim(K.fight([K.at(tank, 3, 2, "tank"), K.at(_dummy("back"), 3, 0, "back")] as Array[UnitSetup],
			[K.foe(runner, 3, 4, "runner")] as Array[UnitSetup]))
		K.step(fight, 200)
		var broke: Array[LogEntry] = K.entries(fight, LogEntry.Kind.BREAK_FREE)
		assert_false(broke.is_empty(), "it broke free")
		ticks.append(broke[0].tick)
	assert_eq(ticks[1] - ticks[0], 20, "1s later")


func test_grudge_gains_more_mana_from_damage() -> void:
	var brannoc: UnitDef = _run.upgrades["grudge"].mod.apply(_run.content.paths["hearthwall"].vowed_kit)
	assert_eq(brannoc.mana.taken_bp, 15000)
	var fight: CombatSim = K.sim(K.fight([UnitSetup.make(brannoc, K.HEROES, 3, 2, "brannoc")] as Array[UnitSetup], [K.foe(_dummy(), 3, 5)] as Array[UnitSetup]))
	var unit: UnitState = fight.unit_by_id("brannoc")
	var before: int = unit.mana
	Mana.on_damage_taken(fight, unit, 100)
	assert_eq(unit.mana - before, 15 * Mana.SCALE, "10 mana per 100 damage, times 1.5")
