extends GutTest
## Confused and controlled (phase 8 part 6, docs/plans/rebuild-phase8-last-heroes.md
## 8f-4; Decision 7): a confused enemy attacks the nearest other unit of its
## own side; a controlled one fights for the side of whoever set it, owned by
## them, keeping no side up, nobody's fallen ally, and goes back as it ends;
## an elite or a boss takes the status's stand-in instead; a Taunt wins over
## both. And the pieces Lucan's apexes need: on_enemy_lost_target and the
## deed count lost_target, on_controlled_fell, a copy's growing share and
## one cast, the aura per summon joined, on_ally_below_hp's "enemies", and
## the deed filters copies and from_stealth and the count status_ms.

const K = preload("res://tests/sim/sim_test_kit.gd")


func _dummy(dummy_id: String, hp: int = 5000, atk: int = 0, extra: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {"stats": {"hp": hp, "atk": atk, "speed": 2, "range": 1, "def": 0},
		"basic_attack": {"cooldown_ms": 500, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}}
	data.merge(extra, true)
	return K.kit(dummy_id, data)


func _status(fight: CombatSim, unit_id: String, status_id: String, by: String, ticks: int = 0) -> void:
	var by_unit: UnitState = fight.unit_by_id(by)
	Statuses.apply(fight, fight.unit_by_id(unit_id), status_id, 1, ticks, by_unit.own_source)


func test_a_confused_enemy_turns_on_its_own() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_dummy("hero", 50000, 0), 3, 1)] as Array[UnitSetup],
		[K.foe(_dummy("biter", 5000, 20), 3, 4), K.foe(_dummy("friend", 5000, 0), 4, 4)] as Array[UnitSetup]))
	K.step(fight, 2)
	var biter: UnitState = fight.unit_by_id("biter")
	assert_eq(biter.target, fight.unit_by_id("hero"))
	_status(fight, "biter", "veil_confused", "hero", 40)
	K.step(fight, 30)
	assert_eq(biter.target, fight.unit_by_id("friend"), "the nearest other unit of its own side")
	assert_true(K.entries(fight, LogEntry.Kind.TARGET, "biter").any(func(entry: LogEntry) -> bool: return entry.note == "confused"))
	assert_true(K.entries(fight, LogEntry.Kind.DAMAGE, "biter").any(func(entry: LogEntry) -> bool: return entry.target == "friend"), "and hits it")
	K.step(fight, 20)
	assert_true(K.entries(fight, LogEntry.Kind.TARGET, "biter").any(func(entry: LogEntry) -> bool: return entry.note == "no longer confused"))
	assert_eq(biter.target, fight.unit_by_id("hero"), "back on the heroes once it ends")


func test_a_taunt_wins_and_ranks_take_the_stand_in() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_dummy("hero", 50000), 3, 1)] as Array[UnitSetup],
		[K.foe(_dummy("biter"), 3, 4), K.foe(_dummy("friend"), 4, 4)] as Array[UnitSetup]))
	K.step(fight, 1)
	_status(fight, "biter", "taunt", "hero", 100)
	_status(fight, "biter", "veil_confused", "hero")
	assert_null(Statuses.find(fight.unit_by_id("biter"), "veil_confused"), "a taunted unit can't be confused")
	assert_eq(K.entries(fight, LogEntry.Kind.RESISTED).filter(func(entry: LogEntry) -> bool: return entry.note == "taunted").size(), 1)
	_status(fight, "friend", "marionette", "hero")
	assert_eq(fight.unit_by_id("friend").side, EffectSource.Team.HEROES)
	_status(fight, "friend", "taunt", "biter", 100)
	assert_eq(fight.unit_by_id("friend").side, EffectSource.Team.ENEMIES, "a Taunt ends control")
	assert_true(K.entries(fight, LogEntry.Kind.STATUS_ENDED).any(func(entry: LogEntry) -> bool: return entry.status == "marionette" and entry.note == "taunted"))
	var elite: UnitDef = _dummy("elite")
	elite.rank = "elite"
	var ranked: CombatSim = K.sim(K.fight([K.at(_dummy("hero", 50000), 3, 1)] as Array[UnitSetup], [K.foe(elite, 3, 4)] as Array[UnitSetup]))
	K.step(ranked, 1)
	_status(ranked, "elite", "marionette", "hero")
	var held: UnitState = ranked.unit_by_id("elite")
	assert_eq([held.side, Statuses.find(held, "marionette") == null, Statuses.find(held, "marionette_exposed") != null], [EffectSource.Team.ENEMIES, true, true],
		"an elite takes 25% more damage instead")


