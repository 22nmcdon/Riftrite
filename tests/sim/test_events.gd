extends GutTest
## Event triggers (docs/plans/keywords-and-affinities.md, section 1): items
## that react to what their holder does, read from the combat log.

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT: UnitSetup.Row = UnitSetup.Row.FRONT
const BIG_HP: int = 100000


## A passive whose only effects are `effects` (event triggers).
func _passive(item_id: String, effects: Array, extra: Dictionary = {}) -> ItemDef:
	var data: Dictionary = {"name": item_id.capitalize(), "slot": "passive", "cooldown_ms": null, "effects": effects}
	data.merge(extra, true)
	return K.item(item_id, data)


func _idle() -> ItemDef:
	return K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)})


func _hero(items: Array, basic_attack: ItemDef = null) -> UnitSetup:
	return K.unit("hero", BIG_HP, FRONT, items, basic_attack if basic_attack != null else _idle())


func _foe(hit: int = 0) -> UnitSetup:
	if hit <= 0:
		return K.dummy("foe", BIG_HP)
	return K.unit("foe", BIG_HP, FRONT, [], K.basic("claw", {"cooldown_ms": 1000, "effects": K.damage(hit)}))


## Runs up to `seconds` of a fight and returns the log.
func _log(heroes: Array[UnitSetup], enemies: Array[UnitSetup], seconds: int = 5) -> Array[LogEntry]:
	var sim := CombatSim.new(K.fight(heroes, enemies), K.content())
	while not sim.finished and sim.tick < seconds * FixedMath.TICKS_PER_SECOND:
		sim.step()
	return sim.combat_log.entries


func _from(entries: Array[LogEntry], kind: LogEntry.Kind, item_id: String) -> Array[LogEntry]:
	return entries.filter(func(entry: LogEntry) -> bool: return entry.kind == kind and entry.source_item == item_id)


func _fires(entries: Array[LogEntry], item_id: String) -> Array[int]:
	return K.ticks_of(_from(entries, LogEntry.Kind.FIRE, item_id))


# --- each trigger --------------------------------------------------------------

func test_on_ability_answers_the_holders_other_abilities() -> void:
	var chime: ItemDef = _passive("chime", [{"trigger": "on_ability", "type": "shield", "amount": 3, "target": "self"}])
	var sword: ItemDef = K.item("sword")
	var entries: Array[LogEntry] = _log([_hero([sword, chime], K.basic())], [_foe()])
	var shields: Array[LogEntry] = _from(entries, LogEntry.Kind.SHIELD, "chime")
	assert_eq(K.ticks_of(shields), _fires(entries, "sword"), "once per ability fire, in the same tick")
	assert_gt(_fires(entries, "basic").size(), 0, "the basic attack fired too, and isn't an ability")
	assert_eq(shields[0].to_text(), "[1.00s] hero · Chime gives hero 3 shield")


func test_on_ability_can_want_a_keyword_and_skips_itself() -> void:
	var picky: ItemDef = _passive("picky", [{"trigger": "on_ability", "keyword": "bow", "type": "shield", "amount": 3, "target": "self"}])
	var sword: ItemDef = K.item("sword")
	var bow: ItemDef = K.item("longbow", {"keywords": ["bow"], "cooldown_ms": 2000})
	var entries: Array[LogEntry] = _log([_hero([sword, bow, picky])], [_foe()])
	assert_eq(K.ticks_of(_from(entries, LogEntry.Kind.SHIELD, "picky")), _fires(entries, "longbow"), "only Bow abilities")
	var echo: ItemDef = K.item("echo", {"effects": [{"trigger": "on_fire", "type": "damage", "amount": 1, "target": "enemy_front"},
		{"trigger": "on_ability", "type": "shield", "amount": 2, "target": "self"}]})
	var alone: Array[LogEntry] = _log([_hero([echo])], [_foe()])
	assert_eq(_from(alone, LogEntry.Kind.SHIELD, "echo").size(), 0, "an ability doesn't answer its own fire")


func test_every_counts_the_events() -> void:
	var chime: ItemDef = _passive("chime", [{"trigger": "on_ability", "every": 3, "type": "shield", "amount": 3, "target": "self"}])
	var entries: Array[LogEntry] = _log([_hero([K.item("sword"), chime])], [_foe()], 7)
	var fires: Array[int] = _fires(entries, "sword")
	assert_eq(fires.size(), 7)
	assert_eq(K.ticks_of(_from(entries, LogEntry.Kind.SHIELD, "chime")), [fires[2], fires[5]] as Array[int], "the 3rd and 6th")


