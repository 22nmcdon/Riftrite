class_name CombatSim
extends RefCounted
## Runs one fight in the arena, tick by tick (20 ticks per second). Pure
## logic: no nodes, no rendering (CLAUDE.md rule 2). Same FightSetup + same
## content = same log. Design: docs/plans/rebuild-phase1-arena-sim.md.
##
## Each tick (section 3; the parts marked "later" come with later steps):
##   0. Auras whose window opens or closes now are folded in again (Passives).
##   1. Rift Collapse: a ring's warning or crumble, and once a second,
##      damage to everyone on crumbled ground (Collapse).
##   2. Statuses tick: damage over time, and timers running out (Statuses).
##   3. Shots land, in the order they were fired (Shots).
##   4. Warned areas land, in the order they were cast (Areas).
##   5. Each standing unit acts, in the fight's order (heroes, then enemies,
##      then summons as they joined; one summoned this tick acts when the
##      order reaches it):
##      its mana regenerates (Mana), and its signature fires if its trigger
##      is met (Signatures; a unit casting does nothing else). Stunned, it
##      stops there. Otherwise its attack's cooldown runs (slower when
##      Slowed); a Taunt makes the taunter its target, or it keeps or picks
##      a target (Targeting). On crumbled ground, it walks back to safe
##      ground (Movement.escape). With the target in reach it stands and
##      attacks when ready, otherwise it walks (Movement; not when Rooted,
##      or while an engager holds it: Engage, checked as it's about to walk,
##      and every tick while it's engaged).
##   6. Events: this tick's log is read for count signatures and ability
##      passives (Events). Then on_interval and on_ally_below_hp passives
##      run (Passives.run_timed), and units below a phase's threshold enter
##      it (Phases).
##   7. Units at 0 HP fall, unless Undying holds them at 1 HP or a would_fall
##      signature saves them; on_kill is raised for whoever felled them,
##      and their on_fall passives run (which may fell others: it goes
##      round again).
##      They were still updated this tick if their place in the order came,
##      so being updated first gives neither side an edge.
##   8. Victory, defeat, or a tie (180s, or both sides falling together; a
##      tie counts as a guild victory).

## A tick that never comes.
const NEVER: int = 1 << 62

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
## Rift Collapse (Collapse): the act's numbers, the tick the first ring
## crumbles, how many rings have been warned and have crumbled, and its log
## source.
var collapse: CollapseDef
var collapse_start: int
var collapse_warned: int = 0
var collapse_rings: int = 0
var collapse_source: EffectSource = EffectSource.make("", LogEntry.COLLAPSE_SOURCE, "Rift Collapse")
## Shots in flight, in the order they were fired, and the soonest one lands
## on (NEVER: none in flight).
var shots: Array[Shots.Shot] = []
var next_shot_tick: int = NEVER
## Warned areas on their way, in the order they were cast.
var areas: Array[Areas.Pending] = []
var finished: bool = false
var outcome: FightResult.Outcome = FightResult.Outcome.TIE
var _nav: NavGrid
## Log entries before this one have been read by Events.
var _events_read: int = 0
## Some unit listens for events (a count signature), so the log is read.
var _listening: bool = false
## Some unit has phases, so they're checked each tick.
var _phased: bool = false
## Some unit has on_interval or on_ally_below_hp passives, so they're
## checked each tick.
var _timed_passives: bool = false
## Some unit has an aura that holds while it's taunting, so auras are folded
## in again when a Taunt starts or ends, or a taunted unit falls.
var taunt_auras: bool = false
## The units with the Engage trait on each side.
var _hero_engagers: Array[UnitState] = []
var _enemy_engagers: Array[UnitState] = []
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
	collapse = tuning.collapse_for_act(setup.act)
	collapse_start = tuning.collapse_start_ticks
	_nav = NavGrid.make(grid.bounds(), tuning.nav_cell)
	for rock: Vector2i in setup.rocks:
		rocks.append(ArenaPlane.Circle.make(grid.center(rock.x, rock.y), tuning.rock_radius, "rock"))
	for unit_setup: UnitSetup in setup.units():
		add_unit(UnitState.from_setup(unit_setup, units.size(), grid, tuning.unit_radius))
	var start := LogEntry.new()
	start.kind = LogEntry.Kind.FIGHT_START
	start.note = "seed %d, act %d" % [setup.seed_value, setup.act]
	combat_log.add(start)
	for unit: UnitState in units:
		if unit.tactic != null:
			Tactics.start(self, unit)
	units_joined()


