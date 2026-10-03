extends "res://tools/bots/bot.gd"
## The random bot (docs/plans/rebuild-phase6-bot-tuning.md, section 2): a
## random legal answer to every decision, from its own SimRng seeded by the
## run's seed, so a run repeats. The floor of the bots: "a random bot clears
## far less". It never sells (a sale undoes a buy, and the floor shouldn't
## churn), and does at most SHOP_ACTIONS things a shop visit.

const SHOP_ACTIONS: int = 6
## Tries at a random legal formation (or markers) before falling back to
## the simple bot's.
const TRIES: int = 60

var rng: SimRng
var _shop_key: String = ""
var _shop_done: int = 0


func _init() -> void:
	label = "random"


func begin(flow: RunFlow) -> void:
	rng = SimRng.new(flow.state.seed_value * 7919 + 17)


func route(flow: RunFlow) -> int:
	return rng.range_int(flow.state.today().size())


## Each stash item goes to a random slot of a random hero (what was there
## goes back to the stash), if that's legal.
func loadout(flow: RunFlow) -> void:
	var state: RunState = flow.state
	for item_id: String in state.stash.duplicate():
		if rng.range_int(2) == 0:
			continue
		var hero: RunState.Hero = state.heroes[rng.range_int(state.heroes.size())]
		if hero.slots.is_empty():
			continue
		flow.equip(hero.id, rng.range_int(hero.slots.size()), item_id)


func formation(flow: RunFlow) -> Dictionary[String, Vector2i]:
	var grid: HexGrid = flow.run.content.tuning.make_grid()
	var zone: Array[Vector2i] = []
	for row: int in grid.height:
		if grid.zone(row) == HexGrid.Zone.HEROES:
			for col: int in grid.width:
				zone.append(Vector2i(col, row))
	for attempt: int in TRIES:
		var free: Array[Vector2i] = zone.duplicate()
		var hexes: Dictionary[String, Vector2i] = {}
		for hero: RunState.Hero in flow.state.heroes:
			hexes[hero.id] = free.pop_at(rng.range_int(free.size()))
		var errors: Array[String] = []
		if flow.fight_setup(hexes, errors) != null:
			return hexes
	return super.formation(flow)


func markers(flow: RunFlow, hexes: Dictionary[String, Vector2i]) -> Dictionary[String, Array]:
	var grid: HexGrid = flow.run.content.tuning.make_grid()
	var placed: Dictionary[String, Array] = {}
	for hero: RunState.Hero in flow.state.heroes:
		var count: int = flow.kit_of(hero.id).placed_markers()
		if count == 0 or not hexes.has(hero.id):
			continue
		for attempt: int in TRIES:
			var mine: Array = []
			while mine.size() < count:
				var hex: Vector2i = Vector2i(rng.range_int(grid.width), rng.range_int(grid.height))
				if not mine.has(hex):
					mine.append(hex)
			placed[hero.id] = mine
			var errors: Array[String] = []
			if flow.fight_setup(hexes, errors, placed) != null:
				break
			placed.erase(hero.id)
	if placed.size() < _placers(flow, hexes):
		return default_markers(flow, hexes)
	return placed


func pick(flow: RunFlow) -> int:
	return rng.range_int(flow.state.pick.size() + 1) - 1


func apex(flow: RunFlow, hero_id: String) -> String:
	var apexes: Array[ApexDef] = flow.run.content.paths[flow.state.hero(hero_id).path].apexes
	return apexes[rng.range_int(apexes.size())].id


func relic(flow: RunFlow) -> int:
	if flow.state.shards < flow.state.relic_choice_price:
		return -1
	return rng.range_int(flow.state.relic_choice.size() + 1) - 1