func test_on_basic_attack() -> void:
	var drum: ItemDef = _passive("drum", [{"trigger": "on_basic_attack", "every": 2, "type": "shield", "amount": 4, "target": "self"}])
	var entries: Array[LogEntry] = _log([_hero([K.item("sword", {"cooldown_ms": 700}), drum], K.basic())], [_foe()], 6)
	var basics: Array[int] = _fires(entries, "basic")
	assert_eq(K.ticks_of(_from(entries, LogEntry.Kind.SHIELD, "drum")), [basics[1], basics[3], basics[5]] as Array[int], "every 2nd basic attack")


func test_on_holder_crit_names_the_unit_hit() -> void:
	var keen: ItemDef = _passive("keen", [{"trigger": "on_holder_crit", "type": "apply_status", "status": "bleed", "stacks": 1, "target": "hit_target"}])
	var sword: ItemDef = K.item("sword", {"crit_chance_bp": 10000})
	var entries: Array[LogEntry] = _log([_hero([sword, keen])], [_foe()], 3)
	var bleeds: Array[LogEntry] = _from(entries, LogEntry.Kind.STATUS_APPLIED, "keen")
	assert_eq(bleeds.size(), 3, "every crit")
	assert_eq(bleeds[0].target, "foe")
	var plain: Array[LogEntry] = _log([_hero([K.item("sword"), keen])], [_foe()], 3)
	assert_eq(_from(plain, LogEntry.Kind.STATUS_APPLIED, "keen").size(), 0, "no crits, nothing")


func test_on_shielded_never_answers_its_own_shield() -> void:
	var ward: ItemDef = K.item("ward", {"effects": [{"trigger": "on_fire", "type": "shield", "amount": 10, "target": "self"}]})
	var echo: ItemDef = _passive("echo", [{"trigger": "on_shielded", "type": "shield", "amount": 1, "target": "self"}])
	var spark: ItemDef = _passive("spark", [{"trigger": "on_shielded", "type": "damage", "amount": 7, "target": "enemy_front"}])
	var entries: Array[LogEntry] = _log([_hero([ward, echo, spark])], [_foe()], 4)
	var wards: int = _from(entries, LogEntry.Kind.SHIELD, "ward").size()
	assert_eq(_from(entries, LogEntry.Kind.SHIELD, "echo").size(), wards, "one per real shield: event effects never set each other off")
	assert_eq(_from(entries, LogEntry.Kind.DAMAGE, "spark").size(), wards)


func test_on_hit_taken_strikes_back_at_the_attacker() -> void:
	var thorns: ItemDef = _passive("thorns", [{"trigger": "on_hit_taken", "type": "damage", "amount": 3, "target": "hit_target"}])
	var entries: Array[LogEntry] = _log([_hero([thorns])], [_foe(4)], 3)
	var claws: Array[LogEntry] = _from(entries, LogEntry.Kind.DAMAGE, "claw")
	var back: Array[LogEntry] = _from(entries, LogEntry.Kind.DAMAGE, "thorns")
	assert_eq(K.ticks_of(back), K.ticks_of(claws))
	assert_eq(K.targets_of(back), ["foe", "foe", "foe"] as Array[String])
	var reflect: ItemDef = _passive("reflect", [{"trigger": "on_hit_taken", "type": "shield", "amount_bp_of_damage": 5000, "target": "self"}])
	var shielded: Array[LogEntry] = _log([_hero([reflect])], [_foe(8)], 2)
	assert_eq(_from(shielded, LogEntry.Kind.SHIELD, "reflect")[0].amount, 4, "half the hit taken")


