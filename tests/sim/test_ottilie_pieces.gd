extends GutTest
## The fight pieces Ottilie's kit and paths added (phase 8 part 6, docs/plans/
## rebuild-phase8-last-heroes.md section 5, 8f-2), each in a small fight: an
## on_interval's first_ms (Brewing's two vials taking turns), on_holder_hit's
## spends (her next Toss carries the vial, spent once for its passive), a
## per-hit aura's summed stacks with per_stacks and cap_bp (Reaction),
## damage's amount_per_stack over several statuses (Reaction Flask), the
## deed counts bonus_damage (Catalyst) and shards, the condition all_statuses
## (Gilded Death's both), a kit's shard_cap, to_smaller_of (Solvent),
## signature_cost_bp (Mana Flood), the condition others (Elixir's mana), and
## a mana trigger's recover_ms (Elixir).

const K = preload("res://tests/sim/sim_test_kit.gd")


func _dummy(dummy_id: String, hp: int = 5000, passives: Array = []) -> UnitDef:
	return K.kit(dummy_id, {"stats": {"hp": hp, "speed": 0, "range": 1, "def": 0},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}, "passives": passives})


## A thrower whose basic attack is "toss": 100 damage a second within 3
## hexes, standing still.
func _thrower(passives: Array, extra: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 1000, "speed": 0, "range": 3},
		"basic_attack": {"id": "toss", "name": "Toss", "cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 100, "target": "target"}]}, "passives": passives}
	data.merge(extra, true)
	return K.kit("thrower", data)


const BREWING: Array = [{"id": "brewing", "name": "Brewing", "kind": "ability", "effects": [
	{"trigger": "on_interval", "interval_ms": 8000, "first_ms": 4000, "type": "apply_status", "status": "fire_vial", "target": "self"},
	{"trigger": "on_interval", "interval_ms": 8000, "type": "apply_status", "status": "venom_vial", "target": "self"},
	{"trigger": "on_holder_hit", "from_ability": ["toss"], "spends": "fire_vial", "type": "apply_status", "status": "burn", "stacks": 10, "target": "hit_target"},
	{"trigger": "on_holder_hit", "from_ability": ["toss"], "spends": "venom_vial", "type": "apply_status", "status": "poison", "stacks": 10, "target": "hit_target"}]}]


func _effect(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	EffectDef.read(DataReader.new(data, "effect", errors))
	return errors


func _applied(fight: CombatSim, status_id: String) -> Array[LogEntry]:
	return K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "thrower").filter(func(entry: LogEntry) -> bool: return entry.status == status_id)


func _condition(data: Dictionary) -> UnitCondition:
	var errors: Array[String] = []
	var condition: UnitCondition = UnitCondition.read(DataReader.new(data, "condition", errors))
	assert_eq(errors, [] as Array[String])
	return condition


func test_reading_the_pieces() -> void:
	assert_eq(_effect({"trigger": "on_interval", "interval_ms": 8000, "first_ms": 4000, "type": "apply_status", "status": "fire_vial", "target": "self"}), [] as Array[String])
	assert_eq(_effect({"trigger": "on_holder_hit", "spends": "fire_vial", "type": "apply_status", "status": "burn", "stacks": 1, "target": "hit_target"}), [] as Array[String])
	assert_eq(_effect({"type": "damage", "amount": 0, "amount_per_stack": {"status": ["burn", "poison"], "per": 3}, "target": "target"}), [] as Array[String])
	var errors: Array[String] = []
	var aura: AuraDef = AuraDef.read(DataReader.new({"target": "holder", "stat": "damage_bp", "value": 10100, "per_target_stacks": ["burn", "poison"], "per_stacks": 5, "cap_bp": 1000}, "aura", errors))
	assert_eq(errors, [] as Array[String])
	assert_eq([aura.per_target_stacks, aura.per_target_more, aura.per_stacks, aura.cap_bp], ["burn", ["poison"] as Array[String], 5, 1000])
	assert_true(aura.is_per_hit())
	AuraDef.read(DataReader.new({"target": "holder", "stat": "damage_bp", "value": 10100, "per_stacks": 5}, "aura", errors))
	assert_false(errors.is_empty(), "per_stacks counts a target's stacks")
	errors.clear()
	DeedDef.read(DataReader.new({"text": "x", "counts": "bonus_damage", "from_part": "reaction"}, "deed", errors))
	DeedDef.read(DataReader.new({"text": "x", "counts": "shards", "from_ability": ["gilded_death"]}, "deed", errors))
	assert_eq(errors, [] as Array[String])
	DeedDef.read(DataReader.new({"text": "x", "counts": "bonus_damage"}, "deed", errors))
	assert_false(errors.is_empty(), "bonus_damage names its passive")
	errors.clear()
	DeedDef.read(DataReader.new({"text": "x", "counts": "damage", "from_part": "reaction"}, "deed", errors))
	assert_false(errors.is_empty(), "only bonus_damage names one")
	errors.clear()
	var kit: UnitDef = UnitDef.read(DataReader.new({"id": "capped", "name": "Capped", "stats": {"hp": 10}, "shard_cap": 3,
		"basic_attack": {"id": "a", "name": "A", "cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}}, "kit", errors))
	assert_eq(errors, [] as Array[String])
	assert_eq([kit.shard_cap, kit.copy().shard_cap], [3, 3])
	var patch: KitPatch = KitPatch.read(DataReader.new({"shard_cap": 8}, "patch", errors))
	assert_eq(errors, [] as Array[String])
	assert_eq(patch.apply(kit, errors).shard_cap, 8)


func test_brewing_vials_take_turns_and_ride_the_next_toss() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_thrower(BREWING), 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	K.step(fight, 13 * 20)
	var burns: Array[LogEntry] = _applied(fight, "burn")
	var poisons: Array[LogEntry] = _applied(fight, "poison")
	assert_eq([burns.size(), poisons.size()], [2, 1], "fire at 4s, venom at 8s, fire at 12s")
	assert_true(burns[0].tick > 80 and burns[0].tick < poisons[0].tick and poisons[0].tick < burns[1].tick, "in turn: fire first")
	assert_true(burns.all(func(entry: LogEntry) -> bool: return entry.source_ability == "brewing"), "sourced to Brewing")
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "thrower").size(), 12, "a Toss a second, the vials riding on them")
	var thrower: UnitState = fight.unit_by_id("thrower")
	assert_null(Statuses.find(thrower, "fire_vial"), "each vial spent")


func test_with_nothing_in_reach_no_vial_flies() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_thrower(BREWING), 0, 0)] as Array[UnitSetup], [K.foe(_dummy("mark"), 7, 6)] as Array[UnitSetup]))
	K.step(fight, 9 * 20)
	assert_eq(_applied(fight, "burn").size() + _applied(fight, "poison").size(), 0, "nothing thrown")
	var thrower: UnitState = fight.unit_by_id("thrower")
	assert_eq([Statuses.stacks_on(thrower, "fire_vial"), Statuses.stacks_on(thrower, "venom_vial")], [1, 1], "both vials wait")
	fight.unit_by_id("mark").pos = thrower.pos + Vector2i(0, 2000)
	K.step(fight, 30)
	var burns: Array[LogEntry] = _applied(fight, "burn")
	var poisons: Array[LogEntry] = _applied(fight, "poison")
	assert_eq([burns.size(), poisons.size()], [1, 1], "the next Toss carries both")
	assert_eq(burns[0].tick, poisons[0].tick)


