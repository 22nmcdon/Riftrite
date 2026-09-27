extends GutTest
## Infused passives spread their essences, and conduits change where spills
## go (docs/plans/keywords-and-affinities.md, sections 2 and 3).

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT: UnitSetup.Row = UnitSetup.Row.FRONT
const BACK: UnitSetup.Row = UnitSetup.Row.BACK
const BIG_HP: int = 100000


func _blade(item_id: String, keywords: Array[String] = ["blade"] as Array[String]) -> ItemDef:
	return K.item(item_id, {"name": item_id.capitalize(), "keywords": keywords, "effects": K.damage(100)})


func _passive(item_id: String, keywords: Array[String] = ["blade"] as Array[String], extra: Dictionary = {}) -> ItemDef:
	var data: Dictionary = {"name": item_id.capitalize(), "slot": "passive", "keywords": keywords, "cooldown_ms": null, "effects": null,
		"auras": [{"target": "holder", "stat": "def_bp", "value": 10000}]}
	data.merge(extra, true)
	return K.item(item_id, data)


func _conduit(item_id: String, conduit: String) -> ItemDef:
	return _passive(item_id, ["ward"] as Array[String], {"conduit": conduit, "auras": null})


func _sim(heroes: Array[UnitSetup]) -> CombatSim:
	return CombatSim.new(K.fight(heroes, [K.dummy("foe", BIG_HP)]), K.content())


## The spills an item receives, as "label strength".
func _received(item: ItemState) -> Array[String]:
	var found: Array[String] = []
	for app: EssenceApplication in item.spills_received:
		found.append("%s %d" % [app.label, app.strength_bp])
	return found


# --- spreading ---------------------------------------------------------------------

func test_an_infused_passive_spreads_at_every_level() -> void:
	var expected: Array[int] = [1500, 3750, 7000]
	var levels: Array[int] = [0, K.tuning().xp_to_attuned, K.tuning().xp_to_resonant]
	for i: int in 3:
		var drum: ItemSetup = K.equip(_passive("drum"), ["wrath"] as Array[String], 0, levels[i])
		var sim := _sim([K.unit("hero", BIG_HP, FRONT, [drum, _blade("sword"), _blade("bow", ["bow"] as Array[String])])])
		assert_eq(_received(sim.units[0].items[2]), ["Wrath spread from Drum %d" % expected[i]] as Array[String], "level %d: its share of that level's strength" % i)
		assert_eq(_received(sim.units[0].items[3]), [] as Array[String], "only items sharing a keyword")
		assert_eq(sim.units[0].items[2].spills_received[0].share_bp, K.tuning().passive_spread_bp[i])
	assert_gt(7000, FixedMath.apply_bp(K.tuning().infusion_level_bp[2], K.tuning().spill_single_bp), "a Resonant passive spreads a bit more than a single spills")


func test_a_passive_spreads_instead_of_spilling_and_spreads_both_halves() -> void:
	var resonant: int = K.tuning().xp_to_resonant
	var drum: ItemState = _sim([K.unit("hero", BIG_HP, FRONT, [K.equip(_passive("drum"), ["wrath"] as Array[String], 0, resonant)])]).units[0].items[1]
	assert_false(drum.spills(), "a passive never spills")
	assert_true(drum.spreads())
	var alloy: ItemSetup = K.equip(_passive("drum"), ["ember", "storm"] as Array[String], 0, 0)
	var sim := _sim([K.unit("hero", BIG_HP, FRONT, [alloy, _blade("sword")])])
	assert_eq(_received(sim.units[0].items[2]), ["Ember spread from Drum 1500", "Storm spread from Drum 1500"] as Array[String])
	var double: ItemSetup = K.equip(_passive("drum"), ["ember", "ember"] as Array[String], 0, 0)
	var twice := _sim([K.unit("hero", BIG_HP, FRONT, [double, _blade("sword")])])
	assert_eq(_received(twice.units[0].items[2]), ["Ember spread from Drum 1500"] as Array[String], "one spread per essence")


func test_a_spread_changes_the_numbers() -> void:
	var drum: ItemSetup = K.equip(_passive("drum"), ["wrath"] as Array[String], 0, K.tuning().xp_to_resonant)
	var sim := _sim([K.unit("hero", BIG_HP, FRONT, [drum, _blade("sword")])])
	assert_eq(sim.units[0].items[2].describe_values(), PackedStringArray(["damage: 135 (base 100, x1.35 Wrath spread from Drum)"]), "+50% same-kind bonus at 70% strength")


# --- conduits ----------------------------------------------------------------------

func _resonant_sword() -> ItemSetup:
	return K.equip(_blade("sword"), ["wrath"] as Array[String], 0, K.tuning().xp_to_resonant)