func test_on_heal_names_who_was_healed() -> void:
	var salve: ItemDef = K.item("salve", {"cooldown_ms": 1500, "effects": [{"trigger": "on_fire", "type": "heal", "amount": 5, "target": "self"}]})
	var lantern: ItemDef = _passive("lantern", [{"trigger": "on_heal", "type": "shield", "amount": 2, "target": "hit_target"}])
	var entries: Array[LogEntry] = _log([_hero([salve, lantern])], [_foe(20)], 5)
	var heals: Array[LogEntry] = _from(entries, LogEntry.Kind.HEAL, "salve").filter(func(e: LogEntry) -> bool: return e.amount > 0)
	assert_eq(K.ticks_of(_from(entries, LogEntry.Kind.SHIELD, "lantern")), K.ticks_of(heals), "only heals that restored HP")
	var full: Array[LogEntry] = _log([_hero([salve, lantern])], [_foe()], 5)
	assert_eq(_from(full, LogEntry.Kind.SHIELD, "lantern").size(), 0, "healing a full-HP hero restores nothing")


func test_on_status_can_want_statuses() -> void:
	var torch: ItemDef = K.item("torch", {"effects": [{"trigger": "on_fire", "type": "apply_status", "status": "burn", "stacks": 1, "target": "enemy_front"}]})
	var vial: ItemDef = K.item("vial", {"cooldown_ms": 2000, "effects": [{"trigger": "on_fire", "type": "apply_status", "status": "poison", "stacks": 1, "target": "enemy_front"}]})
	var bag: ItemDef = _passive("bag", [{"trigger": "on_status", "statuses": ["burn"], "type": "apply_status", "status": "slow", "stacks": 1, "target": "hit_target"}])
	var entries: Array[LogEntry] = _log([_hero([torch, vial, bag])], [_foe()], 4)
	var slows: Array[LogEntry] = _from(entries, LogEntry.Kind.STATUS_APPLIED, "bag")
	assert_eq(K.ticks_of(slows), _fires(entries, "torch"), "Burn only, not Poison")
	assert_eq(slows[0].target, "foe")


func test_on_kill_credits_whoever_hit_last() -> void:
	var leech: ItemDef = _passive("leech", [{"trigger": "on_kill", "type": "shield", "amount": 9, "target": "self"}])
	var sword: ItemDef = K.item("sword", {"effects": K.damage(50)})
	var foes: Array[UnitSetup] = [K.dummy("a", 40), K.dummy("b", 40), K.dummy("c", BIG_HP)]
	var entries: Array[LogEntry] = _log([_hero([sword, leech])], foes, 4)
	var deaths: Array[LogEntry] = entries.filter(func(e: LogEntry) -> bool: return e.kind == LogEntry.Kind.DEATH)
	assert_eq(K.ticks_of(_from(entries, LogEntry.Kind.SHIELD, "leech")), K.ticks_of(deaths), "one per enemy the hero felled")
	var torch: ItemDef = K.item("torch", {"cooldown_ms": 500, "effects": [{"trigger": "on_fire", "type": "apply_status", "status": "burn", "stacks": 30, "target": "enemy_front"}]})
	var burned: Array[LogEntry] = _log([_hero([torch, leech])], [K.dummy("a", 60)], 10)
	assert_eq(_from(burned, LogEntry.Kind.SHIELD, "leech").size(), 1, "a status's damage counts as the hero's")


func test_a_kill_effect_that_fells_another_enemy_kills_it_at_once() -> void:
	var blast: ItemDef = _passive("blast", [{"trigger": "on_kill", "type": "damage", "amount": 100, "target": "all_enemies"}])
	var sword: ItemDef = K.item("sword", {"effects": K.damage(50)})
	var entries: Array[LogEntry] = _log([_hero([sword, blast])], [K.dummy("a", 40), K.dummy("b", 60, UnitSetup.Row.BACK)], 3)
	var deaths: Array[LogEntry] = entries.filter(func(e: LogEntry) -> bool: return e.kind == LogEntry.Kind.DEATH)
	assert_eq(K.ticks_of(deaths), [20, 20] as Array[int], "both fall the same tick")
	assert_eq(_from(entries, LogEntry.Kind.DAMAGE, "blast").size(), 1, "and b's fall sets off no second blast")


