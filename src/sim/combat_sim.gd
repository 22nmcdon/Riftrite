class_name CombatSim
extends RefCounted
## Runs one fight in the arena, tick by tick (20 ticks per second). Pure
## logic: no nodes, no rendering (CLAUDE.md rule 2). Same FightSetup + same
## content = same log. Design: docs/plans/rebuild-phase1-arena-sim.md.
##
## Each tick (section 3; the parts marked "later" come with later steps):
##   0. Auras whose window opens or closes now are folded in again (Passives).
##   1. Rift Collapse (later).
##   2. Statuses tick: damage over time, and timers running out (Statuses).
##   3. Shots land, in the order they were fired (Shots).
##   4. Warned areas land (later).
##   5. Each standing unit acts, in the fight's order (heroes, then enemies):
##      its mana regenerates (Mana), and its signature fires if its trigger
##      is met (Signatures; a unit casting does nothing else). Stunned, it
##      stops there. Otherwise its attack's cooldown runs (slower when
##      Slowed); a Taunt makes the taunter its target, or it keeps or picks
##      a target (Targeting); with the target in reach it stands and
##      attacks when ready, otherwise it walks (Movement; not when Rooted).
##   6. Events: this tick's log is read for count signatures and ability
##      passives (Events). Phases come later.
##   7. Units at 0 HP fall, unless Undying holds them at 1 HP or a would_fall
##      signature saves them; on_kill is raised for whoever felled them.
##      They still acted this tick if their turn came, so going first gives
##      neither side an edge.
##   8. Victory, defeat, or a tie (180s, or both sides falling together; a
##      tie counts as a guild victory).

var content: ContentDb
var tuning: TuningDef
var setup: FightSetup
var grid: HexGrid
var rng: SimRng
var combat_log: CombatLog = CombatLog.new()
var tick: int = 0
## Every unit, in the fight's order.
var units: Array[UnitState] = []
var heroes: Array[UnitState] = []
var enemies: Array[UnitState] = []
var rocks: Array[ArenaPlane.Circle] = []
## The ground still standing (the whole arena until the collapse).
var safe: Rect2i
## Shots in flight, in the order they were fired.
var shots: Array[Shots.Shot] = []
var finished: bool = false
var outcome: FightResult.Outcome = FightResult.Outcome.TIE
var _nav: NavGrid
## Log entries before this one have been read by Events.
var _events_read: int = 0
## Some unit listens for events (a count signature), so the log is read.
var _listening: bool = false
## Each unit by id (lookup only; never iterated).
var _by_id: Dictionary[String, UnitState] = {}
## Ticks where an aura window opens or closes (lookup only), and the auras
## active now ("unit:passive", see Passives.rederive).
var _aura_ticks: Dictionary[int, bool] = {}
var _active_auras: Array[String] = []


## Validates the setup and runs the whole fight.
static func run(fight_setup: FightSetup, fight_content: ContentDb) -> FightResult:
	var result := FightResult.new()
	result.errors = fight_setup.validate(fight_content)
	if not result.errors.is_empty():
		return result
	var sim := CombatSim.new(fight_setup, fight_content)
	while not sim.finished:
		sim.step()
	result.outcome = sim.outcome
	result.end_tick = sim.tick
	result.combat_log = sim.combat_log
	return result


## Builds a fight ready to step. Use run() unless you need to step it tick
## by tick (to play it back, or in tests). The setup must be valid.
func _init(fight_setup: FightSetup, fight_content: ContentDb) -> void:
	setup = fight_setup
	content = fight_content
	tuning = content.tuning
	grid = tuning.make_grid()
	rng = SimRng.new(setup.seed_value)
	safe = grid.bounds()
	_nav = NavGrid.make(grid.bounds(), tuning.nav_cell)
	for rock: Vector2i in setup.rocks:
		rocks.append(ArenaPlane.Circle.make(grid.center(rock.x, rock.y), tuning.rock_radius, "rock"))
	for unit_setup: UnitSetup in setup.units():
		var unit: UnitState = UnitState.from_setup(unit_setup, units.size(), grid, tuning.unit_radius)
		unit.attack_rate_bp = attack_rate_bp(unit)
		units.append(unit)
		_by_id[unit.id] = unit
		(heroes if unit.side == EffectSource.Team.HEROES else enemies).append(unit)
		if (unit.signature != null and unit.signature.def.trigger.kind == TriggerDef.Kind.COUNT) or not unit.listeners.is_empty():
			_listening = true
	var start := LogEntry.new()
	start.kind = LogEntry.Kind.FIGHT_START
	start.note = "seed %d, act %d" % [setup.seed_value, setup.act]
	combat_log.add(start)
	_aura_ticks = Passives.aura_boundaries(self)
	_active_auras = Passives.rederive(self, _active_auras)


