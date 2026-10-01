extends GutTest
## The small sim pieces the loadout pool's frame needed (docs/plans/
## rebuild-phase5c-combos.md, step 6a, section 14.5), each in a small fight:
## on_below_hp (the unit itself, up to "times" a fight), the target
## allies_near_self (as its unit falls too), and cleanse's "statuses".

const K = preload("res://tests/sim/sim_test_kit.gd")


func _hero(passives: Array = [], hero_id: String = "hero", hp: int = 1000) -> UnitDef:
	return K.kit(hero_id, {"stats": {"hp": hp, "atk": 10, "speed": 0, "range": 2}, "passives": passives,
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


func _dummy() -> UnitDef:
	return K.kit("dummy", {"stats": {"hp": 100000, "speed": 0, "range": 2},
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


func _from_dummy() -> EffectSource:
	return EffectSource.make("dummy", "dummy_attack", "Strike")


func _read(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	PartDef.read(DataReader.new({"id": "p", "name": "P", "kind": "ability", "effects": [data]}, "part", errors))
	return errors


func test_reading_the_pieces() -> void:
	assert_eq(_read({"trigger": "on_below_hp", "threshold_bp": 5000, "times": 2, "type": "shield", "amount_bp_of_max_hp": 1500, "target": "self"}), [] as Array[String])
	assert_false(_read({"trigger": "on_below_hp", "type": "shield", "amount": 1, "target": "self"}).is_empty(), "it needs a threshold")
	assert_eq(_read({"trigger": "on_fall", "type": "shield", "amount": 1, "target": "allies_near_self", "within_hexes": 2}), [] as Array[String])
	assert_false(_read({"trigger": "on_fall", "type": "shield", "amount": 1, "target": "allies_near_self"}).is_empty(), "it needs a reach")
	assert_eq(_read({"trigger": "on_heal", "type": "cleanse", "amount_bp": 10000, "statuses": ["bleed"], "target": "hit_target"}), [] as Array[String])


func test_on_below_hp_runs_as_it_drops_below() -> void:
	var ward: Array = [{"id": "ward", "name": "Ward", "kind": "ability",
		"effects": [{"trigger": "on_below_hp", "threshold_bp": 5000, "times": 2, "type": "shield", "amount": 50, "target": "self"}]}]
	var fight: CombatSim = K.sim(K.fight([K.at(_hero(ward), 3, 2)] as Array[UnitSetup], [K.foe(_dummy(), 3, 5)] as Array[UnitSetup]))
	var hero: UnitState = fight.unit_by_id("hero")
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.SHIELD).size(), 0, "at full HP, nothing")
	hero.hp = 400
	fight.step()
	assert_eq(hero.shield, 50, "it dropped below half")
	K.step(fight, 5)
	assert_eq(K.entries(fight, LogEntry.Kind.SHIELD).size(), 1, "once for each drop")
	hero.hp = 900
	fight.step()
	hero.hp = 300
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.SHIELD).size(), 2, "healed above and dropped again: the second time")
	hero.hp = 900
	fight.step()
	hero.hp = 300
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.SHIELD).size(), 2, "twice a fight at most")


func test_allies_near_self_as_it_falls() -> void:
	var last: Array = [{"id": "last", "name": "Last", "kind": "ability",
		"effects": [{"trigger": "on_fall", "type": "shield", "amount": 40, "target": "allies_near_self", "within_hexes": 2}]}]
	var fight: CombatSim = K.sim(K.fight([K.at(_hero(last, "giver", 10), 3, 2, "giver"), K.at(_hero([], "near"), 4, 2, "near"), K.at(_hero([], "far"), 0, 0, "far")] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 5)] as Array[UnitSetup]))
	EffectRunner.deal_hit(fight, _from_dummy(), fight.unit_by_id("giver"), 100, false)
	K.step(fight, 2)
	assert_false(fight.unit_by_id("giver").alive)
	assert_eq([fight.unit_by_id("near").shield, fight.unit_by_id("far").shield], [40, 0], "within 2 hexes of where it fell")


