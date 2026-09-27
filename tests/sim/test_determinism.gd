extends GutTest
## CLAUDE.md rule 1: same seed + same inputs = same fight, every time.
## These must keep passing through every change to the sim.

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT := UnitSetup.Row.FRONT
const BACK := UnitSetup.Row.BACK


## A fight that leans on randomness: random targets, frequent crits, and
## all eight essences (conversions, statuses, Storm's extra fires, Umbral crits),
## a mid-fight level-up to Resonant that starts a keyword spill, awakened
## alloys (Inferno,
## Plasma's jumping burn), auras with windows (row allies, the holder's
## other items), and relics on both sides
## (a grant, filtered and side-wide auras, and every relic trigger), and
## real synergies (Paper Cuts' charge, the Wildfire Torch transformation,
## and Ember Resonance), specializations at rank S (one with a new basic
## attack and auto-attack grants), a real innate, and an enemy with the Act 1
## boss's phases.
func _chaotic_fight(seed_value: int) -> FightSetup:
	var scatter: ItemDef = K.item("scatter", {"cooldown_ms": 700, "crit_chance_bp": 3000, "effects": K.damage(9, "enemy_random")})
	var cleave: ItemDef = K.item("cleave", {"rarity": "epic", "tags": ["weapon"], "cooldown_ms": 2150, "crit_chance_bp": 2000, "effects": K.damage(25)})
	var mend: ItemDef = K.item("mend", {"cooldown_ms": 1650, "xp_per_fire": 5, "effects": [{"trigger": "on_fire", "type": "heal", "amount": 12, "target": "ally_lowest_hp"}]})
	var hex: ItemDef = K.item("hex", {"rarity": "epic", "cooldown_ms": 1300, "effects": K.damage(12, "enemy_random")})
	var drum: ItemDef = K.item("drum", {"cooldown_ms": 2000, "effects": K.damage(3, "all_enemies"), "auras": [
		{"target": "row_allies", "stat": "damage_bp", "value": 15000, "window": {"until_ms": 10000}},
		{"target": "holder_items", "stat": "crit_chance_bp", "value": 2000}]})
	var claw: ItemDef = K.item("claw", {"cooldown_ms": 900, "crit_chance_bp": 2500, "effects": K.damage(7, "enemy_random")})
	var setup: FightSetup = FightSetup.make(
		[K.unit("warden", 420, FRONT, [K.equip(cleave, ["ember", "ember"] as Array[String], 0, 300), drum]), K.unit("striker", 300, FRONT, [K.equip(scatter, ["umbral"] as Array[String], 0, 300), K.content().items["whetstone"], K.content().items["twin_daggers"], K.equip(K.content().items["tallow_torch"], ["ember"] as Array[String])]), K.unit("mender", 260, BACK, [K.equip(mend, ["verdant"] as Array[String], 0, 280), K.equip(scatter, ["stone"] as Array[String])]), _vell()],
		[K.unit("ghoul_a", 380, FRONT, [K.equip(claw, ["frost"] as Array[String])]), K.unit("ghoul_b", 380, FRONT, [K.equip(claw, ["venom"] as Array[String])]), K.unit("shade", 300, BACK, [K.equip(claw, ["wrath"] as Array[String]), K.equip(hex, ["ember", "storm"] as Array[String], 0, 300)])],
		seed_value, 1)
	setup.relics = ["warding_knot", "pilgrims_flask", "cinder_crown", "hourglass", "emberglass"] as Array[String]
	setup.enemy_relics = ["gloam_totem", "kindled_seal"] as Array[String]
	setup.heroes[0].rank = 3
	setup.heroes[0].specialization = _real_spec_for("brannoc_ironbrand", "warden")
	setup.heroes[3].rank = 3
	setup.heroes[3].specialization = K.content().specializations["vell_vigil_keeper"]
	setup.enemies[0].phases = K.content().enemies["mother_ash"].phases
	return setup


## A real specialization, handed to a test unit with a different id.
func _real_spec_for(spec_id: String, unit_id: String) -> SpecializationDef:
	for entry: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/specializations.json")):
		if entry["id"] == spec_id:
			entry["hero"] = unit_id
			var errors: Array[String] = []
			var def: SpecializationDef = SpecializationDef.read(DataReader.new(entry, spec_id, errors))
			assert(errors.is_empty(), str(errors))
			return def
	return null


## Vell with her real innate (Lantern Vigil) and a passive.
func _vell() -> UnitSetup:
	var vell: UnitSetup = K.unit("vell", 260, BACK, [K.item("chime", {"rarity": "uncommon", "slot": "passive", "effects": null,
		"auras": [{"target": "row_allies", "stat": "heal_bp", "value": 12000}]})])
	vell.innate = K.content().heroes["vell"].innate
	return vell


func test_same_seed_same_log() -> void:
	var first: FightResult = CombatSim.run(_chaotic_fight(5), K.content())
	var second: FightResult = CombatSim.run(_chaotic_fight(5), K.content())
	assert_eq(first.errors, [] as Array[String])
	assert_gt(first.combat_log.entries.size(), 100, "a real fight happened")
	assert_gt(first.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED).size(), 0, "statuses are in play")
	assert_gt(first.combat_log.of_kind(LogEntry.Kind.INFUSION_LEVEL).size(), 0, "an infusion levels up")
	assert_eq(first.combat_log.of_kind(LogEntry.Kind.AURA).size() >= 2, true, "auras start and end")
	assert_string_contains(first.combat_log.to_text(), "(Cinder Crown) applies", "a relic grant fires")
	assert_string_contains(first.combat_log.to_text(), "relic · Pilgrim's Flask heals", "a cooldown relic fires")
	for expected: String in ["ghoul_a enters Molt", "warden · Brand Blow", "(Ironbrand S) charges", "vell · Shelter (Vigil Keeper A)", "vell · Lantern Vigil", "Paper Cuts: striker", "Wildfire Torch: striker", "Ember Resonance (3): 3 Ember", "(Paper Cuts) charges Whetstone", "Golden Flame to", "Plasma to", "Verdant spill from Test Item"]:
		assert_string_contains(first.combat_log.to_text(), expected)
	assert_eq(first.combat_log.to_text(), second.combat_log.to_text())
	assert_eq(first.outcome, second.outcome)
	assert_eq(first.end_tick, second.end_tick)


func test_different_seed_different_log() -> void:
	var first: FightResult = CombatSim.run(_chaotic_fight(5), K.content())
	var other: FightResult = CombatSim.run(_chaotic_fight(6), K.content())
	assert_ne(first.combat_log.to_text(), other.combat_log.to_text())


func test_stepping_matches_running() -> void:
	var ran: FightResult = CombatSim.run(_chaotic_fight(9), K.content())
	var sim := CombatSim.new(_chaotic_fight(9), K.content())
	while not sim.finished:
		sim.step()
	assert_eq(sim.combat_log.to_text(), ran.combat_log.to_text())
