class_name FightPlayer
extends RefCounted
## Plays a fight live (docs/plans/rebuild-phase3-fight-sandbox.md, section 4):
## it owns a CombatSim built from the fight's setup and steps it as real time
## passes, 20 ticks a second at 1x. It's the only thing that steps the sim;
## the UI only reads it. (The old game's player, from git history, adapted.)
##   - Time comes in only through advance(seconds), so tests can drive a
##     fight with fake time. Real time is presentation, so floats are fine
##     here; the sim still moves in whole ticks.
##   - Speeds 0.5x, 1x, and 2x, and pause (Decision 2).
##   - Seeking to a tick (and restarting, which is seeking to 0) builds a
##     fresh sim and runs it there: the sim is deterministic, so that's the
##     same fight at that moment.
##   - Smooth motion: a unit is drawn between where it stood before the last
##     step and where it stands now, by how far real time is into the next
##     tick (drawn_position).

const SPEEDS: Array[float] = [0.5, 1.0, 2.0]

var setup: FightSetup
var content: ContentDb
var sim: CombatSim
var speed: float = 1.0
var paused: bool = false
## How far real time is into the next tick (0 to 1).
var _carry: float = 0.0
## Log entries already handed out.
var _shown: int = 0
## Where each unit stood before the last step (by id).
var _before: Dictionary[String, Vector2i] = {}


static func make(fight_setup: FightSetup, content_db: ContentDb) -> FightPlayer:
	var player := FightPlayer.new()
	player.setup = fight_setup
	player.content = content_db
	player.sim = CombatSim.new(fight_setup, content_db)
	return player


func finished() -> bool:
	return sim.finished


## Moves the fight on by `seconds` of real time at the current speed.
## Returns the log entries that happened.
func advance(seconds: float) -> Array[LogEntry]:
	if not paused and not sim.finished:
		_carry += seconds * speed * FixedMath.TICKS_PER_SECOND
		while _carry >= 1.0 and not sim.finished:
			_step()
			_carry -= 1.0
		if sim.finished:
			_carry = 0.0
	return take_new()


## Runs the rest of the fight at once.
func skip_to_end() -> Array[LogEntry]:
	while not sim.finished:
		sim.step()
	_before.clear()
	_carry = 0.0
	return take_new()


## The same fight from the start: a fresh sim, nothing handed out yet.
func restart() -> void:
	seek(0)


## The same fight at `tick` (or its end, if it ends sooner): a fresh sim run
## there. Entries up to it count as handed out; read them from the sim's log.
func seek(tick: int) -> void:
	sim = CombatSim.new(setup, content)
	while sim.tick < tick and not sim.finished:
		sim.step()
	_before.clear()
	_carry = 0.0
	_shown = sim.combat_log.entries.size()


## Log entries not handed out yet (the fight's first lines, the first time).
func take_new() -> Array[LogEntry]:
	var entries: Array[LogEntry] = []
	var all: Array[LogEntry] = sim.combat_log.entries
	for i: int in range(_shown, all.size()):
		entries.append(all[i])
	_shown = all.size()
	return entries


## Where to draw a unit on the plane: between where it stood before the last
## step and where it stands now. A unit that joined in the last step, or any
## unit after a skip or seek, is drawn where it stands.
func drawn_position(unit: UnitState) -> Vector2:
	var now := Vector2(unit.pos)
	if not _before.has(unit.id):
		return now
	return Vector2(_before[unit.id]).lerp(now, clampf(_carry, 0.0, 1.0))


## The fight's time as drawn, in ticks: between the last two ticks, like
## drawn_position (the tick itself after a skip or seek). Effects on the
## board run on this clock, so they pause and change speed with the fight.
func drawn_time() -> float:
	if _before.is_empty():
		return float(sim.tick)
	return float(sim.tick) - 1.0 + clampf(_carry, 0.0, 1.0)


## Seconds of fight so far.
func fight_seconds() -> float:
	return float(sim.tick) / FixedMath.TICKS_PER_SECOND


func _step() -> void:
	_before.clear()
	for unit: UnitState in sim.units:
		_before[unit.id] = unit.pos
	sim.step()
