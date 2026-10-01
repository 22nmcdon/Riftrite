extends RefCounted
## Small helpers for driving a RunFlow through the day's order in tests
## (phase 5c step 8: the route, the fight, after it, the Pedlar, a node).


## From after the fight (the pick and any relic choice settled) to the next
## day's route: the Pedlar, then a Camp node with nothing taken.
static func next_day(flow: RunFlow) -> String:
	var refused: String = flow.finish_day()
	if refused.is_empty():
		refused = flow.leave_shop()
	if refused.is_empty():
		refused = flow.choose_node(flow.state.nodes.find("camp"))
	if refused.is_empty():
		refused = flow.leave_node()
	return refused


## Into a Camp node now, whatever the phase, with `options` its menu (the
## drawn menu if empty).
static func to_camp(flow: RunFlow, options: Array[String] = []) -> void:
	flow.close_shop()
	flow.state.phase = RunState.Phase.NODES
	flow.state.nodes.assign(["camp"])
	flow.choose_node(0)
	if not options.is_empty():
		flow.state.camp.assign(options)


## Into the Magpie's node now, whatever the phase.
static func to_magpie(flow: RunFlow) -> void:
	flow.close_shop()
	flow.state.phase = RunState.Phase.NODES
	flow.state.nodes.assign(["magpie"])
	flow.choose_node(0)


## The Pedlar open now, whatever the phase (after the fight's shop).
static func to_pedlar(flow: RunFlow) -> void:
	flow.close_shop()
	flow.state.phase = RunState.Phase.SHOP
	flow.open_shop("pedlar")
