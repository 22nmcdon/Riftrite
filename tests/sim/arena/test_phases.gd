extends GutTest
## Phases (PhaseDef, Phases; docs/plans/rebuild-phase1-arena-sim.md,
## section 3): entered once each as HP drops, in order, changing the kit
## from the next update; and the checks on reading them.

const K = preload("res://tests/sim/sim_test_kit.gd")


func _post() -> UnitDef:
	return K.kit("post", {"stats": {"hp": 100000, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


## A boss (hp 1000, standing still, range 8) with `phases` and any other
## kit keys in `overrides`.
func _boss(phases: Array, overrides: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 1000, "speed": 0, "range": 8}, "phases": phases,
		"basic_attack": {"id": "claw", "cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}
	data.merge(overrides, true)
	return K.kit("boss", data)


func _fight(boss: UnitDef) -> CombatSim:
	return K.sim(K.fight([K.at(_post(), 3, 2, "hero")] as Array[UnitSetup], [K.foe(boss, 3, 5)] as Array[UnitSetup]))


func _phase_log(fight: CombatSim) -> Array:
	return K.entries(fight, LogEntry.Kind.PHASE).map(func(entry: LogEntry) -> Array: return [entry.tick, entry.note])


const MOLT: Dictionary = {"id": "molt", "name": "Molt", "below_hp_bp": 6000, "targeting": "farthest"}
const EMBER: Dictionary = {"id": "last_ember", "name": "Last Ember", "below_hp_bp": 2500,
	"signature": {"id": "ember_breath", "name": "Ember Breath", "trigger": {"kind": "fight_start"}, "targeting": "self",
		"effects": [{"type": "start_collapse"}]}}


func test_a_phase_begins_once_below_its_threshold() -> void:
	var fight: CombatSim = _fight(_boss([MOLT]))
	var boss: UnitState = fight.unit_by_id("boss")
	fight.step()
	boss.hp = 600
	fight.step()
	assert_eq(_phase_log(fight), [], "600 of 1000 isn't below 60%")
	boss.hp = 599
	fight.step()
	assert_eq(_phase_log(fight), [[3, "Molt"]])
	var entry: LogEntry = K.entries(fight, LogEntry.Kind.PHASE)[0]
	assert_eq([entry.source_unit, entry.source_ability, entry.to_text()], ["boss", "molt", "[0.15s] boss enters Molt"])
	assert_eq(boss.def, boss.phases[0].kit)
	boss.hp = 100
	K.step(fight, 5)
	assert_eq(_phase_log(fight).size(), 1, "once")


func test_several_phases_at_once_go_in_order() -> void:
	var fight: CombatSim = _fight(_boss([MOLT, EMBER]))
	var boss: UnitState = fight.unit_by_id("boss")
	boss.hp = 100
	fight.step()
	assert_eq(_phase_log(fight), [[1, "Molt"], [1, "Last Ember"]])
	assert_eq(boss.def.targeting, "farthest", "the second builds on the first")
	assert_eq(boss.def.signature.id, "ember_breath")


func test_a_unit_at_zero_hp_enters_no_phase() -> void:
	var fight: CombatSim = _fight(_boss([MOLT]))
	var boss: UnitState = fight.unit_by_id("boss")
	boss.hp = 0
	fight.step()
	assert_eq(_phase_log(fight), [])


func test_a_new_signature_starts_fresh_and_fires_as_the_phase_begins() -> void:
	var fight: CombatSim = _fight(_boss([EMBER], {"signature": {"id": "roar", "name": "Roar", "trigger": {"kind": "fight_start"}, "targeting": "self",
		"effects": [{"type": "shield", "amount": 5, "target": "self"}]}}))
	var boss: UnitState = fight.unit_by_id("boss")
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE, "boss").size(), 1, "Roar")
	boss.hp = 200
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.COLLAPSE_RING), [] as Array[LogEntry], "from its next update")
	fight.step()
	var warning: LogEntry = K.entries(fight, LogEntry.Kind.COLLAPSE_RING)[0]
	assert_eq([warning.tick, warning.source_text()], [3, "boss · Ember Breath"], "the rift closes early")


func test_a_cast_under_way_is_cancelled() -> void:
	var fight: CombatSim = _fight(_boss([EMBER], {"mana": {"max": 10, "start": 10},
		"signature": {"id": "hex", "name": "Hex", "trigger": {"kind": "mana"}, "cast_ms": 1000, "effects": [{"type": "damage", "amount": 5, "target": "target"}]}}))
	var boss: UnitState = fight.unit_by_id("boss")
	fight.step()
	assert_true(boss.signature.casting())
	boss.hp = 200
	fight.step()
	var cancelled: LogEntry = K.entries(fight, LogEntry.Kind.CAST_CANCELLED)[0]
	assert_eq([cancelled.source_ability, cancelled.note], ["hex", "phase"])
	assert_eq([boss.mana, boss.mana_cap, boss.mana_regen], [0, 0, 0], "Ember Breath has no bar, so the bar is gone")


