extends GutTest
## Each essence socketed in an item, using the real data/essences.json and the
## conversion rule (same kind x1.5, same family 50%, direct -> over time 5%,
## over time -> direct 500%).

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT := UnitSetup.Row.FRONT
const BACK := UnitSetup.Row.BACK
const BIG_HP: int = 10000000


func _idle() -> ItemDef:
	return K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)})


func _sword(amount: int = 100, overrides: Dictionary = {}) -> ItemDef:
	var data: Dictionary = {"name": "Sword", "effects": K.damage(amount)}
	data.merge(overrides, true)
	return K.item("sword", data)


func _applier(status: String, stacks: int) -> ItemDef:
	return K.item("sword", {"name": "Sword", "effects": [
		{"trigger": "on_fire", "type": "apply_status", "status": status, "stacks": stacks, "target": "enemy_front"}]})


func _self_heal(amount: int) -> ItemDef:
	return K.item("sword", {"name": "Charm", "effects": [
		{"trigger": "on_fire", "type": "heal", "amount": amount, "target": "self"}]})


func _hero(item: ItemDef, essence: String) -> UnitSetup:
	return K.unit("hero", BIG_HP, FRONT, [K.equip(item, [essence] as Array[String])], _idle())


func _run_with(item: ItemDef, essence: String, foe: UnitSetup = null) -> FightResult:
	return K.run([_hero(item, essence)], [foe if foe != null else K.dummy("foe", BIG_HP)])


## Entries of `kind` credited to `essence`, in order.
func _from(result: FightResult, kind: LogEntry.Kind, essence: String) -> Array[LogEntry]:
	return result.combat_log.of_kind(kind).filter(
		func(entry: LogEntry) -> bool: return entry.source_infusion == essence)


func _values(item: ItemDef, essence: String) -> PackedStringArray:
	var sim := CombatSim.new(K.fight([_hero(item, essence)], [K.dummy("foe", BIG_HP)]), K.content())
	return sim.units[0].items[1].describe_values()


# --- sockets ---------------------------------------------------------------------------

func _setup_errors(items: Array) -> Array[String]:
	return K.run([K.unit("hero", 100, FRONT, items)], [K.dummy("foe", 100)]).errors


func test_small_items_have_one_socket() -> void:
	var errors: Array[String] = _setup_errors([K.equip(_sword(), ["ember", "frost"] as Array[String])])
	assert_true(errors.any(func(e: String) -> bool: return e.contains("has 2 essences but only 1 socket(s)")), str(errors))


func test_two_essences_wait_for_alloys() -> void:
	var errors: Array[String] = _setup_errors([K.equip(_sword(100, {"size": 2}), ["ember", "frost"] as Array[String])])
	assert_true(errors.any(func(e: String) -> bool: return e.contains("which the sim doesn't support yet")), str(errors))


func test_unknown_essence_is_rejected() -> void:
	var errors: Array[String] = _setup_errors([K.equip(_sword(), ["glitter"] as Array[String])])
	assert_true(errors.any(func(e: String) -> bool: return e.contains("unknown essence \"glitter\"")), str(errors))


# --- direct -> over time (5%) ---------------------------------------------------------

func test_ember_on_a_sword_adds_five_percent_burn() -> void:
	var applied: LogEntry = _from(_run_with(_sword(100), "ember"), LogEntry.Kind.STATUS_APPLIED, "ember")[0]
	assert_eq(applied.to_text(), "[1.00s] hero · Sword [Ember] applies 5 Burn to foe (5 total)")


func test_venom_on_a_sword_adds_five_percent_poison() -> void:
	var applied: LogEntry = _from(_run_with(_sword(100), "venom"), LogEntry.Kind.STATUS_APPLIED, "venom")[0]
	assert_eq([applied.status, applied.amount, applied.target], ["poison", 5, "foe"])


func test_fractions_carry_over_between_hits() -> void:
	var applied: Array[LogEntry] = _from(_run_with(_sword(30), "ember"), LogEntry.Kind.STATUS_APPLIED, "ember")
	assert_eq([applied[0].amount, applied[1].amount, applied[2].amount], [1, 2, 1], "1.5 per hit: 1, then 2, then 1")


func test_damage_essence_on_a_heal_item_hits_the_enemy_across() -> void:
	var applied: LogEntry = _from(_run_with(_self_heal(100), "ember"), LogEntry.Kind.STATUS_APPLIED, "ember")[0]
	assert_eq([applied.amount, applied.target], [5, "foe"])


# --- same family, other kind (50%) --------------------------------------------------

func test_stone_on_a_sword_shields_the_holder() -> void:
	var shield: LogEntry = _from(_run_with(_sword(100), "stone"), LogEntry.Kind.SHIELD, "stone")[0]
	assert_eq(shield.to_text(), "[1.00s] hero · Sword [Stone] gives hero 50 shield")