func test_ember_censer_reaches_the_basic_attack() -> void:
	var plain := _sim([K.unit("hero", BIG_HP, FRONT, [_resonant_sword()])])
	assert_eq(_received(plain.units[0].items[0]), [] as Array[String], "the built-in basic attack has no keywords")
	var sim := _sim([K.unit("hero", BIG_HP, FRONT, [_resonant_sword(), _conduit("censer", "basic_attack")])])
	assert_eq(_received(sim.units[0].items[0]), ["Wrath spill from Sword 6000"] as Array[String])
	assert_eq(_received(sim.units[0].items[2]), [] as Array[String], "the censer itself shares no keyword")


func test_open_channel_reaches_every_ability() -> void:
	var bow: ItemDef = _blade("longbow", ["bow"] as Array[String])
	var sim := _sim([K.unit("hero", BIG_HP, FRONT, [_resonant_sword(), bow, _conduit("channel", "all_abilities"), _passive("drum", ["bow"] as Array[String])])])
	assert_eq(_received(sim.units[0].items[2]), ["Wrath spill from Sword 6000"] as Array[String], "an ability without the keyword")
	assert_eq(_received(sim.units[0].items[4]), [] as Array[String], "a passive isn't an ability")
	assert_eq(_received(sim.units[0].items[0]), [] as Array[String], "nor the basic attack")


func test_prism_makes_awakened_infusions_spill() -> void:
	var hex: ItemSetup = K.equip(_blade("hex"), ["ember", "storm"] as Array[String], 0, K.tuning().xp_to_resonant)
	var without := _sim([K.unit("hero", BIG_HP, FRONT, [hex, _blade("sword")])])
	assert_true(without.units[0].items[1].awakened())
	assert_eq(_received(without.units[0].items[2]), [] as Array[String], "awakened infusions never spill")
	var sim := _sim([K.unit("hero", BIG_HP, FRONT, [hex, _blade("sword"), _conduit("prism", "awakened")])])
	assert_eq(_received(sim.units[0].items[2]), ["Ember spill from Hex 6000", "Storm spill from Hex 6000"] as Array[String])
	var early: ItemSetup = K.equip(_blade("hex"), ["ember", "storm"] as Array[String], 0, 0)
	var asleep := _sim([K.unit("hero", BIG_HP, FRONT, [early, _blade("sword"), _conduit("prism", "awakened")])])
	assert_eq(_received(asleep.units[0].items[2]), [] as Array[String], "only once awakened")


func test_bond_chain_reaches_the_heroes_in_its_row() -> void:
	var chained: UnitSetup = K.unit("a", BIG_HP, FRONT, [_resonant_sword(), _conduit("chain", "row")])
	var beside: UnitSetup = K.unit("b", BIG_HP, FRONT, [_blade("knife"), _blade("bow", ["bow"] as Array[String])])
	var behind: UnitSetup = K.unit("c", BIG_HP, BACK, [_blade("dirk")])
	var sim := _sim([chained, beside, behind])
	var b: UnitState = sim.unit_by_id("b")
	assert_eq(_received(b.items[1]), ["Wrath spill from Sword 6000"] as Array[String], "a hero in the same row")
	assert_eq(_received(b.items[2]), [] as Array[String], "only through a shared keyword")
	assert_eq(_received(sim.unit_by_id("c").items[1]), [] as Array[String], "not the back row")
	var unchained := _sim([K.unit("a", BIG_HP, FRONT, [_resonant_sword()]), K.unit("b", BIG_HP, FRONT, [_blade("knife")])])
	assert_eq(_received(unchained.unit_by_id("b").items[1]), [] as Array[String], "spills stay in the loadout without it")


func test_bond_chain_spills_only_through_a_shared_keyword_and_ends_when_its_holder_falls() -> void:
	var chained: UnitSetup = K.unit("a", BIG_HP, FRONT, [_resonant_sword(), _conduit("chain", "row")])
	var beside: UnitSetup = K.unit("b", BIG_HP, FRONT, [_blade("bow", ["bow"] as Array[String]), _conduit("channel", "all_abilities"), _conduit("censer", "basic_attack")])
	var sim := _sim([chained, beside])
	var b: UnitState = sim.unit_by_id("b")
	assert_eq(_received(b.items[1]), [] as Array[String], "b's own conduits don't carry a's spill")
	assert_eq(_received(b.items[0]), [] as Array[String], "nor to b's basic attack")
	var knife := _sim([K.unit("a", BIG_HP, FRONT, [_resonant_sword(), _conduit("chain", "row")]), K.unit("b", BIG_HP, FRONT, [_blade("knife")])])
	var holder: UnitState = knife.unit_by_id("b")
	assert_eq(_received(holder.items[1]).size(), 1)
	knife.unit_by_id("a").hp = 0
	knife.step()
	assert_false(knife.unit_by_id("a").alive)
	assert_eq(_received(holder.items[1]), [] as Array[String], "the spill ends when the chain's holder falls")