## Adds a unit at the end of the fight's order (at the start, or a summon:
## then call units_joined once they're all in).
func add_unit(unit: UnitState) -> void:
	unit.melee_reach = tuning.melee_reach
	unit.refresh_reach()
	unit.joined_at = tick
	unit.attack_rate_bp = attack_rate_bp(unit)
	units.append(unit)
	_by_id[unit.id] = unit
	if unit.def.has_trait("engage"):
		(_hero_engagers if unit.side == EffectSource.Team.HEROES else _enemy_engagers).append(unit)
	(heroes if unit.side == EffectSource.Team.HEROES else enemies).append(unit)
	note_listeners(unit)
	if not unit.phases.is_empty():
		_phased = true


## Starts reading the log for events if `unit` listens for any (a count
## signature or an ability passive).
func note_listeners(unit: UnitState) -> void:
	if (unit.signature != null and unit.signature.def.trigger.kind == TriggerDef.Kind.COUNT) or not unit.listeners.is_empty():
		_listening = true
	if Passives.has_timed(unit):
		_timed_passives = true


## After units join (at the start, or summons) or enter a phase: auras are
## folded in again, so theirs count and they get their side's.
func units_joined() -> void:
	_aura_ticks = Passives.aura_boundaries(self)
	taunt_auras = false
	for unit: UnitState in units:
		if Passives.has_taunting_aura(unit):
			taunt_auras = true
	_active_auras = Passives.rederive(self, _active_auras)


## Folds every aura in again (a Taunt started or ended, for auras that hold
## while taunting).
func refold_auras() -> void:
	_active_auras = Passives.rederive(self, _active_auras)


## The first free id for a unit of this kit: its id, then "#2", "#3", ...
func next_unit_id(kit_id: String) -> String:
	if not _by_id.has(kit_id):
		return kit_id
	var n: int = 2
	while _by_id.has("%s#%d" % [kit_id, n]):
		n += 1
	return "%s#%d" % [kit_id, n]


## How many units stand on a side.
func standing_count(side: EffectSource.Team) -> int:
	var count: int = 0
	for unit: UnitState in (heroes if side == EffectSource.Team.HEROES else enemies):
		if unit.alive:
			count += 1
	return count


## Advances one tick. Does nothing once the fight is over.
func step() -> void:
	if finished:
		return
	tick += 1
	if _aura_ticks.has(tick):
		_active_auras = Passives.rederive(self, _active_auras)
	Collapse.tick(self)
	Statuses.tick_all(self)
	Shots.land_due(self)
	Areas.land_due(self)
	for unit: UnitState in units:
		if unit.alive:
			_act(unit)
	var read_to: int = combat_log.entries.size()
	if _listening:
		Events.dispatch(self, _events_read, read_to)
	_events_read = read_to
	if _timed_passives:
		Passives.run_timed(self)
	if _phased:
		Phases.check(self)
	_process_deaths()
	_check_end()


