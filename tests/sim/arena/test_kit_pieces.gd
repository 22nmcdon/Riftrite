extends GutTest
## The sim pieces phase 2's kits need (docs/plans/rebuild-phase2-heroes-enemies.md,
## section 4): an aura that holds while its holder is taunting, the
## on_ally_below_hp, on_interval, and on_fall passive triggers, areas in
## passives, heals of a share of max HP, and damage that grows with nearby
## allies.

const K = preload("res://tests/sim/sim_test_kit.gd")


## A unit that stands still and barely fights: speed 0, range 2, and a
## 0-damage attack once a minute.
func _still(unit_id: String, stats: Dictionary = {}, passives: Array = [], extra: Dictionary = {}) -> UnitDef:
	var all_stats: Dictionary = {"hp": 1000, "atk": 10, "speed": 0, "range": 2}
	all_stats.merge(stats, true)
	var data: Dictionary = {"stats": all_stats, "passives": passives,
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}
	data.merge(extra, true)
	return K.kit(unit_id, data)


func _ability(part_id: String, effects: Array) -> Dictionary:
	return {"id": part_id, "name": part_id.capitalize(), "kind": "ability", "effects": effects}


func _def(unit: UnitState) -> int:
	return unit.stats.get_stat(UnitStats.Stat.DEF)


func _entries(fight: CombatSim, kind: LogEntry.Kind, unit_id: String) -> Array:
	return K.entries(fight, kind, unit_id).map(func(entry: LogEntry) -> Array: return [entry.tick, entry.target, entry.amount])


func _all_from_event(fight: CombatSim, unit_id: String) -> bool:
	var found: Array[LogEntry] = K.entries(fight, LogEntry.Kind.HEAL, unit_id) + K.entries(fight, LogEntry.Kind.SHIELD, unit_id) \
		+ K.entries(fight, LogEntry.Kind.DAMAGE, unit_id) + K.entries(fight, LogEntry.Kind.AREA_LANDED, unit_id)
	return found.all(func(entry: LogEntry) -> bool: return entry.from_event or entry.source_ability.ends_with("_attack"))


# --- reading ---------------------------------------------------------------------------

func test_reading_the_new_pieces() -> void:
	var errors: Array[String] = []
	var aura: AuraDef = AuraDef.read(DataReader.new({"target": "holder", "stat": "def_bp", "value": 15000, "while": "taunting"}, "aura", errors))
	assert_true(aura.while_taunting)
	assert_eq(aura.describe(), "x1.5 DEF for its holder while taunting")
	assert_false(AuraDef.read(DataReader.new({"target": "holder", "stat": "def_bp", "value": 15000}, "aura", errors)).while_taunting)
	var heal: EffectDef = EffectDef.read(DataReader.new({"type": "heal", "amount_bp_of_max_hp": 500, "target": "self"}, "e", errors))
	assert_eq([heal.amount, heal.amount_bp_of_max_hp], [0, 500])
	var pup: EffectDef = EffectDef.read(DataReader.new({"type": "damage", "amount": 8, "target": "target",
		"bonus_per_ally": {"bp": 2500, "within_hexes": 2, "kit": "pup"}}, "e", errors))
	assert_eq([pup.bonus_bp_per_ally, pup.bonus_within, pup.bonus_kit], [2500, 2000, "pup"])
	var any_ally: EffectDef = EffectDef.read(DataReader.new({"type": "damage", "amount": 8, "target": "target",
		"bonus_per_ally": {"bp": 1000, "within_hexes": 1}}, "e", errors))
	assert_eq([any_ally.bonus_bp_per_ally, any_ally.bonus_within, any_ally.bonus_kit], [1000, 1000, ""])
	var part: PartDef = PartDef.read(DataReader.new(_ability("kit", [
		{"trigger": "on_interval", "interval_ms": 3000, "type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "self", "hits": "other_allies",
			"effects": [{"type": "heal", "amount_bp_of_max_hp": 500, "target": "target"}]},
		{"trigger": "on_ally_below_hp", "threshold_bp": 5000, "type": "shield", "amount": 40, "target": "trigger_ally"},
		{"trigger": "on_fall", "type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "self", "hits": "all",
			"effects": [{"type": "damage", "amount": 20, "target": "target"}]},
		{"trigger": "on_fall", "type": "damage", "amount": 5, "target": "all_enemies"},
		{"trigger": "on_hit_taken", "type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "target", "hits": "enemies",
			"effects": [{"type": "damage", "amount": 3, "target": "target"}]}]), "part", errors))
	assert_eq(errors, [] as Array[String])
	assert_eq(part.ability.effects.map(func(effect: EffectDef) -> int: return effect.trigger),
		[EffectDef.Trigger.ON_INTERVAL, EffectDef.Trigger.ON_ALLY_BELOW_HP, EffectDef.Trigger.ON_FALL, EffectDef.Trigger.ON_FALL, EffectDef.Trigger.ON_HIT_TAKEN])
	assert_eq(part.ability.effects[0].interval_ticks, 60)
	assert_eq(part.ability.effects[0].hits, EffectDef.Hits.OTHER_ALLIES)