func test_a_controlled_enemy_fights_for_the_heroes() -> void:
	var kills: Dictionary = {"text": "x", "counts": "kills"}
	var hero: UnitSetup = K.at(_dummy("hero", 50000, 0), 3, 1)
	var errors: Array[String] = []
	hero.tally_keys.append("kills")
	hero.tally_counts.append(DeedDef.read(DataReader.new(kills, "count", errors)))
	hero.tally_keys.append("time")
	hero.tally_counts.append(DeedDef.read(DataReader.new({"text": "x", "counts": "status_ms", "statuses": ["marionette"]}, "count", errors)))
	assert_eq(errors, [] as Array[String])
	var heard: Array = [{"id": "cut", "name": "Cut", "kind": "ability", "effects": [{"trigger": "on_controlled_fell", "type": "apply_status", "status": "puppet_cut", "target": "self"}]}]
	hero.def = _dummy("hero", 50000, 0, {"passives": heard})
	var fight: CombatSim = K.sim(K.fight([hero] as Array[UnitSetup],
		[K.foe(_dummy("puppet", 5000, 50), 3, 4), K.foe(_dummy("victim", 40), 4, 4), K.foe(_dummy("other", 5000), 1, 6)] as Array[UnitSetup]))
	K.step(fight, 1)
	var puppet: UnitState = fight.unit_by_id("puppet")
	var lead: UnitState = fight.unit_by_id("hero")
	_status(fight, "puppet", "marionette", "hero", 60)
	assert_eq([puppet.side, puppet.owner, puppet.controlled, fight.heroes.has(puppet), fight.enemies.has(puppet)], [EffectSource.Team.HEROES, lead, true, true, false])
	assert_eq(Passives.allied_units(fight, lead), 2, "an allied unit")
	assert_eq(Passives.allied_summons(fight, lead), 0, "not a summon")
	K.step(fight, 40)
	assert_false(fight.unit_by_id("victim").alive, "it fights the enemies")
	assert_eq(fight.unit_by_id("victim").last_attacker, "puppet")
	assert_eq(CombatSim.result_of(fight).tally_amount("hero", "kills"), 1, "its kills are its owner's")
	assert_eq(CombatSim.result_of(fight).tally_amount("hero", "time"), 3000, "the time it was set to fight for him")
	K.step(fight, 30)
	assert_eq([puppet.side, puppet.owner, puppet.controlled, fight.enemies.has(puppet)], [EffectSource.Team.ENEMIES, null, false, true], "back as it ends")
	_status(fight, "puppet", "marionette", "hero", 60)
	puppet.hp = 0
	K.step(fight, 1)
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "hero").filter(func(entry: LogEntry) -> bool: return entry.status == "puppet_cut").size(), 1, "on_controlled_fell")
	assert_eq(Passives.fallen_allies(fight, lead), 0, "nobody's fallen ally")


func test_a_controlled_enemy_holds_no_side_up() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_dummy("hero", 50000), 3, 1)] as Array[UnitSetup], [K.foe(_dummy("last"), 3, 4)] as Array[UnitSetup]))
	K.step(fight, 1)
	_status(fight, "last", "marionette", "hero", 200)
	K.step(fight, 1)
	assert_true(fight.finished, "the enemies have nobody left")
	assert_eq(fight.outcome, FightResult.Outcome.VICTORY)
	var other: CombatSim = K.sim(K.fight([K.at(_dummy("hero", 50000), 3, 1)] as Array[UnitSetup], [K.foe(_dummy("puppet"), 3, 4), K.foe(_dummy("foe"), 4, 4)] as Array[UnitSetup]))
	K.step(other, 1)
	_status(other, "puppet", "marionette", "hero", 200)
	other.unit_by_id("hero").hp = 0
	K.step(other, 1)
	assert_eq([other.finished, other.outcome], [true, FightResult.Outcome.DEFEAT], "nor the heroes")


