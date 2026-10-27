extends GutTest
## The upgrade pools' six big pieces (docs/plans/rebuild-phase5c-combos.md,
## step 7d, section 15.7), each on its real card: Chasing Storm (a zone that
## follows), Ricochet, Reflecting Wall, Snag, Guarded Ground (a snare under
## the front-most ally), and First Lantern (a lantern placed before the
## fight).

const K = preload("res://tests/sim/sim_test_kit.gd")
const Bot = preload("res://tools/run_bot.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func _kit(path_id: String, cards: Array[String]) -> UnitDef:
	var kit: UnitDef = _run.content.paths[path_id].transformed_kit
	for card: String in cards:
		var problems: Array[String] = []
		kit = _run.upgrades[card].mod.apply(kit, problems)
		assert_eq(problems, [] as Array[String])
	return kit


func _dummy(dummy_id: String, overrides: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 100000, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}
	data.merge(overrides, true)
	return K.kit(dummy_id, data)


func _effect(data: Dictionary) -> EffectDef:
	var errors: Array[String] = []
	var effect: EffectDef = EffectDef.read(DataReader.new(data, "effect", errors))
	assert_eq(errors, [] as Array[String])
	return effect


func test_chasing_storm_follows_the_biggest_group() -> void:
	var maren: UnitDef = _kit("volley", ["chasing_storm"] as Array[String])
	assert_true(maren.signature.effects[0].follows)
	var foes: Array[UnitSetup] = [K.foe(_dummy("lone"), 3, 4, "lone")]
	for i: int in 3:
		foes.append(K.foe(_dummy("pack%d" % i), 6 + i % 2, 5 + i / 2, "pack%d" % i))
	var fight: CombatSim = K.sim(K.fight([UnitSetup.make(maren, K.HEROES, 3, 1, "maren")] as Array[UnitSetup], foes))
	fight.step()
	var unit: UnitState = fight.unit_by_id("maren")
	unit.mana = unit.mana_cap
	K.step(fight, 3)
	assert_eq(fight.zones.size(), 1, "the storm is up")
	var start: Vector2i = fight.zones[0].origin
	K.step(fight, 30)
	var moved: Array[LogEntry] = K.entries(fight, LogEntry.Kind.AREA_LANDED).filter(func(entry: LogEntry) -> bool: return entry.note == "moved")
	assert_false(moved.is_empty(), "its pulses move")
	var pack: Vector2i = fight.unit_by_id("pack1").pos
	assert_lt(ArenaPlane.distance(moved[moved.size() - 1].from_pos, pack), ArenaPlane.distance(start, pack), "toward the pack")
	for entry: LogEntry in moved:
		assert_true(entry.from_pos != start)


func test_ricochet_finds_a_third() -> void:
	var maren: UnitDef = _kit("volley", ["ricochet"] as Array[String])
	assert_eq(maren.basic_attack.effects[1].ricochet, 1)
	var fight: CombatSim = K.sim(K.fight([UnitSetup.make(maren, K.HEROES, 3, 1, "maren")] as Array[UnitSetup],
		[K.foe(_dummy("a"), 3, 4, "a"), K.foe(_dummy("b"), 2, 4, "b"), K.foe(_dummy("c"), 1, 4, "c")] as Array[UnitSetup]))
	fight.step()
	var a: Vector2i = fight.unit_by_id("a").pos
	fight.unit_by_id("b").pos = a + Vector2i(-700, 0)
	fight.unit_by_id("c").pos = a + Vector2i(-1400, 0)
	K.step(fight, 60)
	var bounced: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "maren").filter(func(entry: LogEntry) -> bool: return entry.note == "ricochet")
	assert_false(bounced.is_empty(), "a split arrow ricochets")
	for entry: LogEntry in bounced:
		assert_ne(entry.target, "a", "never the target")


func test_reflecting_wall_sends_a_stopped_shot_back() -> void:
	var brannoc: UnitDef = _kit("hearthwall", ["reflecting_wall"] as Array[String])
	var fight: CombatSim = K.sim(K.fight([UnitSetup.make(brannoc, K.HEROES, 3, 2, "brannoc"), K.at(_dummy("ally"), 3, 0, "ally")] as Array[UnitSetup],
		[K.foe(_dummy("archer"), 3, 6, "archer")] as Array[UnitSetup]))
	fight.step()
	var unit: UnitState = fight.unit_by_id("brannoc")
	var archer: UnitState = fight.unit_by_id("archer")
	Walls.raise(fight, unit, EffectSource.make("brannoc", "hearthwall", "Hearthwall"), brannoc.signature.effects[0], archer)
	assert_eq(fight.walls[0].reflect_bp, 5000)
	var shot := Shots.Shot.new()
	shot.source = EffectSource.make("archer", "archer_attack", "Strike")
	shot.shooter = archer
	shot.target = fight.unit_by_id("ally")
	shot.ability = archer.def.basic_attack
	shot.effects.append(_effect({"type": "damage", "amount": 100, "target": "target"}))
	shot.amounts.append(100)
	shot.powers.append(0)
	shot.crits.append(false)
	Shots.fire(fight, shot)
	K.step(fight, 20)
	var back: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "brannoc").filter(func(entry: LogEntry) -> bool: return entry.note == "reflected")
	assert_eq(back.size(), 1, "stopped, and sent back")
	assert_eq(back[0].target, "archer")
	assert_eq(fight.unit_by_id("ally").hp, fight.unit_by_id("ally").max_hp, "the ally untouched")