func test_the_new_pieces_refuse_what_cant_work() -> void:
	var area: Dictionary = {"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "self", "hits": "all", "effects": [{"type": "damage", "amount": 1, "target": "target"}]}
	var cases: Dictionary = {
		"while: unknown value \"raging\"": ["aura", {"target": "holder", "stat": "def_bp", "value": 15000, "while": "raging"}],
		"heal needs exactly one of \"amount\" or \"amount_bp_of_max_hp\"": ["effect", {"type": "heal", "target": "self"}],
		"heal needs exactly one of": ["effect", {"type": "heal", "amount": 5, "amount_bp_of_max_hp": 500, "target": "self"}],
		"amount_bp_of_max_hp": ["effect", {"type": "heal", "amount_bp_of_max_hp": 10001, "target": "self"}],
		"\"scaling\" can't be combined with amount_bp_of_max_hp": ["effect", {"type": "heal", "amount_bp_of_max_hp": 500, "target": "self", "scaling": {"mgk": 10000}}],
		"within_hexes": ["effect", {"type": "damage", "amount": 5, "target": "target", "bonus_per_ally": {"bp": 2500}}],
		"range": ["effect", {"type": "damage", "amount": 5, "target": "target", "bonus_per_ally": {"bp": 2500, "within_hexes": 1, "range": 2}}],
		"interval_ms": ["part", _ability("a", [{"trigger": "on_interval", "type": "shield", "amount": 5, "target": "self"}])],
		"on_interval names no unit, so it can't use hit_target": ["part", _ability("b", [{"trigger": "on_interval", "interval_ms": 1000, "type": "damage", "amount": 5, "target": "hit_target"}])],
		"on_fall names no hit, so it can't use amount_bp_of_damage": ["part", _ability("c", [{"trigger": "on_fall", "type": "shield", "amount_bp_of_damage": 5000, "target": "all_allies"}])],
		"on_fall runs once the unit has fallen, so it can't aim at \"self\"": ["part", _ability("d", [{"trigger": "on_fall", "type": "heal", "amount": 5, "target": "self"}])],
		"on_fall runs once the unit has fallen, so its area is anchored on it": ["part", _ability("e", [{"trigger": "on_fall", "type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "target", "hits": "all",
			"effects": [{"type": "damage", "amount": 1, "target": "target"}]}])],
		"an area is cast as its ability fires or on a passive's trigger, never on_hit or on_crit": ["effect", area.merged({"trigger": "on_crit"})],
		"\"trigger_ally\" only works with the on_ally_below_hp trigger": ["part", _ability("f", [{"trigger": "on_interval", "interval_ms": 1000, "type": "heal", "amount": 5, "target": "trigger_ally"}])],
		"a passive's effects need a passive trigger": ["part", _ability("g", [{"type": "heal", "amount": 5, "target": "self"}])],
	}
	for expected: String in cases:
		var errors: Array[String] = []
		var reader := DataReader.new(cases[expected][1], "x", errors)
		match cases[expected][0]:
			"aura":
				AuraDef.read(reader)
			"effect":
				EffectDef.read(reader)
			"part":
				PartDef.read(reader)
		assert_true(errors.any(func(message: String) -> bool: return message.contains(expected)), "expected '%s' in %s" % [expected, errors])


# --- an aura while taunting (Hold the Line) ---------------------------------------

func test_an_aura_while_taunting_follows_the_holders_own_taunts() -> void:
	var keeper: UnitDef = _still("keeper", {"def": 20}, [{"id": "stand", "name": "Stand", "kind": "aura",
		"aura": {"target": "holder", "stat": "def_bp", "value": 15000, "while": "taunting"}}])
	var fight: CombatSim = K.sim(K.fight([K.at(keeper, 3, 2), K.at(_still("other"), 1, 2)] as Array[UnitSetup],
		[K.foe(_still("foe_a"), 3, 4), K.foe(_still("foe_b"), 5, 4)] as Array[UnitSetup]))
	var hero: UnitState = fight.unit_by_id("keeper")
	var foe_a: UnitState = fight.unit_by_id("foe_a")
	var foe_b: UnitState = fight.unit_by_id("foe_b")
	var from_keeper: EffectSource = EffectSource.make("keeper", "hold", "Hold the Line")
	assert_true(fight.taunt_auras)
	assert_eq(_def(hero), 20, "off until it taunts")
	Statuses.apply(fight, foe_a, "taunt", 0, 40, from_keeper)
	assert_eq(_def(hero), 30, "on once its Taunt lands")
	Statuses.apply(fight, foe_a, "taunt", 0, 100, EffectSource.make("other", "jeer", "Jeer"))
	assert_eq(_def(hero), 20, "another unit's newer Taunt takes foe_a over")
	Statuses.apply(fight, foe_b, "taunt", 0, 40, from_keeper)
	assert_eq(_def(hero), 30)
	K.step(fight, 39)
	assert_eq(_def(hero), 30, "on while the Taunt lasts")
	K.step(fight, 1)
	assert_eq(_def(hero), 20, "off as the Taunt runs out")
	Statuses.apply(fight, foe_b, "taunt", 0, 400, from_keeper)
	K.step(fight, 300)
	assert_eq(_def(hero), 30, "a longer Taunt keeps it on longer")
	foe_b.hp = 0
	K.step(fight, 1)
	assert_false(foe_b.alive)
	assert_eq(_def(hero), 20, "off once the taunted unit falls")
	var notes: Array = K.entries(fight, LogEntry.Kind.AURA, "keeper").map(func(entry: LogEntry) -> Array: return [entry.tick, entry.note])
	assert_eq(notes, [[0, "starts: x1.5 DEF for its holder while taunting"], [0, "ends"], [0, "starts: x1.5 DEF for its holder while taunting"],
		[40, "ends"], [40, "starts: x1.5 DEF for its holder while taunting"], [341, "ends"]])


func test_a_fight_without_taunting_auras_never_refolds_on_taunts() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_still("keeper"), 3, 2)] as Array[UnitSetup], [K.foe(_still("foe"), 3, 4)] as Array[UnitSetup]))
	assert_false(fight.taunt_auras)


