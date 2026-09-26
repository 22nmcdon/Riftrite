class_name UnitCard
extends PanelContainer
## A unit in the fight view (docs/ui-asset-design.md, 6.3): portrait, name,
## HP bar with its shield and a damage ghost that trails behind, status pips
## (a shape per status), and its items, each with a radial cooldown sweep
## that flashes when the item fires. Damage, heals, and shields float up as
## outlined numbers (crits bigger, with a brass outline). Elite and boss
## enemies carry the rift bleed. It reads the live UnitState every frame
## (read-only).

const WIDTH: int = 280

var unit: UnitState
var display_name: String
var _hp_bar: ProgressBar
## Trails behind the HP bar after damage, then catches up.
var _ghost_bar: ProgressBar
var _shield_bar: ProgressBar
var _hp_label: Label
var _statuses: HFlowContainer
var _items_box: HFlowContainer
## Floating numbers are drawn here, over the card.
var _overlay: Control
## One per item, in the unit's item order: [ItemState, panel, sweep Glyph].
var _item_views: Array[Array] = []
## The statuses shown last refresh ("id:stacks" joined), to skip rebuilding.
var _status_key: String = ""


static func make(fight_unit: UnitState, shown_name: String = "", rift: bool = false) -> UnitCard:
	var card := UnitCard.new()
	card.unit = fight_unit
	card.display_name = shown_name if not shown_name.is_empty() else fight_unit.name
	card.custom_minimum_size = Vector2(WIDTH, 0)
	var hero: bool = fight_unit.side == UnitSetup.Side.HEROES
	card.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL if hero else Color("2a2230"), UiStyle.BORDER if hero else Glyph.ENEMY))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	var color: Color = Glyph.CLASS_COLORS.get(fight_unit.unit_class, UiStyle.EMBER) if hero else Glyph.ENEMY.lightened(0.25)
	top.add_child(Glyph.portrait(card.display_name, color, 44))
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	names.add_child(UiStyle.label(card.display_name + (" (backup)" if fight_unit.benched else ""), 17))
	card._hp_label = UiStyle.label("", 15)
	names.add_child(card._hp_label)
	var bars := Control.new()
	bars.custom_minimum_size = Vector2(0, 16)
	box.add_child(bars)
	card._ghost_bar = card._bar(UiStyle.BRASS_300, fight_unit.max_hp)
	bars.add_child(card._ghost_bar)
	card._hp_bar = card._bar(UiStyle.GOOD if hero else UiStyle.BAD, fight_unit.max_hp)
	card._hp_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	bars.add_child(card._hp_bar)
	card._shield_bar = card._bar(UiStyle.SHIELD, fight_unit.max_hp)
	card._shield_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	card._shield_bar.modulate = Color(1, 1, 1, 0.75)
	bars.add_child(card._shield_bar)
	card._statuses = HFlowContainer.new()
	card._statuses.custom_minimum_size = Vector2(0, 22)
	box.add_child(card._statuses)
	card._items_box = HFlowContainer.new()
	card._items_box.add_theme_constant_override("h_separation", 4)
	box.add_child(card._items_box)
	if rift:
		card.add_child(FrameDecor.make(0, true))
	card._overlay = Control.new()
	card._overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card._overlay)
	card._build_items()
	card.refresh()
	return card


func _bar(fill: Color, max_value: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = max_value
	bar.show_percentage = false
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_theme_stylebox_override("fill", UiStyle.box(fill, fill, 0))
	bar.add_theme_stylebox_override("background", UiStyle.box(UiStyle.BACKGROUND, UiStyle.BORDER, 1))
	return bar


func _build_items() -> void:
	for child: Node in _items_box.get_children():
		child.queue_free()
	_item_views.clear()
	for item: ItemState in unit.items:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.BACKGROUND, UiStyle.rarity_color(item.def.rarity) if item.slot >= 0 else UiStyle.BORDER, 1))
		panel.tooltip_text = "%s\n%s" % [item.def.name, "\n".join(item.describe_values())]
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 1)
		panel.add_child(inner)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		inner.add_child(line)
		var sweep: Glyph = Glyph.item(item.def, UiStyle.rarity_color(item.def.rarity).lightened(0.3), 30)
		sweep.progress = 0.0
		line.add_child(sweep)
		var name_label: Label = UiStyle.label(item.def.name, 12)
		name_label.custom_minimum_size = Vector2(80, 0)
		name_label.clip_text = true
		line.add_child(name_label)
		_items_box.add_child(panel)
		_item_views.append([item, panel, sweep])