func test_snag_catches_a_leap() -> void:
	for card: String in ["", "snag"]:
		var maren: UnitDef = _run.content.paths["trapper"].transformed_kit if card.is_empty() else _kit("trapper", [card] as Array[String])
		var fight: CombatSim = K.sim(K.fight([UnitSetup.make(maren, K.HEROES, 3, 0, "maren"), K.at(_dummy("ally"), 3, 2, "ally")] as Array[UnitSetup],
			[K.foe(_dummy("leaper"), 3, 5, "leaper")] as Array[UnitSetup]))
		fight.step()
		var unit: UnitState = fight.unit_by_id("maren")
		var leaper: UnitState = fight.unit_by_id("leaper")
		var ally: UnitState = fight.unit_by_id("ally")
		var midway: Vector2i = (leaper.pos + ally.pos) / 2
		Snares.place(fight, unit, maren.signature, EffectSource.make("maren", "bramble_field", "Bramble Field"), Snares.placed_effect(maren), midway)
		Displacement.leap(fight, leaper, ally, _effect({"type": "leap", "max_hexes": 6, "target": "target"}), EffectSource.make("leaper", "leap", "Leap"))
		assert_eq(Statuses.find(leaper, "root") != null, not card.is_empty(), "a leap over it springs it only with Snag")


func test_guarded_ground_under_the_front_most() -> void:
	var maren: UnitDef = _kit("trapper", ["guarded_ground"] as Array[String])
	var fight: CombatSim = K.sim(K.fight([UnitSetup.make(maren, K.HEROES, 3, 0, "maren"), K.at(_dummy("front"), 4, 2, "front")] as Array[UnitSetup],
		[K.foe(_dummy("foe"), 3, 6, "foe")] as Array[UnitSetup]))
	fight.step()
	var set: Array[LogEntry] = K.entries(fight, LogEntry.Kind.SNARE).filter(func(entry: LogEntry) -> bool: return entry.note == "set")
	assert_eq(set.size(), 1)
	assert_eq(set[0].to_pos, fight.unit_by_id("front").pos, "under the front-most ally")
	assert_eq(fight.snares[0].effect, Snares.placed_effect(maren), "one of Bramble Field's, counted toward its 3")


func test_first_lantern_is_placed_and_lit_at_the_start() -> void:
	var vell: UnitDef = _kit("lanternbearer", ["first_lantern"] as Array[String])
	assert_true(vell.placed_lantern)
	assert_eq(vell.placed_markers(), 1)
	var hero: UnitSetup = UnitSetup.make(vell, K.HEROES, 3, 1, "vell")
	hero.lantern = Vector2i(2, 2)
	var setup: FightSetup = K.fight([hero] as Array[UnitSetup], [K.foe(_dummy("foe"), 3, 6, "foe")] as Array[UnitSetup])
	var fight: CombatSim = K.sim(setup)
	var zones: Array[LogEntry] = K.entries(fight, LogEntry.Kind.ZONE, "vell")
	assert_eq(zones.size(), 1, "lit before the first tick")
	assert_eq(zones[0].from_pos, fight.grid.center(2, 2))
	assert_eq(fight.unit_by_id("vell").mana, 0, "as if she'd just cast it")
	hero.lantern = Vector2i(2, 5)
	assert_true(setup.validate(K.content()).any(func(error: String) -> bool: return error.contains("lantern is in the enemies' half")))
	var plain: UnitSetup = UnitSetup.make(_run.content.paths["lanternbearer"].transformed_kit, K.HEROES, 3, 1, "vell")
	plain.lantern = Vector2i(2, 2)
	assert_true(K.fight([plain] as Array[UnitSetup], [K.foe(_dummy("foe"), 3, 6, "foe")] as Array[UnitSetup]).validate(K.content()).any(
		func(error: String) -> bool: return error.contains("can't place a lantern")))


func test_the_run_carries_the_lantern() -> void:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, 7, {"maren": "deadeye", "brannoc": "hearthwall", "vell": "lanternbearer"}, errors)
	var vell: RunState.Hero = flow.state.hero("vell")
	vell.transformed = true
	vell.upgrades.append("first_lantern")
	flow.choose_fight(0)
	var rocks: Array[Vector2i] = flow.fight_setup(Bot.formation(), errors).rocks
	var spot: Vector2i = Vector2i(-1, -1)
	for col: int in 8:
		if not rocks.has(Vector2i(col, 3)):
			spot = Vector2i(col, 3)
			break
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors, {"vell": [spot]})
	assert_eq(errors, [] as Array[String])
	var hero: UnitSetup = setup.heroes.filter(func(unit: UnitSetup) -> bool: return unit.id == "vell")[0]
	assert_eq(hero.lantern, spot)
	assert_true(hero.snares.is_empty())


func test_the_board_shows_the_lantern_marker() -> void:
	var hero: UnitSetup = UnitSetup.make(_kit("lanternbearer", ["first_lantern"] as Array[String]), K.HEROES, 3, 1, "vell")
	hero.lantern = Vector2i(2, 2)
	var view := ArenaView.new()
	add_child_autofree(view)
	view.show_setup(K.fight([hero] as Array[UnitSetup], [K.foe(_dummy("foe"), 3, 6, "foe")] as Array[UnitSetup]), K.content())
	assert_eq(view.snare_markers.size(), 1)
	assert_true(view.snare_markers[0].lantern, "drawn as a lantern, dragged like a snare")
	assert_eq(view.snare_markers[0].hex, Vector2i(2, 2))
