extends GutTest
## The sim pieces phase 5's elites and boss need (docs/plans/rebuild-phase5-run.md,
## section 7): an aura on while an ally of a kit stands (Pack Bond), a
## signature that fires with an ally's (The Hunt), and the inert trait (the
## Gloam Totem). Old Mother Ash's walk in (a range aura in a phase) and her
## pups from the edges use pieces that were already there.

const K = preload("res://tests/sim/sim_test_kit.gd")


static func still(unit_id: String, extra: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 5000, "atk": 10, "speed": 0, "range": 3},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}
	for key: String in extra:
		if key == "stats":
			(data["stats"] as Dictionary).merge(extra["stats"], true)
		else:
			data[key] = extra[key]
	return K.kit(unit_id, data)


func test_an_aura_holds_while_an_ally_of_a_kit_stands() -> void:
	var bond: Dictionary = {"id": "pack_bond", "name": "Pack Bond", "kind": "aura",
		"aura": {"target": "all_allies", "stat": "def_bp", "value": 20000, "while": "ally_standing", "kit": "hound"}}
	var mother: UnitDef = still("mother", {"passives": [bond], "stats": {"def": 10}})
	var fight: CombatSim = K.sim(K.fight([K.at(still("hero"), 3, 1)] as Array[UnitSetup],
		[K.foe(mother, 3, 6), K.foe(still("hound", {"stats": {"def": 5}}), 2, 5), K.foe(still("hound", {"stats": {"def": 5}}), 5, 5, "hound#2")] as Array[UnitSetup]))
	var unit: UnitState = fight.unit_by_id("mother")
	K.step(fight, 1)
	assert_eq([unit.defense(), fight.unit_by_id("hound").defense()], [20, 10], "the whole pack, hounds too")
	fight.unit_by_id("hound").hp = 0
	K.step(fight, 1)
	assert_eq(unit.defense(), 20, "one hound still stands")
	fight.unit_by_id("hound#2").hp = 0
	K.step(fight, 1)
	assert_eq(unit.defense(), 10, "off once none does")


func test_a_pack_pounces_with_its_alpha_on_the_same_hero() -> void:
	var leap: Array = [{"type": "leap", "max_hexes": 8, "target": "target"}, {"type": "damage", "amount": 5, "target": "target"}]
	var alpha: UnitDef = still("alpha", {"signature": {"id": "pounce", "name": "Pounce", "trigger": {"kind": "fight_start"}, "targeting": "farthest", "max_range": 8, "effects": leap}})
	var hound: UnitDef = still("hound", {"signature": {"id": "join", "name": "Join the Hunt", "trigger": {"kind": "ally_fires", "ability": "pounce"},
		"targeting": "nearest", "max_range": 8, "effects": leap}})
	var fight: CombatSim = K.sim(K.fight([K.at(still("near"), 3, 2), K.at(still("far"), 6, 0)] as Array[UnitSetup],
		[K.foe(alpha, 3, 6), K.foe(hound, 1, 4), K.foe(hound, 5, 4, "hound#2")] as Array[UnitSetup]))
	K.step(fight, 10)
	var fires: Array[LogEntry] = K.entries(fight, LogEntry.Kind.FIRE).filter(func(entry: LogEntry) -> bool: return entry.source_ability in ["pounce", "join"])
	assert_eq(fires.map(func(entry: LogEntry) -> String: return "%s>%s" % [entry.source_unit, entry.target]), ["alpha>far", "hound>far", "hound#2>far"],
		"the pack goes for the Alpha's target, not their own nearest")
	assert_eq([fires[1].note, fires[2].note], ["with alpha", "with alpha"])
	assert_eq(fires[1].tick, fires[0].tick + 1, "on the next update")


func test_an_inert_unit_never_acts_but_its_passives_do() -> void:
	var ward: Dictionary = {"id": "gloam_ward", "name": "Gloam Ward", "kind": "ability",
		"effects": [{"trigger": "on_interval", "interval_ms": 1000, "type": "area", "shape": {"kind": "circle", "radius": 2}, "anchor": "self", "hits": "other_allies",
			"effects": [{"type": "shield", "amount": 25, "target": "target"}]}]}
	var totem: UnitDef = K.kit("totem", {"stats": {"hp": 500, "speed": 2, "range": 1}, "traits": ["inert"], "passives": [ward]})
	var fight: CombatSim = K.sim(K.fight([K.at(still("hero"), 3, 2)] as Array[UnitSetup], [K.foe(totem, 3, 4), K.foe(still("guard"), 4, 4)] as Array[UnitSetup]))
	var start: Vector2i = fight.unit_by_id("totem").pos
	K.step(fight, 100)
	assert_eq(fight.unit_by_id("totem").pos, start, "it never walks")
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE, "totem"), [] as Array[LogEntry], "nor attacks")
	assert_null(fight.unit_by_id("totem").target, "nor targets")
	assert_gt(K.entries(fight, LogEntry.Kind.SHIELD, "totem").size(), 3, "its passive Shields its allies")


func test_the_boss_goes_through_her_phases() -> void:
	var content: ContentDb = K.content()
	var errors: Array[String] = []
	var formation: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(3, 0), "vell": Vector2i(4, 0)}
	var setup: FightSetup = Encounters.setup(content, "old_mother_ash", formation, 1, errors)
	assert_eq(errors, [] as Array[String])
	var sim := CombatSim.new(setup, content)
	var ash: UnitState = sim.unit_by_id("old_mother_ash")
	sim.step()
	ash.hp = ash.max_hp / 2
	for i: int in 260:
		sim.step()
	assert_true(K.entries(sim, LogEntry.Kind.SUMMON).size() >= 2, "Molt: pups from the edges")
	ash.hp = ash.max_hp / 5
	for i: int in 40:
		sim.step()
	var breaths: Array[LogEntry] = K.entries(sim, LogEntry.Kind.FIRE, "old_mother_ash").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "ember_breath")
	assert_false(breaths.is_empty(), "Last Ember breathes at once")
	assert_lt(sim.collapse_start, content.tuning.collapse_start_ticks, "and the rift closes early")
