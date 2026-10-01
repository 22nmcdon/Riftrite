extends GutTest
## The combo readout's pieces (docs/plans/rebuild-phase5c-combos.md, step
## 9a, section 17.3–17.4): the damage rule's notes on each number, kept out
## of the log's text; and ComboTally's fires, chains, and what each engine
## added, read from the chaos fight's log.

const K = preload("res://tests/sim/sim_test_kit.gd")
const Chaos = preload("res://tests/sim/chaos_fight.gd")

var chaos: FightResult
var chaos_setup: FightSetup


func before_all() -> void:
	chaos_setup = Chaos.setup()
	chaos = CombatSim.run(chaos_setup, K.content())


func _hero_ids(setup: FightSetup) -> Array[String]:
	var ids: Array[String] = []
	for unit: UnitSetup in setup.heroes:
		ids.append(unit.id)
	return ids


func test_every_number_keeps_its_rule() -> void:
	var kinds: Array = [LogEntry.Kind.DAMAGE, LogEntry.Kind.HEAL, LogEntry.Kind.STATUS_DAMAGE]
	var seen: Dictionary[int, int] = {}
	for entry: LogEntry in chaos.combat_log.entries:
		if not kinds.has(entry.kind):
			continue
		assert_gte(entry.rule_base, 0, "%s has its rule" % entry.to_text())
		seen[entry.kind] = seen.get(entry.kind, 0) + 1
		var made: int = entry.ruled_amount()
		match entry.kind:
			LogEntry.Kind.STATUS_DAMAGE:
				assert_eq(made, entry.amount, "damage over time is what the rule made: " + entry.to_text())
			LogEntry.Kind.HEAL:
				assert_lte(entry.amount, made, "a heal is the rule's number, capped by missing HP: " + entry.to_text())
	assert_eq(seen.size(), kinds.size(), "each kind came up")
	var shields: Array = chaos.combat_log.of_kind(LogEntry.Kind.SHIELD).filter(func(entry: LogEntry) -> bool: return entry.rule_base >= 0)
	assert_false(shields.is_empty(), "an ability's Shield keeps its rule")
	for entry: LogEntry in shields:
		assert_eq(entry.ruled_amount(), entry.amount)


func test_a_plain_hit_adds_up() -> void:
	var hero: UnitDef = K.kit("hero", {"stats": {"hp": 1000, "atk": 40, "speed": 0, "range": 4},
		"basic_attack": {"cooldown_ms": 500, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]},
		"passives": [{"id": "keen", "name": "Keen", "kind": "aura", "aura": {"stat": "damage_bp", "value": 13500, "target": "holder"}}]})
	var dummy: UnitDef = K.kit("dummy", {"stats": {"hp": 100000, "speed": 0, "range": 2},
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 1, "hero")] as Array[UnitSetup], [K.foe(dummy, 3, 4, "dummy")] as Array[UnitSetup]))
	K.step(fight, 40)
	var hits: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "hero")
	assert_false(hits.is_empty())
	var hit: LogEntry = hits[0]
	assert_eq([hit.rule_base, hit.rule_power], [40, 3500], "base 40, power +35%")
	assert_eq(hit.ruled_amount(), hit.amount + hit.mitigated + hit.absorbed, "the rule, then DEF and a Shield")
	assert_string_starts_with(ComboTally.rule_note(hit), "40 · power +35%")


func test_the_rule_stays_out_of_the_log_text() -> void:
	var entry: LogEntry = chaos.combat_log.of_kind(LogEntry.Kind.DAMAGE)[0]
	var text: String = entry.to_text()
	var kept: int = entry.rule_base
	entry.rule_base = -1
	entry.starts_fire = not entry.starts_fire
	assert_eq(entry.to_text(), text, "players' log reads the same")
	entry.rule_base = kept
	entry.starts_fire = not entry.starts_fire


func test_the_tally_of_the_chaos_fight() -> void:
	var chain_limit: int = K.content().tuning.chain_limit
	var tally: ComboTally = ComboTally.of_log(chaos.combat_log, chain_limit, _hero_ids(chaos_setup))
	var damage: int = 0
	var fires: int = 0
	var started: int = 0
	var limit: int = 0
	for entry: LogEntry in chaos.combat_log.entries:
		var sourced: bool = not entry.source_unit.is_empty() or entry.source_relic_side >= 0
		if sourced and (entry.kind == LogEntry.Kind.DAMAGE or entry.kind == LogEntry.Kind.STATUS_DAMAGE):
			damage += entry.amount
		if sourced and entry.kind == LogEntry.Kind.FIRE:
			fires += 1
		if entry.starts_fire:
			assert_true(entry.from_event, "a passive's firing")
			started += 1
		limit += 1 if entry.chain >= chain_limit else 0
	var tallied: int = tally.engines.reduce(func(sum: int, engine: ComboTally.EngineRow) -> int: return sum + engine.damage, 0)
	assert_eq(tallied, damage, "every point of damage is some engine's")
	assert_eq(tally.engines.reduce(func(sum: int, engine: ComboTally.EngineRow) -> int: return sum + engine.fires, 0), fires + started)
	assert_gt(started, 0, "passives fired")
	assert_eq(tally.at_limit, limit)
	assert_true(tally.engines.any(func(engine: ComboTally.EngineRow) -> bool: return engine.from_chains > 0), "some fire was set off by another")
	assert_true(tally.engines.any(func(engine: ComboTally.EngineRow) -> bool: return engine.deepest >= 2))
	for engine: ComboTally.EngineRow in tally.hero_engines():
		assert_eq(engine.side, EffectSource.Team.HEROES)
		assert_gt(engine.fires, 0)


func test_rule_notes_read_plainly() -> void:
	var entry := LogEntry.new()
	entry.kind = LogEntry.Kind.DAMAGE
	entry.set_rule(40, 3500, 5000, 2000, 0)
	assert_eq(ComboTally.rule_note(entry), "40 · power +35% · crit +50% · vulnerability +20%")
	entry.set_rule(12, 0, 0, 0, 0)
	assert_eq(ComboTally.rule_note(entry), "12 · no bonuses")
	entry.kind = LogEntry.Kind.HEAL
	entry.set_rule(30, 0, 0, -2550, 125)
	assert_eq(ComboTally.rule_note(entry), "30 · healing taken −25.5% · relic +1.25%")
	entry.rule_base = -1
	assert_eq(ComboTally.rule_note(entry), "")