## Reads the unit's current HP, shield, statuses, and cooldowns.
func refresh() -> void:
	if _item_views.size() != unit.items.size():
		_build_items()
	_hp_bar.value = unit.hp
	# The ghost drains toward the HP it trails (about a second for full HP).
	_ghost_bar.value = unit.hp if _ghost_bar.value < unit.hp else maxf(unit.hp, _ghost_bar.value - unit.max_hp * 0.015)
	_shield_bar.value = mini(unit.shield, unit.max_hp)
	var shield: String = "   +%d shield" % unit.shield if unit.shield > 0 else ""
	_hp_label.text = ("%d / %d%s" % [unit.hp, unit.max_hp, shield]) if unit.alive else "fallen"
	_refresh_statuses()
	modulate = Color(1, 1, 1, 1.0 if unit.alive else 0.4)
	for view: Array in _item_views:
		var item: ItemState = view[0]
		(view[2] as Glyph).set_progress(float(item.progress_bp) / float(maxi(item.cooldown_ticks * FixedMath.BP_ONE, 1)))


func _refresh_statuses() -> void:
	var parts: PackedStringArray = PackedStringArray()
	for status: StatusState in unit.statuses:
		parts.append("%s:%d" % [status.def.id, status.total_stacks()])
	var key: String = ",".join(parts)
	if key == _status_key:
		return
	_status_key = key
	for child: Node in _statuses.get_children():
		_statuses.remove_child(child)
		child.queue_free()
	for status: StatusState in unit.statuses:
		var color: Color = UiStyle.STATUS_COLORS.get(status.def.id, UiStyle.EMBER)
		var chip := PanelContainer.new()
		var style: StyleBoxFlat = UiStyle.box(color.darkened(0.6), color, 1)
		style.content_margin_top = 1
		style.content_margin_bottom = 1
		style.content_margin_left = 5
		style.content_margin_right = 5
		chip.add_theme_stylebox_override("panel", style)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 3)
		chip.add_child(line)
		line.add_child(Glyph.status(status.def.id, 13))
		line.add_child(UiStyle.label("%s %d" % [status.def.name, status.total_stacks()], 13, color.lightened(0.3)))
		_statuses.add_child(chip)


## Lights up the item that just fired.
func flash(item_id: String) -> void:
	for view: Array in _item_views:
		if (view[0] as ItemState).def.id == item_id:
			var panel: PanelContainer = view[1]
			panel.modulate = UiStyle.HIGHLIGHT * 1.4
			var tween: Tween = panel.create_tween()
			tween.tween_property(panel, "modulate", Color.WHITE, 0.35)


## A number that floats up over the card and fades (damage, heal, shield),
## over `seconds`.
## A crit is bigger, with a brass outline.
func float_number(text: String, color: Color, seconds: float = 0.9, crit: bool = false) -> void:
	if not is_inside_tree():
		return
	var label: Label = UiStyle.label(text, 30 if crit else 22, color)
	label.add_theme_color_override("font_outline_color", UiStyle.BRASS_500 if crit else UiStyle.INK_900)
	label.add_theme_constant_override("outline_size", 8 if crit else 6)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.position = Vector2(size.x * 0.5 + (_overlay.get_child_count() % 3 - 1) * 40.0, size.y * 0.35)
	_overlay.add_child(label)
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50.0, seconds)
	tween.tween_property(label, "modulate:a", 0.0, seconds * 0.7).set_delay(seconds * 0.3)
	tween.chain().tween_callback(label.queue_free)


## Removes any floating numbers (the fight is over).
func clear_floats() -> void:
	for child: Node in _overlay.get_children():
		child.queue_free()


## Tints the card red for a moment (it was hit).
func hit() -> void:
	if not is_inside_tree():
		return
	self_modulate = Color(1.6, 0.7, 0.7)
	var tween: Tween = create_tween()
	tween.tween_property(self, "self_modulate", Color.WHITE, 0.25)
