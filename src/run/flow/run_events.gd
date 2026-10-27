class_name RunEvents
extends RefCounted
## The Event node's rules for RunFlow (phase 5c step 8c, docs/plans/design/events.md;
## data/run/events.json): a scene's choices, what each one's results do, and the
## Bloodied Oath. RunFlow keeps the actions' names (choose_event, take_oath, ...)
## and delegates here; every function takes the flow it acts on and changes only
## its state, so RunFlow is still the only way a run changes.


## The scene of the event node the day is in, or null.
static func event_scene(flow: RunFlow) -> EventDef.Scene:
	if flow.state.phase != RunState.Phase.NODE or not flow.state.node.begins_with("event:"):
		return null
	return flow.run.events.scene(flow.state.node.trim_prefix("event:"))


## Why the event's choice `index` can't be made with `target` (a hero id, an
## item id, or "<hero id>:<path id>" for the mirror; "" when it needs none),
## or "". A choice that needs a target, asked with none, says whether any
## target would do.
static func event_problem(flow: RunFlow, index: int, target: String = "") -> String:
	var scene: EventDef.Scene = event_scene(flow)
	if scene == null:
		return flow._not_now("choose in an event")
	if flow.state.event_done:
		return "the choice is made"
	if index < 0 or index >= scene.choices.size():
		return "there's no choice %d" % index
	var choice: EventDef.Choice = scene.choices[index]
	var needs: EventDef.Needs = choice.needs()
	if needs != EventDef.Needs.NOTHING and target.is_empty():
		for candidate: String in event_targets(flow, choice):
			if _choice_problem(flow, choice, candidate).is_empty():
				return ""
		return "no one it fits" if needs != EventDef.Needs.ITEM else "no item it fits"
	return _choice_problem(flow, choice, target)


## Every target a choice could take (the heroes, the run's items, or each
## hero's other paths), fitting or not.
static func event_targets(flow: RunFlow, choice: EventDef.Choice) -> Array[String]:
	var targets: Array[String] = []
	match choice.needs():
		EventDef.Needs.HERO:
			targets.append_array(flow.state.hero_ids())
		EventDef.Needs.ITEM:
			for id: String in flow.run.item_ids:
				if flow.state.item_ranks.has(id):
					targets.append(id)
		EventDef.Needs.PATH:
			for hero: RunState.Hero in flow.state.heroes:
				for path: PathDef in flow.run.content.heroes[hero.id].paths:
					if path.id != hero.path:
						targets.append("%s:%s" % [hero.id, path.id])
	return targets


static func _choice_problem(flow: RunFlow, choice: EventDef.Choice, target: String) -> String:
	var shards: int = flow.state.shards
	for result: EventDef.Result in choice.results:
		match result.kind:
			"pay":
				if shards < result.shards:
					return "it costs %d shards; there are %d" % [result.shards, shards]
				shards -= result.shards
			"item":
				if _item_pool(flow, result.kinds).is_empty():
					return "there's no item left to find"
			"wound":
				var hero: RunState.Hero = flow.state.hero(target)
				if hero == null:
					return "unknown hero \"%s\"" % target
				if hero.wounds >= flow.run.content.tuning.max_wounds:
					return "%s can't take another wound" % target
			"deed":
				var hero: RunState.Hero = flow.state.hero(target)
				if hero == null:
					return "unknown hero \"%s\"" % target
				if hero.transformed:
					return "%s has transformed" % target
			"next_fight":
				if not result.team and flow.state.hero(target) == null:
					return "unknown hero \"%s\"" % target
			"seal":
				if flow.run.day_kind(flow.state, flow.state.day + 1) != "normal":
					return "not before an elite or the boss"
			"rank_up_random":
				if _rankable(flow).is_empty():
					return "no item of yours can go a rank up"
			"rank_up_chosen":
				if not _rankable(flow).has(target):
					return "%s can't go a rank up" % target
			"hunt":
				if Offers.hunt(flow.run, flow.state).is_empty():
					return "there's nothing to drive off today"
			"mirror":
				var hero: RunState.Hero = flow.state.hero(target.get_slice(":", 0))
				var path_id: String = target.get_slice(":", 1)
				if hero == null:
					return "unknown hero \"%s\"" % target.get_slice(":", 0)
				if hero.transformed:
					return "%s has transformed" % hero.id
				if not flow.run.content.paths.has(path_id) or flow.run.content.paths[path_id].hero != hero.id or path_id == hero.path:
					return "%s can't take \"%s\"" % [hero.id, path_id]
	return ""


## Makes the event's choice `index` (with `target`, as event_problem says):
## its results in order. One choice an event; leaving without one is
## walking away.
static func choose_event(flow: RunFlow, index: int, target: String = "") -> String:
	var problem: String = event_problem(flow, index, target)
	if problem.is_empty() and event_scene(flow).choices[index].needs() != EventDef.Needs.NOTHING and target.is_empty():
		problem = "choose who or what it's for"
	if not problem.is_empty():
		return problem
	var choice: EventDef.Choice = event_scene(flow).choices[index]
	for r: int in choice.results.size():
		_event_result(flow, choice.results[r], target, r)
	flow.state.event_done = true
	return ""