## Advances one tick. Does nothing once the fight is over.
func step() -> void:
	if finished:
		return
	tick += 1
	if _aura_ticks.has(tick):
		_active_auras = Passives.rederive(self, _active_auras)
	Statuses.tick_all(self)
	Shots.land_due(self)
	for unit: UnitState in units:
		if unit.alive:
			_act(unit)
	var read_to: int = combat_log.entries.size()
	if _listening:
		Events.dispatch(self, _events_read, read_to)
	_events_read = read_to
	_process_deaths()
	_check_end()


func _act(unit: UnitState) -> void:
	if unit.def.mana != null:
		Mana.regen(self, unit)
	var casting: bool = Signatures.act(self, unit) if unit.signature != null else false
	var has_statuses: bool = not unit.statuses.is_empty()
	if has_statuses and Statuses.has_kind(unit, StatusDef.Kind.STUN):
		if unit.leg_active:
			Movement.halt(self, unit, "stunned")
		return
	var slow: int = Statuses.slow_bp(unit) if has_statuses else 0
	unit.attack.advance(unit.attack_rate_bp if slow == 0 else FixedMath.apply_bp(unit.attack_rate_bp, FixedMath.BP_ONE - slow))
	if casting:
		if unit.leg_active:
			Movement.halt(self, unit, "casting")
		return
	var target: UnitState = unit.target
	if has_statuses:
		var taunter: UnitState = Statuses.taunter(self, unit)
		if taunter != null and taunter != target:
			Targeting.set_target(self, unit, taunter, "taunted")
			target = taunter
	if target == null or not target.alive:
		Targeting.update(self, unit)
		target = unit.target
	if target == null:
		if unit.leg_active:
			Movement.halt(self, unit, "no target")
		return
	if unit.in_reach_of(target):
		if unit.leg_active:
			Movement.halt(self, unit, "in reach")
		if unit.attack.ready():
			EffectRunner.basic_attack(self, unit)
		return
	Movement.walk(self, unit)


## How fast the unit's basic attack cooldown runs before any Slow (10000 =
## normal): faster with ATSP.
func attack_rate_bp(unit: UnitState) -> int:
	return FixedMath.BP_ONE + unit.stats.get_stat(UnitStats.Stat.ATSP) * tuning.atsp_bp_per_point


# --- the board ---------------------------------------------------------------

## Everything `unit` mustn't overlap: every other standing unit (but
## `except`, if given) and every rock.
func obstacles_for(unit: UnitState, except: UnitState) -> Array[ArenaPlane.Circle]:
	var found: Array[ArenaPlane.Circle] = []
	for other: UnitState in units:
		if other != unit and other != except and other.alive:
			found.append(other.circle())
	found.append_array(rocks)
	return found


## True if `unit` fits at `point`: inside the safe ground and overlapping no
## other standing unit and no rock.
func fits(unit: UnitState, point: Vector2i) -> bool:
	if not ArenaPlane.inside(safe, point, unit.radius):
		return false
	for other: UnitState in units:
		if other != unit and other.alive and ArenaPlane.overlaps(point, unit.radius, other.pos, other.radius):
			return false
	for rock: ArenaPlane.Circle in rocks:
		if ArenaPlane.overlaps(point, unit.radius, rock.center, rock.radius):
			return false
	return true


## The pathfinding grid set up for `unit` walking (with `except` not in the
## way; its target, when it has one).
func nav_for(unit: UnitState, except: UnitState) -> NavGrid:
	_nav.begin(safe, unit.radius)
	for circle: ArenaPlane.Circle in obstacles_for(unit, except):
		_nav.add_obstacle(circle.center, circle.radius)
	return _nav


func standing_allies_of(unit: UnitState) -> Array[UnitState]:
	return _standing(heroes if unit.side == EffectSource.Team.HEROES else enemies)


func standing_enemies_of(unit: UnitState) -> Array[UnitState]:
	return _standing(enemies if unit.side == EffectSource.Team.HEROES else heroes)


func unit_by_id(unit_id: String) -> UnitState:
	return _by_id.get(unit_id, null)