func test_an_enemy_losing_its_target_to_stealth() -> void:
	var veil: Array = [{"id": "veil", "name": "Veil", "kind": "ability", "effects": [{"trigger": "on_enemy_lost_target", "type": "apply_status", "status": "veil_confused", "target": "hit_target"}]}]
	var hero: UnitSetup = K.at(_dummy("hero", 50000, 0, {"passives": veil}), 3, 1)
	var errors: Array[String] = []
	hero.tally_keys.append("lost")
	hero.tally_counts.append(DeedDef.read(DataReader.new({"text": "x", "counts": "lost_target"}, "count", errors)))
	var fight: CombatSim = K.sim(K.fight([hero, K.at(_dummy("ally", 50000), 5, 1)] as Array[UnitSetup], [K.foe(_dummy("hunter"), 3, 4), K.foe(_dummy("friend"), 1, 5)] as Array[UnitSetup]))
	K.step(fight, 2)
	assert_eq(fight.unit_by_id("hunter").target, fight.unit_by_id("hero"))
	_status(fight, "hero", "shrouded", "hero", 40)
	K.step(fight, 1)
	var lost: Array[LogEntry] = fight.combat_log.of_kind(LogEntry.Kind.TARGET).filter(func(entry: LogEntry) -> bool: return entry.lost_to_stealth)
	assert_eq(lost.map(func(entry: LogEntry) -> String: return entry.source_unit), ["hunter", "friend"], "both were after him")
	assert_not_null(Statuses.find(fight.unit_by_id("hunter"), "veil_confused"), "on_enemy_lost_target names it")
	assert_eq(CombatSim.result_of(fight).tally_amount("hero", "lost"), 2)
	_status(fight, "friend", "taunt", "ally", 100)
	_status(fight, "ally", "shrouded", "ally", 40)
	K.step(fight, 2)
	assert_eq(CombatSim.result_of(fight).tally_amount("hero", "lost"), 2, "a taunted unit drawn back to a hidden taunter loses nothing it chose")


func test_on_ally_below_hp_watching_the_enemies() -> void:
	var thread: Array = [{"id": "thread", "name": "Thread", "kind": "ability", "effects": [{"trigger": "on_ally_below_hp", "enemies": true, "threshold_bp": 3000, "once": true,
		"type": "apply_status", "status": "puppet_thread", "target": "trigger_ally"}]}]
	var fight: CombatSim = K.sim(K.fight([K.at(_dummy("hero", 50000, 0, {"passives": thread}), 3, 1)] as Array[UnitSetup], [K.foe(_dummy("a", 1000), 3, 4), K.foe(_dummy("b", 1000), 4, 4)] as Array[UnitSetup]))
	K.step(fight, 1)
	fight.unit_by_id("b").hp = 200
	K.step(fight, 1)
	assert_true(fight.unit_by_id("b").controlled, "the enemy that dropped")
	fight.unit_by_id("a").hp = 200
	K.step(fight, 1)
	assert_false(fight.unit_by_id("a").controlled, "once a fight")


func _caster(effects: Array, extra: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 1000, "atk": 10, "mgk": 100, "def": 0, "speed": 0, "range": 3},
		"basic_attack": {"id": "glint", "name": "Glint", "cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"mgk": 10000}}]},
		"passives": [{"id": "reflect", "name": "Reflect", "kind": "ability", "effects": effects}]}
	data.merge(extra, true)
	return K.kit("caster", data)


func test_a_copy_s_share_grows_with_each_copy() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_caster([{"trigger": "on_interval", "interval_ms": 100, "type": "summon", "copy_of": "self", "share_pct": 30,
		"grows_per_copy_pct": 10, "share_max_pct": 50, "lasts_ms": 5000}]), 3, 1)] as Array[UnitSetup], [K.foe(_dummy("mark", 50000), 3, 6)] as Array[UnitSetup]))
	K.step(fight, 9)
	var mgk: Array = fight.units.filter(func(unit: UnitState) -> bool: return unit.mirror_of != null).map(func(unit: UnitState) -> int: return unit.def.stats.get_stat(UnitStats.Stat.MGK))
	assert_eq(mgk, [30, 40, 50, 50], "30%, then 10% more for each copy made, up to 50%")
	assert_eq(fight.unit_by_id("caster").copies_made, 4)