func test_a_vial_is_spent_once_for_its_passive() -> void:
	var twice: Array = [{"id": "vial", "name": "Vial", "kind": "ability", "effects": [
		{"trigger": "on_interval", "interval_ms": 1000, "once": true, "type": "apply_status", "status": "fire_vial", "target": "self"},
		{"trigger": "on_holder_hit", "from_ability": ["toss"], "spends": "fire_vial", "type": "apply_status", "status": "burn", "stacks": 5, "target": "hit_target"},
		{"trigger": "on_holder_hit", "from_ability": ["toss"], "spends": "fire_vial", "type": "damage", "amount": 7, "target": "hit_target"}]},
		{"id": "other", "name": "Other", "kind": "ability", "effects": [
		{"trigger": "on_holder_hit", "from_ability": ["toss"], "spends": "fire_vial", "type": "apply_status", "status": "poison", "stacks": 5, "target": "hit_target"}]}]
	var fight: CombatSim = K.sim(K.fight([K.at(_thrower(twice), 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	K.step(fight, 3 * 20)
	assert_eq(_applied(fight, "burn").size(), 1, "the vial's passive runs every effect that spends it")
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "thrower").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "vial").size(), 1)
	assert_eq(_applied(fight, "poison").size(), 0, "another passive finds it spent")


func test_reaction_counts_both_stacks_per_five_up_to_a_cap() -> void:
	var reaction: Array = [{"id": "reaction", "name": "Reaction", "kind": "aura", "aura": {"target": "holder", "stat": "damage_bp", "value": 10100,
		"per_target_stacks": ["burn", "poison"], "per_stacks": 5, "cap_bp": 1000}}]
	var fight: CombatSim = K.sim(K.fight([K.at(_thrower(reaction), 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	K.step(fight, 1)
	var thrower: UnitState = fight.unit_by_id("thrower")
	var mark: UnitState = fight.unit_by_id("mark")
	var source: EffectSource = EffectSource.relic("ember", "Ember", EffectSource.Team.HEROES)
	Statuses.apply(fight, mark, "burn", 12, 0, source)
	assert_eq(Passives.vs_bonus_bp(thrower, mark), 200, "12 Burn: +1% for each 5")
	Statuses.apply(fight, mark, "poison", 9, 0, source)
	assert_eq(Passives.vs_bonus_bp(thrower, mark), 400, "12 Burn and 9 Poison, added: 21")
	Statuses.apply(fight, mark, "poison", 200, 0, source)
	assert_eq(Passives.vs_bonus_bp(thrower, mark), 1000, "up to +10%")


func test_damage_per_stack_reads_several_statuses() -> void:
	var errors: Array[String] = []
	var flask: EffectDef = EffectDef.read(DataReader.new({"type": "damage", "amount": 0, "amount_per_stack": {"status": ["burn", "poison"], "per": 3}, "target": "target"}, "effect", errors))
	assert_eq(errors, [] as Array[String])
	var fight: CombatSim = K.sim(K.fight([K.at(_dummy("hero"), 0, 0)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	var mark: UnitState = fight.unit_by_id("mark")
	var source: EffectSource = EffectSource.relic("ember", "Ember", EffectSource.Team.HEROES)
	Statuses.apply(fight, mark, "burn", 10, 0, source)
	Statuses.apply(fight, mark, "poison", 4, 0, source)
	assert_eq(EffectRunner.per_stack(flask, mark, 50), 50 + 3 * 14, "3 for each Burn and Poison")
	assert_eq([Statuses.stacks_on(mark, "burn"), Statuses.stacks_on(mark, "poison")], [10, 4], "read, not spent")


func test_bonus_damage_counts_what_the_passive_added() -> void:
	var reaction: Array = [{"id": "reaction", "name": "Reaction", "kind": "aura", "aura": {"target": "holder", "stat": "damage_bp", "value": 12500, "per_target_stacks": ["fire_vial", "venom_vial"]}},
		{"id": "sharp", "name": "Sharp", "kind": "aura", "aura": {"target": "holder", "stat": "damage_bp", "value": 15000}}]
	var setup: UnitSetup = K.at(_thrower(reaction), 3, 2)
	var errors: Array[String] = []
	setup.tally_keys.append("reaction")
	setup.tally_counts.append(DeedDef.read(DataReader.new({"text": "x", "counts": "bonus_damage", "from_part": "reaction"}, "count", errors)))
	assert_eq(errors, [] as Array[String])
	var fight: CombatSim = K.sim(K.fight([setup] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	var mark: UnitState = fight.unit_by_id("mark")
	var source: EffectSource = EffectSource.relic("ember", "Ember", EffectSource.Team.HEROES)
	Statuses.apply(fight, mark, "fire_vial", 1, 0, source)
	Statuses.apply(fight, mark, "venom_vial", 1, 0, source)
	K.step(fight, 3 * 20)
	var hits: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "thrower")
	assert_gt(hits.size(), 0)
	assert_eq([hits[0].amount, hits[0].part_bonus], [200, 50], "100 x (1 + 0.5 + 0.5): Reaction's two stacks added 50 of it")
	assert_eq(CombatSim.result_of(fight).tally_amount("thrower", "reaction"), 50 * hits.size())


func test_all_statuses_needs_every_one() -> void:
	var both: UnitCondition = _condition({"all_statuses": ["burn", "poison"]})
	var fight: CombatSim = K.sim(K.fight([K.at(_dummy("hero"), 0, 0)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	var mark: UnitState = fight.unit_by_id("mark")
	var source: EffectSource = EffectSource.relic("ember", "Ember", EffectSource.Team.HEROES)
	Statuses.apply(fight, mark, "burn", 10, 0, source)
	assert_false(both.holds(mark), "Burning only")
	Statuses.apply(fight, mark, "poison", 10, 0, source)
	assert_true(both.holds(mark), "Burning and Poisoned")
	assert_eq(both.describe(), "Burn and Poison")


func test_a_shard_cap_logs_the_rest_as_capped() -> void:
	var gather: Array = [{"id": "gather", "name": "Gather", "kind": "ability", "effects": [{"trigger": "on_interval", "interval_ms": 1000, "type": "shards", "amount": 2, "target": "self"}]}]
	var setup: UnitSetup = K.at(_thrower(gather, {"shard_cap": 3}), 3, 2)
	var errors: Array[String] = []
	setup.tally_keys.append("shards")
	setup.tally_counts.append(DeedDef.read(DataReader.new({"text": "x", "counts": "shards"}, "count", errors)))
	var fight: CombatSim = K.sim(K.fight([setup] as Array[UnitSetup], [K.foe(_dummy("mark", 50000), 3, 4)] as Array[UnitSetup]))
	K.step(fight, 3 * 20 + 1)
	var lines: Array[LogEntry] = K.entries(fight, LogEntry.Kind.SHARDS, "thrower")
	assert_eq(lines.map(func(entry: LogEntry) -> Array: return [entry.amount, entry.capped]), [[2, false], [1, false], [1, true], [2, true]],
		"2, then 1 of 2 up to the cap, then nothing paid")
	assert_true(lines[2].to_text().contains("capped"))
	assert_eq(CombatSim.result_of(fight).tally_amount("thrower", "shards"), 3, "the deed counts what was paid")


func test_a_card_quickens_both_vials() -> void:
	var errors: Array[String] = []
	var mod: KitMod = KitMod.read(DataReader.new({"on": [{"slot": "passive:brewing", "cooldown_bp": 7500}]}, "mod", errors))
	assert_eq(errors, [] as Array[String])
	var quick: UnitDef = mod.apply(_thrower(BREWING), errors)
	assert_eq(errors, [] as Array[String])
	var effects: Array[EffectDef] = quick.passives[0].ability.effects
	assert_eq([effects[0].interval_ticks, effects[0].first_ticks, effects[1].interval_ticks, effects[1].first_ticks], [120, 60, 120, 0], "every 3s, the first at 3s")


func test_to_smaller_of_raises_whichever_is_smaller() -> void:
	var errors: Array[String] = []
	var even: EffectDef = EffectDef.read(DataReader.new({"type": "apply_status", "to_smaller_of": ["burn", "poison"], "larger_share_bp": 2000, "target": "target"}, "effect", errors))
	assert_eq(errors, [] as Array[String])
	assert_false(_effect({"type": "apply_status", "to_smaller_of": ["burn"], "target": "target"}).is_empty(), "two or more")
	var fight: CombatSim = K.sim(K.fight([K.at(_dummy("hero"), 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	var hero: UnitState = fight.unit_by_id("hero")
	var mark: UnitState = fight.unit_by_id("mark")
	var source: EffectSource = EffectSource.make("hero", "solvent", "Solvent")
	Statuses.apply(fight, mark, "burn", 30, 0, source)
	EffectRunner.land(fight, hero, null, source, even, mark, 1, false)
	assert_eq([Statuses.stacks_on(mark, "burn"), Statuses.stacks_on(mark, "poison")], [30, 6], "Poison, the smaller, by 20% of the Burn")
	var one: EffectDef = EffectDef.read(DataReader.new({"type": "apply_status", "to_smaller_of": ["burn", "poison"], "stacks": 1, "target": "target"}, "effect", errors))
	EffectRunner.land(fight, hero, null, source, one, mark, 1, false)
	assert_eq(Statuses.stacks_on(mark, "poison"), 7, "1 to the smaller")


func test_a_signature_costs_less_under_signature_cost_bp() -> void:
	var cheap: UnitDef = K.kit("caster", {"stats": {"hp": 1000, "speed": 0, "range": 4}, "mana": {"max": 100, "per_attack": 0},
		"signature": {"id": "spark", "name": "Spark", "trigger": {"kind": "mana"}, "targeting": "self", "effects": [{"type": "shield", "amount": 1, "target": "self"}]},
		"passives": [{"id": "flood", "name": "Flood", "kind": "aura", "aura": {"target": "holder", "stat": "signature_cost_bp", "value": 7000}}]})
	var fight: CombatSim = K.sim(K.fight([K.at(cheap, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 6)] as Array[UnitSetup]))
	var unit: UnitState = fight.unit_by_id("caster")
	K.step(fight, 1)
	assert_eq(Mana.cost(unit), 70 * Mana.SCALE, "30% less")
	unit.mana = 80 * Mana.SCALE
	K.step(fight, 2)
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE, "caster").size(), 1, "70 of 100 is enough")
	assert_eq(unit.mana, 10 * Mana.SCALE, "and the rest stays")


func test_others_leaves_out_the_holder() -> void:
	var others: UnitCondition = _condition({"others": true})
	var giver: UnitDef = K.kit("giver", {"stats": {"hp": 1000, "speed": 0, "range": 4}, "mana": {"max": 50, "per_attack": 0},
		"signature": {"id": "elixir", "name": "Elixir", "trigger": {"kind": "mana"}, "targeting": "self",
			"effects": [{"type": "gain_mana", "amount": 50, "target": "all_allies", "only": {"others": true}}]}})
	var drinker: UnitDef = K.kit("hero", {"stats": {"hp": 1000, "speed": 0, "range": 1}, "mana": {"max": 100, "per_attack": 0},
		"signature": {"id": "spark", "name": "Spark", "trigger": {"kind": "mana"}, "targeting": "self", "effects": [{"type": "shield", "amount": 1, "target": "self"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(giver, 3, 2), K.at(drinker, 1, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 6)] as Array[UnitSetup]))
	var unit: UnitState = fight.unit_by_id("giver")
	assert_false(others.holds(unit, unit))
	assert_true(others.holds(fight.unit_by_id("hero"), unit))
	assert_eq(others.describe(), "another")
	unit.mana = 50 * Mana.SCALE
	K.step(fight, 2)
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE, "giver").size(), 1)
	assert_eq(unit.mana, 0, "nothing back for the giver, so no second cast")
	assert_eq(K.entries(fight, LogEntry.Kind.MANA_GIVEN, "giver").map(func(entry: LogEntry) -> String: return entry.target), ["hero"])


func test_recover_ms_holds_a_full_bar() -> void:
	var errors: Array[String] = []
	var trigger: TriggerDef = TriggerDef.read(DataReader.new({"kind": "mana", "recover_ms": 2000}, "trigger", errors))
	assert_eq([errors, trigger.recover_ticks], [[] as Array[String], 40])
	var caster: UnitDef = K.kit("caster", {"stats": {"hp": 1000, "speed": 0, "range": 4}, "mana": {"max": 50, "per_attack": 0},
		"signature": {"id": "spark", "name": "Spark", "trigger": {"kind": "mana", "recover_ms": 2000}, "targeting": "self", "effects": [{"type": "shield", "amount": 1, "target": "self"}]}})
	assert_eq(UnitInfo.trigger_text(caster.signature.trigger, caster), "At 50 mana, at most every 2s")
	var fight: CombatSim = K.sim(K.fight([K.at(caster, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 6)] as Array[UnitSetup]))
	var unit: UnitState = fight.unit_by_id("caster")
	unit.mana = 50 * Mana.SCALE
	K.step(fight, 2)
	assert_eq(_sparks(fight), 1)
	unit.mana = 50 * Mana.SCALE
	K.step(fight, 30)
	assert_eq(_sparks(fight), 1, "full, but it waits")
	K.step(fight, 12)
	assert_eq(_sparks(fight), 2, "2s after the first")


func _sparks(fight: CombatSim) -> int:
	return K.entries(fight, LogEntry.Kind.FIRE, "caster").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "spark").size()
