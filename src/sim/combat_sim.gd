class_name CombatSim
extends RefCounted
## Runs one fight, tick by tick (20 ticks per second). Pure logic: no nodes,
## no rendering (CLAUDE.md rule 2). Same FightSetup + same content = same log.
##
## Each tick:
##   1. Rift Collapse damage, once per second from collapse start.
##   2. Statuses tick (damage over time, timers running out).
##   3. Every living unit's items advance their cooldowns (slower when Slowed,
##      not at all when Frozen); collect the ones that fire.
##   4. Resolve those firings in resolution order: heroes then enemies, front
##      row then back, left to right, and each unit's items in row order.
##   5. Units at 0 HP die. They still fired whatever was ready this tick,
##      so resolution order gives neither side an edge.
##   6. Check for victory, defeat, or a tie.

var content: ContentDb
var tuning: TuningDef
var setup: FightSetup
var collapse: CollapseDef
var rng: SimRng
var combat_log: CombatLog = CombatLog.new()
var tick: int = 0
var heroes: Array[UnitState] = []
var enemies: Array[UnitState] = []
## Every unit, in resolution order.
var units: Array[UnitState] = []
var finished: bool = false
var outcome: FightResult.Outcome = FightResult.Outcome.TIE


## Validates the setup and runs the whole fight.
static func run(fight_setup: FightSetup, fight_content: ContentDb) -> FightResult:
	var result := FightResult.new()
	result.errors = fight_setup.validate(fight_content)
	if fight_content.tuning.collapse_for_act(fight_setup.act) == null:
		result.errors.append("tuning has no Rift Collapse numbers for act %d" % fight_setup.act)
	if not result.errors.is_empty():
		return result
	var sim := CombatSim.new(fight_setup, fight_content)
	while not sim.finished:
		sim.step()
	result.outcome = sim.outcome
	result.end_tick = sim.tick
	result.combat_log = sim.combat_log
	return result


## Builds a fight ready to step. Call run() instead unless you need to step
## tick by tick (for example, to play a fight back). The setup must be valid.
func _init(fight_setup: FightSetup, fight_content: ContentDb) -> void:
	setup = fight_setup
	content = fight_content
	tuning = content.tuning
	collapse = tuning.collapse_for_act(setup.act)
	rng = SimRng.new(setup.seed_value)
	heroes = _build_side(setup.heroes, UnitSetup.Side.HEROES, content)
	enemies = _build_side(setup.enemies, UnitSetup.Side.ENEMIES, content)
	units.append_array(heroes)
	units.append_array(enemies)
	for i: int in units.size():
		for item: ItemState in units[i].items:
			item.owner_index = i

	var start := LogEntry.new()
	start.kind = LogEntry.Kind.FIGHT_START
	start.note = "seed %d, act %d" % [setup.seed_value, setup.act]
	combat_log.add(start)


## Advances one tick. Does nothing once the fight is over.
func step() -> void:
	if finished:
		return
	tick += 1
	_apply_collapse()
	Statuses.tick_all(self)

	var ready: Array[ItemState] = []
	for unit: UnitState in units:
		if not unit.alive:
			continue
		var rate_bp: int = unit.cooldown_rate_bp()
		for item: ItemState in unit.items:
			if item.advance(rate_bp):
				ready.append(item)
	for item: ItemState in ready:
		EffectRunner.fire(self, item)

	_process_deaths()
	_check_end()


## A log entry for the current tick, credited to `source`.
func new_entry(kind: LogEntry.Kind, source: EffectSource) -> LogEntry:
	var entry := LogEntry.new()
	entry.tick = tick
	entry.kind = kind
	entry.set_source(source)
	return entry


func owner_of(item: ItemState) -> UnitState:
	return units[item.owner_index]


func allies_of(unit: UnitState) -> Array[UnitState]:
	return heroes if unit.side == UnitSetup.Side.HEROES else enemies


func enemies_of(unit: UnitState) -> Array[UnitState]:
	return enemies if unit.side == UnitSetup.Side.HEROES else heroes


## Shield takes damage first, then HP (HP stops at 0). Returns how much the
## shield absorbed.
func apply_damage(target: UnitState, amount: int) -> int:
	var absorbed: int = mini(target.shield, amount)
	target.shield -= absorbed
	target.hp = maxi(target.hp - (amount - absorbed), 0)
	return absorbed


## Collapse damage for the current tick, or 0 if it doesn't hit this tick.
## Starts at `base` at collapse start, grows by `growth` each second, and from
## the surge time the growth itself rises by `accel` each second.
func collapse_damage_at(at_tick: int) -> int:
	if at_tick < tuning.collapse_start_ticks:
		return 0
	if (at_tick - tuning.collapse_start_ticks) % FixedMath.TICKS_PER_SECOND != 0:
		return 0
	@warning_ignore("integer_division")
	var seconds: int = (at_tick - tuning.collapse_start_ticks) / FixedMath.TICKS_PER_SECOND
	var damage: int = collapse.base + collapse.growth * seconds
	if at_tick > tuning.collapse_surge_ticks:
		@warning_ignore("integer_division")
		var surge_seconds: int = (at_tick - tuning.collapse_surge_ticks) / FixedMath.TICKS_PER_SECOND
		@warning_ignore("integer_division")
		damage += collapse.accel * surge_seconds * (surge_seconds + 1) / 2
	return damage


func _apply_collapse() -> void:
	var damage: int = collapse_damage_at(tick)
	if damage <= 0:
		return
	for unit: UnitState in units:
		if not unit.alive:
			continue
		var entry := LogEntry.new()
		entry.tick = tick
		entry.kind = LogEntry.Kind.COLLAPSE
		entry.source_item = LogEntry.COLLAPSE_SOURCE
		entry.source_item_name = "Rift Collapse"
		entry.target = unit.id
		entry.amount = damage
		entry.absorbed = apply_damage(unit, damage)
		unit.last_hit_by = "Rift Collapse"
		combat_log.add(entry)


func _process_deaths() -> void:
	for unit: UnitState in units:
		if unit.alive and unit.hp <= 0:
			unit.alive = false
			var entry := LogEntry.new()
			entry.tick = tick
			entry.kind = LogEntry.Kind.DEATH
			entry.target = unit.id
			entry.note = "last hit: %s" % unit.last_hit_by
			combat_log.add(entry)


func _check_end() -> void:
	var heroes_up: bool = _any_alive(heroes)
	var enemies_up: bool = _any_alive(enemies)
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


static func _any_alive(side_units: Array[UnitState]) -> bool:
	for unit: UnitState in side_units:
		if unit.alive:
			return true
	return false


static func _build_side(setups: Array[UnitSetup], side: UnitSetup.Side, fight_content: ContentDb) -> Array[UnitState]:
	# Resolution order: front row left to right, then back row.
	var result: Array[UnitState] = []
	for row: UnitSetup.Row in [UnitSetup.Row.FRONT, UnitSetup.Row.BACK]:
		var column: int = 0
		for unit_setup: UnitSetup in setups:
			if unit_setup.row == row:
				result.append(UnitState.from_setup(unit_setup, side, column, fight_content))
				column += 1
	return result