func test_a_new_mana_bar_starts_at_its_own_start() -> void:
	var phase: Dictionary = {"id": "molt", "name": "Molt", "below_hp_bp": 6000, "mana": {"max": 50, "start": 20, "regen_per_s": 10},
		"signature": {"id": "brood", "name": "Brood", "trigger": {"kind": "mana"}, "targeting": "self", "effects": [{"type": "shield", "amount": 5, "target": "self"}]}}
	var fight: CombatSim = _fight(_boss([phase]))
	var boss: UnitState = fight.unit_by_id("boss")
	boss.hp = 500
	fight.step()
	assert_eq([boss.mana, boss.mana_cap, boss.mana_regen], [20 * Mana.SCALE, 50 * Mana.SCALE, 10 * Mana.SCALE / 20])
	assert_true(boss.signature.mana_trigger)


func test_a_new_basic_attack_keeps_its_cooldown_progress() -> void:
	var phase: Dictionary = {"id": "molt", "name": "Molt", "below_hp_bp": 6000,
		"basic_attack": {"id": "rend", "name": "Rend", "cooldown_ms": 2000, "effects": [{"type": "damage", "amount": 30, "target": "target"}]}}
	var fight: CombatSim = _fight(_boss([phase]))
	var boss: UnitState = fight.unit_by_id("boss")
	K.step(fight, 10)
	var progress: int = boss.attack.progress_bp
	boss.hp = 500
	fight.step()
	assert_eq([boss.attack.def.id, boss.attack.progress_bp], ["rend", progress + FixedMath.BP_ONE], "the old one ran this tick too")
	K.step(fight, 30)
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE, "boss").map(func(entry: LogEntry) -> Array: return [entry.tick, entry.source_ability]), [[40, "rend"]], "ready 2s after its cooldown started")


func test_a_new_targeting_rule_picks_again() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_post(), 3, 2, "near"), K.at(_post(), 0, 0, "far")] as Array[UnitSetup], [K.foe(_boss([MOLT]), 3, 5)] as Array[UnitSetup]))
	var boss: UnitState = fight.unit_by_id("boss")
	fight.step()
	assert_eq(boss.target.id, "near")
	boss.hp = 500
	fight.step()
	fight.step()
	assert_eq(boss.target.id, "far")
	assert_eq(K.entries(fight, LogEntry.Kind.TARGET, "boss").back().to_text(), "[0.15s] boss targets far: farthest")


func test_passives_are_added_replaced_and_keep_their_counts() -> void:
	var spite: Dictionary = {"id": "spite", "name": "Spite", "kind": "ability", "effects": [{"trigger": "on_hit_taken", "every": 3, "type": "shield", "amount": 1, "target": "self"}]}
	var spite_2: Dictionary = spite.duplicate(true)
	spite_2["name"] = "Deep Spite"
	var phase: Dictionary = {"id": "molt", "name": "Molt", "below_hp_bp": 6000,
		"passives": [{"id": "ash_skin", "name": "Ash Skin", "kind": "aura", "aura": {"target": "holder", "stat": "atk_bp", "value": 20000}}]}
	var fight: CombatSim = _fight(_boss([phase], {"passives": [spite, {"id": "grudge", "name": "Grudge", "kind": "ability", "effects": [{"trigger": "on_hit_taken", "every": 2, "type": "shield", "amount": 1, "target": "self"}]}]}))
	var boss: UnitState = fight.unit_by_id("boss")
	boss.listeners[0].count = 2
	boss.hp = 500
	fight.step()
	assert_eq(boss.listeners.map(func(listener: Passives.Listener) -> Array: return [listener.part.id, listener.count]), [["spite", 2], ["grudge", 0]], "counts carry over")
	assert_eq(K.entries(fight, LogEntry.Kind.AURA).back().to_text(), "[0.05s] boss · Ash Skin aura starts: x2 ATK for its holder")
	var replacing: UnitDef = _boss([{"id": "molt", "name": "Molt", "below_hp_bp": 6000, "passives": [spite_2]}], {"passives": [spite]})
	assert_eq(replacing.phases[0].kit.passives.map(func(part: PartDef) -> String: return part.name), ["Deep Spite"], "the same id replaces")
	fight = _fight(replacing)
	boss = fight.unit_by_id("boss")
	boss.listeners[0].count = 2
	boss.hp = 500
	fight.step()
	assert_eq(boss.listeners[0].count, 0, "a replaced passive counts afresh")


