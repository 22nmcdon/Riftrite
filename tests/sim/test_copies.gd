extends GutTest
## Copying a signature (docs/plans/rebuild-phase8-act3.md, part 8c-5c-3;
## Copies, the copy passive): the first copyable hero signature becomes the
## copier's, cast on its own bar with the sides turned; what can't be
## copied; Greedy, Twinned, and the Queen's court.

const K = preload("res://tests/sim/sim_test_kit.gd")


static func still(unit_id: String, extra: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 5000, "atk": 10, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}
	for key: String in extra:
		if key == "stats":
			(data["stats"] as Dictionary).merge(extra["stats"], true)
		else:
			data[key] = extra[key]
	return K.kit(unit_id, data)


## A hero whose signature fires as the fight starts (or at `at_ms`).
static func caster(unit_id: String, signature: Dictionary, at_ms: int = 0) -> UnitDef:
	var trigger: Dictionary = {"kind": "fight_start"} if at_ms == 0 else {"kind": "at_time", "at_ms": at_ms}
	var whole: Dictionary = {"trigger": trigger, "max_range": 9}
	whole.merge(signature, true)
	return still(unit_id, {"signature": whole})


static func blast(unit_id: String = "blaster", at_ms: int = 0) -> UnitDef:
	return caster(unit_id, {"id": "blast", "name": "Blast", "targeting": "nearest",
		"effects": [{"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "target", "hits": "enemies",
			"effects": [{"type": "damage", "amount": 30, "target": "target"}]}]}, at_ms)


static func mend(unit_id: String = "mender", at_ms: int = 0) -> UnitDef:
	return caster(unit_id, {"id": "mend", "name": "Mend", "targeting": "lowest_hp_ally", "effects": [{"type": "heal", "amount": 40, "target": "target"}]}, at_ms)


static func pounce(unit_id: String = "leaper") -> UnitDef:
	return caster(unit_id, {"id": "pounce", "name": "Pounce", "targeting": "nearest", "max_range": 6,
		"effects": [{"type": "leap", "max_hexes": 6, "target": "target"}, {"type": "damage", "amount": 5, "target": "target"}]})


## A copier: a weak bolt on a mana bar until it has a copy.
static func mirror(unit_id: String = "mirror", copy: Dictionary = {}) -> UnitDef:
	var part: Dictionary = {"id": "mirror_sight", "name": "Mirror Sight", "kind": "copy"}
	part.merge(copy, true)
	return still(unit_id, {"stats": {"range": 9}, "mana": {"max": 20, "regen_per_s": 0},
		"signature": {"id": "dull_bolt", "name": "Dull Bolt", "trigger": {"kind": "mana"}, "targeting": "nearest", "max_range": 9,
			"effects": [{"type": "damage", "amount": 1, "target": "target"}]},
		"passives": [part]})


## A fight for the log's audit (test_arena_log.gd): a court that copies a
## Blast and casts it back.
static func copy_setup() -> FightSetup:
	var court: UnitDef = mirror("court")
	court.mana.regen_per_s = 40
	return K.fight([K.at(blast(), 3, 1), K.at(mend(), 4, 0)] as Array[UnitSetup],
		[K.foe(mirror("queen", {"share": true, "twice_pct": 60}), 3, 5), K.foe(court, 5, 5)] as Array[UnitSetup])


func _fire_now(fight: CombatSim, unit_id: String) -> void:
	var unit: UnitState = fight.unit_by_id(unit_id)
	unit.mana = unit.mana_cap


func test_the_first_copyable_signature_is_copied_and_cast_back() -> void:
	var setup: FightSetup = K.fight([K.at(pounce(), 3, 2), K.at(blast(), 4, 0)] as Array[UnitSetup], [K.foe(mirror(), 3, 5), K.foe(still("ally"), 5, 6)] as Array[UnitSetup])
	var fight: CombatSim = K.sim(setup)
	K.step(fight, 5)
	var copied: Array[LogEntry] = K.entries(fight, LogEntry.Kind.COPIED)
	assert_eq(copied.size(), 1, "the Pounce (a leap) isn't copyable; the Blast is")
	assert_eq([copied[0].source_unit, copied[0].source_ability, copied[0].target, copied[0].note], ["mirror", "mirror_sight", "blaster", "Blast"])
	var unit: UnitState = fight.unit_by_id("mirror")
	assert_eq(unit.signature.def.name, "Blast (copied from blaster)")
	assert_eq(unit.signature.def.trigger.kind, TriggerDef.Kind.MANA, "on its own bar")
	_fire_now(fight, "mirror")
	K.step(fight, 3)
	var fires: Array[LogEntry] = K.entries(fight, LogEntry.Kind.FIRE, "mirror")
	assert_eq(fires[-1].source_ability, "blast_copy")
	assert_string_contains(fires[-1].to_text(), "Blast (copied from blaster)")
	var hits: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "mirror")
	assert_false(hits.is_empty())
	assert_true(hits.all(func(entry: LogEntry) -> bool: return entry.target == "leaper" or entry.target == "blaster"), "the heroes take it: the sides turned")
	assert_eq(hits[0].amount, 30)
	assert_eq(K.entries(fight, LogEntry.Kind.COPIED).size(), 1, "only the first")