# --- on_ally_below_hp (Hearthguard) ---------------------------------------------------

func _guard(once: bool = false) -> Dictionary:
	var effect: Dictionary = {"trigger": "on_ally_below_hp", "threshold_bp": 5000, "type": "shield", "amount": 50, "target": "trigger_ally"}
	if once:
		effect["once"] = true
	return _ability("hearthguard", [effect])


func test_on_ally_below_hp_runs_once_for_each_ally_but_never_for_its_holder() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_still("guard", {}, [_guard()]), 3, 2), K.at(_still("ally_a"), 1, 2), K.at(_still("ally_b"), 5, 2),
		K.at(_still("ally_c"), 6, 1)] as Array[UnitSetup], [K.foe(_still("foe"), 3, 6)] as Array[UnitSetup]))
	var guard: UnitState = fight.unit_by_id("guard")
	var ally_a: UnitState = fight.unit_by_id("ally_a")
	var ally_b: UnitState = fight.unit_by_id("ally_b")
	var ally_c: UnitState = fight.unit_by_id("ally_c")
	assert_true(fight._timed_passives)
	K.step(fight, 1)
	ally_a.hp = 400
	ally_b.hp = 500
	K.step(fight, 1)
	assert_eq(_entries(fight, LogEntry.Kind.SHIELD, "guard"), [[2, "ally_a", 50]], "ally_b at exactly half isn't below it")
	ally_a.hp = 100
	guard.hp = 100
	K.step(fight, 1)
	assert_eq(_entries(fight, LogEntry.Kind.SHIELD, "guard").size(), 1, "once per ally, and never for itself")
	ally_b.hp = 499
	ally_c.hp = 0
	K.step(fight, 1)
	assert_eq(_entries(fight, LogEntry.Kind.SHIELD, "guard"), [[2, "ally_a", 50], [4, "ally_b", 50]], "an ally at 0 HP is falling, not below")
	assert_false(ally_c.alive)
	assert_eq(ally_a.shield, 50)
	assert_true(K.entries(fight, LogEntry.Kind.SHIELD, "guard").all(func(entry: LogEntry) -> bool: return entry.from_event and entry.source_ability == "hearthguard"))


