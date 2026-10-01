extends GutTest
## The log tells the whole story of the board (docs/plans/rebuild-phase1-arena-sim.md,
## section 11): replaying every leg, stop, push, and summon from the log
## alone gives each unit's exact position on every tick, and every entry
## names its source (CLAUDE.md rule 4), in a busy fight, the chaos fight, and
## the three heroes against every Act 1 enemy.

const K = preload("res://tests/sim/sim_test_kit.gd")
const Chaos = preload("res://tests/sim/chaos_fight.gd")
const TacticFights = preload("res://tests/sim/test_tactics.gd")
const PathFights = preload("res://tests/sim/path_fights.gd")


## A busy fight: melee and ranged on both sides, a rock in the middle.
static func busy_setup(fight_seed: int = 5) -> FightSetup:
	var tank: UnitDef = K.kit("tank", {"stats": {"hp": 500, "atk": 12, "def": 30, "speed": 2}, "traits": ["engage"],
		"signature": {"id": "stand", "name": "Stand", "trigger": {"kind": "hp_below", "threshold_bp": 4000}, "targeting": "self",
			"effects": [{"type": "shield", "amount": 60, "target": "self"}]}})
	var archer: UnitDef = K.kit("archer", {"stats": {"hp": 250, "atk": 20, "speed": 2, "range": 4, "crit": 20},
		"basic_attack": {"cooldown_ms": 900, "effects": [{"type": "damage", "amount": 6, "target": "target", "scaling": {"atk": 6000}}]},
		"mana": {"max": 40, "per_attack": 10, "regen_per_s": 2},
		"signature": {"id": "volley", "name": "Volley", "trigger": {"kind": "mana"}, "max_range": 5, "cast_ms": 400,
			"effects": [{"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "target", "warning_ms": 500, "hits": "enemies",
				"effects": [{"type": "damage", "amount": 15, "target": "target", "scaling": {"atk": 5000}}, {"type": "apply_status", "status": "slow", "target": "target"}]}]}})
	var hound: UnitDef = K.kit("hound", {"stats": {"hp": 180, "atk": 14, "speed": 3, "crit": 10}, "traits": ["engage", "flying"],
		"passives": [{"id": "pack", "name": "Pack", "kind": "aura", "aura": {"target": "all_allies", "stat": "atsp_bp", "value": 11000}},
			{"id": "snap", "name": "Snap", "kind": "ability", "effects": [{"trigger": "on_hit_taken", "every": 3, "type": "damage", "amount": 4, "target": "hit_target"},
				{"trigger": "on_hit_taken", "every": 3, "type": "knockback", "hexes": 1, "target": "hit_target"}]}],
		"signature": {"id": "pounce", "name": "Pounce", "trigger": {"kind": "fight_start"}, "max_range": 4,
			"effects": [{"type": "leap", "max_hexes": 4, "target": "target"}, {"type": "damage", "amount": 8, "target": "target"}]}})
	# Snipers taunt whoever they hit, so heroes walk past the hounds, which
	# engage them.
	var sniper: UnitDef = K.kit("sniper", {"stats": {"hp": 140, "atk": 12, "speed": 2, "range": 5}, "traits": ["hop_away"], "hop_cooldown_ms": 4000,
		"basic_attack": {"effects": [{"type": "damage", "amount": 10, "target": "target"}, {"type": "apply_status", "status": "taunt", "target": "target"}]}})
	return K.fight([K.at(tank, 3, 2), K.at(archer, 3, 0), K.at(tank, 5, 1), K.at(archer, 1, 1)] as Array[UnitSetup],
		[K.foe(hound, 1, 4), K.foe(hound, 3, 4), K.foe(hound, 5, 4), K.foe(sniper, 2, 6), K.foe(sniper, 4, 6), K.foe(hound, 6, 5)] as Array[UnitSetup],
		[Vector2i(4, 3), Vector2i(1, 3)] as Array[Vector2i], fight_seed)


## Brannoc, Maren, and Vell against one of each of phase 2's Act 1 enemies
## (`first` of them: the first nine), or of `enemy_ids`, all from content.
static func content_setup(fight_seed: int = 7, enemy_ids: Array[String] = []) -> FightSetup:
	var content: ContentDb = K.content()
	var heroes: Array[UnitSetup] = []
	var hero_hexes: Array[Vector2i] = [Vector2i(3, 2), Vector2i(3, 0), Vector2i(4, 0)]
	for i: int in content.hero_ids.size():
		heroes.append(K.at((content.heroes[content.hero_ids[i]] as HeroDef).kit, hero_hexes[i].x, hero_hexes[i].y))
	var ids: Array[String] = enemy_ids if not enemy_ids.is_empty() else content.enemy_ids.slice(0, 9)
	var enemies: Array[UnitSetup] = []
	var enemy_hexes: Array[Vector2i] = [Vector2i(1, 4), Vector2i(3, 4), Vector2i(5, 4), Vector2i(0, 5), Vector2i(2, 5), Vector2i(4, 5), Vector2i(6, 5), Vector2i(3, 6), Vector2i(5, 6)]
	for i: int in ids.size():
		enemies.append(K.foe((content.enemies[ids[i]] as EnemyDef).kit, enemy_hexes[i].x, enemy_hexes[i].y))
	var fight: FightSetup = K.fight(heroes, enemies, [Vector2i(1, 3)] as Array[Vector2i], fight_seed)
	fight.summon_kits = Encounters.summon_kits(content, heroes + enemies, FixedMath.BP_ONE)
	return fight