func test_a_cleanse_of_some_statuses() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_hero(), 3, 2)] as Array[UnitSetup], [K.foe(_dummy(), 3, 5)] as Array[UnitSetup]))
	var hero: UnitState = fight.unit_by_id("hero")
	var burn := EffectDef.new()
	for status: String in ["bleed", "burn"]:
		Statuses.apply(fight, hero, status, 3, 0, _from_dummy())
	burn.type = EffectDef.Type.CLEANSE
	burn.amount = FixedMath.BP_ONE
	burn.cleanse_statuses.assign(["bleed"])
	burn.target = EffectDef.Target.TARGET
	EffectRunner.land(fight, hero, hero.def.basic_attack, EffectSource.make("hero", "hero_attack", "Strike"), burn, hero, FixedMath.BP_ONE, false)
	var left: Array = hero.statuses.map(func(state: StatusState) -> String: return state.def.id)
	assert_eq(left, ["burn"], "only Bleed is cleansed")


# --- step 6b: the charms' and sigils' pieces -----------------------------------------------

func _with(passives: Array, extra: Dictionary = {}, hero_id: String = "hero", stats: Dictionary = {}) -> UnitDef:
	var all_stats: Dictionary = {"hp": 1000, "atk": 10, "speed": 0, "range": 2}
	all_stats.merge(stats, true)
	var kit: Dictionary = {"stats": all_stats, "passives": passives,
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}}
	kit.merge(extra, true)
	return K.kit(hero_id, kit)


func _aura(stat: String, value: int, more: Dictionary = {}) -> Array:
	var aura: Dictionary = {"target": "holder", "stat": stat, "value": value}
	aura.merge(more, true)
	return [{"id": "a", "name": "A", "kind": "aura", "aura": aura}]


func _ability(effects: Array) -> Array:
	return [{"id": "p", "name": "P", "kind": "ability", "effects": effects}]


func _duel(hero: UnitDef, foe: UnitDef = null) -> CombatSim:
	return K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(foe if foe != null else _dummy(), 3, 4)] as Array[UnitSetup]))


func _hit(fight: CombatSim, from_id: String, to_id: String, amount: int, ability_id: String = "") -> int:
	var source: EffectSource = EffectSource.make(from_id, ability_id if not ability_id.is_empty() else from_id + "_attack", "Strike")
	return EffectRunner.deal_hit(fight, source, fight.unit_by_id(to_id), amount, false)


func test_reading_the_6b_pieces() -> void:
	assert_eq(_read({"trigger": "on_charged", "type": "shield", "amount_bp_of_max_hp": 1000, "target": "self"}), [] as Array[String])
	assert_eq(_read({"trigger": "on_enemy_fell", "fell_within_hexes": 2, "type": "gain_mana", "amount": 5, "target": "self"}), [] as Array[String])
	assert_eq(_read({"trigger": "on_kill", "from_signature": true, "type": "gain_mana", "amount_bp_of_max_mana": 2500, "target": "self"}), [] as Array[String])
	assert_eq(_read({"trigger": "on_hit_taken", "min_bp_of_max_hp": 1500, "cooldown_ms": 8000, "type": "apply_status", "status": "stun", "duration_ms": 500, "target": "hit_target"}), [] as Array[String])
	var errors: Array[String] = []
	KitMod.read(DataReader.new({"on": [{"slot": "basic_attack", "targets_add": 1}]}, "mod", errors))
	assert_false(errors.is_empty(), "targets_add changes a signature")
	errors.clear()
	AuraDef.read(DataReader.new({"target": "holder", "stat": "lifesteal_bp", "value": 100, "from_signature": true, "from_basic": true}, "aura", errors))
	assert_false(errors.is_empty(), "the basic attack or the signature, not both")