func test_on_ally_below_hp_once_runs_for_the_first_ally_in_the_fights_order() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_still("guard", {}, [_guard(true)]), 3, 2), K.at(_still("ally_a"), 1, 2), K.at(_still("ally_b"), 5, 2)] as Array[UnitSetup],
		[K.foe(_still("foe"), 3, 6)] as Array[UnitSetup]))
	fight.unit_by_id("ally_b").hp = 100
	fight.unit_by_id("ally_a").hp = 100
	K.step(fight, 3)
	assert_eq(_entries(fight, LogEntry.Kind.SHIELD, "guard"), [[1, "ally_a", 50]])


func test_a_phase_keeps_the_allies_on_ally_below_hp_has_run_for() -> void:
	var warden: UnitDef = _still("warden", {}, [_guard()], {"phases": [{"id": "wake", "name": "Wake", "below_hp_bp": 5000, "targeting": "farthest"}]})
	var fight: CombatSim = K.sim(K.fight([K.at(_still("hero"), 3, 0)] as Array[UnitSetup],
		[K.foe(warden, 3, 6), K.foe(_still("ally"), 1, 6)] as Array[UnitSetup]))
	fight.unit_by_id("ally").hp = 100
	K.step(fight, 1)
	fight.unit_by_id("warden").hp = 400
	K.step(fight, 3)
	assert_eq(K.entries(fight, LogEntry.Kind.PHASE, "warden").size(), 1)
	assert_eq(_entries(fight, LogEntry.Kind.SHIELD, "warden"), [[1, "ally", 50]])


# --- on_interval, other_allies, and heals of max HP (Hearthlight) ---------------------

func _hearthlight() -> Dictionary:
	return _ability("hearthlight", [{"trigger": "on_interval", "interval_ms": 1000, "type": "area", "shape": {"kind": "circle", "radius": 1},
		"anchor": "self", "hits": "other_allies", "effects": [{"type": "heal", "amount_bp_of_max_hp": 500, "target": "target"}]}])


