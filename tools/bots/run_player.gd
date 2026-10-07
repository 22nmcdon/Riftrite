extends RefCounted
## Plays a run with a bot (docs/plans/rebuild-phase6-bot-tuning.md, section
## 2.1): one RunFlow action at a time, each one the bot's answer to what the
## run is waiting on (tools/bots/bot.gd). The player owns the order of
## things; a bot only decides.

const Bot = preload("res://tools/bots/bot.gd")

## A run is at most 7 days of at most 2 attempts, a few dozen actions each;
## anything past this is a bug.
## Endless runs (phase 8 part 1) go on for many floors.
const MAX_STEPS: int = 8000


## Plays a run from `run_seed` to its end with `bot`. A refused action goes
## in `errors` and stops it.
static func play(run: RunContent, run_seed: int, bot: Bot, vows: Dictionary[String, String], errors: Array[String]) -> RunFlow:
	# A testing bot plays a testing run (phase 8 part 3): Act 1's endless is
	# offered; otherwise the choice comes after Act 3 (8c-6c).
	var flow: RunFlow = RunFlow.start(run, run_seed, vows, errors, bot.testing)
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
	# The apex vow, once open (phase 8 part 2).
	var waiting: Array[String] = flow.apex_waiting()
	if not waiting.is_empty():
		return flow.vow_apex(waiting[0], bot.apex(flow, waiting[0]))
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
			if bot.go_deeper(flow) and flow.can_go_deeper():
				return flow.go_deeper()
			return flow.next_act() if flow.run.next_act(flow.state) != null else flow.end_run()
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
	_move_rock(flow, bot)
	var hexes: Dictionary[String, Vector2i] = bot.formation(flow)
	var errors: Array[String] = []
	if flow.fight(hexes, errors, bot.markers(flow, hexes)) == null:
		return ", ".join(errors)
	return ""


## Dig In's rock, placed at the node before the fight was chosen, moved to
## the nearest hex of the bot's choice that isn't the chosen fight's water or
## void (the player would click another hex).
static func _move_rock(flow: RunFlow, bot: Bot) -> void:
	var state: RunState = flow.state
	if not state.dig_in or state.rock.size() != 2 or not state.hunt.is_empty() or state.chosen.is_empty():
		return
	if flow.rock_on_ground(state.chosen, Vector2i(state.rock[0], state.rock[1])).is_empty():
		return
	for hex: Vector2i in Bot.nearest_first(flow.run.content.tuning.make_grid(), bot.rock(flow)):
		if flow.place_rock(hex).is_empty():
			return
