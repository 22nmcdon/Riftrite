extends SceneTree
## Times the arena sim against its budget (docs/plans/rebuild-phase1-arena-sim.md,
## section 13: a 60s fight of 3 against 6 in under 100 ms) and prints a
## fingerprint of each fight's log, so a speed-up can be checked to change
## nothing.
## Usage: godot --headless --path . -s tools/bench_sim.gd
## Three fights, each run 3 times (the fastest counts):
##   steady    3 against 6 at 1x to 3x HP (1.5x runs about a minute, the
##             budget's case): tanks, archers, hounds, and snipers that mostly
##             stand and trade
##   crowded   the same, but the snipers taunt whoever they hit and the hounds
##             engage, so heroes keep walking through the enemy line (the
##             hardest case for pathfinding)
##   swarm     3 against a caller behind rocks that brings 2 pups from the
##             edges every 5s, at 1x and 2x its HP (docs/plans/
##             rebuild-phase2-heroes-enemies.md, section 1: under 300 ms per
##             60s)
##   chains    steady at 1x and 1.5x HP, but every unit hits back for 1 each
##             time it's hit, so every hit starts a chain that runs to the
##             chain limit (docs/plans/rebuild-phase5c-combos.md, step 3)
## The kits are fixed here, so the numbers compare across changes.
## Then the loaded fights (the tuning phase): each run state saved in
## tools/bench_states/ (a good-bot run at a day's loadout, late in an act:
## a full team's relics, upgrades, items, an apex) fights its waiting fight,
## placed the way the good bot places, on a fixed seed. These read the real
## content, so their numbers move when the data does; they're the fights
## the bots spend their time on.

const K = preload("res://tests/sim/sim_test_kit.gd")
const Practice = preload("res://tools/bots/practice.gd")
const Bot = preload("res://tools/bots/bot.gd")
const RUNS: int = 3
const STATES: String = "res://tools/bench_states"


func _init() -> void:
	# Loaded once: K.run loads the data afresh each call, which by now costs
	# more than a fight (the tuning phase).
	var content: ContentDb = K.content()
	var total_ms: int = 0
	var total_ticks: int = 0
	for kind: String in ["steady", "crowded", "swarm", "chains"]:
		for hp_bp: int in ([10000, 20000] if kind == "swarm" else [10000, 15000] if kind == "chains" else [10000, 15000, 20000, 30000]):
			for fight_seed: int in [5, 11]:
				var best_usec: int = 0
				var result: FightResult = null
				for run: int in RUNS:
					var setup: FightSetup = _swarm_setup(fight_seed, hp_bp) if kind == "swarm" else _chain_setup(fight_seed, hp_bp) if kind == "chains" else _setup(fight_seed, hp_bp, kind == "crowded")
					var started: int = Time.get_ticks_usec()
					result = CombatSim.run(setup, content)
					var usec: int = Time.get_ticks_usec() - started
					best_usec = usec if run == 0 else mini(best_usec, usec)
				@warning_ignore("integer_division")
				var ms: int = best_usec / 1000
				total_ms += ms
				total_ticks += result.end_tick
				@warning_ignore("integer_division")
				var units: String = ""
				if kind == "swarm":
					units = ", up to %d pups" % _most_pups(result)
				print("%-8s hp x%-3s seed %2d: %4d ticks (%3ds), %4d ms, %3d ms per 60s%s, log %s" % [kind, str(hp_bp / 10000.0), fight_seed, result.end_tick, result.end_tick / FixedMath.TICKS_PER_SECOND, ms, ms * 1200 / maxi(result.end_tick, 1), units, result.combat_log.to_text().md5_text()])
	@warning_ignore("integer_division")
	print("all: %d ms per 60s" % (total_ms * 1200 / maxi(total_ticks, 1)))
	_loaded()
	quit()


