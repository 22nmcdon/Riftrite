extends GutTest
## Backup heroes: off the field, acting through their Backup effect and their
## items' backup modes (docs/plans/backup-in-sim.md).

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT := UnitSetup.Row.FRONT
const BIG_HP: int = 10000000


func _idle() -> ItemDef:
	return K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)})


func _benched(unit_id: String, items: Array = [], backup: BackupDef = null, stats: UnitStats = null) -> UnitSetup:
	var setup: UnitSetup = K.unit(unit_id, BIG_HP, FRONT, items, K.basic("swing", {"effects": K.damage(50)}))
	if stats != null:
		setup.stats = stats
	setup.backup = backup
	return setup


func _vigil() -> BackupDef:
	return K.backup({"name": "Lantern Vigil", "cooldown_ms": 5000, "effects": [
		{"trigger": "on_fire", "type": "heal", "amount": 4, "scaling": {"mgk": 3000}, "target": "ally_lowest_hp"}]})


func _item_errors(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var full: Dictionary = K.DEFAULT_ITEM.duplicate(true)
	full.merge(data, true)
	full["id"] = "x"
	ItemDef.read(DataReader.new(full, "x", errors))
	return errors


func _has(errors: Array[String], expected: String) -> bool:
	return errors.any(func(message: String) -> bool: return message.contains(expected))


# --- off the field ----------------------------------------------------------------------

func test_backup_heroes_are_never_hit() -> void:
	var claw: ItemDef = K.item("claw", {"effects": K.damage(5, "enemy_random")})
	var result: FightResult = K.run([K.unit("hero", BIG_HP, FRONT, [], _idle())], [K.unit("foe", BIG_HP, FRONT, [claw], _idle())], 1, 1,
		[_benched("vell", [], _vigil())])
	for entry: LogEntry in result.combat_log.entries:
		assert_ne(entry.target, "vell", entry.to_text())
	assert_gt(result.combat_log.of_kind(LogEntry.Kind.COLLAPSE).size(), 0, "collapse happened, but not to the bench")


func test_bench_doesnt_count_for_victory() -> void:
	var result: FightResult = K.run([K.dummy("hero", 10)], [K.unit("foe", BIG_HP, FRONT, [K.item("club", {"effects": K.damage(100)})], _idle())], 1, 1,
		[_benched("vell", [], _vigil())])
	assert_eq(result.outcome, FightResult.Outcome.DEFEAT)


# --- what acts from backup ------------------------------------------------------------

func test_hero_backup_effect_fires_and_scales_from_their_stats() -> void:
	var result: FightResult = K.run([K.unit("hero", BIG_HP, FRONT, [], _idle())], [K.dummy("foe", BIG_HP)], 1, 1,
		[_benched("vell", [], _vigil(), UnitStats.make(260, 0, 20))])
	var fires: Array[LogEntry] = K.entries(result, LogEntry.Kind.FIRE, "vell_backup")
	assert_eq(fires[0].to_text(), "[5.00s] vell · Lantern Vigil (backup) fires")
	var sim := CombatSim.new(FightSetup.make([K.unit("hero", BIG_HP, FRONT, [], _idle())] as Array[UnitSetup], [K.dummy("foe", BIG_HP)] as Array[UnitSetup], 1, 1,
		[_benched("vell", [], _vigil(), UnitStats.make(260, 0, 20))] as Array[UnitSetup]), K.content())
	assert_eq(sim.bench[0].items[0].describe_values(), PackedStringArray(["heal: 10 (base 4 + 30% MGK 6 = 10)"]))


func test_backup_aura_boosts_the_fielded_team() -> void:
	var watch: BackupDef = K.backup({"auras": [{"target": "all_allies", "stat": "def_bp", "value": 11000}]})
	var hero: UnitSetup = K.unit_with("hero", UnitStats.make(BIG_HP, 0, 0, 50), FRONT, [], _idle())
	var sim := CombatSim.new(FightSetup.make([hero] as Array[UnitSetup], [K.dummy("foe", BIG_HP)] as Array[UnitSetup], 1, 1,
		[_benched("brannoc", [], watch)] as Array[UnitSetup]), K.content())
	assert_eq(sim.heroes[0].stats.get_stat(UnitStats.Stat.DEF), 55)


func test_only_items_with_a_backup_mode_act_from_backup() -> void:
	var lantern: ItemDef = K.item("lantern", {"name": "Lantern", "rarity": "uncommon", "effects": K.damage(1),
		"backup": {"cooldown_ms": 2000, "effects": [{"trigger": "on_fire", "type": "heal", "amount": 3, "target": "ally_lowest_hp"}]}})
	var knife: ItemDef = K.item("knife", {"effects": K.damage(9)})
	var result: FightResult = K.run([K.unit("hero", BIG_HP, FRONT, [], _idle())], [K.dummy("foe", BIG_HP)], 1, 1,
		[_benched("vell", [lantern, knife])])
	var sources: Dictionary[String, bool] = {}
	for entry: LogEntry in result.combat_log.of_kind(LogEntry.Kind.FIRE):
		if entry.source_unit == "vell":
			sources[entry.source_item_name] = true
	assert_eq(sources.keys(), ["Lantern (backup)"], "no knife, no basic attack, no normal lantern")


func test_infusions_work_and_earn_xp_in_backup() -> void:
	var brand: ItemDef = K.item("brand", {"name": "Brand", "rarity": "uncommon", "xp_per_fire": 3, "effects": K.damage(1),
		"backup": {"cooldown_ms": 1000, "effects": [{"trigger": "on_fire", "type": "damage", "amount": 100, "target": "enemy_front"}]}})
	var result: FightResult = K.run([K.unit("hero", BIG_HP, FRONT, [], _idle())], [K.dummy("foe", BIG_HP)], 1, 1,
		[_benched("odo", [K.equip(brand, ["ember"] as Array[String])])])
	var burn: LogEntry = result.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED)[0]
	assert_eq(burn.to_text(), "[1.00s] odo · Brand (backup) [Ember] applies 5 Burn to foe (5 total)")
	var infusion: FightResult.InfusionResult = result.infusions[0]
	assert_eq([infusion.unit_id, infusion.item_id], ["odo", "brand"])
	assert_gt(infusion.xp_after, infusion.xp_before + 10, "fires plus the battle")


