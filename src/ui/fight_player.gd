class_name FightPlayer
extends RefCounted
## Plays a fight back by stepping a fresh CombatSim built from the fight's
## setup: same setup, same fight (CLAUDE.md rule 1), so the replay matches
## the recorded result. Time here is presentation only (floats are fine);
## the sim still advances in whole ticks.

const SPEEDS: Array[float] = [0.5, 1.0, 2.0, 4.0]

var sim: CombatSim
var speed: float = 1.0
var paused: bool = false
## Fractional ticks waiting to be stepped.
var _carry: float = 0.0
## Log entries already handed out.
var _shown: int = 0


static func make(setup: FightSetup, content: ContentDb) -> FightPlayer:
	var player := FightPlayer.new()
	player.sim = CombatSim.new(setup, content)
	return player


func finished() -> bool:
	return sim.finished


## Moves the fight forward by `seconds` of real time at the current speed.
## Returns the log entries that happened.
func advance(seconds: float) -> Array[LogEntry]:
	if not paused and not sim.finished:
		_carry += seconds * speed * FixedMath.TICKS_PER_SECOND
		while _carry >= 1.0 and not sim.finished:
			sim.step()
			_carry -= 1.0
	return take_new()


func skip_to_end() -> Array[LogEntry]:
	while not sim.finished:
		sim.step()
	return take_new()


## Log entries not handed out yet (the fight-start lines, the first time).
func take_new() -> Array[LogEntry]:
	var entries: Array[LogEntry] = []
	var all: Array[LogEntry] = sim.combat_log.entries
	for i: int in range(_shown, all.size()):
		entries.append(all[i])
	_shown = all.size()
	return entries
