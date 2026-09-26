class_name ItemTile
extends PanelContainer
## One item as a token (docs/ui-asset-design.md, 8.1), as wide as its slots:
## its icon, tier, and infusion gem, with the rarity ladder's frame (color
## plus rivets, crest, wings), the rift bleed for enemy-only items, and
## spill arrows when its infusion is Resonant. Hovering lifts it and shows
## it in the inspector.
## Owned tiles are clicked to select them and drag and drop (move, combine
## onto a copy, drop an essence on to infuse); while dragging, a target is
## outlined green if the drop would work and red if not. Offer tiles are
## clicked (buy or take). A lit tile glows (an upgrade for something you
## hold).

signal clicked

enum Drop { INFUSE, COMBINE, MOVE }

## A ware card (the Caravan's stall): large art, name, rarity, size, price.
const WARE_SIZE := Vector2(196, 250)
## A compact tile (the guild bar's stash): icon, tier, and gem only, per slot.
const COMPACT_SLOT_WIDTH: int = 60
const COMPACT_HEIGHT: int = 64

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
## Icon, tier, and gem only (the name shows on hover).
var compact: bool = false
## A large card for the Caravan's stall.
var ware: bool = false
## What the item does (shown in the inspector on hover).
var info: String = ""
## The frame when not hovered or a drop target.
var _style: StyleBoxFlat
## Drop checks already made this drag: payload key -> would it work.
var _drop_checks: Dictionary[String, bool] = {}


static func owned(run_session: RunSession, item: RunItem, holder: String, at: int, holder_stats: UnitStats, small: bool = false) -> ItemTile:
	var tile := ItemTile.new()
	tile.session = run_session
	tile.compact = small
	tile.uid = item.uid
	tile.owner_id = holder
	tile.index = at
	tile._fill(item.item_id, item.tier, item.essence_ids, item.xp, holder_stats, "")
	return tile


static func offer(run_session: RunSession, item: String, item_tier: int, footer: String, glow: bool = false, big: bool = false) -> ItemTile:
	var tile := ItemTile.new()
	tile.session = run_session
	tile.lit = glow
	tile.ware = big
	tile._fill(item, item_tier, [] as Array[String], 0, null, footer)
	return tile


func _fill(item: String, item_tier: int, essences: Array[String], xp: int, holder_stats: UnitStats, footer: String) -> void:
	item_id = item
	tier = item_tier
	essence_ids = essences
	var content: ContentDb = session.content
	var def: ItemDef = content.items[item]
	var slots: int = maxi(def.size, 1)
	custom_minimum_size = Vector2(slots * COMPACT_SLOT_WIDTH, COMPACT_HEIGHT) if compact else Vector2(slots * UiStyle.SLOT_WIDTH, UiStyle.TILE_HEIGHT)
	if ware:
		custom_minimum_size = WARE_SIZE
	var selected: bool = uid >= 0 and session.selected_uid == uid
	var border: Color = UiStyle.HIGHLIGHT if lit or selected else UiStyle.rarity_color(def.rarity)
	var fill: Color = UiStyle.PANEL_WARM if selected else (Color("241a2e") if def.enemy_only else UiStyle.PANEL)
	_style = UiStyle.box(fill, border, 4 if lit or selected else 3)
	add_theme_stylebox_override("panel", _style)
	pivot_offset = custom_minimum_size / 2.0
	info = ItemInfo.item_text(content, item, item_tier, essences, xp, holder_stats)
	Inspector.hover_text(self, info)
	mouse_entered.connect(_lift.bind(true))
	mouse_exited.connect(_lift.bind(false))
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ware:
		_fill_ware(def, footer)
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0 if compact else 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	top.add_theme_constant_override("separation", 2 if compact else 4)
	top.add_child(Glyph.item(def, UiStyle.rarity_color(def.rarity).lightened(0.25), 32 if compact else 38))
	if compact:
		# Tier and gems go on a second line under the icon.
		top.alignment = BoxContainer.ALIGNMENT_CENTER
		top = HBoxContainer.new()
		top.alignment = BoxContainer.ALIGNMENT_CENTER
		top.add_theme_constant_override("separation", 2)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(top)
	var tier_label: Label = UiStyle.label(TuningDef.TIER_LABELS[item_tier], 13 if compact else 16, UiStyle.EMBER)
	tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(tier_label)
	var discovered: Array[String] = session.state.discovered if session.state != null else ([] as Array[String])
	var form: Glyph.Infusion = InfusionLook.form(content, item, essences, discovered)
	var sockets: int = content.tuning.socket_count(def)
	if form != Glyph.Infusion.EMPTY:
		top.add_child(Glyph.infusion_gem(form, essences, 16 if compact else 28))
	# Empty sockets: all of them, or the second one beside a single essence.
	var filled: int = 0 if form == Glyph.Infusion.EMPTY else (1 if form == Glyph.Infusion.SINGLE else sockets)
	for i: int in sockets - filled:
		top.add_child(Glyph.infusion_gem(Glyph.Infusion.EMPTY, [] as Array[String], 14 if compact else 22))
	var level: int = InfusionLook.level(content, essences, xp)
	var decor: FrameDecor = FrameDecor.make(ItemDef.RARITIES.find(def.rarity), def.enemy_only, InfusionLook.spill_colors(form, essences, level), InfusionLook.shows_no_spill(form, level))
	if compact:
		add_child(decor)
		return
	var name_label: Label = UiStyle.label(def.name, 14)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	if not footer.is_empty():
		var price: Label = UiStyle.label(footer, 14, UiStyle.HIGHLIGHT)
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(price)
	add_child(decor)