func test_def_ignore() -> void:
	var foe: UnitDef = K.kit("dummy", {"stats": {"hp": 100000, "def": 100, "speed": 0, "range": 2},
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var plain: CombatSim = _duel(_with([]), foe)
	var keen: CombatSim = _duel(_with(_aura("def_ignore_bp", 5000)), foe)
	assert_gt(_hit(keen, "hero", "dummy", 1000), _hit(plain, "hero", "dummy", 1000), "half its DEF ignored")


func test_unpushable_resists_a_knockback() -> void:
	var pusher: UnitDef = _with([], {"basic_attack": {"cooldown_ms": 50, "shot": false, "effects": [{"type": "knockback", "hexes": 1, "target": "target"}]}}, "pusher")
	var firm: UnitDef = K.kit("dummy", {"stats": {"hp": 100000, "speed": 0, "range": 2}, "passives": _aura("unpushable", 1),
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(pusher, 3, 2, "pusher")] as Array[UnitSetup], [K.foe(firm, 3, 4)] as Array[UnitSetup]))
	var start: Vector2i = fight.unit_by_id("dummy").pos
	K.step(fight, 2)
	assert_eq(fight.unit_by_id("dummy").pos, start, "it isn't moved")
	assert_eq(K.entries(fight, LogEntry.Kind.PUSH).size(), 0)
	var resisted: Array[LogEntry] = K.entries(fight, LogEntry.Kind.RESISTED)
	assert_false(resisted.is_empty())
	assert_string_contains(resisted[0].to_text(), "resists being knocked back")


func test_a_dodge_misses_then_waits() -> void:
	var fight: CombatSim = _duel(_with(_aura("dodge_every_ms", 2000)))
	var hero: UnitState = fight.unit_by_id("hero")
	assert_eq(_hit(fight, "dummy", "hero", 100), 0, "the first hit misses")
	assert_eq(hero.hp, 1000)
	var dodged: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DODGED)
	assert_eq(dodged.size(), 1)
	assert_eq([dodged[0].source_unit, dodged[0].target], ["dummy", "hero"])
	assert_string_contains(dodged[0].to_text(), "misses hero")
	assert_gt(_hit(fight, "dummy", "hero", 100), 0, "the next lands")
	K.step(fight, 40)
	assert_eq(_hit(fight, "dummy", "hero", 100), 0, "2s later, another misses")


func test_a_dodged_hit_sets_off_no_on_hit_effects() -> void:
	var burner: UnitDef = K.kit("dummy", {"stats": {"hp": 100000, "atk": 10, "speed": 0, "range": 2},
		"basic_attack": {"cooldown_ms": 50, "shot": false, "effects": [{"type": "damage", "amount": 5, "target": "target"},
			{"trigger": "on_hit", "type": "apply_status", "status": "burn", "stacks": 1, "target": "hit_target"}]}})
	var fight: CombatSim = _duel(_with(_aura("dodge_every_ms", 60000)), burner)
	K.step(fight, 1)
	assert_eq(K.entries(fight, LogEntry.Kind.DODGED).size(), 1)
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED).size(), 0, "the miss lands no Burn")


func test_halved_hits() -> void:
	var fight: CombatSim = _duel(_with(_aura("halved_hits", 2)))
	var first: int = _hit(fight, "dummy", "hero", 100)
	var second: int = _hit(fight, "dummy", "hero", 100)
	var third: int = _hit(fight, "dummy", "hero", 100)
	assert_eq([first, second], [third / 2, third / 2], "the first two at half")
	assert_string_contains(K.entries(fight, LogEntry.Kind.DAMAGE)[0].to_text(), "halved")