func test_event_effects_are_deterministic_and_earn_no_xp() -> void:
	var keen: ItemDef = _passive("keen", [{"trigger": "on_holder_crit", "every": 2, "type": "damage", "amount": 3, "target": "enemy_random"}])
	var sword: ItemDef = K.item("sword", {"crit_chance_bp": 5000})
	var heroes: Array[UnitSetup] = [_hero([sword, K.equip(keen, ["wrath"] as Array[String])])]
	var foes: Array[UnitSetup] = [_foe(3), K.dummy("b", BIG_HP, UnitSetup.Row.BACK)]
	var one: FightResult = K.run(heroes, foes, 7)
	var two: FightResult = K.run(heroes, foes, 7)
	assert_eq(one.combat_log.to_text(), two.combat_log.to_text())
	assert_gt(K.entries(one, LogEntry.Kind.DAMAGE, "keen").size(), 0)
	assert_eq(one.infusions[0].xp_after, K.tuning().xp_per_battle, "battle XP only")


# --- reading ---------------------------------------------------------------------

func _errors(data: Dictionary) -> Array[String]:
	var full: Dictionary = K.DEFAULT_ITEM.duplicate(true)
	full.merge(data, true)
	for key: String in data:
		if data[key] == null:
			full.erase(key)
	full["id"] = "x"
	var errors: Array[String] = []
	ItemDef.read(DataReader.new(full, "x", errors))
	return errors


func _assert_error(errors: Array[String], expected: String) -> void:
	assert_true(errors.any(func(e: String) -> bool: return e.contains(expected)), "%s in %s" % [expected, errors])


func test_event_effects_are_checked() -> void:
	_assert_error(_errors({"slot": "passive", "effects": K.damage(3)}), "a passive never fires, so its effects need event triggers (not on_fire)")
	_assert_error(_errors({"slot": "passive", "effects": []}), "a passive needs auras, event effects, or a conduit")
	_assert_error(_errors({"conduit": "row"}), "only a passive can be a conduit")
	_assert_error(_errors({"slot": "passive", "conduit": "sideways", "effects": []}), "conduit: unknown value \"sideways\"")
	_assert_error(_errors({"effects": [{"trigger": "on_ability", "type": "damage", "amount": 1, "target": "hit_target"}]}), "on_ability names no unit, so it can't use hit_target")
	_assert_error(_errors({"effects": [{"trigger": "on_kill", "type": "shield", "amount_bp_of_damage": 100, "target": "self"}]}), "on_kill names no hit")
	_assert_error(_errors({"effects": [{"trigger": "on_status", "every": 0, "type": "damage", "amount": 1, "target": "enemy_front"}]}), "every: 0 is out of range")
	_assert_error(_errors({"effects": [{"trigger": "on_fire", "every": 2, "type": "damage", "amount": 1, "target": "enemy_front"}]}), "unknown key \"every\"")
	var passive: Array[String] = _errors({"slot": "passive", "cooldown_ms": null, "effects": [{"trigger": "on_heal", "type": "shield", "amount": 1, "target": "hit_target"}]})
	assert_eq(passive, [] as Array[String], "a passive with an event effect needs no cooldown")
	var relic_errors: Array[String] = []
	RelicDef.read(DataReader.new({"id": "r", "name": "R", "rarity": "rare", "effects": [{"trigger": "on_kill", "type": "heal", "amount": 1, "target": "all_allies"}]}, "r", relic_errors))
	_assert_error(relic_errors, "relic effects can't use the trigger \"on_kill\"")


func test_a_kill_effect_never_sets_off_another_event() -> void:
	var leech: ItemDef = _passive("leech", [{"trigger": "on_kill", "type": "shield", "amount": 9, "target": "self"}])
	var spark: ItemDef = _passive("spark", [{"trigger": "on_shielded", "type": "damage", "amount": 7, "target": "enemy_front"}])
	var sword: ItemDef = K.item("sword", {"effects": K.damage(50)})
	var entries: Array[LogEntry] = _log([_hero([sword, leech, spark])], [K.dummy("a", 40), K.dummy("b", BIG_HP)], 4)
	assert_eq(_from(entries, LogEntry.Kind.SHIELD, "leech").size(), 1, "the kill shields")
	assert_eq(_from(entries, LogEntry.Kind.DAMAGE, "spark").size(), 0, "but that shield sets nothing off, even a tick later")
	var ward: ItemDef = K.item("ward", {"cooldown_ms": 3000, "effects": [{"trigger": "on_fire", "type": "shield", "amount": 5, "target": "self"}]})
	var plain: Array[LogEntry] = _log([_hero([ward, spark])], [_foe()], 4)
	assert_eq(_from(plain, LogEntry.Kind.DAMAGE, "spark").size(), 1, "a real shield does")