## A ware card: the art large, tier, name, rarity and size, and the price.
func _fill_ware(def: ItemDef, footer: String) -> void:
	_style.content_margin_top = 12
	_style.content_margin_bottom = 10
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var art: Glyph = Glyph.item(def, UiStyle.rarity_color(def.rarity).lightened(0.25), 96)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(art)
	var name_label: Label = UiStyle.heading("%s  %s" % [def.name, TuningDef.TIER_LABELS[tier]], 17, UiStyle.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(WARE_SIZE.x - 24, 0)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	var size_text: String = "%d slot%s" % [def.size, "" if def.size == 1 else "s"]
	var kind: Label = UiStyle.label("%s · %s" % [def.rarity.capitalize(), size_text], 13, UiStyle.rarity_color(def.rarity).lightened(0.2))
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(kind)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	var price: Control = UiStyle.icon_label("gold", footer, 18, UiStyle.HIGHLIGHT) if footer.ends_with("gold") else UiStyle.label(footer, 16, UiStyle.TEXT_DIM)
	price.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(price)
	if lit:
		var note: Label = UiStyle.label("Combines with yours", 13, UiStyle.HIGHLIGHT)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(note)
	add_child(FrameDecor.make(ItemDef.RARITIES.find(def.rarity), def.enemy_only))


## Hover: lift the token a little with a brass rim (docs/ui-asset-design.md, 9).
func _lift(on: bool) -> void:
	scale = Vector2(1.04, 1.04) if on else Vector2.ONE
	z_index = 1 if on else 0
	if not on:
		_outline(Color())


## Outlines the token (a drop target), or restores its frame (no color).
func _outline(color: Color) -> void:
	if color == Color():
		add_theme_stylebox_override("panel", _style)
		return
	var style: StyleBoxFlat = _style.duplicate()
	style.border_color = color
	style.set_border_width_all(4)
	add_theme_stylebox_override("panel", style)


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
	var preview: Label = UiStyle.label(session.content.items[item_id].name, 16, UiStyle.HIGHLIGHT)
	preview.add_theme_color_override("font_outline_color", UiStyle.INK_900)
	preview.add_theme_constant_override("outline_size", 6)
	set_drag_preview(preview)
	return {"uid": uid}


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_drop_checks.clear()
		_outline(Color())


## What dropping `payload` here does: an essence infuses this item; a copy
## at the same tier combines into it; any other item moves to this spot.
func drop_kind(payload: Dictionary) -> Drop:
	if payload.has("pouch_index"):
		return Drop.INFUSE
	var dragged: RunItem = session.state.find_item(payload["uid"])
	if dragged != null and dragged.item_id == item_id and dragged.tier == tier:
		return Drop.COMBINE
	return Drop.MOVE


## The drop's action on `state` (the real run, or a copy to check it).
func _drop_on(state: RunState, payload: Dictionary) -> RunActions.Result:
	match drop_kind(payload):
		Drop.INFUSE:
			return RunActions.infuse(state, session.content, uid, payload["pouch_index"])
		Drop.COMBINE:
			return RunActions.combine_items(state, session.content, uid, payload["uid"])
	return RunActions.move_item(state, session.content, payload["uid"], owner_id, index)


## Would dropping `payload` here work? Checked once per drag on a copy of
## the run, so the answer is the game's own rules.
func would_accept(payload: Dictionary) -> bool:
	var key: String = str(payload)
	if not _drop_checks.has(key):
		_drop_checks[key] = session.would_succeed(func(state: RunState) -> RunActions.Result: return _drop_on(state, payload))
	return _drop_checks[key]


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if uid < 0 or typeof(data) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = data
	if not (payload.has("pouch_index") or (payload.has("uid") and payload["uid"] != uid)):
		return false
	var ok: bool = would_accept(payload)
	_outline(UiStyle.GOOD if ok else UiStyle.BAD)
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var payload: Dictionary = data
	_outline(Color())
	match drop_kind(payload):
		Drop.INFUSE:
			session.infuse(uid, payload["pouch_index"])
		Drop.COMBINE:
			session.combine(uid, payload["uid"])
		_:
			session.move_item(payload["uid"], owner_id, index)
