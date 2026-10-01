class_name ActMap
extends Control
## The act map (docs/plans/rebuild-phase5b-art.md, section 4, Decision 4):
## the route as the uploaded map (art/ui/map/act_map.svg), one island a day
## and the boss's last. It only reads the run.
##   - Each day's island holds that day's fights as nodes by tier
##     (art/ui/nodes/: fight, fight_harder, elite, boss), known from the
##     act's start. Over them, the node taken at that day's end (phase 5c
##     step 8: a camp's place, Rift Tear, or the Magpie; RunState.taken_nodes),
##     and today's once it's taken.
##   - Past days are dimmed, with the fight fought there ringed (gold won,
##     red lost). Today's nodes glow and can be clicked: a click selects one
##     (`selected`, reported by `node_selected`), and whoever shows the map
##     shows that fight's card. A node's tooltip names its fight.
##   - The map keeps its shape, fitted and centered in the control.

signal node_selected(index: int)

const MAP: String = "res://art/ui/map/act_map.svg"
const NODES: String = "res://art/ui/nodes/%s.svg"
const MAP_SIZE := Vector2(1920, 1080)
## Each island's fights' middle, in the map's pixels (from the map look
## test): days 1-6, then the boss's.
const ISLANDS: Array[Vector2] = [
	Vector2(190, 705), Vector2(430, 475), Vector2(690, 695), Vector2(950, 435),
	Vector2(1210, 685), Vector2(1460, 445), Vector2(1720, 600)]
## How far apart a day's fights stand, and how far over them its place is.
const FIGHT_GAP: float = 110.0
const PLACE_RISE: float = 115.0
## A node's size on the map (map pixels): a fight's, and a place's.
const NODE_SIDE: float = 76.0
const PLACE_SIDE: float = 64.0
const TIER_NODES: Dictionary[String, String] = {"easier": "fight", "harder": "fight_harder", "elite": "elite", "boss": "boss"}
const PAST_ALPHA: float = 0.5
const WON_RING := Color("ffd66e")
const LOST_RING := Color("e0503c")
const TODAY_GLOW := Color(1.0, 0.9, 0.55, 0.55)

var session: RunSession
## Day (1-based) -> its fights' nodes, in RunState.options' order.
var fights: Dictionary[int, Array] = {}
## Day -> its place's node (only days reached).
var places: Dictionary[int, TextureRect] = {}
## Today's selected fight (an index into RunState.today()).
var selected: int = 0
var _scale: float = 1.0
var _origin: Vector2 = Vector2.ZERO


static func make(run_session: RunSession) -> ActMap:
	var map := ActMap.new()
	map.session = run_session
	map.custom_minimum_size = Vector2(0, 620)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map._build()
	return map


func _build() -> void:
	var state: RunState = session.state()
	var content: ContentDb = session.content
	for day: int in range(1, state.options.size() + 1):
		var nodes: Array[TextureButton] = []
		var options: Array = state.options[day - 1]
		for i: int in options.size():
			var encounter: EncounterDef = content.encounters[options[i]]
			var node := TextureButton.new()
			node.texture_normal = ArenaView.art(NODES % TIER_NODES.get(encounter.tier, "fight"))
			node.ignore_texture_size = true
			node.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			node.tooltip_text = "Day %d · %s (%s)" % [day, encounter.name, encounter.tier]
			node.disabled = day != state.day
			node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if day == state.day else Control.CURSOR_ARROW
			if day < state.day:
				node.modulate.a = PAST_ALPHA if _fought_there(day) != i else 1.0
			if day == state.day:
				node.pressed.connect(select.bind(i))
			add_child(node)
			nodes.append(node)
		fights[day] = nodes
		if not _place_id(day).is_empty():
			var place := TextureRect.new()
			place.texture = ArenaView.art(RunContent.ART_UI + _place_icon(day))
			place.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			place.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			place.mouse_filter = Control.MOUSE_FILTER_PASS
			place.tooltip_text = "Day %d · %s" % [day, _place_name(day)]
			if day < state.day:
				place.modulate.a = PAST_ALPHA
			add_child(place)
			places[day] = place


