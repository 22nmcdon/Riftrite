class_name UnitCard
extends PanelContainer
## A unit in the fight view: name, HP and shield, statuses, and its items,
## each with a cooldown bar that flashes when the item fires. It reads the
## live UnitState every frame (read-only).

var unit: UnitState
var _hp_bar: ProgressBar
var _hp_label: Label
var _status_label: Label
var _items_box: HBoxContainer
## One per item, in the unit's item order: [ItemState, panel, cooldown bar].
var _item_views: Array[Array] = []


static func make(fight_unit: UnitState) -> UnitCard:
	var card := UnitCard.new()
	card.unit = fight_unit
	card.custom_minimum_size = Vector2(260, 0)
	var box := VBoxContainer.new()
	card.add_child(box)
	box.add_child(UiStyle.label(fight_unit.name + (" (backup)" if fight_unit.benched else ""), 15, UiStyle.TEXT))
	card._hp_bar = ProgressBar.new()
	card._hp_bar.max_value = fight_unit.max_hp
	card._hp_bar.show_percentage = false
	card._hp_bar.custom_minimum_size = Vector2(0, 14)
	card._hp_bar.add_theme_stylebox_override("fill", UiStyle.box(UiStyle.GOOD, UiStyle.GOOD, 0))
	card._hp_bar.add_theme_stylebox_override("background", UiStyle.box(UiStyle.BACKGROUND, UiStyle.BORDER, 1))
	box.add_child(card._hp_bar)
	card._hp_label = UiStyle.label("", 13)
	box.add_child(card._hp_label)
	card._status_label = UiStyle.label("", 13, UiStyle.EMBER)
	box.add_child(card._status_label)
	card._items_box = HBoxContainer.new()
	box.add_child(card._items_box)
	card._build_items()
	card.refresh()
	return card


func _build_items() -> void:
	for child: Node in _items_box.get_children():
		child.queue_free()
	_item_views.clear()
	for item: ItemState in unit.items:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL, UiStyle.rarity_color(item.def.rarity) if item.slot >= 0 else UiStyle.BORDER, 1))
		panel.tooltip_text = "%s\n%s" % [item.def.name, "\n".join(item.describe_values())]
		var inner := VBoxContainer.new()
		panel.add_child(inner)
		var name_label: Label = UiStyle.label(item.def.name, 10)
		name_label.custom_minimum_size = Vector2(56, 0)
		name_label.clip_text = true
		inner.add_child(name_label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.step = 0.0
		bar.custom_minimum_size = Vector2(56, 6)
		inner.add_child(bar)
		_items_box.add_child(panel)
		_item_views.append([item, panel, bar])


## Reads the unit's current HP, shield, statuses, and cooldowns.
func refresh() -> void:
	if _item_views.size() != unit.items.size():
		_build_items()
	_hp_bar.value = unit.hp
	var shield: String = "  +%d shield" % unit.shield if unit.shield > 0 else ""
	_hp_label.text = ("%d / %d%s" % [unit.hp, unit.max_hp, shield]) if unit.alive else "fallen"
	var tags: PackedStringArray = PackedStringArray()
	for status: StatusState in unit.statuses:
		tags.append("%s %d" % [UiStyle.STATUS_TAGS.get(status.def.id, status.def.id), status.total_stacks()])
	_status_label.text = " ".join(tags)
	modulate = Color(1, 1, 1, 1.0 if unit.alive else 0.45)
	for view: Array in _item_views:
		var item: ItemState = view[0]
		(view[2] as ProgressBar).value = float(item.progress_bp) / float(maxi(item.cooldown_ticks * FixedMath.BP_ONE, 1))


## Lights up the item that just fired.
func flash(item_id: String) -> void:
	for view: Array in _item_views:
		if (view[0] as ItemState).def.id == item_id:
			var panel: PanelContainer = view[1]
			panel.modulate = UiStyle.HIGHLIGHT
			var tween: Tween = panel.create_tween()
			tween.tween_property(panel, "modulate", Color.WHITE, 0.35)
