class_name Inspector
extends PanelContainer
## The side panel. Click an item you hold to select it: the panel shows what
## it does and buttons for everything you can do with it right now (give it
## to a hero, stash it, combine, infuse, sell, reforge, upgrade, throw away).
## Hovering an offer, relic, or hero shows it here until the mouse leaves.
## Every button goes through the RunSession, like the rest of the UI; the
## selection itself is RunSession.selected_uid.

const GROUP: String = "inspector"
const WIDTH: int = 440

var session: RunSession
var _title: Label
var _body: Label
var _actions: VBoxContainer
## True while a hover preview is shown instead of the selection.
var _previewing: bool = false


static func make(run_session: RunSession) -> Inspector:
	var panel := Inspector.new()
	panel.session = run_session
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	panel.add_theme_stylebox_override("panel", UiStyle.parchment())
	panel.add_to_group(GROUP)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	panel._title = UiStyle.label("", 21, UiStyle.OAK_600)
	panel._title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(panel._title)
	panel._body = UiStyle.label("", 16, UiStyle.INK_TEXT)
	panel._body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(panel._body)
	panel._actions = VBoxContainer.new()
	panel._actions.add_theme_constant_override("separation", 6)
	box.add_child(panel._actions)
	panel.refresh()
	return panel


## The inspector in the scene, or null (e.g. in a test without Main).
static func find(node: Node) -> Inspector:
	if not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as Inspector


## Makes `node` show `title` and `body` here while the mouse is over it.
static func hover(node: Control, title: String, body: String) -> void:
	node.mouse_entered.connect(func() -> void:
		var inspector: Inspector = find(node)
		if inspector != null:
			inspector.preview(title, body))
	node.mouse_exited.connect(func() -> void:
		var inspector: Inspector = find(node)
		if inspector != null:
			inspector.end_preview())


## Hover for a block of info text whose first line is its title.
static func hover_text(node: Control, text: String) -> void:
	var lines: PackedStringArray = text.split("\n", true, 1)
	hover(node, lines[0], lines[1] if lines.size() > 1 else "")


## Shows something under the mouse (not selectable), until end_preview().
func preview(title: String, body: String) -> void:
	_previewing = true
	_show(title, body)
	_clear_actions()


func end_preview() -> void:
	if _previewing:
		_previewing = false
		refresh()


## Shows the selected item and what can be done with it, or a hint.
func refresh() -> void:
	_previewing = false
	_clear_actions()
	var state: RunState = session.state
	var item: RunItem = state.find_item(session.selected_uid) if state != null and session.selected_uid >= 0 else null
	if item == null:
		_show("Inspector", "Click an item you hold to see what it does and what you can do with it.\n\nHover a ware, relic, or hero to read about it.\n\nYou can also drag items between rows, the stash, and the zones.")
		return
	var owner: String = state.owner_of(item.uid)
	var stats: UnitStats = ItemInfo.hero_stats(session.content, state.hero(owner)) if owner != RunState.STASH else null
	var text: String = ItemInfo.item_text(session.content, item.item_id, item.tier, item.essence_ids, item.xp, stats)
	var lines: PackedStringArray = text.split("\n", true, 1)
	var where: String = "In the stash" if owner == RunState.STASH else "Held by " + session.content.heroes[owner].name
	_show(lines[0], where + "\n" + (lines[1] if lines.size() > 1 else ""))
	_add_actions(item, owner)


func _show(title: String, body: String) -> void:
	_title.text = title
	_body.text = body


func _clear_actions() -> void:
	for child: Node in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()


func _action(text: String, action: Callable, color: Color = UiStyle.TEXT) -> void:
	var button: Button = UiStyle.button(text, action)
	button.size_flags_horizontal = Control.SIZE_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_color_override("font_color", color)
	_actions.add_child(button)


func _add_actions(item: RunItem, owner: String) -> void:
	var state: RunState = session.state
	var content: ContentDb = session.content
	var def: ItemDef = content.items[item.item_id]
	var uid: int = item.uid
	# Combine with a copy at the same tier.
	for other: RunItem in _all_items():
		if other.uid != uid and other.item_id == item.item_id and other.tier == item.tier and item.tier < 3 and def.rarity != "legendary":
			_action("Combine with your other copy → tier %s" % TuningDef.TIER_LABELS[item.tier + 1], func() -> void: session.combine(uid, other.uid), UiStyle.HIGHLIGHT)
			break
	# Infuse from the pouch (one button per kind of essence).
	if item.essence_ids.size() < content.tuning.socket_count(def):
		var offered: Array[String] = []
		for i: int in state.pouch.size():
			if not offered.has(state.pouch[i]):
				offered.append(state.pouch[i])
				_action("Infuse with %s" % content.essences[state.pouch[i]].name, func() -> void: session.infuse(uid, i), UiStyle.ESSENCE.get(state.pouch[i], UiStyle.TEXT).lightened(0.3))
	# Move it.
	for hero: RunHero in state.heroes:
		if hero.hero_id != owner:
			_action("Give to %s" % content.heroes[hero.hero_id].name, func() -> void: session.move_item(uid, hero.hero_id, 99))
	if owner != RunState.STASH:
		var at: int = state.list_for(owner).find(item)
		if at > 0:
			_action("◀ Move left in the row", func() -> void: session.move_item(uid, owner, at - 1))
		if at < state.list_for(owner).size() - 1:
			_action("Move right in the row ▶", func() -> void: session.move_item(uid, owner, at + 1))
		_action("Put in the stash", func() -> void: session.move_item(uid, RunState.STASH, 99))
	# What the current step allows.
	if state.phase == "caravan":
		_action("Sell for %d gold" % session.sell_price(uid), func() -> void: session.sell(uid), UiStyle.HIGHLIGHT)
	if state.phase == "stop" and state.stop_kind == "forge" and not item.essence_ids.is_empty():
		_action("Reforge: remove the infusion (%d gold)" % content.tuning.reforge_gold, func() -> void: session.forge_reforge(uid))
	if state.phase == "stop" and state.stop_kind == "upgrade" and not state.stop_used and item.tier < 3 and def.rarity != "legendary":
		_action("Upgrade to tier %s (free)" % TuningDef.TIER_LABELS[item.tier + 1], func() -> void: session.upgrade(uid), UiStyle.HIGHLIGHT)
	_action("Throw away", func() -> void: session.discard_item(uid), UiStyle.BAD)


func _all_items() -> Array[RunItem]:
	var items: Array[RunItem] = session.state.stash.duplicate()
	for hero: RunHero in session.state.heroes:
		items.append_array(hero.items)
	return items