func test_on_interval_heals_the_allies_around_it_by_their_max_hp() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_still("light", {}, [_hearthlight()]), 3, 1), K.at(_still("near"), 3, 2),
		K.at(_still("big", {"hp": 2000}), 3, 0), K.at(_still("far"), 6, 1)] as Array[UnitSetup], [K.foe(_still("foe"), 3, 6)] as Array[UnitSetup]))
	for unit: UnitState in fight.heroes:
		unit.hp = 100
	K.step(fight, 19)
	assert_eq(_entries(fight, LogEntry.Kind.HEAL, "light"), [])
	K.step(fight, 21)
	assert_eq(_entries(fight, LogEntry.Kind.HEAL, "light"), [[20, "near", 50], [20, "big", 100], [40, "near", 50], [40, "big", 100]],
		"every second, 5% of each ally's own max HP; not the healer, nor an ally out of reach")
	assert_eq(fight.unit_by_id("light").hp, 100)
	assert_eq(fight.unit_by_id("far").hp, 100)
	assert_eq(K.entries(fight, LogEntry.Kind.AREA_LANDED, "light").size(), 2)
	assert_true(_all_from_event(fight, "light"))
	fight.unit_by_id("light").hp = 0
	K.step(fight, 41)
	assert_false(fight.unit_by_id("light").alive)
	assert_eq(K.entries(fight, LogEntry.Kind.AREA_LANDED, "light").size(), 2, "a fallen unit's on_interval stops")


func test_a_heal_of_max_hp_takes_the_healers_heal_auras() -> void:
	var light: UnitDef = _still("light", {}, [_hearthlight(), {"id": "warmth", "name": "Warmth", "kind": "aura", "aura": {"target": "holder", "stat": "heal_bp", "value": 15000}}])
	var fight: CombatSim = K.sim(K.fight([K.at(light, 3, 1), K.at(_still("near"), 3, 2)] as Array[UnitSetup], [K.foe(_still("foe"), 3, 6)] as Array[UnitSetup]))
	fight.unit_by_id("near").hp = 100
	K.step(fight, 20)
	assert_eq(_entries(fight, LogEntry.Kind.HEAL, "light"), [[20, "near", 75]])


func test_on_interval_counts_from_when_a_summon_joins() -> void:
	var ember: UnitDef = _still("ember", {}, [_ability("glow", [{"trigger": "on_interval", "interval_ms": 1000, "type": "shield", "amount": 5, "target": "self"}])])
	var caller: UnitDef = _still("caller", {}, [], {"signature": {"id": "call", "name": "Call", "trigger": {"kind": "at_time", "at_ms": 500}, "targeting": "self",
		"effects": [{"type": "summon", "kit": "ember", "placement": "adjacent"}]}})
	var setup: FightSetup = K.fight([K.at(_still("hero"), 3, 0)] as Array[UnitSetup], [K.foe(caller, 3, 6)] as Array[UnitSetup])
	setup.summon_kits.append(ember)
	var fight: CombatSim = K.sim(setup)
	assert_false(fight._timed_passives)
	K.step(fight, 60)
	assert_eq(fight.unit_by_id("ember").joined_at, 10)
	assert_true(fight._timed_passives)
	assert_eq(_entries(fight, LogEntry.Kind.SHIELD, "ember").map(func(row: Array) -> int: return row[0]), [30, 50])


# --- bonus_per_ally (Rift Pup) ----------------------------------------------------

func test_damage_grows_with_each_nearby_ally_of_the_kit() -> void:
	var bite: Dictionary = {"cooldown_ms": 1000, "shot": false, "effects": [{"type": "damage", "amount": 20, "target": "target",
		"bonus_per_ally": {"bp": 2500, "within_hexes": 1, "kit": "pup"}}]}
	var pup: UnitDef = _still("pup", {}, [], {"basic_attack": bite})
	var fight: CombatSim = K.sim(K.fight([K.at(_still("hero"), 3, 2)] as Array[UnitSetup],
		[K.foe(pup, 3, 4, "pup_a"), K.foe(pup, 3, 5, "pup_b"), K.foe(pup, 3, 6, "pup_c"), K.foe(_still("wolf"), 4, 4)] as Array[UnitSetup]))
	var effect: EffectDef = pup.basic_attack.effects[0]
	var pup_a: UnitState = fight.unit_by_id("pup_a")
	var pup_b: UnitState = fight.unit_by_id("pup_b")
	assert_eq(EffectRunner.amount_of(effect, pup_a, 0, fight), 25, "pup_b is a hex away; pup_c two; the wolf isn't a pup")
	assert_eq(EffectRunner.amount_of(effect, pup_b, 0, fight), 30)
	assert_eq(EffectRunner.amount_of(effect, pup_a), 20, "no fight, no allies")
	K.step(fight, 20)
	assert_eq(_entries(fight, LogEntry.Kind.DAMAGE, "pup_a"), [[20, "hero", 25]], "as it attacks, too")
	fight.unit_by_id("pup_c").alive = false
	assert_eq(EffectRunner.amount_of(effect, pup_b, 0, fight), 25, "a fallen pup doesn't count")
	var any_kit: EffectDef = EffectDef.read(DataReader.new({"type": "damage", "amount": 20, "target": "target",
		"bonus_per_ally": {"bp": 2500, "within_hexes": 1}}, "e", [] as Array[String]))
	assert_eq(EffectRunner.amount_of(any_kit, pup_a, 0, fight), 30, "without a kit, the wolf counts too")