func test_grounded_takes_flight_away_while_it_lasts() -> void:
	var flier: UnitDef = K.kit("dummy", {"traits": ["flying"], "stats": {"hp": 100000, "speed": 0, "range": 2},
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var fight: CombatSim = _duel(_with([]), flier)
	var foe: UnitState = fight.unit_by_id("dummy")
	assert_true(foe.flying)
	Statuses.apply(fight, foe, "grounded", 1, 20, EffectSource.make("hero", "hero_attack", "Strike"))
	assert_false(foe.flying, "grounded")
	K.step(fight, 25)
	assert_true(foe.flying, "it flies again once Grounded ends")
	var walker: CombatSim = _duel(_with([]))
	Statuses.apply(walker, walker.unit_by_id("dummy"), "grounded", 1, 20, EffectSource.make("hero", "hero_attack", "Strike"))
	K.step(walker, 25)
	assert_false(walker.unit_by_id("dummy").flying, "a walker stays a walker")


func test_a_boost_until_its_next_attack() -> void:
	var hero: UnitDef = _with([], {"basic_attack": {"cooldown_ms": 500, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}})
	var fight: CombatSim = _duel(hero)
	_until_hits(fight, 1)
	var plain: int = K.entries(fight, LogEntry.Kind.DAMAGE, "hero")[0].amount
	Statuses.apply(fight, fight.unit_by_id("hero"), "shadow_step", 1, 0, EffectSource.make("hero", "shadow_step", "Shadow Step"))
	_until_hits(fight, 2)
	assert_gt(K.entries(fight, LogEntry.Kind.DAMAGE, "hero")[1].amount, plain, "the next attack has it")
	fight.step()
	assert_null(Statuses.find(fight.unit_by_id("hero"), "shadow_step"), "and it's gone")
	_until_hits(fight, 3)
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "hero")[2].amount, plain)


func _until_hits(fight: CombatSim, hits: int) -> void:
	for i: int in 200:
		if K.entries(fight, LogEntry.Kind.DAMAGE, "hero").size() >= hits:
			return
		fight.step()


func test_a_mark_that_stacks_by_its_effect() -> void:
	var fight: CombatSim = _duel(_with([]))
	var foe: UnitState = fight.unit_by_id("dummy")
	var source: EffectSource = EffectSource.make("hero", "hero_attack", "Strike")
	Statuses.apply(fight, foe, "marked", 1, 0, source, true)
	Statuses.apply(fight, foe, "marked", 1, 0, source, true)
	assert_eq(Statuses.stacks_on(foe, "marked"), 2)
	Statuses.apply(fight, foe, "marked", 1, 0, source)
	assert_eq(Statuses.stacks_on(foe, "marked"), 2, "a plain Mark only refreshes")


func test_a_kit_that_prefers_some_enemies() -> void:
	var mod: KitMod = KitMod.read(DataReader.new({"prefer": {"label": "Bloodhound", "vs": {"below_hp_pct": 50}}}, "mod", [] as Array[String]))
	var hero: UnitDef = mod.apply(_with([]))
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_dummy(), 3, 4, "near"), K.foe(_dummy(), 5, 6, "far")] as Array[UnitSetup]))
	fight.unit_by_id("far").hp = 100
	fight.step()
	assert_eq(fight.unit_by_id("hero").target.id, "far", "the wounded one, though farther")
	assert_eq(K.entries(fight, LogEntry.Kind.TARGET, "hero")[0].note, "Bloodhound")


