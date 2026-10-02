extends RefCounted
## Plays a run with a bot (docs/plans/rebuild-phase6-bot-tuning.md, section
## 2.1): one RunFlow action at a time, each one the bot's answer to what the
## run is waiting on (tools/bots/bot.gd). The player owns the order of
## things; a bot only decides.

const Bot = preload("res://tools/bots/bot.gd")

## A run is at most 7 days of at most 2 attempts, a few dozen actions each;
## anything past this is a bug.
const MAX_STEPS: int = 1000


## Plays a run from `run_seed` to its end with `bot`. A refused action goes
## in `errors` and stops it.
static func play(run: RunContent, run_seed: int, bot: Bot, vows: Dictionary[String, String], errors: Array[String]) -> RunFlow:
	var flow: RunFlow = RunFlow.start(run, run_seed, vows, errors)
	if flow == null:
		return null
	bot.begin(flow)
	for i: int in MAX_STEPS:
		if flow.state.phase == RunState.Phase.ENDED:
			return flow
		var refused: String = step(flow, bot)
		if not refused.is_empty():
			errors.append("day %d (%s): %s" % [flow.state.day, RunState.PHASE_NAMES[flow.state.phase], refused])
			return flow
	errors.append("the run didn't end in %d steps" % MAX_STEPS)
	return flow


## One action for wherever the run is, as `bot` answers. Returns why it was
## refused ("": done).
static func step(flow: RunFlow, bot: Bot) -> String:
	var state: RunState = flow.state
	if not state.pick.is_empty():
		var card: int = bot.pick(flow)
		return flow.take_shards() if card < 0 else flow.take_pick(card)
	if not state.relic_choice.is_empty():
		var relic: int = bot.relic(flow)
		return flow.decline_relic() if relic < 0 else flow.take_relic(relic)
	match state.phase:
		RunState.Phase.ROUTE:
			return flow.choose_fight(bot.route(flow))
		RunState.Phase.LOADOUT:
			return _fight(flow, bot)
		RunState.Phase.AFTER:
			return flow.finish_day()
		RunState.Phase.SHOP:
			if bot.shop(flow):
				return ""
			return flow.leave_shop()
		RunState.Phase.NODES:
			return flow.choose_node(bot.node(flow))
		RunState.Phase.NODE:
			return _at_node(flow, bot)
		RunState.Phase.CHOICE:
			return flow.go_deeper() if bot.go_deeper(flow) else flow.end_run()
	return "nothing to do"


static func _at_node(flow: RunFlow, bot: Bot) -> String:
	var state: RunState = flow.state
	if state.node == "camp" and state.camp_used.is_empty():
		return flow.choose_camp(bot.camp(flow))
	if state.node == "rift_tear" and state.rift_depth.is_empty():
		return flow.choose_depth(bot.depth(flow))
	if state.shrine == "open":
		var offer: Array = bot.shrine(flow)
		if not offer.is_empty():
			return flow.shrine_offer(offer[0], offer[1])
	if state.node.begins_with("event:") and not state.event_done:
		var chosen: Array = bot.event(flow)
		if not chosen.is_empty():
			return flow.choose_event(chosen[0], chosen[1])
	if state.node == "oath" and not state.event_done:
		var sworn: int = bot.oath(flow)
		if sworn >= 0:
			return flow.take_oath(sworn)
	if not state.hunt.is_empty():
		return _fight(flow, bot)
	if state.mapping:
		return flow.swap_fight(bot.swap(flow))
	if not state.shop.is_empty() and bot.shop(flow):
		return ""
	if state.dig_in and state.rock.is_empty():
		return flow.place_rock(bot.rock(flow))
	return flow.leave_node()


## The waiting fight, as the bot sets it up: its loadout, formation, and
## markers.
static func _fight(flow: RunFlow, bot: Bot) -> String:
	bot.loadout(flow)
	var hexes: Dictionary[String, Vector2i] = bot.formation(flow)
	var errors: Array[String] = []
	if flow.fight(hexes, errors, bot.markers(flow, hexes)) == null:
		return ", ".join(errors)
	return ""