## Selects today's fight `index` (a node click, or the screen's default).
func select(index: int) -> void:
	selected = index
	queue_redraw()
	node_selected.emit(index)


## Which of a past day's fights was fought last there (-1: none).
func _fought_there(day: int) -> int:
	var state: RunState = session.state()
	for i: int in range(state.fought.size() - 1, -1, -1):
		var fought: RunState.Fought = state.fought[i]
		if fought.day == day:
			return (state.options[day - 1] as Array).find(fought.encounter)
	return -1


## A day's last try (today's: now).
func _attempt(day: int) -> int:
	var state: RunState = session.state()
	if day == state.day:
		return state.attempt
	var last: int = 0
	for fought: RunState.Fought in state.fought:
		if fought.day == day:
			last = maxi(last, fought.attempt)
	return last


## The node taken at the end of `day` ("camp:<place>", "rift_tear",
## "magpie"; "" if none yet).
func _place_id(day: int) -> String:
	var state: RunState = session.state()
	if day == state.day and not state.node.is_empty():
		return "camp:" + state.place if state.node == "camp" else state.node
	return state.taken_nodes[day - 1] if day - 1 < state.taken_nodes.size() else ""


func _place_icon(day: int) -> String:
	return RunDayScreen.node_icon(session.run, _place_id(day))


func _place_name(day: int) -> String:
	return RunDayScreen.node_name(session.run, _place_id(day))


## Where a point of the map (its pixels) is drawn.
func to_view(point: Vector2) -> Vector2:
	return _origin + point * _scale


## Where day `day`'s fight `index` of `count` stands on the map.
static func fight_point(day: int, index: int, count: int) -> Vector2:
	var middle: Vector2 = ISLANDS[mini(day - 1, ISLANDS.size() - 1)]
	return middle + Vector2((index - (count - 1) / 2.0) * FIGHT_GAP, 0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	_scale = minf(size.x / MAP_SIZE.x, size.y / MAP_SIZE.y)
	_origin = (size - MAP_SIZE * _scale) / 2.0
	for day: int in fights:
		var nodes: Array = fights[day]
		for i: int in nodes.size():
			var node: TextureButton = nodes[i]
			var side: float = NODE_SIDE * _scale
			node.size = Vector2(side, side)
			node.position = to_view(fight_point(day, i, nodes.size())) - node.size / 2.0
	for day: int in places:
		var place: TextureRect = places[day]
		var side: float = PLACE_SIDE * _scale
		place.size = Vector2(side, side)
		place.position = to_view(ISLANDS[mini(day - 1, ISLANDS.size() - 1)] - Vector2(0.0, PLACE_RISE)) - place.size / 2.0
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(ArenaView.art(MAP), Rect2(_origin, MAP_SIZE * _scale), false)
	var state: RunState = session.state()
	var radius: float = NODE_SIDE * _scale * 0.62
	# Today's fights glow, the selected one most.
	var today: Array = fights.get(state.day, [])
	for i: int in today.size():
		var at: Vector2 = to_view(fight_point(state.day, i, today.size()))
		var glow: Color = TODAY_GLOW
		glow.a *= 1.0 if i == selected else 0.45
		draw_circle(at, radius, glow)
		if i == selected:
			draw_arc(at, radius, 0.0, TAU, 40, WON_RING, 3.0, true)
	# A past day's fight fought there: ringed, gold won or red lost.
	for day: int in range(1, state.day):
		var index: int = _fought_there(day)
		if index < 0:
			continue
		var won: bool = false
		for fought: RunState.Fought in state.fought:
			if fought.day == day and fought.attempt == _attempt(day):
				won = fought.outcome != FightResult.Outcome.DEFEAT
		draw_arc(to_view(fight_point(day, index, (fights[day] as Array).size())), radius, 0.0, TAU, 40, WON_RING if won else LOST_RING, 3.0, true)