func test_a_charge_sets_off_on_charged() -> void:
	var charger: UnitDef = K.kit("dummy", {"stats": {"hp": 100000, "speed": 0, "range": 1},
		"signature": {"id": "rush", "name": "Rush", "trigger": {"kind": "fight_start"}, "max_range": 6, "shot": false,
			"effects": [{"type": "charge", "hexes": 5, "target": "target"}, {"type": "damage", "amount": 5, "target": "target"}]},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var braced: UnitDef = _with(_ability([{"trigger": "on_charged", "type": "shield", "amount": 30, "target": "self"}]))
	var fight: CombatSim = _duel(braced, charger)
	K.step(fight, 3)
	assert_eq(K.entries(fight, LogEntry.Kind.SHIELD, "hero").size(), 1, "the charge's hit Shields it")
	var plain: CombatSim = _duel(braced)
	_hit(plain, "dummy", "hero", 5)
	K.step(plain, 2)
	assert_eq(K.entries(plain, LogEntry.Kind.SHIELD).size(), 0, "a plain hit doesn't")


func test_a_big_hit_and_a_cooldown() -> void:
	var brand: UnitDef = _with(_ability([{"trigger": "on_hit_taken", "min_bp_of_max_hp": 1500, "cooldown_ms": 2000, "type": "apply_status", "status": "stun", "duration_ms": 500, "target": "hit_target"}]))
	var fight: CombatSim = _duel(brand)
	_hit(fight, "dummy", "hero", 100)
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED).size(), 0, "10% of its max HP isn't enough")
	_hit(fight, "dummy", "hero", 200)
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED).size(), 1, "20% is")
	_hit(fight, "dummy", "hero", 200)
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED).size(), 1, "not again within 2s")
	K.step(fight, 40)
	_hit(fight, "dummy", "hero", 200)
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED).size(), 2)


func test_an_enemy_falling_near() -> void:
	var scavenger: UnitDef = _with(_ability([{"trigger": "on_enemy_fell", "fell_within_hexes": 2, "type": "shield", "amount": 10, "target": "self"}]))
	var fight: CombatSim = K.sim(K.fight([K.at(scavenger, 3, 2)] as Array[UnitSetup], [K.foe(_dummy(), 3, 4, "near"), K.foe(_dummy(), 7, 6, "far")] as Array[UnitSetup]))
	fight.unit_by_id("near").hp = 1
	fight.unit_by_id("far").hp = 1
	EffectRunner.deal_hit(fight, EffectSource.make("far", "far_attack", "Strike"), fight.unit_by_id("far"), 10, false)
	K.step(fight, 2)
	assert_eq(K.entries(fight, LogEntry.Kind.SHIELD).size(), 0, "too far away")
	_hit(fight, "hero", "near", 10)
	K.step(fight, 2)
	assert_eq(K.entries(fight, LogEntry.Kind.SHIELD).size(), 1, "within 2 hexes")


func test_a_kill_by_the_signature_refunds_a_share() -> void:
	var refund: UnitDef = _with(_ability([{"trigger": "on_kill", "from_signature": true, "type": "gain_mana", "amount_bp_of_max_mana": 5000, "target": "self"}]),
		{"mana": {"max": 40, "start": 0}, "signature": {"id": "sig", "name": "Sig", "trigger": {"kind": "mana"}, "shot": false, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}})
	var fight: CombatSim = _duel(refund)
	fight.unit_by_id("dummy").hp = 1
	_hit(fight, "hero", "dummy", 10, "hero_attack")
	K.step(fight, 2)
	assert_eq(fight.unit_by_id("hero").mana, 0, "a basic attack's kill gives nothing")
	var by_sig: CombatSim = _duel(refund)
	by_sig.unit_by_id("dummy").hp = 1
	_hit(by_sig, "hero", "dummy", 10, "sig")
	K.step(by_sig, 2)
	assert_eq(by_sig.unit_by_id("hero").mana, 20 * Mana.SCALE, "half its bar")