func test_reading_phases() -> void:
	var cases: Array = [
		[[{"id": "a", "name": "A", "below_hp_bp": 5000}], "a phase needs a signature, mana, a basic_attack, a targeting rule, or passives"],
		[[MOLT, MOLT.merged({"id": "b", "below_hp_bp": 6000}, true)], "phases go from the highest threshold down"],
		[[MOLT, MOLT.merged({"below_hp_bp": 3000}, true)], "two phases are called \"molt\""],
		[[{"id": "a", "name": "A", "below_hp_bp": 5000, "signature": {"id": "s", "name": "S", "trigger": {"kind": "mana"}, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}}], "a mana signature needs \"mana\""],
		[[{"id": "a", "name": "A", "below_hp_bp": 5000, "mana": {"max": 10}}], "\"mana\": only a unit whose signature fires on mana has a mana bar"],
		[[{"id": "a", "name": "A", "below_hp_bp": 5000, "passives": [{"id": "claw", "name": "C", "kind": "replace_status", "from": "burn", "to": "poison"}]}], "its abilities and passives need different ids (\"claw\" twice)"],
		[[{"id": "a", "name": "A", "below_hp_bp": 10000, "targeting": "farthest"}], "10000 is out of range"],
	]
	for case: Array in cases:
		var errors: Array[String] = []
		var data: Dictionary = {"id": "boss", "name": "Boss", "stats": {"hp": 10}, "phases": case[0],
			"basic_attack": {"id": "claw", "name": "Claw", "cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}}
		UnitDef.read(DataReader.new(data, "boss", errors))
		assert_eq(errors.size(), 1, "%s" % [errors])
		if errors.size() == 1:
			assert_string_contains(errors[0], case[1])
	# A later phase's mana signature can use the bar an earlier one gave.
	var errors: Array[String] = []
	var ok: Dictionary = {"id": "boss", "name": "Boss", "stats": {"hp": 10},
		"basic_attack": {"id": "claw", "name": "Claw", "cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 1, "target": "target"}]},
		"mana": {"max": 10}, "signature": {"id": "s", "name": "S", "trigger": {"kind": "mana"}, "effects": [{"type": "damage", "amount": 1, "target": "target"}]},
		"phases": [{"id": "a", "name": "A", "below_hp_bp": 5000, "signature": {"id": "t", "name": "T", "trigger": {"kind": "mana"}, "effects": [{"type": "damage", "amount": 2, "target": "target"}]}}]}
	var kit: UnitDef = UnitDef.read(DataReader.new(ok, "boss", errors))
	assert_eq(errors, [] as Array[String])
	assert_eq([kit.phases[0].kit.mana, kit.signature.id], [kit.mana, "s"], "the base kit is untouched")


func test_the_setup_checks_what_phases_bring() -> void:
	var phase: Dictionary = {"id": "molt", "name": "Molt", "below_hp_bp": 6000,
		"basic_attack": {"id": "rend", "name": "Rend", "cooldown_ms": 1000, "effects": [{"type": "apply_status", "status": "venom", "target": "target"}]},
		"passives": [{"id": "brood", "name": "Brood", "kind": "ability", "effects": [{"trigger": "on_hit_taken", "type": "summon", "kit": "pup", "placement": "adjacent"}]},
			{"id": "embers", "name": "Embers", "kind": "replace_status", "from": "burn", "to": "cinders"}]}
	var setup: FightSetup = K.fight([K.at(_post(), 3, 2)] as Array[UnitSetup], [K.foe(_boss([phase]), 3, 5)] as Array[UnitSetup])
	assert_eq(setup.validate(K.content()), [
		"boss at (3, 5) names an unknown status \"cinders\"",
		"boss at (3, 5) names an unknown status \"venom\"",
		"boss at (3, 5) summons \"pup\", which isn't among the fight's summon kits",
	] as Array[String])


func test_a_replaced_status_swap_is_gone() -> void:
	var phase: Dictionary = {"id": "molt", "name": "Molt", "below_hp_bp": 6000,
		"passives": [{"id": "embers", "name": "Embers", "kind": "replace_status", "from": "bleed", "to": "poison"}]}
	var fight: CombatSim = _fight(_boss([phase], {"passives": [{"id": "embers", "name": "Embers", "kind": "replace_status", "from": "burn", "to": "poison"}]}))
	var boss: UnitState = fight.unit_by_id("boss")
	boss.hp = 500
	fight.step()
	assert_eq(boss.status_swaps, {"bleed": "poison"})


func test_a_phase_can_bring_the_fights_first_event_passive() -> void:
	var phase: Dictionary = {"id": "molt", "name": "Molt", "below_hp_bp": 6000,
		"passives": [{"id": "spite", "name": "Spite", "kind": "ability", "effects": [{"trigger": "on_hit_taken", "type": "shield", "amount": 3, "target": "self"}]}]}
	var hero: UnitDef = K.kit("hero", {"stats": {"hp": 100000, "speed": 0, "range": 8}, "basic_attack": {"shot": false, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_boss([phase]), 3, 5)] as Array[UnitSetup]))
	fight.unit_by_id("boss").hp = 500
	K.step(fight, 21)
	assert_eq(K.entries(fight, LogEntry.Kind.SHIELD, "boss").map(func(entry: LogEntry) -> String: return entry.to_text()), ["[1.00s] boss · Spite gives boss 3 shield"])
