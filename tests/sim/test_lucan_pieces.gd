extends GutTest
## The fight pieces Lucan's kit added (phase 8 part 6, docs/plans/
## rebuild-phase8-last-heroes.md section 7, 8f-4), each in a small fight:
## copies (a summon's "copy_of": the caster or each standing hero, beside
## it, its kit as it stands with its HP, ATK, and MGK at a share and its
## basic attack only; the caster's, keeping no side up, nobody's fallen ally,
## their work its own; going quietly when their time is up; max_standing
## counting every copy on the side).

const K = preload("res://tests/sim/sim_test_kit.gd")


func _dummy(dummy_id: String, hp: int = 5000) -> UnitDef:
	return K.kit(dummy_id, {"stats": {"hp": hp, "speed": 0, "range": 1, "def": 0},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


## A caster whose signature makes `copy` (a summon's fields) as the fight
## starts, with a passive a copy shouldn't carry.
func _caster(copy: Dictionary, caster_id: String = "caster", extra: Dictionary = {}) -> UnitDef:
	var summon: Dictionary = {"type": "summon"}
	summon.merge(copy, true)
	var data: Dictionary = {"stats": {"hp": 400, "atk": 20, "mgk": 30, "def": 6, "speed": 0, "range": 3},
		"basic_attack": {"id": "glint", "name": "Glint", "cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"mgk": 10000}}]},
		"signature": {"id": "mirror", "name": "Mirror", "trigger": {"kind": "fight_start"}, "targeting": "self", "effects": [summon]},
		"passives": [{"id": "veil", "name": "Veil", "kind": "aura", "aura": {"target": "holder", "stat": "evade_bp", "value": 1500}}]}
	data.merge(extra, true)
	return K.kit(caster_id, data)


func _read(effect: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	EffectDef.read(DataReader.new(effect, "effect", errors))
	return errors


func _copies(fight: CombatSim) -> Array[UnitState]:
	return fight.units.filter(func(unit: UnitState) -> bool: return unit.mirror_of != null)


func test_reading_a_copy() -> void:
	assert_eq(_read({"type": "summon", "copy_of": "self", "share_pct": 30, "lasts_ms": 6000}), [] as Array[String])
	assert_eq(_read({"type": "summon", "copy_of": "each_ally", "share_pct": 30, "lasts_ms": 6000, "max_standing": 3}), [] as Array[String])
	for bad: Dictionary in [
			{"type": "summon", "copy_of": "self", "share_pct": 30},
			{"type": "summon", "copy_of": "self", "share_pct": 0, "lasts_ms": 6000},
			{"type": "summon", "copy_of": "self", "share_pct": 30, "lasts_ms": 6000, "kit": "pup"},
			{"type": "summon", "copy_of": "self", "share_pct": 30, "lasts_ms": 6000, "count": 2},
			{"type": "summon", "copy_of": "self", "share_pct": 30, "lasts_ms": 6000, "placement": "edges"},
			{"type": "summon", "copy_of": "them", "share_pct": 30, "lasts_ms": 6000}]:
		assert_ne(_read(bad), [] as Array[String], str(bad))
	assert_eq(_caster({"copy_of": "self", "share_pct": 30, "lasts_ms": 1000}).summon_ids(), [] as Array[String], "a copy names no kit")


func test_a_copy_of_itself() -> void:
	var hale: Dictionary = {"id": "hale", "name": "Hale", "kind": "aura", "aura": {"target": "holder", "stat": "max_hp_bp", "value": 12000}}
	var caster: UnitSetup = K.at(_caster({"copy_of": "self", "share_pct": 30, "lasts_ms": 1000}, "caster", {"passives": [hale]}), 3, 1)
	caster.max_hp_bp = 8500
	var fight: CombatSim = K.sim(K.fight([caster] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	assert_eq(fight.setup.validate(K.content()), [] as Array[String])
	K.step(fight, 1)
	var copies: Array[UnitState] = _copies(fight)
	assert_eq(copies.size(), 1)
	var copy: UnitState = copies[0]
	var owner: UnitState = fight.unit_by_id("caster")
	assert_eq([copy.id, copy.def.name, copy.owner, copy.mirror_of, copy.summoned, copy.side], ["caster_copy", "Copy of Caster", owner, owner, true, EffectSource.Team.HEROES])
	assert_eq(copy.max_hp, 102, "30% of its 340 (400 with a wound), not of what an aura adds in the fight")
	assert_gt(owner.max_hp, 340)
	assert_eq([copy.stats.get_stat(UnitStats.Stat.ATK), copy.stats.get_stat(UnitStats.Stat.MGK), copy.stats.get_stat(UnitStats.Stat.DEF), copy.stats.get_stat(UnitStats.Stat.RANGE)], [6, 9, 6, 3],
		"its ATK and MGK at the share, the rest its own")
	assert_eq([copy.def.signature, copy.def.mana, copy.def.passives.size()], [null, null, 0], "its basic attack only")
	assert_eq(copy.def.basic_attack, owner.def.basic_attack)
	assert_eq(ArenaPlane.length_sq(copy.pos - owner.pos), (copy.radius + owner.radius) * (copy.radius + owner.radius), "beside it")
	var joined: LogEntry = K.entries(fight, LogEntry.Kind.SUMMON, "caster")[0]
	assert_eq([joined.source_ability, joined.target, joined.note, joined.end_tick], ["mirror", "caster_copy", "", copy.expires_at])
	K.step(fight, 30)
	assert_gt(K.entries(fight, LogEntry.Kind.DAMAGE, "caster_copy").size(), 0, "it casts its Glint")
	assert_false(copy.alive, "1s, then it goes")
	assert_eq(K.entries(fight, LogEntry.Kind.DEATH).filter(func(entry: LogEntry) -> bool: return entry.target == "caster_copy")[0].note, "its time is up")


func test_a_copy_carries_its_basic_attack_as_it_stands() -> void:
	var setup: UnitSetup = K.at(_caster({"copy_of": "self", "share_pct": 50, "lasts_ms": 1000}, "caster", {"traits": ["engage"]}), 3, 1)
	var errors: Array[String] = []
	var mod: KitMod = KitMod.read(DataReader.new({"on": [{"slot": "basic_attack", "amount_bp": 15000}]}, "mod", errors))
	assert_eq(errors, [] as Array[String])
	setup.def = mod.apply(setup.def, errors)
	var fight: CombatSim = K.sim(K.fight([setup] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	K.step(fight, 1)
	var copy: UnitState = _copies(fight)[0]
	assert_eq(copy.def.basic_attack.effects[0].power_bp, fight.unit_by_id("caster").def.basic_attack.effects[0].power_bp, "its upgrades with it")
	assert_ne(copy.def.basic_attack.effects[0].power_bp, 0)
	assert_false(copy.def.has_trait("engage"), "no Engage")


func test_a_copy_of_each_hero() -> void:
	var caster: UnitSetup = K.at(_caster({"copy_of": "each_ally", "share_pct": 40, "lasts_ms": 2000}), 3, 1)
	var fight: CombatSim = K.sim(K.fight([caster, K.at(_dummy("ally", 500), 5, 1), K.at(_dummy("fallen", 500), 1, 1)] as Array[UnitSetup],
		[K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
	fight.unit_by_id("fallen").alive = false
	K.step(fight, 1)
	var copies: Array[UnitState] = _copies(fight)
	assert_eq(copies.map(func(unit: UnitState) -> String: return unit.mirror_of.id), ["caster", "ally"], "each standing hero, the caster too")
	assert_eq(copies[1].max_hp, 200, "40% of the ally's HP")
	assert_eq(copies[1].owner, fight.unit_by_id("caster"), "the caster's copy")
	var ally: UnitState = fight.unit_by_id("ally")
	assert_eq(ArenaPlane.length_sq(copies[1].pos - ally.pos), (ally.radius + copies[1].radius) * (ally.radius + copies[1].radius), "beside the one it copies")


func test_max_standing_counts_every_copy() -> void:
	var reflect: Dictionary = {"id": "reflect", "name": "Reflect", "kind": "ability",
		"effects": [{"trigger": "on_interval", "interval_ms": 100, "type": "summon", "copy_of": "self", "share_pct": 20, "lasts_ms": 5000, "max_standing": 3}]}
	var fight: CombatSim = K.sim(K.fight([K.at(_caster({"copy_of": "each_ally", "share_pct": 30, "lasts_ms": 5000}, "caster", {"passives": [reflect]}), 3, 1),
		K.at(_dummy("ally", 500), 5, 1)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
	K.step(fight, 20)
	var standing: Array[UnitState] = _copies(fight).filter(func(unit: UnitState) -> bool: return unit.alive)
	assert_eq(standing.size(), 3, "the Mirror's copies of both count toward Reflect's 3")
	assert_eq(standing.filter(func(unit: UnitState) -> bool: return unit.def.id == "caster_copy").size(), 2, "so Reflect adds one")
	assert_gt(K.entries(fight, LogEntry.Kind.SUMMON, "caster").filter(func(entry: LogEntry) -> bool: return entry.note == "enough stand").size(), 0)


func test_a_copy_keeps_no_side_up_and_is_no_fallen_ally() -> void:
	var mourn: Dictionary = {"id": "mourn", "name": "Mourn", "trigger": {"kind": "ally_falls"}, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}
	var watcher: UnitDef = K.kit("watcher", {"stats": {"hp": 500, "speed": 0, "range": 1}, "signature": mourn,
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(_caster({"copy_of": "self", "share_pct": 30, "lasts_ms": 5000}), 3, 1), K.at(watcher, 5, 1)] as Array[UnitSetup],
		[K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
	K.step(fight, 1)
	var copy: UnitState = _copies(fight)[0]
	copy.hp = 0
	K.step(fight, 1)
	assert_false(copy.alive)
	assert_eq(fight.unit_by_id("watcher").signature.pending, 0, "a copy falling sets off no ally falling")
	assert_eq(Passives.fallen_allies(fight, fight.unit_by_id("watcher")), 0)
	var other: CombatSim = K.sim(K.fight([K.at(_caster({"copy_of": "self", "share_pct": 30, "lasts_ms": 5000}), 3, 1)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
	K.step(other, 1)
	other.unit_by_id("caster").hp = 0
	K.step(other, 1)
	assert_true(other.finished)
	assert_eq(other.outcome, FightResult.Outcome.DEFEAT, "its copy alone doesn't hold the fight")


func test_a_copy_s_work_counts_for_its_caster() -> void:
	var setup: UnitSetup = K.at(_caster({"copy_of": "self", "share_pct": 30, "lasts_ms": 5000}), 3, 1)
	var errors: Array[String] = []
	setup.tally_keys.append("glints")
	setup.tally_counts.append(DeedDef.read(DataReader.new({"text": "x", "counts": "damage", "from_ability": ["glint"]}, "count", errors)))
	assert_eq(errors, [] as Array[String])
	var fight: CombatSim = K.sim(K.fight([setup] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	K.step(fight, 3 * 20)
	var glints: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE).filter(func(entry: LogEntry) -> bool: return entry.source_ability == "glint")
	assert_gt(glints.filter(func(entry: LogEntry) -> bool: return entry.source_unit == "caster_copy").size(), 0)
	assert_eq(CombatSim.result_of(fight).tally_amount("caster", "glints"), glints.reduce(func(total: int, entry: LogEntry) -> int: return total + entry.amount, 0),
		"its own and its copy's")


func test_a_copy_falling_is_a_summon_falling() -> void:
	var heard: Array = [{"id": "heard", "name": "Heard", "kind": "ability", "effects": [{"trigger": "on_summon_fell", "type": "apply_status", "status": "pealing", "duration_ms": 4000, "target": "self"}]}]
	var fight: CombatSim = K.sim(K.fight([K.at(_caster({"copy_of": "self", "share_pct": 30, "lasts_ms": 5000}, "caster", {"passives": heard}), 3, 1)] as Array[UnitSetup],
		[K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
	K.step(fight, 1)
	_copies(fight)[0].hp = 0
	K.step(fight, 1)
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "caster").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "heard").size(), 1, "on_summon_fell hears it")


func test_its_numbers_line() -> void:
	var content: ContentDb = K.content()
	var kit: UnitDef = content.heroes["lucan"].kit
	assert_eq(UnitInfo.signature_numbers(kit, content), "At 60 mana · a copy of itself at 30% of its stats for 6s")