static func _event_result(flow: RunFlow, result: EventDef.Result, target: String, what: int) -> void:
	match result.kind:
		"item":
			for id: String in Offers.event_picks(flow.state, _item_pool(flow, result.kinds), result.count, what):
				flow._gain_item(id, result.rank)
		"wound":
			var hero: RunState.Hero = flow.state.hero(target)
			hero.wounds = mini(hero.wounds + 1, flow.run.content.tuning.max_wounds)
		"clear_wounds":
			for hero: RunState.Hero in flow.state.heroes:
				hero.wounds = 0
		"relic":
			var relic: String = Offers.event_relic(flow.run, flow.state, result.tier)
			if not relic.is_empty():
				flow._gain_relic(relic)
		"dear_shop":
			flow.state.dear_shop_bp = result.bp
		"pay":
			flow.state.shards -= result.shards
		"gain":
			flow.state.shards += result.shards
		"deed":
			var hero: RunState.Hero = flow.state.hero(target)
			var threshold: int = flow.run.content.paths[hero.path].deed.threshold
			hero.deeds[hero.path] = mini(hero.deeds.get(hero.path, 0) + FixedMath.apply_bp(threshold, result.bp), maxi(threshold, hero.deeds.get(hero.path, 0)))
		"next_fight":
			for hero: RunState.Hero in flow.state.heroes:
				if result.team or hero.id == target:
					hero.next_fight.append(result.mod)
		"seal":
			flow.state.sealed = true
		"rank_up_random":
			for id: String in Offers.event_picks(flow.state, _rankable(flow), 1, what):
				flow._gain_item(id)
		"rank_up_chosen":
			flow._gain_item(target)
		"weaken":
			for id: String in Offers.event_picks(flow.state, flow.state.hero_ids(), 1, what):
				flow.state.hero(id).weakened += 1
		"hunt":
			flow.state.hunt = Offers.hunt(flow.run, flow.state)
		"mirror":
			var hero: RunState.Hero = flow.state.hero(target.get_slice(":", 0))
			var old: PathDef = flow.run.content.paths[hero.path]
			var new: PathDef = flow.run.content.paths[target.get_slice(":", 1)]
			# Half its share of the old path's threshold, as a share of the new one's.
			@warning_ignore("integer_division")
			var carried: int = hero.deeds.get(old.id, 0) * new.deed.threshold / maxi(old.deed.threshold, 1) / 2
			hero.deeds[new.id] = hero.deeds.get(new.id, 0) + carried
			hero.path = new.id


## The items an event may give of `kinds`: not held at rank III.
static func _item_pool(flow: RunFlow, kinds: Array[String]) -> Array[String]:
	var pool: Array[String] = []
	for id: String in flow.run.item_ids:
		if kinds.has(ItemDef.KIND_NAMES[flow.run.items[id].kind]) and flow.state.item_ranks.get(id, 0) < ItemDef.RANKS:
			pool.append(id)
	return pool


## The run's items below rank III.
static func _rankable(flow: RunFlow) -> Array[String]:
	var found: Array[String] = []
	for id: String in flow.run.item_ids:
		if flow.state.item_ranks.has(id) and flow.state.item_ranks[id] < ItemDef.RANKS:
			found.append(id)
	return found


## Takes the Bloodied Oath's oath `index` (phase 5c step 8c): its hero bears
## it for its next oath_fights day fights. Passing is leaving the node.
static func take_oath(flow: RunFlow, index: int) -> String:
	if flow.state.phase != RunState.Phase.NODE or flow.state.node != "oath":
		return flow._not_now("take an oath")
	if flow.state.event_done:
		return "an oath is taken"
	if index < 0 or index >= flow.state.oath_offer.size():
		return "there's no oath %d" % index
	var hero: RunState.Hero = flow.state.hero(flow.state.oath_offer[index].get_slice(":", 1))
	if not hero.oath.is_empty():
		return "%s is already sworn" % hero.id
	hero.oath = flow.state.oath_offer[index].get_slice(":", 0)
	hero.oath_fights = flow.run.events.oath_fights
	flow.state.event_done = true
	return ""


## The oath `hero` bears, or null.
static func oath_of(flow: RunFlow, hero: RunState.Hero) -> EventDef.Oath:
	return flow.run.events.oath(hero.oath) if not hero.oath.is_empty() else null


## The heroes' front row (the Oath of the Vanguard's).
static func front_row(flow: RunFlow) -> int:
	var grid: HexGrid = flow.run.content.tuning.make_grid()
	var front: int = 0
	for row: int in grid.height:
		if grid.zone(row) == HexGrid.Zone.HEROES:
			front = maxi(front, row)
	return front