func test_backup_only_item_does_nothing_fielded() -> void:
	var chime: ItemDef = K.item("chime", {"name": "Chime", "rarity": "uncommon", "backup_only": true, "effects": [],
		"backup": {"auras": [{"target": "all_allies", "stat": "heal_bp", "value": 12000}]}})
	var mend: ItemDef = K.item("mend", {"effects": [{"trigger": "on_fire", "type": "heal", "amount": 10, "target": "self"}]})
	var fielded: FightResult = K.run([K.unit("hero", BIG_HP, FRONT, [chime, mend], _idle())], [K.dummy("foe", BIG_HP)])
	assert_eq(K.entries(fielded, LogEntry.Kind.FIRE, "chime").size(), 0)
	var sim := CombatSim.new(FightSetup.make([K.unit("hero", BIG_HP, FRONT, [mend], _idle())] as Array[UnitSetup], [K.dummy("foe", BIG_HP)] as Array[UnitSetup], 1, 1,
		[_benched("vell", [chime])] as Array[UnitSetup]), K.content())
	assert_eq(sim.heroes[0].items[1].describe_values(), PackedStringArray(["heal: 12 (base 10, x1.2 Chime (backup))"]))


# --- rules ---------------------------------------------------------------------------------

func test_backup_blocks_are_checked() -> void:
	var cases: Dictionary[String, Dictionary] = {
		"needs a spot on the field": {"cooldown_ms": 1000, "effects": [{"trigger": "on_fire", "type": "heal", "amount": 1, "target": "self"}]},
		"a backup aura can only target all_allies": {"auras": [{"target": "holder", "stat": "atk_bp", "value": 11000}]},
		"missing required key \"cooldown_ms\"": {"effects": [{"trigger": "on_fire", "type": "heal", "amount": 1, "target": "all_allies"}]},
		"a backup needs effects or auras": {"name": "Empty"},
	}
	for expected: String in cases:
		var errors: Array[String] = []
		BackupDef.read(DataReader.new(cases[expected], "backup", errors), false)
		assert_true(_has(errors, expected), "%s in %s" % [expected, errors])


func test_backup_modes_by_rarity() -> void:
	var backup: Dictionary = {"auras": [{"target": "all_allies", "stat": "def_bp", "value": 11000}]}
	assert_true(_has(_item_errors({"rarity": "common", "backup": backup}), "Common items can't have a backup mode"))
	assert_true(_has(_item_errors({"rarity": "legendary"}), "Legendary items must have a backup mode"))
	assert_eq(_item_errors({"rarity": "legendary", "backup": backup}), [] as Array[String])
	assert_true(_has(_item_errors({"rarity": "rare", "backup_only": true}), "a backup-only item needs a backup mode"))


func test_roster_limits() -> void:
	var six: Array[UnitSetup] = []
	for i: int in 6:
		six.append(K.dummy("h%d" % i, 100))
	assert_true(_has(K.run(six, [K.dummy("foe", 100)]).errors, "6 heroes fielded; the limit is 5"))
	var five: Array[UnitSetup] = six.slice(0, 5)
	var bench: Array[UnitSetup] = [K.dummy("b1", 100), K.dummy("b2", 100)]
	assert_true(_has(K.run(five, [K.dummy("foe", 100)], 1, 1, bench).errors, "7 heroes in the roster; the cap is 6"))