func test_signature_mods_start_share_cast_and_more_targets() -> void:
	var kit: UnitDef = _with([], {"mana": {"max": 40, "start": 0},
		"signature": {"id": "sig", "name": "Sig", "trigger": {"kind": "mana"}, "cast_ms": 1000, "targeting": "nearest", "shot": false,
			"effects": [{"type": "apply_status", "status": "marked", "target": "target"}]}})
	var opener: KitMod = KitMod.read(DataReader.new({"mana": {"start_bp": 5000}}, "mod", [] as Array[String]))
	assert_eq(opener.apply(kit).mana.start, 20)
	var quick: KitMod = KitMod.read(DataReader.new({"on": [{"slot": "signature", "cast_bp": 0}]}, "mod", [] as Array[String]))
	assert_eq(quick.apply(kit).signature.cast_ticks, 0)
	var wide: KitMod = KitMod.read(DataReader.new({"on": [{"slot": "signature", "targets_add": 1, "radius_add": 1, "one_of": true}]}, "mod", [] as Array[String]))
	var wider: UnitDef = wide.apply(kit)
	assert_eq(wider.signature.effects.size(), 2)
	assert_eq(wider.signature.effects[1].target, EffectDef.Target.ENEMY_NEAR_TARGET)
	var fight: CombatSim = K.sim(K.fight([K.at(wider, 3, 2)] as Array[UnitSetup], [K.foe(_dummy(), 3, 4, "a"), K.foe(_dummy(), 4, 5, "b"), K.foe(_dummy(), 0, 6, "c")] as Array[UnitSetup]))
	fight.unit_by_id("hero").mana = 40 * Mana.SCALE
	K.step(fight, 30)
	var marked: Array = K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "hero").map(func(entry: LogEntry) -> String: return entry.target)
	assert_eq(marked.slice(0, 2), ["a", "b"], "its target and the one nearest it")
	var area: UnitDef = _with([], {"mana": {"max": 40, "start": 0},
		"signature": {"id": "sig", "name": "Sig", "trigger": {"kind": "mana"}, "targeting": "nearest", "shot": false,
			"effects": [{"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "target", "hits": "enemies", "effects": [{"type": "damage", "amount": 1, "target": "target"}]},
				{"type": "apply_status", "status": "marked", "target": "target"}]}})
	assert_eq(wide.apply(area).signature.effects.size(), 2, "one_of: an area grows instead")


func test_lifesteal_on_the_signature_only() -> void:
	var siphon: UnitDef = _with(_aura("lifesteal_bp", 5000, {"from_signature": true}),
		{"signature": {"id": "sig", "name": "Sig", "trigger": {"kind": "fight_start"}, "shot": false, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}})
	var fight: CombatSim = _duel(siphon)
	fight.unit_by_id("hero").hp = 500
	_hit(fight, "hero", "dummy", 100, "hero_attack")
	assert_eq(K.entries(fight, LogEntry.Kind.LIFESTEAL).size(), 0, "its basic attack steals nothing")
	_hit(fight, "hero", "dummy", 100, "sig")
	assert_eq(K.entries(fight, LogEntry.Kind.LIFESTEAL).size(), 1, "its signature does")


func test_hopping_from_farther() -> void:
	var hopper: UnitDef = _with([], {"traits": ["hop_away"], "hop_cooldown_ms": 3000}, "hero", {"range": 4})
	var mod: KitMod = KitMod.read(DataReader.new({"hop": {"within_add": 1000, "cooldown_add_ms": -1000}}, "mod", [] as Array[String]))
	var light: UnitDef = mod.apply(hopper)
	assert_eq([light.hop_within, light.hop_cooldown_ticks], [2000, FixedMath.ms_to_ticks(2000)])
	var foe_kit: UnitDef = _dummy()
	var plain: CombatSim = K.sim(K.fight([K.at(hopper, 3, 2)] as Array[UnitSetup], [K.foe(foe_kit, 3, 4)] as Array[UnitSetup]))
	var lighter: CombatSim = K.sim(K.fight([K.at(light, 3, 2)] as Array[UnitSetup], [K.foe(foe_kit, 3, 4)] as Array[UnitSetup]))
	K.step(plain, 2)
	K.step(lighter, 2)
	assert_eq(K.entries(plain, LogEntry.Kind.HOP).size(), 0, "2 hexes off: no hop")
	assert_eq(K.entries(lighter, LogEntry.Kind.HOP).size(), 1, "with Light Feet, a hop")