# --- on_fall (Ashling's Cinder Burst) ---------------------------------------------

func test_on_fall_bursts_from_where_the_unit_fell_and_can_fell_others() -> void:
	var burst: Dictionary = _ability("cinder_burst", [{"trigger": "on_fall", "type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "self", "hits": "all",
		"effects": [{"type": "damage", "amount": 30, "target": "target"}]}])
	var fight: CombatSim = K.sim(K.fight([K.at(_still("hero"), 3, 2)] as Array[UnitSetup],
		[K.foe(_still("victim", {"hp": 30}), 4, 4), K.foe(_still("ashling", {}, [burst]), 3, 4, "ash_a"), K.foe(_still("ashling", {"hp": 30}, [burst]), 3, 5, "ash_b"),
			K.foe(_still("bystander"), 3, 6)] as Array[UnitSetup]))
	var hero: UnitState = fight.unit_by_id("hero")
	hero.pos = fight.grid.center(3, 3)
	K.step(fight, 1)
	fight.unit_by_id("ash_a").hp = 0
	K.step(fight, 1)
	assert_eq(K.entries(fight, LogEntry.Kind.DEATH).map(func(entry: LogEntry) -> Array: return [entry.tick, entry.target]), [[2, "ash_a"], [2, "ash_b"], [2, "victim"]],
		"the deaths step goes round again for a unit its burst felled earlier in the fight's order")
	assert_eq(_entries(fight, LogEntry.Kind.DAMAGE, "ash_a").filter(func(row: Array) -> bool: return row[0] == 2), [[2, "hero", 30], [2, "victim", 30], [2, "ash_b", 30]])
	assert_eq(_entries(fight, LogEntry.Kind.DAMAGE, "ash_b").filter(func(row: Array) -> bool: return row[0] == 2), [[2, "bystander", 30]],
		"ash_b's burst doesn't hit ash_a, already fallen, or the hero, two hexes off")
	assert_eq([hero.hp, fight.unit_by_id("bystander").hp], [970, 970])
	assert_true(_all_from_event(fight, "ash_a") and _all_from_event(fight, "ash_b"))


func test_a_shot_and_an_area_leave_with_the_bonus() -> void:
	var bonus: Dictionary = {"bp": 2500, "within_hexes": 1, "kit": "pup"}
	var howl: Dictionary = _ability("howl", [{"trigger": "on_interval", "interval_ms": 1000, "type": "area", "shape": {"kind": "circle", "radius": 2}, "anchor": "self", "hits": "enemies",
		"effects": [{"type": "damage", "amount": 20, "target": "target", "bonus_per_ally": bonus}]}])
	var pup: UnitDef = _still("pup", {}, [howl], {"basic_attack": {"cooldown_ms": 1000, "shot": true, "effects": [{"type": "damage", "amount": 20, "target": "target", "bonus_per_ally": bonus}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(_still("hero"), 3, 2)] as Array[UnitSetup], [K.foe(pup, 3, 4, "pup_a"), K.foe(pup, 3, 5, "pup_b")] as Array[UnitSetup]))
	K.step(fight, 30)
	var hits: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "pup_a")
	assert_eq(hits.map(func(entry: LogEntry) -> Array: return [entry.source_ability, entry.amount]), [["howl", 25], ["pup_attack", 25]])