## One unit's update this tick. It runs for every unit every tick, so it's
## written for speed: the common checks are inlined.
func _act(unit: UnitState) -> void:
	var has_statuses: bool = not unit.statuses.is_empty()
	# Mana regen (Mana), unless Silenced.
	if unit.mana_regen > 0 and unit.mana < unit.mana_cap and not (has_statuses and Statuses.has_kind(unit, StatusDef.Kind.SILENCE)):
		unit.mana = mini(unit.mana + unit.mana_regen, unit.mana_cap)
	# Landing from a leap: it can't act.
	if tick < unit.landing_until:
		return
	var casting: bool = false
	var signature: AbilityState = unit.signature
	if signature != null and (signature.pending > 0 or signature.cast_ends_at >= 0 \
			or (signature.mana_trigger and unit.mana >= unit.mana_cap) or (signature.once_trigger and not signature.fired)):
		casting = Signatures.act(self, unit)
		has_statuses = not unit.statuses.is_empty()
		if tick < unit.landing_until:
			return
	if has_statuses and Statuses.has_kind(unit, StatusDef.Kind.STUN):
		if unit.leg_active:
			Movement.halt(self, unit, "stunned")
		return
	var attack: AbilityState = unit.attack
	if attack.progress_bp < attack.needed:
		var rate: int = unit.attack_rate_bp
		if has_statuses:
			var slow: int = Statuses.slow_bp(unit)
			if slow != 0:
				rate = FixedMath.apply_bp(rate, FixedMath.BP_ONE - slow)
		attack.progress_bp = mini(attack.progress_bp + rate, attack.needed)
	if casting:
		if unit.leg_active:
			Movement.halt(self, unit, "casting")
		return
	if unit.holding:
		Tactics.check_release(self, unit)
	var target: UnitState = unit.target
	if has_statuses:
		var taunter: UnitState = Statuses.taunter(self, unit)
		if taunter != null and taunter != target:
			Targeting.set_target(self, unit, taunter, "taunted")
			target = taunter
	if target != null and target.alive and target.side != unit.side and Statuses.is_stealthed(target):
		Targeting.lose(self, unit, "%s is stealthed" % target.id)
		target = null
	if target == null or not target.alive:
		Targeting.update(self, unit)
		target = unit.target
	var engagers: Array[UnitState] = _enemy_engagers if unit.side == EffectSource.Team.HEROES else _hero_engagers
	if not unit.engagements.is_empty():
		Engage.update(self, unit, engagers)
	if collapse_rings > 0 and not unit.airborne and on_crumbled(unit.pos):
		Movement.escape(self, unit)
		return
	if target == null:
		if unit.leg_active:
			Movement.halt(self, unit, "no target")
		return
	if unit.def.hop_cooldown_ticks > 0 and tick >= unit.hop_ready_at and Displacement.hop_away(self, unit, engagers):
		return
	var dx: int = target.pos.x - unit.pos.x
	var dy: int = target.pos.y - unit.pos.y
	if dx * dx + dy * dy <= unit.reach_sq:
		# A flier in the air lands on a free spot before it attacks.
		if unit.airborne and not Movement.settle(self, unit, target):
			return
		if unit.leg_active:
			Movement.halt(self, unit, "in reach")
		if attack.progress_bp >= attack.needed:
			EffectRunner.basic_attack(self, unit)
		return
	# About to walk: a unit holding its ground (Tactics) doesn't.
	if unit.holding:
		Tactics.stay(self, unit)
		return
	# About to walk: an engager next to it may hold it.
	if unit.engagements.is_empty() and not engagers.is_empty():
		Engage.update(self, unit, engagers)
	if not unit.engagements.is_empty() and Engage.holds(unit):
		if unit.leg_active:
			Movement.halt(self, unit, "engaged")
		return
	Movement.walk(self, unit)


## How fast the unit's basic attack cooldown runs before any Slow (10000 =
## normal): faster with ATSP.
func attack_rate_bp(unit: UnitState) -> int:
	return FixedMath.BP_ONE + unit.stats.get_stat(UnitStats.Stat.ATSP) * tuning.atsp_bp_per_point


# --- the board ---------------------------------------------------------------