## The heroes against phase 5's elites' and boss's enemies (their kits
## unscaled, so the heroes lose; the log is what's tested).
static func elite_setup(fight_seed: int = 7) -> FightSetup:
	return content_setup(fight_seed, ["hound_alpha", "hunt_hound", "gloam_totem", "ash_hound", "old_mother_ash"] as Array[String])


func test_the_log_replays_every_position() -> void:
	_assert_replays(busy_setup())


func test_the_log_replays_the_chaos_fight() -> void:
	# Pushes, leaps, charges, hops, summons, and walking off crumbled ground.
	_assert_replays(Chaos.setup())


## Runs the fight, noting where every standing unit is on every tick (and
## that no two overlap), then replays the log from the hex centers alone and
## checks it lands every unit in the same place on every tick.
func test_the_log_replays_a_fight_of_the_content_kits() -> void:
	_assert_replays(content_setup())
	_assert_replays(elite_setup(), 5)


## The paths' leaps, pushes, and walls of moves replay too (phase 4).
func test_the_log_replays_the_paths_fights() -> void:
	for setup: FightSetup in PathFights.all(K.content()):
		_assert_replays(setup, 1)


func _assert_replays(setup: FightSetup, fewest_moves: int = 11) -> void:
	var fight: CombatSim = K.sim(setup)
	var truth: Array[Dictionary] = []
	while not fight.finished:
		fight.step()
		var at: Dictionary = {}
		for unit: UnitState in fight.units:
			if unit.alive:
				at[unit.id] = unit.pos
		truth.append(at)
		if not K.no_overlaps(fight):
			fail_test("tick %d: two units overlap\n%s" % [fight.tick, ArenaDebug.render(fight)])
			return
	assert_gte(K.entries(fight, LogEntry.Kind.MOVE).size(), fewest_moves, "plenty of walking")
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
				# A push can come after the pushed unit stepped this tick, so
				# it's taken as where the unit ends up; it ends any leg.
				LogEntry.Kind.PUSH:
					pos[entry.target] = entry.to_pos
					legs.erase(entry.target)
				LogEntry.Kind.SUMMON:
					if entry.note.is_empty():
						pos[entry.target] = entry.to_pos
				LogEntry.Kind.LEAP, LogEntry.Kind.CHARGE, LogEntry.Kind.HOP:
					assert_eq(entry.from_pos, pos[entry.source_unit], "it leaps or charges from where it is (%s)" % entry.to_text())
					pos[entry.source_unit] = entry.to_pos
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


## What each kind of entry must name (CLAUDE.md rule 4): "unit" a source
## unit, "ability" a source ability, "target" a unit it's about, "status" a
## status. A number a payoff made bigger names the tactic it came from.
## COLLAPSE and COLLAPSE_RING are Rift Collapse's (or, for a ring, the
## unit and ability that started it early); the fight's start and end name
## nothing. A status that just runs out ends with no note. Every kind the
## log can hold is listed, so a new one needs a rule.
const NAMES: Dictionary = {
	LogEntry.Kind.FIGHT_START: [], LogEntry.Kind.FIGHT_END: [],
	LogEntry.Kind.FIRE: ["unit", "ability"],
	LogEntry.Kind.DAMAGE: ["unit", "ability", "target"], LogEntry.Kind.HEAL: ["unit", "ability", "target"],
	LogEntry.Kind.SHIELD: ["unit", "ability", "target"], LogEntry.Kind.MANA_DRAIN: ["unit", "ability", "target"],
	LogEntry.Kind.COLLAPSE: ["collapse", "target"], LogEntry.Kind.COLLAPSE_RING: ["collapse"],
	LogEntry.Kind.DEATH: ["target", "note"],
	LogEntry.Kind.STATUS_APPLIED: ["unit", "ability", "target", "status"], LogEntry.Kind.STATUS_DAMAGE: ["unit", "ability", "target", "status"],
	LogEntry.Kind.STATUS_REDUCED: ["unit", "ability", "target", "status"], LogEntry.Kind.STATUS_ENDED: ["target", "status"],
	LogEntry.Kind.AURA: ["unit", "ability"], LogEntry.Kind.PHASE: ["unit", "ability", "target"],
	LogEntry.Kind.MOVE: ["unit"], LogEntry.Kind.STOP: ["unit"], LogEntry.Kind.TARGET: ["unit", "note"], LogEntry.Kind.BREAK_FREE: ["unit", "target"],
	LogEntry.Kind.SHOT: ["unit", "ability", "target"], LogEntry.Kind.SHOT_FIZZLED: ["unit", "ability", "target"],
	LogEntry.Kind.CAST: ["unit", "ability", "target"], LogEntry.Kind.CAST_CANCELLED: ["unit", "ability", "note"],
	LogEntry.Kind.SAVED: ["unit", "ability", "target"],
	LogEntry.Kind.PUSH: ["unit", "ability", "target"], LogEntry.Kind.LEAP: ["unit", "ability", "target"],
	LogEntry.Kind.CHARGE: ["unit", "ability", "target"], LogEntry.Kind.HOP: ["unit", "ability", "target"],
	LogEntry.Kind.AREA_WARNING: ["unit", "ability"], LogEntry.Kind.AREA_LANDED: ["unit", "ability"],
	LogEntry.Kind.SUMMON: ["unit", "ability", "target"],
	LogEntry.Kind.TACTIC: ["unit", "ability", "note"],
	LogEntry.Kind.ZONE: ["unit", "ability"], LogEntry.Kind.SNARE: ["unit", "ability", "note"],
	LogEntry.Kind.WALL: ["unit", "ability"], LogEntry.Kind.GUARD: ["unit", "ability", "target"],
	LogEntry.Kind.LIFESTEAL: ["unit", "ability", "target"], LogEntry.Kind.STATUS_EXTENDED: ["unit", "ability", "target", "status"],
}


