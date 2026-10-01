class_name LogPanel
extends VBoxContainer
## The combat log beside the board (docs/plans/rebuild-phase3-fight-sandbox.md,
## section 6): each LogEntry's line as it happens, with names instead of ids
## and colored by side (FightNames).
##   - The chatter (walking, stopping, and picking targets) is hidden unless
##     "Show movement and targeting" is on.
##   - Clicking a unit on the board filters the log to lines about it (its
##     own, and those aimed at it); "Show everyone" (or clicking it again)
##     lifts the filter.
##   - It keeps every entry handed to it, so changing what's shown rewrites
##     the lines from the start.

const CHATTER: Array[LogEntry.Kind] = [LogEntry.Kind.MOVE, LogEntry.Kind.STOP, LogEntry.Kind.TARGET]

var names: FightNames
## Every entry so far, shown or not.
var entries: Array[LogEntry] = []
var show_chatter: bool = false
## The combo readout's notes (for testing, phase 5c step 9a): each DAMAGE,
## HEAL, SHIELD, and STATUS_DAMAGE line gets how the damage rule made it.
var show_rule: bool = false
## The unit the lines are about ("": everyone).
var only_unit: String = ""
var lines: RichTextLabel
var chatter_toggle: CheckButton
var filter_row: HBoxContainer
var filter_label: Label


static func make() -> LogPanel:
	var panel := LogPanel.new()
	panel.add_theme_constant_override("separation", 6)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(UiStyle.label("Combat log", 20, UiStyle.HIGHLIGHT))
	panel.chatter_toggle = CheckButton.new()
	panel.chatter_toggle.text = "Show movement and targeting"
	panel.chatter_toggle.toggled.connect(panel.set_show_chatter)
	panel.add_child(panel.chatter_toggle)
	panel.filter_row = HBoxContainer.new()
	panel.filter_row.add_theme_constant_override("separation", 8)
	panel.filter_label = UiStyle.label("", 15, UiStyle.TEXT_DIM)
	panel.filter_row.add_child(panel.filter_label)
	panel.filter_row.add_child(UiStyle.button("Show everyone", panel.filter_to.bind("")))
	panel.filter_row.visible = false
	panel.add_child(panel.filter_row)
	panel.lines = RichTextLabel.new()
	panel.lines.bbcode_enabled = true
	panel.lines.scroll_following = true
	panel.lines.selection_enabled = true
	panel.lines.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.lines.custom_minimum_size = Vector2(0, 200)
	panel.lines.add_theme_font_size_override("normal_font_size", 14)
	panel.lines.add_theme_font_size_override("bold_font_size", 14)
	panel.add_child(panel.lines)
	return panel


## Starts over for a fight (or the same fight restarted). The filter stays.
func start(fight_names: FightNames) -> void:
	names = fight_names
	entries.clear()
	lines.clear()


func add(new_entries: Array[LogEntry]) -> void:
	for entry: LogEntry in new_entries:
		entries.append(entry)
		if shows(entry):
			var note: String = rule_note(entry) if show_rule else ""
			lines.append_text(names.bbcode(entry) + ("  [color=#8a8fa3](%s)[/color]" % note if not note.is_empty() else "") + "\n")


## Whether an entry's line is shown under the current toggle and filter.
func shows(entry: LogEntry) -> bool:
	if not show_chatter and CHATTER.has(entry.kind):
		return false
	return only_unit.is_empty() or entry.source_unit == only_unit or entry.target == only_unit


## The rule's note on an entry: the damage rule's parts, then what DEF took
## and a Shield absorbed ("" without one).
static func rule_note(entry: LogEntry) -> String:
	var note: String = ComboTally.rule_note(entry)
	if note.is_empty():
		return ""
	if entry.mitigated > 0:
		note += " · DEF −%d" % entry.mitigated
	if entry.absorbed > 0:
		note += " · Shield took %d" % entry.absorbed
	return note


func set_show_rule(on: bool) -> void:
	show_rule = on
	_rewrite()


func set_show_chatter(on: bool) -> void:
	show_chatter = on
	chatter_toggle.set_pressed_no_signal(on)
	_rewrite()


## Filters to lines about `unit_id` ("" for everyone; the unit already
## filtered to lifts it).
func filter_to(unit_id: String) -> void:
	only_unit = "" if unit_id == only_unit else unit_id
	filter_row.visible = not only_unit.is_empty()
	filter_label.text = "Only %s" % names.name_of(only_unit)
	_rewrite()


## The lines as shown, without their BBCode.
func shown_text() -> String:
	return lines.get_parsed_text()


func _rewrite() -> void:
	lines.clear()
	var kept: Array[LogEntry] = entries.duplicate()
	entries.clear()
	add(kept)