func test_verdant_on_a_sword_heals_only_the_holder() -> void:
	var foe: UnitSetup = K.unit("foe", BIG_HP, FRONT, [K.item("club", {"effects": K.damage(60)})], _idle())
	var ally: UnitSetup = K.unit("ally", 10, BACK, [], _idle())
	var result: FightResult = K.run([_hero(_sword(100), "verdant"), ally], [foe])
	var heals: Array[LogEntry] = _from(result, LogEntry.Kind.HEAL, "verdant")
	assert_eq([heals[1].tick, heals[1].target, heals[1].amount], [40, "hero", 50], "lifesteal: half the hit, to the holder")


func test_ember_on_a_poison_item_adds_half_as_burn() -> void:
	var applied: LogEntry = _from(_run_with(_applier("poison", 10), "ember"), LogEntry.Kind.STATUS_APPLIED, "ember")[0]
	assert_eq([applied.status, applied.amount], ["burn", 5])


# --- over time -> direct (500%) ------------------------------------------------------

func test_wrath_on_a_burn_item_adds_five_times_the_burn_as_damage() -> void:
	var hit: LogEntry = _from(_run_with(_applier("burn", 10), "wrath"), LogEntry.Kind.DAMAGE, "wrath")[0]
	assert_eq(hit.to_text(), "[1.00s] hero · Sword [Wrath] hits foe for 50")


func test_added_damage_goes_through_defense() -> void:
	var foe: UnitSetup = K.unit_with("foe", UnitStats.make(BIG_HP, 0, 0, 100), FRONT, [], _idle())
	var hit: LogEntry = _from(_run_with(_applier("burn", 10), "wrath", foe), LogEntry.Kind.DAMAGE, "wrath")[0]
	assert_eq([hit.amount, hit.mitigated], [25, 25])


# --- same kind (x1.5) --------------------------------------------------------------------

func test_same_kind_makes_the_output_half_again_bigger() -> void:
	assert_eq(_values(_sword(100), "wrath"), PackedStringArray(["damage: 150 (base 100, x1.5 Wrath)"]))
	assert_eq(_values(_applier("burn", 10), "ember"), PackedStringArray(["burn stacks: 15 (base 10, x1.5 Ember)"]))
	assert_eq(_values(_self_heal(40), "verdant"), PackedStringArray(["heal: 60 (base 40, x1.5 Verdant)"]))


func test_same_kind_adds_nothing_extra() -> void:
	var result: FightResult = _run_with(_sword(100), "wrath")
	assert_eq(_from(result, LogEntry.Kind.DAMAGE, "wrath").size(), 0, "folded into the sword's own hit")
	assert_eq(K.entries(result, LogEntry.Kind.DAMAGE, "sword")[0].amount, 150)


# --- Umbral, Frost, Storm --------------------------------------------------------------

func test_umbral_adds_crit_and_crits_add_bleed() -> void:
	var sim := CombatSim.new(K.fight([_hero(_sword(), "umbral")], [K.dummy("foe", BIG_HP)]), K.content())
	assert_eq(sim.units[0].items[1].crit_chance_bp, 1500, "+15% crit")
	var result: FightResult = _run_with(_sword(100, {"crit_chance_bp": 10000}), "umbral")
	var bleed: LogEntry = _from(result, LogEntry.Kind.STATUS_APPLIED, "umbral")[0]
	assert_eq([bleed.status, bleed.amount], ["bleed", 7], "5% of the 150 crit = 7.5, so 7 now and the half carries")


func test_umbral_adds_nothing_without_crits() -> void:
	var result: FightResult = _run_with(_applier("bleed", 10), "umbral")
	assert_eq(_from(result, LogEntry.Kind.STATUS_APPLIED, "umbral").size(), 0)
	assert_eq(_values(_applier("bleed", 10), "umbral"), PackedStringArray(["bleed stacks: 10"]), "no same-kind boost for crit-only")


func test_frost_slows_on_hit() -> void:
	var applied: LogEntry = _from(_run_with(_sword(10), "frost"), LogEntry.Kind.STATUS_APPLIED, "frost")[0]
	assert_eq([applied.tick, applied.status], [20, "slow"])


func test_storm_shortens_cooldown_and_sometimes_fires_twice() -> void:
	var fires: Array[LogEntry] = K.entries(_run_with(_sword(10), "storm"), LogEntry.Kind.FIRE, "sword")
	var first_fires: Array[int] = []
	var again: int = 0
	for entry: LogEntry in fires:
		if entry.note.is_empty():
			first_fires.append(entry.tick)
		else:
			again += 1
			assert_eq(entry.note, "again (Storm)")
	assert_eq(first_fires.slice(0, 3), [17, 34, 51] as Array[int], "1s cooldown -15% = 17 ticks")
	assert_between(again * 10, first_fires.size(), first_fires.size() * 3, "about 20% of fires repeat")


func test_basic_attack_carries_no_essence_effects() -> void:
	var result: FightResult = K.run([_hero(_self_heal(1), "ember")], [K.dummy("foe", BIG_HP)])
	for entry: LogEntry in result.combat_log.entries:
		if entry.source_item == "idle":
			assert_eq(entry.source_infusion, "", "ember sits in the charm, not the basic attack")
