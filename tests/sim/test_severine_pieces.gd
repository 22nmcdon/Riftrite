extends GutTest
## The pieces Severine's kit and paths added (phase 8 part 5, docs/plans/
## rebuild-phase8-severine-edric.md section 4), each in a small fight: a
## damage effect's own lifesteal ("lifesteal_pct"), added to its unit's
## lifesteal auras, and the aura stat lifesteal_more_bp, which multiplies
## the whole share and may be worked out per hit against some targets
## (8e-1); Engorge (lifesteal past full as max HP, capped or not; the deed
## count max_hp_gained), damage plus a share of its unit's max HP or of the
## HP it just spent, a signature's HP cost (HP_SPENT; the count hp_spent),
## the trigger hp_above, and a kit's starting HP share (8e-2a).

const K = preload("res://tests/sim/sim_test_kit.gd")


func _dummy(dummy_id: String) -> UnitDef:
	return K.kit(dummy_id, {"stats": {"hp": 1000, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


func _effect(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	EffectDef.read(DataReader.new(data, "effect", errors))
	return errors


func _aura(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	AuraDef.read(DataReader.new(data, "aura", errors))
	return errors


## A striker that hits for 100 a second with `steal_pct` lifesteal of its
## own, hurt so it can heal, beside a dummy at `hp_pct` of its HP.
func _fight(steal_pct: int, passives: Array = [], hp_pct: int = 100) -> CombatSim:
	var hit: Dictionary = {"type": "damage", "amount": 100, "target": "target"}
	if steal_pct > 0:
		hit["lifesteal_pct"] = steal_pct
	var striker: UnitDef = K.kit("striker", {"stats": {"hp": 1000, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 1000, "effects": [hit]}, "passives": passives})
	var fight: CombatSim = K.sim(K.fight([K.at(striker, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	fight.unit_by_id("striker").hp = 100
	var mark: UnitState = fight.unit_by_id("mark")
	mark.pos = fight.unit_by_id("striker").pos + Vector2i(0, 400)
	mark.hp = mark.max_hp * hp_pct / 100
	return fight


func _stolen(fight: CombatSim) -> Array:
	return K.entries(fight, LogEntry.Kind.LIFESTEAL, "striker").map(func(entry: LogEntry) -> int: return entry.amount)


func test_reading_the_pieces() -> void:
	assert_eq(_effect({"type": "damage", "amount": 10, "target": "target", "lifesteal_pct": 15}), [] as Array[String])
	assert_false(_effect({"type": "damage", "amount": 10, "target": "target", "lifesteal_pct": 15, "plain": true}).is_empty(), "a plain hit never lifesteals")
	assert_eq(_aura({"target": "holder", "stat": "lifesteal_more_bp", "value": 10000, "vs": {"below_hp_pct": 50}}), [] as Array[String])
	assert_eq(_aura({"target": "holder", "stat": "lifesteal_more_bp", "value": 10000, "from_basic": true}), [] as Array[String])


func test_a_hit_lifesteals_its_own_share() -> void:
	var fight: CombatSim = _fight(20)
	K.step(fight, 22)
	assert_eq(_stolen(fight), [20], "20% of the 100 it dealt")
	var none: CombatSim = _fight(0)
	K.step(none, 22)
	assert_eq(_stolen(none), [], "no lifesteal anywhere: none")


func test_its_share_adds_to_the_units_auras() -> void:
	var fight: CombatSim = _fight(20, [{"id": "thirst", "name": "Thirst", "kind": "aura", "aura": {"target": "holder", "stat": "lifesteal_bp", "value": 1000}}])
	K.step(fight, 22)
	assert_eq(_stolen(fight), [30], "20% and the aura's 10%")


func test_more_lifesteal_multiplies_the_share_against_some_targets() -> void:
	var more: Array = [{"id": "hemophage", "name": "Hemophage", "kind": "aura", "aura": {"target": "holder", "stat": "lifesteal_more_bp", "value": 10000, "vs": {"below_hp_pct": 50}}}]
	var healthy: CombatSim = _fight(20, more, 100)
	K.step(healthy, 22)
	assert_eq(_stolen(healthy), [20], "the target is above half its HP")
	var wounded: CombatSim = _fight(20, more, 40)
	K.step(wounded, 22)
	assert_eq(_stolen(wounded), [40], "doubled below half its HP")
	var always: CombatSim = _fight(20, [{"id": "more", "name": "More", "kind": "aura", "aura": {"target": "holder", "stat": "lifesteal_more_bp", "value": 5000}}])
	K.step(always, 22)
	assert_eq(_stolen(always), [30], "+50% on every hit")


func _tally(setup: UnitSetup, key: String, counts: String, from_ability: Array = []) -> void:
	var errors: Array[String] = []
	var data: Dictionary = {"text": "x", "counts": counts}
	if not from_ability.is_empty():
		data["from_ability"] = from_ability
	setup.tally_keys.append(key)
	setup.tally_counts.append(DeedDef.read(DataReader.new(data, "count", errors)))
	assert_eq(errors, [] as Array[String])


func _ability(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	AbilityDef.read_signature(DataReader.new(data, "signature", errors))
	return errors


func test_reading_the_path_pieces() -> void:
	assert_eq(_effect({"type": "damage", "amount": 0, "target": "target", "plus_bp_of_max_hp": 300, "plus_bp_of_spent": 20000}), [] as Array[String])
	assert_eq(_aura({"target": "holder", "stat": "lifesteal_max_hp_bp", "value": 10000}), [] as Array[String])
	assert_eq(_aura({"target": "holder", "stat": "lifesteal_max_hp_cap_bp", "value": 500}), [] as Array[String])
	assert_eq(_ability({"id": "x", "name": "X", "trigger": {"kind": "hp_above", "threshold_bp": 5000}, "hp_cost_bp": 1000,
		"effects": [{"type": "damage", "amount": 1, "target": "target"}]}), [] as Array[String])
	assert_false(_ability({"id": "x", "name": "X", "trigger": {"kind": "hp_above"}, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}).is_empty(), "it needs its line")
	assert_eq(K.kit("k", {"start_hp_pct": 50}).start_hp_bp, 5000)


## Engorge: a striker at full HP whose every hit would heal 20 past full.
func _engorged(passives: Array) -> CombatSim:
	var striker: UnitDef = K.kit("striker", {"stats": {"hp": 1000, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 1000,
		"effects": [{"type": "damage", "amount": 100, "target": "target", "lifesteal_pct": 20}]}, "passives": passives})
	var setup: UnitSetup = K.at(striker, 3, 2)
	_tally(setup, "gained", "max_hp_gained", ["engorge"])
	var fight: CombatSim = K.sim(K.fight([setup] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	fight.unit_by_id("mark").pos = fight.unit_by_id("striker").pos + Vector2i(0, 400)
	return fight


func test_engorge_turns_lifesteal_past_full_into_max_hp() -> void:
	var fight: CombatSim = _engorged([{"id": "engorge", "name": "Engorge", "kind": "aura", "aura": {"target": "holder", "stat": "lifesteal_max_hp_bp", "value": 10000}}])
	K.step(fight, 62)
	var striker: UnitState = fight.unit_by_id("striker")
	var grown: Array[LogEntry] = K.entries(fight, LogEntry.Kind.MAX_HP_UP, "striker")
	assert_eq(grown.map(func(entry: LogEntry) -> int: return entry.amount), [20, 20, 20], "all of each hit's 20 past full, three hits")
	assert_eq(grown[0].source_ability, "engorge", "sourced to the passive")
	assert_eq([striker.max_hp, striker.hp], [1060, 1060], "max HP and HP")
	assert_eq(CombatSim.result_of(fight).tally_amount("striker", "gained"), 60, "the deed counts it")


func test_engorge_stops_at_its_cap() -> void:
	var fight: CombatSim = _engorged([{"id": "engorge", "name": "Engorge", "kind": "aura", "aura": {"target": "holder", "stat": "lifesteal_max_hp_bp", "value": 10000}},
		{"id": "engorge_cap", "name": "Engorge", "kind": "aura", "aura": {"target": "holder", "stat": "lifesteal_max_hp_cap_bp", "value": 500}}])
	K.step(fight, 82)
	var grown: Array = K.entries(fight, LogEntry.Kind.MAX_HP_UP, "striker").map(func(entry: LogEntry) -> int: return entry.amount)
	assert_eq(grown, [20, 20, 10], "up to 5% of its 1,000 max HP, then nothing")
	assert_eq(fight.unit_by_id("striker").max_hp, 1050)


func test_damage_plus_a_share_of_its_own_max_hp() -> void:
	var striker: UnitDef = K.kit("striker", {"stats": {"hp": 1000, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 1000,
		"effects": [{"type": "damage", "amount": 10, "target": "target", "plus_bp_of_max_hp": 300}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(striker, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	fight.unit_by_id("mark").pos = fight.unit_by_id("striker").pos + Vector2i(0, 400)
	K.step(fight, 22)
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "striker").map(func(entry: LogEntry) -> int: return entry.amount), [40], "10 and 3% of 1,000")


## A caster whose signature costs 10% of its max HP and hits for 5 plus twice
## that, on `trigger`, starting at `start_pct` of its HP.
func _bleeder(trigger: Dictionary, start_pct: int = 100, mana: Dictionary = {}) -> CombatSim:
	var data: Dictionary = {"stats": {"hp": 1000, "speed": 0, "range": 1}, "start_hp_pct": start_pct, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]},
		"signature": {"id": "bleed_out", "name": "Bleed Out", "trigger": trigger, "hp_cost_bp": 1000,
			"effects": [{"type": "damage", "amount": 5, "target": "target", "plus_bp_of_spent": 20000}]}}
	if not mana.is_empty():
		data["mana"] = mana
	var caster: UnitDef = K.kit("caster", data)
	var setup: UnitSetup = K.at(caster, 3, 2)
	_tally(setup, "spent", "hp_spent")
	var fight: CombatSim = K.sim(K.fight([setup] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	fight.unit_by_id("mark").pos = fight.unit_by_id("caster").pos + Vector2i(0, 400)
	return fight


func test_a_kit_starts_at_a_share_of_its_hp() -> void:
	var fight: CombatSim = _bleeder({"kind": "hp_above", "threshold_bp": 9900}, 50)
	assert_eq(fight.unit_by_id("caster").hp, 500, "half its 1,000")


func test_a_signature_above_an_hp_line_fires_until_it_drops_below() -> void:
	var fight: CombatSim = _bleeder({"kind": "hp_above", "threshold_bp": 5000}, 75)
	K.step(fight, 5)
	var spent: Array = K.entries(fight, LogEntry.Kind.HP_SPENT, "caster").map(func(entry: LogEntry) -> Array: return [entry.tick, entry.amount])
	assert_eq(spent.size(), 3, "75%, 65%, 55%: three casts, then at 45% none")
	assert_eq(spent[1][0] - spent[0][0], 1, "at most once a tick")
	assert_eq(fight.unit_by_id("caster").hp, 450)
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "caster").map(func(entry: LogEntry) -> int: return entry.amount), [205, 205, 205], "5 and twice the 100 it spent")
	assert_eq(CombatSim.result_of(fight).tally_amount("caster", "spent"), 300, "the deed counts HP spent")
	assert_string_contains(K.entries(fight, LogEntry.Kind.HP_SPENT, "caster")[0].to_text(), "spends 100 HP")


func test_an_hp_cost_never_takes_it_below_1_hp() -> void:
	var fight: CombatSim = _bleeder({"kind": "mana"}, 100, {"max": 10, "start": 10, "per_attack": 0})
	var caster: UnitState = fight.unit_by_id("caster")
	caster.hp = 100
	K.step(fight, 3)
	assert_eq(K.entries(fight, LogEntry.Kind.HP_SPENT, "caster").size(), 0, "100 HP can't pay 100")
	assert_eq([caster.hp, caster.mana], [100, caster.mana_cap], "nothing paid; the bar waits, full")
	caster.hp = 101
	K.step(fight, 2)
	assert_eq(K.entries(fight, LogEntry.Kind.HP_SPENT, "caster").size(), 1)
	assert_eq(caster.hp, 1)