## A random affordable buy, wound, or reroll, or leaving (one chance in as
## many as there are things to do, plus one).
func shop(flow: RunFlow) -> bool:
	var state: RunState = flow.state
	var key: String = "%d:%d:%s:%s" % [state.day, state.attempt, state.phase, state.shop]
	if key != _shop_key:
		_shop_key = key
		_shop_done = 0
	if _shop_done >= SHOP_ACTIONS:
		return false
	var actions: Array[Callable] = []
	for i: int in state.wares.size():
		if not state.wares[i].is_empty() and flow.price_of(state.wares[i]) <= state.shards:
			actions.append(_buy.bind(flow, i))
	for i: int in state.shop_relics.size():
		if not state.shop_relics[i].is_empty() and flow.relic_price(i) <= state.shards:
			actions.append(flow.buy_relic.bind(i))
	for hero: RunState.Hero in state.heroes:
		if hero.wounds > 0 and flow.wound_price() <= state.shards:
			actions.append(flow.treat_wound.bind(hero.id))
	if state.shop == "pedlar" and flow.reroll_price() <= state.shards:
		actions.append(flow.reroll)
	var chosen: int = rng.range_int(actions.size() + 1)
	if chosen == actions.size():
		return false
	_shop_done += 1
	return actions[chosen].call() == ""


func node(flow: RunFlow) -> int:
	return rng.range_int(flow.state.nodes.size())


func camp(flow: RunFlow) -> int:
	return rng.range_int(flow.state.camp.size())


func depth(flow: RunFlow) -> int:
	return rng.range_int(flow.run.camps.depths.size())


## A random choice it can make (with a random target that fits), or walking
## away.
func event(flow: RunFlow) -> Array:
	var scene: EventDef.Scene = flow.event_scene()
	var options: Array = []
	for i: int in scene.choices.size():
		var choice: EventDef.Choice = scene.choices[i]
		if choice.needs() == EventDef.Needs.NOTHING:
			if flow.event_problem(i).is_empty():
				options.append([i, ""])
			continue
		var targets: Array[String] = []
		for target: String in flow.event_targets(choice):
			if flow.event_problem(i, target).is_empty():
				targets.append(target)
		if not targets.is_empty():
			options.append([i, targets[rng.range_int(targets.size())]])
	var chosen: int = rng.range_int(options.size() + 1)
	return options[chosen] if chosen < options.size() else []


func oath(flow: RunFlow) -> int:
	var options: Array[int] = []
	for i: int in flow.state.oath_offer.size():
		var hero: RunState.Hero = flow.state.hero(flow.state.oath_offer[i].get_slice(":", 1))
		if hero != null and hero.oath.is_empty():
			options.append(i)
	var chosen: int = rng.range_int(options.size() + 1)
	return options[chosen] if chosen < options.size() else -1


func shrine(flow: RunFlow) -> Array:
	var options: Array = []
	if flow.state.shards >= flow.run.act.shrine_price:
		options.append(["shards", ""])
	for hero: RunState.Hero in flow.state.heroes:
		if hero.wounds < flow.run.content.tuning.max_wounds:
			options.append(["wound", hero.id])
	for relic_id: String in flow.state.relics:
		if flow.shrine_tier(relic_id).is_empty():
			options.append(["relic", relic_id])
	var chosen: int = rng.range_int(options.size() + 1)
	return options[chosen] if chosen < options.size() else []


func swap(flow: RunFlow) -> int:
	return rng.range_int(flow.state.options[flow.state.day].size())


func rock(flow: RunFlow) -> Vector2i:
	var grid: HexGrid = flow.run.content.tuning.make_grid()
	var rows: Array[int] = []
	for row: int in grid.height:
		if grid.zone(row) == HexGrid.Zone.HEROES:
			rows.append(row)
	return Vector2i(rng.range_int(grid.width), rows[rng.range_int(rows.size())])


## Buys ware `index`, and equips it on a random hero with a free slot.
func _buy(flow: RunFlow, index: int) -> String:
	var item_id: String = flow.state.wares[index]
	var said: String = flow.buy(index)
	if said.is_empty() and flow.state.stash.has(item_id):
		var hero: RunState.Hero = flow.state.heroes[rng.range_int(flow.state.heroes.size())]
		var free: int = hero.slots.find("")
		if free >= 0:
			flow.equip(hero.id, free, item_id)
	return said


static func _placers(flow: RunFlow, hexes: Dictionary[String, Vector2i]) -> int:
	return flow.state.heroes.filter(func(hero: RunState.Hero) -> bool: return hexes.has(hero.id) and flow.kit_of(hero.id).placed_markers() > 0).size()
