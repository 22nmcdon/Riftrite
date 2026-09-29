class_name FightChart
extends VBoxContainer
## The fight chart (docs/plans/rebuild-phase3-fight-sandbox.md, section 6),
## shown above the log: three tabs (Damage, Healing and Shield, Damage
## taken), a legend, and a bar per hero, largest first, split into colored
## types. Hovering a bar lists its sources. Reads a FightTally; call
## refresh() after adding entries to it.
## (The old game's chart, from git history, without the relics' bar.)

## Type colors per tab, in FightTally.TYPES order. Checked for colorblind
## safety as neighbors in a stack on the panel color (the dataviz
## validator); the 2px gaps, the legend, and the hover breakdown back them
## up.
const COLORS: Array[Array] = [
	[Color("c98500"), Color("3987e5"), Color("d95926"), Color("199e70"), Color("e66767")],
	[Color("199e70"), Color("3987e5")],
	[Color("e66767"), Color("3987e5")],
]
const SURFACE := UiStyle.NAVY_800
const NAME_WIDTH: float = 150.0
const BAR_HEIGHT: float = 18.0
const GAP: float = 2.0
## Small enough that the three tabs fit the arena's side column.
const TAB_FONT: int = 14

var tally: FightTally
var tab: FightTally.Tab = FightTally.Tab.DAMAGE
var _tab_buttons: Array[Button] = []
var _legend: HBoxContainer
var _rows: VBoxContainer
## What's drawn: the bars' ids in order, and each row's parts (row, strip,
## value), so a refresh with the same order updates them in place (and an
## open hover stays open).
var _shown_ids: Array[String] = []
var _shown_tab: int = -1
var _row_parts: Array[Array] = []


static func make(fight_tally: FightTally) -> FightChart:
	var chart := FightChart.new()
	chart.tally = fight_tally
	chart.add_theme_constant_override("separation", 6)
	var tabs := HBoxContainer.new()
	var group := ButtonGroup.new()
	for i: int in FightTally.TAB_NAMES.size():
		var button: Button = UiStyle.button(FightTally.TAB_NAMES[i], chart.show_tab.bind(i))
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", TAB_FONT)
		button.button_group = group
		button.button_pressed = i == 0
		chart._tab_buttons.append(button)
		tabs.add_child(button)
	chart.add_child(tabs)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.box(SURFACE, UiStyle.BORDER, 1))
	chart.add_child(panel)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 6)
	panel.add_child(inside)
	chart._legend = HBoxContainer.new()
	chart._legend.add_theme_constant_override("separation", 8)
	inside.add_child(chart._legend)
	chart._rows = VBoxContainer.new()
	chart._rows.add_theme_constant_override("separation", 4)
	inside.add_child(chart._rows)
	chart.refresh()
	return chart


## Reads a new tally (a restarted fight).
func set_tally(fight_tally: FightTally) -> void:
	tally = fight_tally
	refresh()


func show_tab(index: int) -> void:
	tab = index as FightTally.Tab
	for i: int in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == index)
	refresh()


## Updates the legend and bars from the tally (none yet: nothing to show).
func refresh() -> void:
	if tally == null:
		return
	var bars: Array[FightTally.Bar] = tally.sorted(tab)
	var most: int = 1
	for bar: FightTally.Bar in bars:
		most = maxi(most, bar.total())
	var ids: Array[String] = []
	for bar: FightTally.Bar in bars:
		ids.append(bar.id)
	if ids == _shown_ids and tab == _shown_tab:
		for i: int in bars.size():
			_update_row(_row_parts[i], bars[i], most)
		return
	_shown_ids = ids
	_shown_tab = tab
	for box: Container in [_legend, _rows]:
		for child: Node in box.get_children():
			child.free()
	var types: Array = FightTally.TYPES[tab]
	for i: int in types.size():
		var key := HBoxContainer.new()
		key.add_theme_constant_override("separation", 4)
		var swatch := ColorRect.new()
		swatch.color = COLORS[tab][i]
		swatch.custom_minimum_size = Vector2(12, 12)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		key.add_child(swatch)
		key.add_child(UiStyle.label(types[i], 13, UiStyle.TEXT_DIM))
		_legend.add_child(key)
	_row_parts.clear()
	for bar: FightTally.Bar in bars:
		var parts: Array = _row(bar)
		_row_parts.append(parts)
		_rows.add_child(parts[0])
		_update_row(parts, bar, most)


## A bar's row: [the row, its StackedBar, its value label].
func _row(bar: FightTally.Bar) -> Array:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var name_label: Label = UiStyle.label(bar.name, 14)
	name_label.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	name_label.clip_text = true
	row.add_child(name_label)
	var strip := StackedBar.new()
	strip.colors = COLORS[tab]
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	strip.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(strip)
	var value: Label = UiStyle.label("0", 14, UiStyle.TEXT)
	value.custom_minimum_size = Vector2(52, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return [row, strip, value]


func _update_row(parts: Array, bar: FightTally.Bar, most: int) -> void:
	var row: Control = parts[0]
	var strip: StackedBar = parts[1]
	var value: Label = parts[2]
	row.tooltip_text = breakdown_text(bar)
	strip.amounts = bar.by_type.duplicate()
	strip.most = most
	strip.queue_redraw()
	value.text = str(bar.total())


## The hover text: the total, each type, then each source with its share.
func breakdown_text(bar: FightTally.Bar) -> String:
	var total: int = bar.total()
	var lines: PackedStringArray = PackedStringArray(["%s: %d %s" % [bar.name, total, FightTally.TAB_NAMES[tab].to_lower()]])
	var types: Array = FightTally.TYPES[tab]
	for i: int in types.size():
		if bar.by_type[i] > 0:
			lines.append("  %s %d (%d%%)" % [types[i], bar.by_type[i], _percent(bar.by_type[i], total)])
	var sources: Array[Array] = bar.breakdown()
	if not sources.is_empty():
		lines.append("By source:")
		for pair: Array in sources:
			lines.append("  %s %d (%d%%)" % [pair[0], pair[1], _percent(pair[1], total)])
	return "\n".join(lines)


static func _percent(part: int, whole: int) -> int:
	return roundi(100.0 * part / whole) if whole > 0 else 0


## One horizontal bar, its types side by side, 2px of panel color between
## them, and the end rounded.
class StackedBar extends Control:
	var amounts: Array[int] = []
	var colors: Array = []
	var most: int = 1

	func _draw() -> void:
		var x: float = 0.0
		var full: float = size.x * _sum() / maxf(most, 1.0)
		var last: int = -1
		for i: int in amounts.size():
			if amounts[i] > 0:
				last = i
		for i: int in amounts.size():
			if amounts[i] <= 0:
				continue
			var width: float = full * amounts[i] / maxf(_sum(), 1.0)
			var drawn: float = maxf(width - (FightChart.GAP if i != last else 0.0), 1.0)
			if i == last:
				var end := StyleBoxFlat.new()
				end.bg_color = colors[i]
				end.corner_radius_top_right = 4
				end.corner_radius_bottom_right = 4
				draw_style_box(end, Rect2(x, 0, drawn, size.y))
			else:
				draw_rect(Rect2(x, 0, drawn, size.y), colors[i])
			x += width

	func _sum() -> int:
		var total: int = 0
		for amount: int in amounts:
			total += amount
		return total