## The loaded fights: each saved run state's waiting fight.
static func _loaded() -> void:
	if not DirAccess.dir_exists_absolute(STATES):
		return
	var run: RunContent = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))
	var total_ms: int = 0
	var total_ticks: int = 0
	var names: PackedStringArray = DirAccess.get_files_at(STATES)
	names.sort()
	for name: String in names:
		if not name.ends_with(".json"):
			continue
		var flow: RunFlow = RunFlow.resume(run, RunState.from_dict(JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [STATES, name]))))
		var hexes: Dictionary[String, Vector2i] = Practice.place(flow)
		var errors: Array[String] = []
		var best_usec: int = 0
		var result: FightResult = null
		for i: int in RUNS:
			var setup: FightSetup = flow.fight_setup(hexes, errors, Bot.default_markers(flow, hexes))
			if setup == null:
				print("loaded   %s: no fight (%s)" % [name, ", ".join(errors)])
				break
			setup.seed_value = 5
			var started: int = Time.get_ticks_usec()
			result = CombatSim.run(setup, run.content)
			var usec: int = Time.get_ticks_usec() - started
			best_usec = usec if i == 0 else mini(best_usec, usec)
		if result == null:
			continue
		@warning_ignore("integer_division")
		var ms: int = best_usec / 1000
		total_ms += ms
		total_ticks += result.end_tick
		@warning_ignore("integer_division")
		print("loaded   %-14s %-22s %4d ticks (%3ds), %4d ms, %3d ms per 60s, %d relics, %d summons, log %s" % [name.get_basename(), flow.state.chosen, result.end_tick,
			result.end_tick / FixedMath.TICKS_PER_SECOND, ms, ms * 1200 / maxi(result.end_tick, 1), flow.state.relics.size(),
			result.combat_log.of_kind(LogEntry.Kind.SUMMON).size(), result.combat_log.to_text().md5_text()])
	if total_ticks > 0:
		@warning_ignore("integer_division")
		print("loaded: %d ms per 60s" % (total_ms * 1200 / total_ticks))


## The swarm: a tank, an archer, and a healer-less bruiser against a caller
## that stands behind rocks and brings 2 pups every 5s, near the heroes'
## side of the arena, plus 4 pups to start.
static func _swarm_setup(fight_seed: int, hp_bp: int) -> FightSetup:
	var tank: UnitDef = K.kit("tank", {"stats": {"hp": 600, "atk": 12, "def": 30, "speed": 2}, "traits": ["engage"]})
	var archer: UnitDef = K.kit("archer", {"stats": {"hp": 300, "atk": 20, "speed": 2, "range": 4},
		"basic_attack": {"cooldown_ms": 900, "effects": [{"type": "damage", "amount": 6, "target": "target", "scaling": {"atk": 6000}}]}})
	var bruiser: UnitDef = K.kit("bruiser", {"stats": {"hp": 450, "atk": 16, "def": 10, "speed": 2},
		"basic_attack": {"effects": [{"type": "damage", "amount": 8, "target": "target", "scaling": {"atk": 5000}}]}})
	var pup: UnitDef = K.kit("pup", {"stats": {"hp": 60, "atk": 8, "speed": 3}, "basic_attack": {"cooldown_ms": 800, "effects": [{"type": "damage", "amount": 5, "target": "target"}]}})
	var caller: UnitDef = K.kit("caller", {"stats": {"hp": 900, "atk": 10, "def": 10, "speed": 0, "range": 3},
		"mana": {"max": 100, "regen_per_s": 20},
		"signature": {"id": "call", "name": "Call", "trigger": {"kind": "mana"}, "targeting": "nearest", "max_range": 8,
			"effects": [{"type": "summon", "kit": "pup", "count": 2, "placement": "edges", "near": "target"}]}})
	caller.stats.values[UnitStats.Stat.HP] = FixedMath.apply_bp(caller.stats.values[UnitStats.Stat.HP], hp_bp)
	var setup: FightSetup = K.fight([K.at(tank, 3, 2), K.at(archer, 3, 0), K.at(bruiser, 5, 1)] as Array[UnitSetup],
		[K.foe(caller, 3, 6), K.foe(pup, 1, 4), K.foe(pup, 2, 4), K.foe(pup, 5, 4), K.foe(pup, 6, 4)] as Array[UnitSetup],
		[Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5)] as Array[Vector2i], fight_seed)
	setup.summon_kits.append(pup)
	return setup


