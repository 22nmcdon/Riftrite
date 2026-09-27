extends GutTest
## The log tells the whole story of the board (docs/plans/rebuild-phase1-arena-sim.md,
## section 11): replaying every leg and stop from the log alone gives each
## unit's exact position on every tick, and every move names its unit.

const K = preload("res://tests/sim/sim_test_kit.gd")


## A busy fight: melee and ranged on both sides, a rock in the middle.
static func busy_setup(fight_seed: int = 5) -> FightSetup:
	var tank: UnitDef = K.kit("tank", {"stats": {"hp": 500, "atk": 12, "def": 30, "speed": 2},
		"signature": {"id": "stand", "name": "Stand", "trigger": {"kind": "hp_below", "threshold_bp": 4000}, "targeting": "self",
			"effects": [{"type": "shield", "amount": 60, "target": "self"}]}})
	var archer: UnitDef = K.kit("archer", {"stats": {"hp": 250, "atk": 20, "speed": 2, "range": 4, "crit": 20},
		"basic_attack": {"cooldown_ms": 900, "effects": [{"type": "damage", "amount": 6, "target": "target", "scaling": {"atk": 6000}}]},
		"mana": {"max": 40, "per_attack": 10, "regen_per_s": 2},
		"signature": {"id": "volley", "name": "Volley", "trigger": {"kind": "mana"}, "max_range": 5, "cast_ms": 400,
			"effects": [{"type": "damage", "amount": 15, "target": "target", "scaling": {"atk": 5000}}, {"type": "apply_status", "status": "slow", "target": "target"}]}})
	var hound: UnitDef = K.kit("hound", {"stats": {"hp": 180, "atk": 14, "speed": 3, "crit": 10}})
	var sniper: UnitDef = K.kit("sniper", {"stats": {"hp": 140, "atk": 12, "speed": 2, "range": 5}})
	return K.fight([K.at(tank, 3, 2), K.at(archer, 3, 0), K.at(tank, 5, 1), K.at(archer, 1, 1)] as Array[UnitSetup],
		[K.foe(hound, 1, 4), K.foe(hound, 3, 4), K.foe(hound, 5, 4), K.foe(sniper, 2, 6), K.foe(sniper, 4, 6), K.foe(hound, 6, 5)] as Array[UnitSetup],
		[Vector2i(4, 3), Vector2i(1, 3)] as Array[Vector2i], fight_seed)


func test_the_log_replays_every_position() -> void:
	var setup: FightSetup = busy_setup()
	var fight: CombatSim = K.sim(setup)
	var truth: Array[Dictionary] = []
	while not fight.finished:
		fight.step()
		var at: Dictionary = {}
		for unit: UnitState in fight.units:
			if unit.alive:
				at[unit.id] = unit.pos
		truth.append(at)
	assert_gt(K.entries(fight, LogEntry.Kind.MOVE).size(), 10, "plenty of walking")
	# Replay: start on the hex centers, then follow the log.
	var grid: HexGrid = fight.grid
	var pos: Dictionary = {}
	for unit: UnitSetup in setup.units():
		pos[unit.id] = grid.center(unit.col, unit.row)
	var legs: Dictionary = {}
	var entries: Array[LogEntry] = fight.combat_log.entries
	var next: int = 0
	for tick: int in range(1, fight.tick + 1):
		while next < entries.size() and entries[next].tick <= tick:
			var entry: LogEntry = entries[next]
			next += 1
			if entry.tick < tick:
				continue
			match entry.kind:
				LogEntry.Kind.MOVE:
					assert_eq(entry.from_pos, pos[entry.source_unit], "a leg starts where the unit is (%s)" % entry.to_text())
					legs[entry.source_unit] = [entry.to_pos, entry.amount]
				LogEntry.Kind.STOP:
					assert_eq(entry.to_pos, pos[entry.source_unit], "a stop is where the unit is (%s)" % entry.to_text())
					legs.erase(entry.source_unit)
		for id: String in legs.keys():
			var leg: Array = legs[id]
			pos[id] = ArenaPlane.step_toward(pos[id], leg[0], leg[1])
			if pos[id] == leg[0]:
				legs.erase(id)
		var expected: Dictionary = truth[tick - 1]
		for id: String in expected:
			if pos[id] != expected[id]:
				fail_test("tick %d: %s replays to %s but stands at %s" % [tick, id, pos[id], expected[id]])
				return
	pass_test("every unit's position replays on every tick")


func test_moves_name_their_unit() -> void:
	var fight: CombatSim = K.sim(busy_setup())
	while not fight.finished:
		fight.step()
	for entry: LogEntry in fight.combat_log.entries:
		match entry.kind:
			LogEntry.Kind.MOVE, LogEntry.Kind.STOP, LogEntry.Kind.TARGET:
				assert_false(entry.source_unit.is_empty(), entry.to_text())
			LogEntry.Kind.FIRE, LogEntry.Kind.SHOT, LogEntry.Kind.DAMAGE, LogEntry.Kind.HEAL, LogEntry.Kind.SHIELD, LogEntry.Kind.SHOT_FIZZLED:
				assert_false(entry.source_unit.is_empty() or entry.source_ability.is_empty(), "names its unit and ability: " + entry.to_text())


func test_the_text_board_shows_a_fight() -> void:
	var fight: CombatSim = K.sim(busy_setup())
	var board: String = ArenaDebug.render(fight)
	var lines: PackedStringArray = board.split("\n")
	assert_eq([lines.size(), lines[0].length()], [30, 29], "a character per quarter hex")
	for mark: String in ["t", "a", "h", "s", "#"]:
		assert_string_contains(board, mark)
	assert_false(board.contains("~"), "nothing has crumbled")
