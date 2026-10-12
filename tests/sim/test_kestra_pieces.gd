extends GutTest
## The fight pieces Kestra's kit and paths added (phase 8 part 6, docs/plans/
## rebuild-phase8-last-heroes.md section 6, 8f-3), each in a small fight:
## companions (CompanionDef: beside their hero from the start, their HP and
## ATK shares of hers with her wounds, returning beside her if she stands,
## keeping no side up, nobody's fallen ally, their work hers), an ability
## done by a companion ("by": "companion"), a companion's effect scaled by
## its owner ("scaling_of": "owner"), an aura "per": "allied_summon" and the
## condition "summon", the trigger on_summon_fell, a summon of a companion
## kit that lasts, and a kit mod's "companions".

const K = preload("res://tests/sim/sim_test_kit.gd")


func _dummy(dummy_id: String, hp: int = 5000) -> UnitDef:
	return K.kit(dummy_id, {"stats": {"hp": hp, "speed": 0, "range": 1, "def": 0},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


## A companion kit: it bites for its ATK, standing still.
func _pet(pet_id: String = "pup", extra: Dictionary = {}) -> Dictionary:
	var data: Dictionary = {"id": pet_id, "name": pet_id.capitalize(), "stats": {"hp": 1, "atk": 1, "speed": 0, "range": 1},
		"basic_attack": {"id": pet_id + "_bite", "name": "Bite", "cooldown_ms": 1000,
			"effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}}
	data.merge(extra, true)
	return data


## A hero with companions (and anything in `extra`): HP 500, ATK 20.
func _keeper(companions: Array, extra: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 500, "atk": 20, "speed": 0, "range": 2}, "companions": companions}
	data.merge(extra, true)
	return K.kit("keeper", data)


func _companion(pet: Dictionary, return_ms: int = 0, starts: bool = true) -> Dictionary:
	var entry: Dictionary = {"kit": pet, "hp_pct": 40, "atk_pct": 60}
	if return_ms > 0:
		entry["return_ms"] = return_ms
	if not starts:
		entry["starts"] = false
	return entry


func test_a_companion_stands_beside_its_hero() -> void:
	var keeper: UnitSetup = K.at(_keeper([_companion(_pet())]), 3, 1)
	keeper.max_hp_bp = 8500
	var fight: CombatSim = K.sim(K.fight([keeper] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
	var pet: UnitState = fight.unit_by_id("pup")
	var owner: UnitState = fight.unit_by_id("keeper")
	assert_not_null(pet)
	assert_eq([pet.owner, pet.summoned, pet.side], [owner, true, EffectSource.Team.HEROES])
	assert_eq(pet.max_hp, 170, "40% of her 425 (500 with a wound)")
	assert_eq(pet.stats.get_stat(UnitStats.Stat.ATK), 12, "60% of her ATK")
	assert_eq(ArenaPlane.length_sq(pet.pos - owner.pos), (pet.radius + owner.radius) * (pet.radius + owner.radius), "touching her")
	var joined: LogEntry = K.entries(fight, LogEntry.Kind.SUMMON, "keeper")[0]
	assert_eq([joined.source_ability, joined.target, joined.amount, joined.note], ["pup", "pup", 170, ""], "sourced to her")


func test_a_companion_returns_while_its_hero_stands() -> void:
	var mourn: Dictionary = {"id": "mourn", "name": "Mourn", "trigger": {"kind": "ally_falls"}, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}
	var keeper: UnitSetup = K.at(_keeper([_companion(_pet(), 1000)], {"signature": mourn}), 3, 1)
	var ally: UnitSetup = K.at(_dummy("ally"), 5, 1)
	var fight: CombatSim = K.sim(K.fight([keeper, ally] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
	var pet: UnitState = fight.unit_by_id("pup")
	K.step(fight, 1)
	Statuses.apply(fight, pet, "root", 0, 100000, EffectSource.make("", "test", "Test"))
	pet.hp = 0
	K.step(fight, 1)
	assert_false(pet.alive)
	assert_eq(Passives.fallen_allies(fight, fight.unit_by_id("keeper")), 0, "it returns, so it's no fallen ally")
	assert_eq(fight.unit_by_id("keeper").signature.pending, 0, "nor sets off an ally falling")
	K.step(fight, 19)
	assert_false(pet.alive, "not yet")
	K.step(fight, 1)
	assert_true(pet.alive, "back after 1s")
	assert_eq(pet.hp, pet.max_hp)
	assert_true(pet.statuses.is_empty(), "its statuses gone")
	var back: LogEntry = K.entries(fight, LogEntry.Kind.SUMMON, "keeper").back()
	assert_eq(back.note, "returns")
	assert_eq(back.to_text(), "[1.10s] keeper · Pup: pup returns at %s" % LogEntry._point(pet.pos))
	pet.hp = 0
	K.step(fight, 1)
	fight.unit_by_id("keeper").hp = 0
	K.step(fight, 40)
	assert_false(pet.alive, "her down, it stays down")
	assert_false(fight.finished, "the ally stands")


func test_a_companion_keeps_no_side_up() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_keeper([_companion(_pet(), 1000)]), 3, 1)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
	K.step(fight, 1)
	fight.unit_by_id("keeper").hp = 0
	K.step(fight, 1)
	assert_true(fight.finished)
	assert_eq(fight.outcome, FightResult.Outcome.DEFEAT, "the pup alone doesn't hold the fight")


func test_an_ability_done_by_a_companion() -> void:
	var sic: Dictionary = {"id": "sic", "name": "Sic", "trigger": {"kind": "mana"}, "targeting": "nearest", "max_range": 6, "by": "companion",
		"effects": [{"type": "leap", "max_hexes": 6, "target": "target"}, {"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 20000}}]}
	var kit: UnitDef = _keeper([_companion(_pet(), 1000)], {"mana": {"max": 50, "per_attack": 0}, "signature": sic})
	var fight: CombatSim = K.sim(K.fight([K.at(kit, 3, 1)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 5), K.foe(_dummy("other"), 0, 6)] as Array[UnitSetup]))
	var owner: UnitState = fight.unit_by_id("keeper")
	var pet: UnitState = fight.unit_by_id("pup")
	pet.target = fight.unit_by_id("other")
	owner.mana = 50 * Mana.SCALE
	K.step(fight, 1)
	assert_eq(pet.target, fight.unit_by_id("mark"), "the enemy it leapt to is its target now")
	var fired: Array[LogEntry] = K.entries(fight, LogEntry.Kind.FIRE, "pup").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "sic")
	assert_eq(fired.size(), 1, "the pup does it, sourced to it")
	assert_eq(K.entries(fight, LogEntry.Kind.LEAP, "pup").size(), 1, "and leaps")
	var bitten: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "pup").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "sic")
	assert_eq(bitten.size(), 1)
	assert_eq(bitten[0].amount, 24, "200% of the pup's ATK, not hers")
	assert_eq(owner.mana, 0, "her bar pays")
	assert_eq(owner.signature.fires, 1, "and it counts as her signature's fire")
	pet.hp = 0
	K.step(fight, 1)
	owner.mana = 50 * Mana.SCALE
	K.step(fight, 5)
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE).filter(func(entry: LogEntry) -> bool: return entry.source_ability == "sic").size(), 1, "with it down, nothing fires")
	assert_eq(owner.mana, 50 * Mana.SCALE, "and the bar waits, full")


func test_a_passive_done_by_a_companion_may_leap() -> void:
	var habit: Array = [{"id": "sic", "name": "Sic", "kind": "ability", "by": "companion",
		"effects": [{"trigger": "on_basic_attack", "type": "leap", "max_hexes": 6, "target": "target"}]}]
	var kit: UnitDef = _keeper([_companion(_pet())], {"stats": {"hp": 500, "atk": 20, "speed": 0, "range": 4}, "passives": habit})
	var fight: CombatSim = K.sim(K.fight([K.at(kit, 3, 1)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4), K.foe(_dummy("other"), 0, 6)] as Array[UnitSetup]))
	fight.unit_by_id("pup").target = fight.unit_by_id("other")
	K.step(fight, 40)
	var leaps: Array[LogEntry] = K.entries(fight, LogEntry.Kind.LEAP, "pup")
	assert_gt(leaps.size(), 0, "her attack sends the pup")
	assert_eq([leaps[0].target, leaps[0].source_ability], ["mark", "sic"], "to her target")
	assert_eq(fight.unit_by_id("pup").target, fight.unit_by_id("mark"), "which is its target now")
	var errors: Array[String] = []
	habit[0].erase("by")
	PartDef.read(DataReader.new(habit[0], "passive", errors))
	assert_eq(errors.size(), 1, "without a companion, a passive can't leap")


func test_scaling_of_owner_reads_her_stats() -> void:
	var errors: Array[String] = []
	var effect: EffectDef = EffectDef.read(DataReader.new({"type": "apply_status", "status": "burn", "stacks": 0, "scaling": {"atk": 5000}, "scaling_of": "owner", "target": "target"}, "effect", errors))
	assert_eq(errors, [] as Array[String])
	var fight: CombatSim = K.sim(K.fight([K.at(_keeper([_companion(_pet())]), 3, 1)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
	var pet: UnitState = fight.unit_by_id("pup")
	assert_eq(EffectRunner.amount_of(effect, pet), 10, "half of her 20 ATK, not of its 12")
	assert_eq(EffectRunner.amount_of(effect, fight.unit_by_id("keeper")), 10, "one with no owner reads its own")


func test_per_allied_summon_and_the_summon_condition() -> void:
	var call: Array = [{"id": "call", "name": "Call", "kind": "aura", "aura": {"target": "holder", "stat": "atk_bp", "value": 11000, "per": "allied_summon"}}]
	var kit: UnitDef = _keeper([_companion(_pet("pup", {"passives": call})), _companion(_pet("cub"))], {"stats": {"atk": 100}})
	var fight: CombatSim = K.sim(K.fight([K.at(kit, 3, 1)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
	K.step(fight, 1)
	var pet: UnitState = fight.unit_by_id("pup")
	assert_eq(Passives.allied_summons(fight, pet), 2)
	assert_eq(pet.stats.get_stat(UnitStats.Stat.ATK), 72, "60, +10% for each of the two")
	fight.unit_by_id("cub").hp = 0
	K.step(fight, 2)
	assert_eq(pet.stats.get_stat(UnitStats.Stat.ATK), 66, "+10% for itself alone")
	var summon: UnitCondition = UnitCondition.read(DataReader.new({"summon": true}, "condition", []))
	assert_true(summon.holds(pet))
	assert_false(summon.holds(fight.unit_by_id("keeper")))
	assert_eq(summon.describe(), "a summon")


func test_a_summon_falling_is_heard() -> void:
	var fury: Array = [{"id": "fury", "name": "Fury", "kind": "ability", "effects": [{"trigger": "on_summon_fell", "type": "apply_status", "status": "pealing", "duration_ms": 4000, "target": "self"}]}]
	var kit: UnitDef = _keeper([_companion(_pet(), 1000)], {"passives": fury})
	var fight: CombatSim = K.sim(K.fight([K.at(kit, 3, 1)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
	K.step(fight, 1)
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "keeper").size(), 0)
	fight.unit_by_id("pup").hp = 0
	K.step(fight, 1)
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "keeper").map(func(entry: LogEntry) -> String: return entry.status), ["pealing"], "she hears it fall")


func test_a_summon_of_a_companion_kit_lasts() -> void:
	var brood: Dictionary = {"id": "brood", "name": "Brood", "trigger": {"kind": "fight_start"}, "targeting": "self",
		"effects": [{"type": "summon", "kit": "spawn", "count": 2, "placement": "adjacent", "lasts_ms": 1000}]}
	var fury: Array = [{"id": "fury", "name": "Fury", "kind": "ability", "effects": [{"trigger": "on_summon_fell", "type": "apply_status", "status": "pealing", "duration_ms": 4000, "target": "self"}]}]
	var kit: UnitDef = _keeper([_companion(_pet("spawn"), 0, false)], {"signature": brood, "passives": fury})
	var fight: CombatSim = K.sim(K.fight([K.at(kit, 3, 1)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
	assert_null(fight.unit_by_id("spawn"), "it doesn't start the fight")
	K.step(fight, 1)
	var spawn: Array[UnitState] = fight.units.filter(func(unit: UnitState) -> bool: return unit.def.id == "spawn")
	assert_eq(spawn.size(), 2)
	assert_eq([spawn[0].owner, spawn[0].max_hp, spawn[0].stats.get_stat(UnitStats.Stat.ATK)], [fight.unit_by_id("keeper"), 200, 12], "her companion, at her shares")
	K.step(fight, 21)
	assert_false(spawn[0].alive or spawn[1].alive, "1s, then they go")
	assert_eq(K.entries(fight, LogEntry.Kind.DEATH).filter(func(entry: LogEntry) -> bool: return entry.note == "its time is up").size(), 2)
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "keeper").size(), 0, "going quietly isn't a fall")


func test_a_companion_s_work_counts_for_its_owner() -> void:
	var walker: Dictionary = _pet("pup", {"stats": {"hp": 1, "atk": 1, "speed": 2, "range": 1}})
	var setup: UnitSetup = K.at(_keeper([_companion(walker)]), 3, 2)
	var errors: Array[String] = []
	setup.tally_keys.append("bites")
	setup.tally_counts.append(DeedDef.read(DataReader.new({"text": "x", "counts": "damage", "from_ability": ["pup_bite"]}, "count", errors)))
	assert_eq(errors, [] as Array[String])
	var fight: CombatSim = K.sim(K.fight([setup] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	K.step(fight, 3 * 20)
	var bites: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "pup")
	assert_gt(bites.size(), 0)
	assert_eq(CombatSim.result_of(fight).tally_amount("keeper", "bites"), bites.reduce(func(total: int, entry: LogEntry) -> int: return total + entry.amount, 0))


func test_a_kit_mod_changes_its_companions() -> void:
	var errors: Array[String] = []
	var mod: KitMod = KitMod.read(DataReader.new({"companions": [{"kit": "pup", "hp_add_pct": 15, "atk_add_pct": 15, "return_add_ms": -500, "mod": {"stats_add": {"def": 5}}}]}, "mod", errors))
	assert_eq(errors, [] as Array[String])
	var kit: UnitDef = _keeper([_companion(_pet(), 2000), _companion(_pet("cub"))])
	assert_true(mod.affects(kit))
	var built: UnitDef = mod.apply(kit, errors)
	assert_eq(errors, [] as Array[String])
	var pup: CompanionDef = built.companion("pup")
	assert_eq([pup.hp_bp, pup.atk_bp, pup.return_ticks, pup.kit.stats.get_stat(UnitStats.Stat.DEF)], [5500, 7500, 30, 5])
	assert_eq(built.companion("cub").hp_bp, 4000, "only the pup")
	assert_eq(kit.companion("pup").hp_bp, 4000, "the kit itself untouched")
	assert_eq(mod.times(2).companion_changes[0].hp_add_bp, 3000, "its steps add up")
	var other: KitMod = KitMod.read(DataReader.new({"companions": [{"kit": "hound", "hp_add_pct": 15}]}, "mod", errors))
	assert_false(other.affects(kit), "no hound to change")


func test_a_companion_fallen_into_the_void_is_heard_and_stays_down() -> void:
	var fury: Array = [{"id": "fury", "name": "Fury", "kind": "ability", "effects": [{"trigger": "on_summon_fell", "type": "apply_status", "status": "pealing", "duration_ms": 4000, "target": "self"}]}]
	var mourn: Dictionary = {"id": "mourn", "name": "Mourn", "trigger": {"kind": "ally_falls"}, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}
	var kit: UnitDef = _keeper([_companion(_pet(), 1000)], {"passives": fury, "signature": mourn})
	var fight: CombatSim = K.sim(K.fight([K.at(kit, 3, 1)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
	var pet: UnitState = fight.unit_by_id("pup")
	var owner: UnitState = fight.unit_by_id("keeper")
	K.step(fight, 1)
	pet.fell = true
	K.step(fight, 1)
	assert_false(pet.alive)
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "keeper").map(func(entry: LogEntry) -> String: return entry.status), ["pealing"], "she hears it fall")
	assert_eq(owner.signature.pending, 0, "it's no fallen ally")
	K.step(fight, 40)
	assert_false(pet.alive, "nothing comes back from the void")


func test_targets_owner_holds_on_enemies_at_its_hero() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_keeper([_companion(_pet())]), 3, 1)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 5), K.foe(_dummy("other"), 0, 6)] as Array[UnitSetup]))
	var errors: Array[String] = []
	var guard: UnitCondition = UnitCondition.read(DataReader.new({"targets_owner": true}, "condition", errors))
	assert_eq(errors, [] as Array[String])
	var pet: UnitState = fight.unit_by_id("pup")
	var mark: UnitState = fight.unit_by_id("mark")
	mark.target = fight.unit_by_id("keeper")
	fight.unit_by_id("other").target = pet
	assert_true(guard.holds(mark, pet), "it's after the pup's hero")
	assert_false(guard.holds(fight.unit_by_id("other"), pet), "not this one")
	assert_false(guard.holds(mark, fight.unit_by_id("keeper")), "the hero is nobody's companion")
	assert_eq(guard.describe(), "targeting its hero")


func test_chased_by_summons_counts_the_summons_on_it() -> void:
	var pack: Array = [{"id": "pack", "name": "Pack", "kind": "aura", "aura": {"target": "all_allies", "only": {"summon": true}, "stat": "damage_bp", "value": 15000,
		"vs": {"chased_by_summons": 2}}}]
	var kit: UnitDef = _keeper([_companion(_pet()), _companion(_pet("cub"))], {"passives": pack})
	var fight: CombatSim = K.sim(K.fight([K.at(kit, 3, 1)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 5), K.foe(_dummy("other"), 0, 6)] as Array[UnitSetup]))
	assert_true(fight.track_chasers, "a kit asks")
	var mark: UnitState = fight.unit_by_id("mark")
	var pup: UnitState = fight.unit_by_id("pup")
	var cub: UnitState = fight.unit_by_id("cub")
	pup.target = mark
	cub.target = fight.unit_by_id("other")
	fight.unit_by_id("keeper").target = mark
	fight.mark_chasers()
	assert_eq(mark.chased_by_summons, 1, "the hero doesn't count")
	assert_eq(Passives.vs_bonus_bp(pup, mark), 0, "one summon on it")
	cub.target = mark
	fight.mark_chasers()
	assert_eq(mark.chased_by_summons, 2)
	assert_eq(Passives.vs_bonus_bp(pup, mark), 5000, "two: the pack hits harder")
	var errors: Array[String] = []
	assert_eq(UnitCondition.read(DataReader.new({"chased_by_summons": 2}, "condition", errors)).describe(), "attacked by 2 or more summons")
	var plain: CombatSim = K.sim(K.fight([K.at(_keeper([_companion(_pet())]), 3, 1)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
	assert_false(plain.track_chasers, "no kit asks: no counting")


func test_summoned_counts_the_summons_she_brings() -> void:
	var nest: Dictionary = {"id": "nest", "name": "Nest", "trigger": {"kind": "mana"}, "targeting": "self",
		"effects": [{"type": "summon", "kit": "cub", "count": 2, "placement": "adjacent", "lasts_ms": 1000}]}
	var kit: UnitDef = _keeper([_companion(_pet(), 1000), _companion(_pet("cub"), 0, false)], {"mana": {"max": 50, "per_attack": 0}, "signature": nest})
	var setup: UnitSetup = K.at(kit, 3, 1)
	var errors: Array[String] = []
	setup.tally_keys.append("joined")
	setup.tally_counts.append(DeedDef.read(DataReader.new({"text": "x", "counts": "summoned"}, "count", errors)))
	assert_eq(errors, [] as Array[String])
	var fight: CombatSim = K.sim(K.fight([setup] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
	fight.unit_by_id("keeper").mana = 50 * Mana.SCALE
	K.step(fight, 2)
	fight.unit_by_id("pup").hp = 0
	K.step(fight, 22)
	assert_eq(CombatSim.result_of(fight).tally_amount("keeper", "joined"), 4, "the pup at the start, 2 cubs, and the pup's return")


func test_a_small_hit_carries_its_bonus_over() -> void:
	var call: Array = [{"id": "call", "name": "Call", "kind": "aura", "aura": {"target": "holder", "stat": "damage_bp", "value": 10300, "from_basic": true}}]
	var setup: UnitSetup = K.at(_keeper([_companion(_pet("pup", {"passives": call, "stats": {"hp": 1, "atk": 1, "speed": 2, "range": 1}}))]), 3, 2)
	var errors: Array[String] = []
	setup.tally_keys.append("called")
	setup.tally_counts.append(DeedDef.read(DataReader.new({"text": "x", "counts": "bonus_damage", "from_part": ["call"]}, "count", errors)))
	assert_eq(errors, [] as Array[String])
	var fight: CombatSim = K.sim(K.fight([setup] as Array[UnitSetup], [K.foe(_dummy("mark", 50000), 3, 4)] as Array[UnitSetup]))
	assert_eq(fight.unit_by_id("pup").bonus_parts, ["call"] as Array[String], "the pup's hits read for her")
	K.step(fight, 20 * 20)
	var bites: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "pup")
	var dealt: int = bites.reduce(func(total: int, entry: LogEntry) -> int: return total + entry.amount, 0)
	assert_gt(bites.size(), 10)
	assert_lt(bites[0].amount * 300 / 10300, 1, "3% of one bite is short of a point")
	assert_almost_eq(CombatSim.result_of(fight).tally_amount("keeper", "called"), dealt * 300 / 10300, 1, "but the bites add up to their 3%")


func test_a_companion_s_abilities_count_for_its_hero_s_deeds() -> void:
	var kit: UnitDef = _keeper([_companion(_pet())])
	assert_eq(kit.ability_ids(), ["keeper_attack"] as Array[String])
	assert_true(kit.ability_ids_with_companions().has("pup_bite"))
	assert_false(kit.ability_ids().has("pup_bite"), "its own are its own")


func test_a_summoned_companion_reads_its_hits_for_her_too() -> void:
	var nest: Dictionary = {"id": "nest", "name": "Nest", "trigger": {"kind": "mana"}, "targeting": "self",
		"effects": [{"type": "summon", "kit": "cub", "count": 1, "placement": "adjacent", "lasts_ms": 1000}]}
	var setup: UnitSetup = K.at(_keeper([_companion(_pet("cub"), 0, false)], {"mana": {"max": 50, "per_attack": 0}, "signature": nest}), 3, 1)
	var errors: Array[String] = []
	setup.tally_keys.append("called")
	setup.tally_counts.append(DeedDef.read(DataReader.new({"text": "x", "counts": "bonus_damage", "from_part": ["call"]}, "count", errors)))
	var fight: CombatSim = K.sim(K.fight([setup] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
	fight.unit_by_id("keeper").mana = 50 * Mana.SCALE
	K.step(fight, 2)
	var cub: UnitState = fight.unit_by_id("cub")
	assert_not_null(cub)
	assert_eq(cub.bonus_parts, ["call"] as Array[String])