## Steady, with every unit hitting back for 1 each time it's hit: each hit
## starts a chain of hits back and forth that only the chain limit stops.
static func _chain_setup(fight_seed: int, hp_bp: int) -> FightSetup:
	var setup: FightSetup = _setup(fight_seed, hp_bp)
	var errors: Array[String] = []
	var thorns: PartDef = PartDef.read(DataReader.new({"id": "thorns", "name": "Thorns", "kind": "ability",
		"effects": [{"trigger": "on_hit_taken", "type": "damage", "amount": 1, "target": "hit_target"}]}, "thorns", errors))
	var kits: Array[UnitDef] = []
	for unit: UnitSetup in setup.units():
		if not kits.has(unit.def):
			kits.append(unit.def)
			unit.def.passives.append(thorns)
	return setup


## The most pups standing at once, from the log.
static func _most_pups(result: FightResult) -> int:
	var standing: int = 4
	var most: int = standing
	for entry: LogEntry in result.combat_log.entries:
		if entry.kind == LogEntry.Kind.SUMMON and entry.note.is_empty():
			standing += 1
		elif entry.kind == LogEntry.Kind.DEATH and entry.target.begins_with("pup"):
			standing -= 1
		most = maxi(most, standing)
	return most


static func _setup(fight_seed: int, hp_bp: int, crowded: bool = false) -> FightSetup:
	var tank: UnitDef = K.kit("tank", {"stats": {"hp": 500, "atk": 12, "def": 30, "speed": 2}, "traits": ["engage"],
		"signature": {"id": "stand", "name": "Stand", "trigger": {"kind": "hp_below", "threshold_bp": 4000}, "targeting": "self",
			"effects": [{"type": "shield", "amount": 60, "target": "self"}]}})
	var archer: UnitDef = K.kit("archer", {"stats": {"hp": 250, "atk": 20, "speed": 2, "range": 4, "crit": 20},
		"basic_attack": {"cooldown_ms": 900, "effects": [{"type": "damage", "amount": 6, "target": "target", "scaling": {"atk": 6000}}]},
		"mana": {"max": 40, "per_attack": 10, "regen_per_s": 2},
		"signature": {"id": "volley", "name": "Volley", "trigger": {"kind": "mana"}, "max_range": 5, "cast_ms": 400,
			"effects": [{"type": "damage", "amount": 15, "target": "target", "scaling": {"atk": 5000}}, {"type": "apply_status", "status": "slow", "target": "target"}]}})
	var hound_data: Dictionary = {"stats": {"hp": 180, "atk": 14, "speed": 3, "crit": 10},
		"passives": [{"id": "pack", "name": "Pack", "kind": "aura", "aura": {"target": "all_allies", "stat": "atsp_bp", "value": 11000}},
			{"id": "snap", "name": "Snap", "kind": "ability", "effects": [{"trigger": "on_hit_taken", "every": 3, "type": "damage", "amount": 4, "target": "hit_target"}]}]}
	var sniper_data: Dictionary = {"stats": {"hp": 140, "atk": 12, "speed": 2, "range": 5}}
	if crowded:
		hound_data["traits"] = ["engage"]
		sniper_data["basic_attack"] = {"effects": [{"type": "damage", "amount": 10, "target": "target"}, {"type": "apply_status", "status": "taunt", "target": "target"}]}
	var hound: UnitDef = K.kit("hound", hound_data)
	var sniper: UnitDef = K.kit("sniper", sniper_data)
	for unit_def: UnitDef in [tank, archer, hound, sniper]:
		unit_def.stats.values[UnitStats.Stat.HP] = FixedMath.apply_bp(unit_def.stats.values[UnitStats.Stat.HP], hp_bp)
	return K.fight([K.at(tank, 3, 2), K.at(archer, 3, 0), K.at(tank, 5, 1)] as Array[UnitSetup],
		[K.foe(hound, 1, 4), K.foe(hound, 3, 4), K.foe(hound, 5, 4), K.foe(sniper, 2, 6), K.foe(sniper, 4, 6), K.foe(hound, 6, 5)] as Array[UnitSetup],
		[Vector2i(4, 3), Vector2i(1, 3)] as Array[Vector2i], fight_seed)
