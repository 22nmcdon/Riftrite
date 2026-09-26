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
## The frame when not hovered or a drop target.
var _style: StyleBoxFlat
## The token's column (icon row, name, footer, path bar).
var _box: VBoxContainer
## Drop checks already made this drag: payload key -> would it work.
var _drop_checks: Dictionary[String, bool] = {}


static func owned(run_session: RunSession, item: RunItem, holder: String, at: int, holder_stats: UnitStats) -> ItemTile:
	var tile := ItemTile.new()
	tile.session = run_session
	tile.uid = item.uid
	tile.owner_id = holder
	tile.index = at
	tile._fill(item.item_id, item.tier, item.essence_ids, item.xp, holder_stats, "", item.trace_bp(run_session.content))
	tile._add_path_bar(item)
	return tile


static func offer(run_session: RunSession, item: String, item_tier: int, footer: String, glow: bool = false) -> ItemTile:
	var tile := ItemTile.new()
	tile.session = run_session
	tile.lit = glow
	tile._fill(item, item_tier, [] as Array[String], 0, null, footer)
	return tile


func _fill(item: String, item_tier: int, essences: Array[String], xp: int, holder_stats: UnitStats, footer: String, trace_bp: int = 0) -> void:
	item_id = item
	tier = item_tier
	essence_ids = essences
	var content: ContentDb = session.content
	var def: ItemDef = content.items[item]
	custom_minimum_size = Vector2(maxi(def.size, 1) * UiStyle.SLOT_WIDTH, UiStyle.TILE_HEIGHT)
	var selected: bool = uid >= 0 and session.selected_uid == uid
	var border: Color = UiStyle.HIGHLIGHT if lit or selected else UiStyle.rarity_color(def.rarity)
	var fill: Color = UiStyle.PANEL_WARM if selected else (Color("241a2e") if def.enemy_only else UiStyle.PANEL)
	_style = UiStyle.box(fill, border, 4 if lit or selected else 3)
	add_theme_stylebox_override("panel", _style)
	pivot_offset = custom_minimum_size / 2.0
	info = ItemInfo.item_text(content, item, item_tier, essences, xp, holder_stats, trace_bp)
	Inspector.hover_text(self, info)
	mouse_entered.connect(_lift.bind(true))
	mouse_exited.connect(_lift.bind(false))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	_box = box
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	top.add_child(Glyph.item(def, UiStyle.rarity_color(def.rarity).lightened(0.25), 26))
	var tier_label: Label = UiStyle.label(TuningDef.TIER_LABELS[item_tier], 16, UiStyle.EMBER)
	tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(tier_label)
	var discovered: Array[String] = session.state.discovered if session.state != null else ([] as Array[String])
	var form: Glyph.Infusion = InfusionLook.form(content, item, essences, discovered)
	var sockets: int = content.tuning.socket_count(def)
	if form != Glyph.Infusion.EMPTY:
		top.add_child(Glyph.infusion_gem(form, essences, 28))
	# Empty sockets: all of them, or the second one beside a single essence.
	var filled: int = 0 if form == Glyph.Infusion.EMPTY else (1 if form == Glyph.Infusion.SINGLE else sockets)
	for i: int in sockets - filled:
		top.add_child(Glyph.infusion_gem(Glyph.Infusion.EMPTY, [] as Array[String], 22))
	var name_label: Label = UiStyle.label(def.name, 14)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	if not footer.is_empty():
		var price: Label = UiStyle.label(footer, 14, UiStyle.HIGHLIGHT)
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(price)
	var level: int = InfusionLook.level(content, essences, xp)
	add_child(FrameDecor.make(ItemDef.RARITIES.find(def.rarity), def.enemy_only, InfusionLook.spill_colors(form, essences, level), InfusionLook.shows_no_spill(form, level)))


## A Legendary's path progress: a thin bar along the bottom (full at S).
func _add_path_bar(item: RunItem) -> void:
	var path: LegendaryDef = RunLegendary.path_of(session.content, item)
	if path == null:
		return
	var bar := ProgressBar.new()
	bar.name = "PathBar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 6)
	bar.max_value = maxi(path.goal_at(item.tier), 1)
	bar.value = bar.max_value if item.tier >= 3 else item.progress
	bar.tooltip_text = RunLegendary.describe(session.content, item)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", UiStyle.box(UiStyle.INK_900, UiStyle.INK_900, 0))
	bar.add_theme_stylebox_override("fill", UiStyle.box(UiStyle.rarity_color("legendary"), UiStyle.rarity_color("legendary"), 0))
	_box.add_child(bar)


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
