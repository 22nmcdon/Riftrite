class_name HoverCard
extends PanelContainer
## The hover popup (docs/plans/ui-overhaul.md, 3.3): a parchment card beside
## whatever the mouse is over (an item, hero, relic, essence, or synergy),
## showing what it is and does. It sits on top of everything and never takes
## the mouse. Hook a control up with Inspector.hover() or hover_text().

const GROUP: String = "hover_card"
const WIDTH: int = 400
## Gap between the card and what it describes.
const GAP: float = 10.0

var _title: Label
var _body: Label
## What the card is showing, or null when hidden.
var _owner: Control = null


static func make() -> HoverCard:
	var card := HoverCard.new()
	card.add_to_group(GROUP)
	card.top_level = true
	card.z_index = 100
	card.visible = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(WIDTH, 0)
	card.add_theme_stylebox_override("panel", UiStyle.parchment())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	card._title = UiStyle.heading("", 20, UiStyle.OAK_600)
	card._title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A set width, so wrapped text measures its height right away.
	card._title.custom_minimum_size = Vector2(WIDTH - 32, 0)
	box.add_child(card._title)
	card._body = UiStyle.label("", 16, UiStyle.INK_TEXT)
	card._body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card._body.custom_minimum_size = Vector2(WIDTH - 32, 0)
	box.add_child(card._body)
	return card


## The card in the scene, or null (e.g. in a test without Main).
static func find(node: Node) -> HoverCard:
	if not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as HoverCard


func title_text() -> String:
	return _title.text


func body_text() -> String:
	return _body.text


## Shows `title` and `body` beside `node`.
func show_for(node: Control, title: String, body: String) -> void:
	_owner = node
	_title.text = title
	_body.text = body
	_body.visible = not body.is_empty()
	visible = true
	reset_size()
	_place.call_deferred()


## Hides the card if it's showing `node`.
func hide_for(node: Control) -> void:
	if node == _owner:
		visible = false
		_owner = null


## Beside the owner: to its right, or its left when there's no room, kept
## on screen.
func _place() -> void:
	if _owner == null or not is_instance_valid(_owner) or not _owner.is_inside_tree():
		visible = false
		return
	reset_size()
	var rect: Rect2 = _owner.get_global_rect()
	var view: Vector2 = get_viewport_rect().size
	var at := Vector2(rect.end.x + GAP, rect.position.y)
	if at.x + size.x > view.x - GAP:
		at.x = rect.position.x - size.x - GAP
	at.x = clampf(at.x, GAP, maxf(GAP, view.x - size.x - GAP))
	at.y = clampf(at.y, GAP, maxf(GAP, view.y - size.y - GAP))
	global_position = at


func _process(_delta: float) -> void:
	# The owner can vanish under the mouse (a screen rebuilt after a click).
	if visible and (_owner == null or not is_instance_valid(_owner) or not _owner.is_inside_tree() or not _owner.is_visible_in_tree()):
		visible = false
		_owner = null