static func _standing(side_units: Array[UnitState]) -> Array[UnitState]:
	var found: Array[UnitState] = []
	for unit: UnitState in side_units:
		if unit.alive:
			found.append(unit)
	return found


# --- damage ------------------------------------------------------------------

## A log entry for the current tick, credited to `source`.
func new_entry(kind: LogEntry.Kind, source: EffectSource) -> LogEntry:
	var entry := LogEntry.new()
	entry.tick = tick
	entry.kind = kind
	entry.set_source(source)
	return entry


## Hit damage after the target's DEF: amount x C / (C + DEF).
func mitigate_hit(target: UnitState, amount: int) -> int:
	return FixedMath.mul_div(amount, tuning.defense_constant, tuning.defense_constant + maxi(target.defense(), 0))


## Shield takes damage first, then HP (HP stops at 0). Returns how much the
## shield absorbed.
func apply_damage(target: UnitState, amount: int) -> int:
	return apply_damage_vs_shield(target, amount, FixedMath.BP_ONE)


## Like apply_damage, but the damage is only `vs_shield_bp` effective against
## Shield (5000: each point of Shield soaks 2 damage; 0: skips Shield).
## Whatever the Shield doesn't soak hits HP at full strength. All of it
## counts as damage taken, for mana.
func apply_damage_vs_shield(target: UnitState, amount: int, vs_shield_bp: int) -> int:
	if amount > 0:
		Mana.on_damage_taken(self, target, amount)
	if vs_shield_bp <= 0 or target.shield <= 0:
		target.hp = maxi(target.hp - amount, 0)
		return 0
	var shield_cost: int = FixedMath.apply_bp(amount, vs_shield_bp)
	if target.shield >= shield_cost:
		target.shield -= shield_cost
		return amount
	var absorbed: int = mini(FixedMath.mul_div(target.shield, FixedMath.BP_ONE, vs_shield_bp), amount)
	target.shield = 0
	target.hp = maxi(target.hp - (amount - absorbed), 0)
	return absorbed


# --- the end -----------------------------------------------------------------

## Settles who falls. A would_fall signature fires at once and may fell
## others, so it goes round again until nobody new is at 0 HP.
func _process_deaths() -> void:
	var aura_lost: bool = false
	var again: bool = true
	while again:
		again = false
		for unit: UnitState in units:
			if not unit.alive or unit.hp > 0:
				continue
			var undying: StatusState = _undying(unit)
			if undying != null:
				unit.hp = 1
				var held: LogEntry = new_entry(LogEntry.Kind.SAVED, undying.source)
				held.target = unit.id
				held.note = undying.def.name
				combat_log.add(held)
				continue
			if Signatures.would_fall(self, unit):
				again = true
				continue
			_fall(unit)
			aura_lost = aura_lost or Passives.has_aura(unit)
			Events.kill(self, unit)
	if aura_lost:
		_active_auras = Passives.rederive(self, _active_auras)


func _undying(unit: UnitState) -> StatusState:
	for state: StatusState in unit.statuses:
		if state.def.kind == StatusDef.Kind.UNDYING:
			return state
	return null


func _fall(unit: UnitState) -> void:
	unit.alive = false
	unit.target = null
	unit.route.clear()
	unit.leg_active = false
	var entry := LogEntry.new()
	entry.tick = tick
	entry.kind = LogEntry.Kind.DEATH
	entry.target = unit.id
	entry.to_pos = unit.pos
	entry.note = "last hit: %s" % unit.last_hit_by
	combat_log.add(entry)


func _check_end() -> void:
	var heroes_up: bool = heroes.any(func(unit: UnitState) -> bool: return unit.alive)
	var enemies_up: bool = enemies.any(func(unit: UnitState) -> bool: return unit.alive)
	if heroes_up and enemies_up and tick < tuning.tie_ticks:
		return
	finished = true
	var note: String
	if not heroes_up and not enemies_up:
		outcome = FightResult.Outcome.TIE
		note = "Tie: both sides fell together (counts as a victory)"
	elif not enemies_up:
		outcome = FightResult.Outcome.VICTORY
		note = "Victory"
	elif not heroes_up:
		outcome = FightResult.Outcome.DEFEAT
		note = "Defeat"
	else:
		outcome = FightResult.Outcome.TIE
		note = "Tie: both sides outlasted the rift (counts as a victory)"
	var entry := LogEntry.new()
	entry.tick = tick
	entry.kind = LogEntry.Kind.FIGHT_END
	entry.note = note
	combat_log.add(entry)