func test_a_copy_that_casts_once() -> void:
	var bolt: Dictionary = {"id": "bolt", "name": "Bolt", "trigger": {"kind": "mana"}, "targeting": "nearest", "effects": [{"type": "damage", "amount": 50, "target": "target"}]}
	var ally: UnitDef = _dummy("ally", 1000, 10, {"mana": {"max": 100, "per_attack": 0}, "signature": bolt})
	var hall: Dictionary = {"trigger": "on_interval", "interval_ms": 100, "once": true, "type": "summon", "copy_of": "each_ally", "share_pct": 50, "lasts_ms": 5000, "casts": true}
	var fight: CombatSim = K.sim(K.fight([K.at(_caster([hall]), 3, 1),
		K.at(ally, 5, 1)] as Array[UnitSetup], [K.foe(_dummy("mark", 50000), 3, 4)] as Array[UnitSetup]))
	K.step(fight, 3)
	var copy: UnitState = fight.unit_by_id("ally_copy")
	assert_not_null(copy)
	assert_eq(copy.def.signature.id, "bolt", "it keeps its hero's mana signature")
	var caster_copy: UnitState = fight.unit_by_id("caster_copy")
	assert_null(caster_copy.def.signature, "a copy keeps no signature that makes copies, nor one it hasn't")
	K.step(fight, 40)
	var bolts: Array[LogEntry] = K.entries(fight, LogEntry.Kind.FIRE).filter(func(entry: LogEntry) -> bool: return entry.source_unit.begins_with("ally_copy") and entry.source_ability == "bolt")
	assert_eq(bolts.size(), 1, "it casts once")


func test_an_aura_per_summon_joined() -> void:
	var host: Dictionary = {"id": "host", "name": "Host", "kind": "aura", "aura": {"target": "holder", "stat": "atsp", "value": 5, "per": "summon_joined"}}
	var fight: CombatSim = K.sim(K.fight([K.at(_caster([{"trigger": "on_interval", "interval_ms": 100, "type": "summon", "copy_of": "self", "share_pct": 30, "lasts_ms": 100}],
		{"passives": [{"id": "reflect", "name": "Reflect", "kind": "ability", "effects": [{"trigger": "on_interval", "interval_ms": 100, "type": "summon", "copy_of": "self", "share_pct": 30, "lasts_ms": 100}]}, host]}), 3, 1)] as Array[UnitSetup],
		[K.foe(_dummy("mark", 50000), 3, 6)] as Array[UnitSetup]))
	K.step(fight, 11)
	assert_eq(fight.summons_joined, [5, 0] as Array[int])
	assert_eq(fight.unit_by_id("caster").stats.get_stat(UnitStats.Stat.ATSP), 5 * 5, "every summon that joined, standing or gone")


func test_deeds_by_copies_and_from_stealth() -> void:
	var setup: UnitSetup = K.at(_caster([{"trigger": "on_interval", "interval_ms": 1000, "first_ms": 50, "type": "summon", "copy_of": "self", "share_pct": 30, "lasts_ms": 5000}]), 3, 2)
	var errors: Array[String] = []
	for pair: Array in [["own", {"text": "x", "counts": "damage", "copies": "own"}], ["all", {"text": "x", "counts": "damage"}], ["stealth", {"text": "x", "counts": "hits", "by_allies": true, "from_stealth": true}]]:
		setup.tally_keys.append(pair[0])
		setup.tally_counts.append(DeedDef.read(DataReader.new(pair[1], "count", errors)))
	assert_eq(errors, [] as Array[String])
	assert_ne(_read_deed({"text": "x", "counts": "healing", "copies": "own"}), [] as Array[String], "copies only filters damage or hits")
	assert_ne(_read_deed({"text": "x", "counts": "status_ms"}), [] as Array[String], "status_ms names its statuses")
	var fight: CombatSim = K.sim(K.fight([setup] as Array[UnitSetup], [K.foe(_dummy("mark", 50000), 3, 4)] as Array[UnitSetup]))
	Statuses.apply(fight, fight.unit_by_id("caster"), "shrouded", 1, 100, fight.unit_by_id("caster").own_source)
	K.step(fight, 60)
	var hits: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE).filter(func(entry: LogEntry) -> bool: return entry.source_ability == "glint")
	var by_copies: int = hits.filter(func(entry: LogEntry) -> bool: return entry.source_unit.begins_with("caster_copy")).reduce(func(total: int, entry: LogEntry) -> int: return total + entry.amount, 0)
	var result: FightResult = CombatSim.result_of(fight)
	assert_gt(by_copies, 0)
	assert_eq(result.tally_amount("caster", "own"), by_copies, "its copies' damage only")
	assert_gt(result.tally_amount("caster", "all"), by_copies)
	assert_eq(result.tally_amount("caster", "stealth"), hits.filter(func(entry: LogEntry) -> bool: return entry.from_stealth).size())
	assert_eq(result.tally_amount("caster", "stealth"), 1, "its strike from Stealth")


func _read_deed(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	DeedDef.read(DataReader.new(data, "count", errors))
	return errors