func test_a_copied_heal_goes_to_its_own_allies() -> void:
	var setup: FightSetup = K.fight([K.at(mend(), 3, 1)] as Array[UnitSetup], [K.foe(mirror(), 3, 5), K.foe(still("ally"), 5, 6)] as Array[UnitSetup])
	var fight: CombatSim = K.sim(setup)
	K.step(fight, 3)
	assert_eq(fight.unit_by_id("mirror").copied, "mend")
	fight.unit_by_id("ally").hp = 1000
	_fire_now(fight, "mirror")
	K.step(fight, 3)
	var heals: Array[LogEntry] = K.entries(fight, LogEntry.Kind.HEAL, "mirror")
	assert_eq(heals.size(), 1)
	assert_eq([heals[0].target, heals[0].amount], ["ally", 40], "its hurt ally, not a hero")


func test_greedy_takes_each_new_one_and_the_rest_keep_the_first() -> void:
	for greedy: bool in [false, true]:
		var setup: FightSetup = K.fight([K.at(blast(), 3, 1), K.at(mend("mender", 1000), 4, 0)] as Array[UnitSetup],
			[K.foe(mirror("mirror", {"replace": greedy}), 3, 5)] as Array[UnitSetup])
		var fight: CombatSim = K.sim(setup)
		K.step(fight, 30)
		assert_eq(fight.unit_by_id("mirror").copied, "mend" if greedy else "blast")
		assert_eq(K.entries(fight, LogEntry.Kind.COPIED).size(), 2 if greedy else 1)


func test_twinned_casts_it_twice_each_weaker() -> void:
	var setup: FightSetup = K.fight([K.at(blast(), 3, 1)] as Array[UnitSetup], [K.foe(mirror("mirror", {"twice_pct": 60}), 3, 5)] as Array[UnitSetup])
	var fight: CombatSim = K.sim(setup)
	K.step(fight, 3)
	_fire_now(fight, "mirror")
	K.step(fight, 20)
	var hits: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "mirror")
	assert_eq(hits.size(), 2, "twice")
	assert_eq([hits[0].amount, hits[1].amount], [18, 18], "each at 60%")
	assert_eq(hits[1].tick - hits[0].tick, Copies.TWIN_TICKS)
	assert_eq(hits[1].source_ability, "blast_copy_twin")


func test_the_queens_court_gets_each_copy() -> void:
	var setup: FightSetup = K.fight([K.at(blast(), 3, 1)] as Array[UnitSetup],
		[K.foe(mirror("court", {}), 2, 5), K.foe(mirror("queen", {"share": true, "replace": true}), 3, 6), K.foe(mirror("court2", {}), 5, 5)] as Array[UnitSetup])
	var fight: CombatSim = K.sim(setup)
	K.step(fight, 3)
	var copied: Array[LogEntry] = K.entries(fight, LogEntry.Kind.COPIED)
	assert_eq(copied.map(func(entry: LogEntry) -> String: return "%s%s" % [entry.source_unit, "*" if entry.shape == "shared" else ""]), ["court", "queen", "court*", "court2*"],
		"each took it, and the Queen gave hers to her court")
	assert_true(["court", "queen", "court2"].all(func(unit_id: String) -> bool: return fight.unit_by_id(unit_id).copied == "blast"))


func test_a_copier_needs_a_mana_signature_and_a_fight_without_one_copies_nothing() -> void:
	var errors: Array[String] = []
	var bad: UnitDef = UnitDef.read(DataReader.new({"id": "x", "name": "X", "stats": {"hp": 10, "atk": 1, "speed": 1, "range": 1},
		"basic_attack": {"id": "a", "name": "A", "cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 1, "target": "target"}]},
		"passives": [{"id": "m", "name": "M", "kind": "copy"}]}, "x", errors))
	assert_true(bad.problems().has("a copy passive needs a mana signature of its own"), str(bad.problems()))
	var fight: CombatSim = K.sim(K.fight([K.at(blast(), 3, 1)] as Array[UnitSetup], [K.foe(still("plain"), 3, 5)] as Array[UnitSetup]))
	K.step(fight, 5)
	assert_eq(fight.copiers, [] as Array[UnitState])
	assert_eq(K.entries(fight, LogEntry.Kind.COPIED), [] as Array[LogEntry])


func test_its_words() -> void:
	var content: ContentDb = K.content()
	var kit: UnitDef = mirror("mirror", {"replace": true, "twice_pct": 60, "share": true})
	assert_eq(UnitInfo.passive_numbers(kit.passives[0], kit, content), "Copies each new hero signature it sees; casts it twice, each at 60%; its court gets each copy too")
	assert_true(Copies.copyable(blast().signature))
	assert_false(Copies.copyable(pounce().signature))
	var shove: UnitDef = caster("shover", {"id": "shove", "name": "Shove", "targeting": "nearest",
		"effects": [{"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "target", "hits": "enemies", "effects": [{"type": "knockback", "hexes": 1, "target": "target"}]}]})
	assert_false(Copies.copyable(shove.signature), "an area that knocks back isn't copyable")


func test_the_audit_fight_copies_and_casts_back() -> void:
	var result: FightResult = K.run(copy_setup())
	assert_false(result.combat_log.of_kind(LogEntry.Kind.COPIED).is_empty())
	assert_true(result.combat_log.of_kind(LogEntry.Kind.FIRE).any(func(entry: LogEntry) -> bool: return entry.source_unit == "court" and entry.source_ability.ends_with("_copy")), "the court casts its copy")