func test_every_entry_names_its_source() -> void:
	var fights: Array[FightSetup] = [busy_setup(), Chaos.setup(), content_setup(), TacticFights.tactics_setup(), elite_setup()]
	fights.append_array(PathFights.all(K.content()))
	for setup: FightSetup in fights:
		_assert_sources(K.run(setup), setup)


func _assert_sources(result: FightResult, setup: FightSetup) -> void:
	var ids: Array[String] = []
	var tactic_names: Dictionary[String, String] = {}
	for unit: UnitSetup in setup.units():
		ids.append(unit.id)
		if unit.tactic != null:
			tactic_names[unit.id] = unit.tactic.name
	for entry: LogEntry in result.combat_log.entries:
		if entry.kind == LogEntry.Kind.SUMMON and entry.note.is_empty():
			ids.append(entry.target)
	for entry: LogEntry in result.combat_log.entries:
		var line: String = entry.to_text()
		assert_false(line.ends_with("?"), "every kind has its text: %s" % line)
		if not NAMES.has(entry.kind):
			fail_test("no rule for %s" % LogEntry.Kind.keys()[entry.kind])
			return
		var needs: Array = NAMES[entry.kind]
		var by_collapse: bool = entry.source_ability == LogEntry.COLLAPSE_SOURCE and entry.source_unit.is_empty()
		if needs.has("collapse") and not by_collapse:
			assert_true(entry.kind == LogEntry.Kind.COLLAPSE_RING and ids.has(entry.source_unit) and not entry.source_ability.is_empty(), "Rift Collapse's, or who started it: " + line)
		# A relic's own effect (phase 5c step 5b: at the fight's start) names
		# the relic, not a unit.
		var by_relic: bool = entry.source_relic_side >= 0
		if by_relic:
			assert_true(entry.source_unit.is_empty() and not entry.source_ability.is_empty() and not entry.source_ability_name.is_empty(), "names its relic: " + line)
		elif needs.has("unit"):
			assert_true(ids.has(entry.source_unit), "names its unit: " + line)
		if needs.has("ability"):
			assert_false(entry.source_ability.is_empty() or entry.source_ability_name.is_empty(), "names its ability: " + line)
		if needs.has("target"):
			var dropped: bool = entry.kind == LogEntry.Kind.SUMMON and not entry.note.is_empty()
			assert_true(dropped or ids.has(entry.target), "names the unit it's about: " + line)
		if needs.has("status"):
			assert_false(entry.status.is_empty() or entry.status_name.is_empty(), "names its status: " + line)
		if needs.has("note"):
			assert_false(entry.note.is_empty(), "says why: " + line)
		if not entry.bonus.is_empty():
			assert_true(tactic_names.has(entry.source_unit) and entry.bonus.ends_with("from " + tactic_names[entry.source_unit]), "a payoff names its unit's tactic: " + line)


func test_the_text_board_shows_a_fight() -> void:
	var fight: CombatSim = K.sim(busy_setup())
	var board: String = ArenaDebug.render(fight)
	var lines: PackedStringArray = board.split("\n")
	assert_eq([lines.size(), lines[0].length()], [30, 29], "a character per quarter hex")
	for mark: String in ["t", "a", "h", "s", "#"]:
		assert_string_contains(board, mark)
	assert_false(board.contains("~"), "nothing has crumbled")
