extends RefCounted
## Practice fights (docs/plans/rebuild-phase6-bot-tuning.md, section 2.3):
## how much a fight is worth to the heroes, and how much a choice is worth to
## a run, for the good bot's judgments and the expert's tries.
##   - A fight's worth is a win (1) plus the share of the heroes' HP left (so
##     1 to 2), or that share minus 1 for a loss (-1 to 0): any win beats any
##     loss, and a closer loss beats a rout.
##   - A choice is tried on a copy of the run (RunFlow.resume over the state
##     read back from its dict), and is worth the mean worth of the coming
##     fights the act map shows (practice_set) fought on practice seeds,
##     never a real fight's, plus what it did to the shards (SHARD_WORTH
##     each). Placement in a practice fight is the good bot's reading.

const Placement = preload("res://tools/bots/placement.gd")
const Simple = preload("res://tools/run_bot.gd")
const Bot = preload("res://tools/bots/bot.gd")

## What a shard is worth against a fight's worth on day 1: a rare relic
## (12) has to add about 5% of the heroes' HP left in the coming fights to
## be bought. It falls as the act runs out (shard_worth), since shards buy
## nothing once it ends.
const SHARD_WORTH: float = 0.004
## A practice fight this worth or more is a sure win (won with 45% of the
## heroes' HP left).
const SURE: float = 1.45
## Practice seeds start here, away from RunRandom's fight seeds.
const SEED_BASE: int = 7_700_000

## Worths already practiced: the state (as JSON) and the fights -> worth.
## A run's bot clears it each day (clear_cache).
static var _cache: Dictionary[String, float] = {}


static func clear_cache() -> void:
	_cache.clear()


## A shard's worth on `flow`'s day.
static func shard_worth(flow: RunFlow) -> float:
	var days: int = flow.run.act.days.size()
	return SHARD_WORTH * maxf(days + 1 - flow.state.day, 0) / days


## Fights `setup` to its end and returns its worth.
static func worth(setup: FightSetup, content: ContentDb) -> float:
	if setup == null or not setup.validate(content).is_empty():
		return -2.0
	var sim := CombatSim.new(setup, content)
	while not sim.finished:
		sim.step()
	var hp: int = 0
	var max_hp: int = 0
	for unit: UnitState in sim.heroes:
		hp += maxi(unit.hp, 0) if unit.alive else 0
		max_hp += unit.max_hp
	var left: float = float(hp) / maxf(max_hp, 1)
	return 1.0 + left if sim.outcome != FightResult.Outcome.DEFEAT else left - 1.0


## A copy of the run, to try something on.
static func copy(flow: RunFlow) -> RunFlow:
	return RunFlow.resume(flow.run, RunState.from_dict(flow.state.to_dict()))


## The coming fights a player sees on the act map: the next day fight's
## first option (today's while it's still to be fought) and the next
## elite's or the boss's after it. Empty after the boss.
static func practice_set(flow: RunFlow) -> Array[String]:
	var state: RunState = flow.state
	var days: Array[String] = flow.run.act.days
	var first: int = state.day if state.phase == RunState.Phase.ROUTE or state.phase == RunState.Phase.LOADOUT else state.day + 1
	var found: Array[String] = []
	if first > days.size():
		return found
	found.append(state.options[first - 1][0])
	for day: int in range(first + 1, days.size() + 1):
		if days[day - 1] != "normal" and not found.has(state.options[day - 1][0]):
			found.append(state.options[day - 1][0])
			break
	return found


## How `flow`'s team fares in practice against `encounters`: the mean worth,
## each fought as the day's fight (with whatever the run has set up for it).
static func team_worth(flow: RunFlow, encounters: Array[String]) -> float:
	if encounters.is_empty():
		return 0.0
	var key: String = JSON.stringify(flow.state.to_dict()) + ",".join(encounters)
	if _cache.has(key):
		return _cache[key]
	var trial: RunFlow = copy(flow)
	trial.state.phase = RunState.Phase.LOADOUT
	trial.state.pick.clear()
	trial.state.relic_choice.clear()
	var total: float = 0.0
	for encounter_id: String in encounters:
		trial.state.chosen = encounter_id
		total += fight_worth(trial, encounter_id)
	_cache[key] = total / encounters.size()
	return _cache[key]


## The waiting fight of `flow` (at its loadout, or a Hunt), placed by the
## good bot's reading and fought on a practice seed.
static func fight_worth(flow: RunFlow, encounter_id: String) -> float:
	var hexes: Dictionary[String, Vector2i] = place(flow)
	if hexes.is_empty():
		return -2.0
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(hexes, errors, Bot.default_markers(flow, hexes))
	if setup == null:
		return -2.0
	setup.seed_value = SEED_BASE + (encounter_id.hash() & 0xffff) * 16 + flow.state.day
	return worth(setup, flow.run.content)


## The good bot's formation for `flow`'s waiting fight: the best-scored
## legal ones, best first (`count` of them).
static func candidates(flow: RunFlow, count: int = 6) -> Array[Dictionary]:
	var legal: Array[Dictionary] = []
	var setup: FightSetup = null
	for name: String in Simple.FORMATIONS:
		var errors: Array[String] = []
		setup = flow.fight_setup(Simple.formation(name), errors)
		if setup != null:
			break
	if setup == null:
		return legal
	var grid: HexGrid = flow.run.content.tuning.make_grid()
	for placed: Dictionary in Placement.best_formations(setup, grid, count):
		var hexes: Dictionary[String, Vector2i] = {}
		hexes.assign(placed)
		var problems: Array[String] = []
		if flow.fight_setup(hexes, problems, Bot.default_markers(flow, hexes)) != null:
			legal.append(hexes)
	return legal


static func place(flow: RunFlow) -> Dictionary[String, Vector2i]:
	var found: Array[Dictionary] = candidates(flow, 3)
	var hexes: Dictionary[String, Vector2i] = {}
	if not found.is_empty():
		hexes.assign(found[0])
	return hexes


## What doing `action` (a Callable taking a RunFlow, returning "" or why
## not) is worth: on a copy, then the copy's team in practice against
## `encounters`, plus the shards it gained or spent. -INF if it's refused.
static func value(flow: RunFlow, action: Callable, encounters: Array[String]) -> float:
	var trial: RunFlow = copy(flow)
	if not str(action.call(trial)).is_empty():
		return -INF
	return team_worth(trial, encounters) + (trial.state.shards - flow.state.shards) * shard_worth(flow)
