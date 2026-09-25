class_name ItemTile
extends PanelContainer
## One item as a tile, as wide as its slots: name, tier, and a dot per
## socketed essence, with a rarity-colored border and a full tooltip.
## Owned tiles drag and drop (move, combine onto a copy, drop an essence on
## to infuse); offer tiles are clicked (buy or take). A lit tile glows (an
## upgrade for something you hold).

signal clicked

var session: RunSession
## Owned: the item's uid, who holds it (a hero id or RunState.STASH), and its
## index in that list. Offers have uid -1.
var uid: int = -1
var owner_id: String = ""
var index: int = 0
var item_id: String
var tier: int = 0
var essence_ids: Array[String] = []
var lit: bool = false
## What the item does (shown in the inspector on hover).
var info: String = ""


static func owned(run_session: RunSession, item: RunItem, holder: String, at: int, holder_stats: UnitStats) -> ItemTile:
	var tile := ItemTile.new()
	tile.session = run_session
	tile.uid = item.uid
	tile.owner_id = holder
	tile.index = at
	tile._fill(item.item_id, item.tier, item.essence_ids, item.xp, holder_stats, "")
	return tile


static func offer(run_session: RunSession, item: String, item_tier: int, footer: String, glow: bool = false) -> ItemTile:
	var tile := ItemTile.new()
	tile.session = run_session
	tile.lit = glow
	tile._fill(item, item_tier, [] as Array[String], 0, null, footer)
	return tile


func _fill(item: String, item_tier: int, essences: Array[String], xp: int, holder_stats: UnitStats, footer: String) -> void:
	item_id = item
	tier = item_tier
	essence_ids = essences
	var def: ItemDef = session.content.items[item]
	custom_minimum_size = Vector2(maxi(def.size, 1) * UiStyle.SLOT_WIDTH, UiStyle.TILE_HEIGHT)
	var selected: bool = uid >= 0 and session.selected_uid == uid
	var border: Color = UiStyle.HIGHLIGHT if lit or selected else UiStyle.rarity_color(def.rarity)
	add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL_WARM if selected else UiStyle.PANEL, border, 4 if lit or selected else 2))
	info = ItemInfo.item_text(session.content, item, item_tier, essences, xp, holder_stats)
	Inspector.hover_text(self, info)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	top.add_child(Glyph.item(def, UiStyle.rarity_color(def.rarity).lightened(0.2), 20))
	var tier_label: Label = UiStyle.label(TuningDef.TIER_LABELS[item_tier], 16, UiStyle.EMBER)
	tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(tier_label)
	for essence_id: String in essences:
		top.add_child(Glyph.gem(essence_id, 16))
	for i: int in session.content.tuning.socket_count(def) - essences.size():
		top.add_child(Glyph.dot(UiStyle.BORDER, 8))
	var name_label: Label = UiStyle.label(def.name, 14)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	if not footer.is_empty():
		var price: Label = UiStyle.label(footer, 14, UiStyle.HIGHLIGHT)
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(price)


## Offers are bought or taken on press. Owned items are selected on release
## (a drag never releases here, so dragging doesn't select).
func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if uid < 0 and click.pressed:
		clicked.emit()
	elif uid >= 0 and not click.pressed:
		select()


## Selects this item in the inspector (or clears it if already selected).
func select() -> void:
	session.select(uid)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if uid < 0:
		return null
	var preview: Label = UiStyle.label(session.content.items[item_id].name, 14, UiStyle.HIGHLIGHT)
	set_drag_preview(preview)
	return {"uid": uid}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if uid < 0 or typeof(data) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = data
	return (payload.has("uid") and payload["uid"] != uid) or payload.has("pouch_index")


## Dropped on this tile: an essence infuses it; a copy at the same tier
## combines into it; any other item moves to this spot.
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var payload: Dictionary = data
	if payload.has("pouch_index"):
		session.infuse(uid, payload["pouch_index"])
		return
	var dragged: RunItem = session.state.find_item(payload["uid"])
	if dragged != null and dragged.item_id == item_id and dragged.tier == tier:
		session.combine(uid, dragged.uid)
	else:
		session.move_item(payload["uid"], owner_id, index)