## Everything `unit` mustn't overlap: every other standing unit (but
## `except`, if given, and fliers in the air) and every rock.
func obstacles_for(unit: UnitState, except: UnitState) -> Array[ArenaPlane.Circle]:
	var found: Array[ArenaPlane.Circle] = []
	for other: UnitState in units:
		if other != unit and other != except and other.alive and not other.airborne:
			found.append(other.circle())
	found.append_array(rocks)
	return found


## True if `unit` fits at `point`: inside the safe ground and overlapping no
## other standing unit (fliers in the air aside) and no rock.
func fits(unit: UnitState, point: Vector2i) -> bool:
	return ArenaPlane.inside(safe, point, unit.radius) and _clear(unit, point)


## Like fits, for a unit not wholly on safe ground walking back to it: it
## may step anywhere in the arena that reaches no further past the safe
## ground than where it stands.
func fits_leaving(unit: UnitState, point: Vector2i) -> bool:
	return ArenaPlane.inside(grid.bounds(), point, unit.radius) \
		and crumbled_depth(point, unit.radius) <= crumbled_depth(unit.pos, unit.radius) and _clear(unit, point)


## True if `point` is on crumbled ground (outside the safe rectangle).
func on_crumbled(point: Vector2i) -> bool:
	return point.x < safe.position.x or point.x > safe.end.x or point.y < safe.position.y or point.y > safe.end.y


## How far a circle of `radius` at `point` reaches past the safe ground
## (0: it's wholly on it), the most on any side.
func crumbled_depth(point: Vector2i, radius: int) -> int:
	return maxi(maxi(maxi(safe.position.x + radius - point.x, point.x + radius - safe.end.x),
		maxi(safe.position.y + radius - point.y, point.y + radius - safe.end.y)), 0)


## The nearest point to `point` where a circle of `radius` is wholly on safe
## ground.
func nearest_safe_point(point: Vector2i, radius: int) -> Vector2i:
	return Vector2i(clampi(point.x, safe.position.x + radius, safe.end.x - radius),
		clampi(point.y, safe.position.y + radius, safe.end.y - radius))


## True if `unit` at `point` overlaps no other standing unit (fliers in the
## air aside) and no rock.
func _clear(unit: UnitState, point: Vector2i) -> bool:
	for other: UnitState in units:
		if other != unit and other.alive and not other.airborne and ArenaPlane.overlaps(point, unit.radius, other.pos, other.radius):
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


## The nav grid for `unit` with only the rocks in it (and the safe ground's
## edge): the way it could go if every unit stood aside.
func ground_nav_for(unit: UnitState) -> NavGrid:
	_nav.begin(safe, unit.radius)
	for rock: ArenaPlane.Circle in rocks:
		_nav.add_obstacle(rock.center, rock.radius)
	return _nav


func standing_allies_of(unit: UnitState) -> Array[UnitState]:
	return _standing(heroes if unit.side == EffectSource.Team.HEROES else enemies)


## The standing enemies `unit` may pick as a target: all but the stealthed.
func targetable_enemies_of(unit: UnitState) -> Array[UnitState]:
	return standing_enemies_of(unit).filter(func(other: UnitState) -> bool: return not Statuses.is_stealthed(other))


func standing_enemies_of(unit: UnitState) -> Array[UnitState]:
	return _standing(enemies if unit.side == EffectSource.Team.HEROES else heroes)


func unit_by_id(unit_id: String) -> UnitState:
	return _by_id.get(unit_id, null)


static func _any_standing(side_units: Array[UnitState]) -> bool:
	for unit: UnitState in side_units:
		if unit.alive:
			return true
	return false


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
			aura_lost = aura_lost or Passives.has_aura(unit) or (taunt_auras and Statuses.has_kind(unit, StatusDef.Kind.TAUNT))
			Events.kill(self, unit)
			if Passives.on_fall(self, unit):
				again = true
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
	entry.note = "last hit: %s" % unit.last_hit_text()
	combat_log.add(entry)


func _check_end() -> void:
	var heroes_up: bool = _any_standing(heroes)
	var enemies_up: bool = _any_standing(enemies)
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
