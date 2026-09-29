class_name HeroPopup
extends PanelContainer
## A hero's details, opened by clicking the hero while the fight isn't
## playing: in placement, paused, or over (docs/plans/rebuild-phase3-fight-sandbox.md,
## section 7, Decision 3). Its name and title, role, stats, and a line per
## ability (UnitInfo); in a fight, also its numbers now and its last few log
## lines. ArenaScreen opens it beside the hero and closes it on a click
## elsewhere, and when the fight plays on.
## Its Tactic row (docs/plans/rebuild-phase3b-tactics.md, section 4): while
## placing, a button for no tactic and one for each the hero can take (a
## press asks ArenaScreen to set it: tactic_chosen); in a fight, the one it
## took. Either way, with the tactic's sentence.

## A tactic was picked for the hero shown ("": none).
signal tactic_chosen(hero_id: String, tactic_id: String)

const WIDTH: float = 380.0
const NO_TACTIC: String = "None"

var title: Label
var role: Label
var stats: Label
var live: Label
var recent: Label
var abilities: VBoxContainer
var tactic_box: VBoxContainer
## The tactic buttons while placing (the first is "None").
var tactic_buttons: Array[Button] = []
var tactic_text: Label
## The hero shown ("": closed).
var showing: String = ""
var _column: VBoxContainer


static func make() -> HeroPopup:
	var popup := HeroPopup.new()
	popup.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL_WARM, UiStyle.BRASS_300, 2))
	popup.custom_minimum_size = Vector2(WIDTH, 0)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup._column = VBoxContainer.new()
	popup._column.add_theme_constant_override("separation", 6)
	popup.add_child(popup._column)
	popup.title = UiStyle.label("", 24, UiStyle.HIGHLIGHT)
	popup.role = UiStyle.label("", 16, UiStyle.TEXT_DIM)
	popup.stats = UiStyle.label("", 16, UiStyle.TEXT_DIM)
	popup.live = UiStyle.label("", 16, UiStyle.TEXT)
	popup.recent = UiStyle.label("", 13, UiStyle.TEXT_DIM)
	for label: Label in [popup.title, popup.role, popup.stats, popup.live]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		popup._column.add_child(label)
	popup.abilities = VBoxContainer.new()
	popup._column.add_child(popup.abilities)
	popup.tactic_box = VBoxContainer.new()
	popup.tactic_box.add_theme_constant_override("separation", 4)
	popup._column.add_child(popup.tactic_box)
	popup.recent.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	popup._column.add_child(popup.recent)
	popup.visible = false
	return popup


func show_hero(hero: HeroDef, content: ContentDb) -> void:
	showing = hero.id
	title.text = hero.name
	role.text = "%s · %s" % [hero.title.capitalize(), HeroDef.ROLE_NAMES[hero.role].capitalize()]
	stats.text = UnitInfo.stats_text(hero.kit.stats)
	live.visible = false
	recent.visible = false
	_column.remove_child(abilities)
	abilities.free()
	abilities = UnitInfo.column(UnitInfo.lines(hero.kit, ArenaView.label_for(hero.kit, content), content))
	_column.add_child(abilities)
	_column.move_child(abilities, live.get_index() + 1)
	visible = true


## The Tactic row: `options` the tactics the hero can take, `chosen` its
## tactic's id ("": none), and whether it can be changed now (placing).
func show_tactics(options: Array[TacticDef], chosen: String, can_choose: bool) -> void:
	for child: Node in tactic_box.get_children():
		tactic_box.remove_child(child)
		child.free()
	tactic_buttons.clear()
	tactic_box.visible = not options.is_empty()
	if options.is_empty():
		return
	var picked: TacticDef = null
	for option: TacticDef in options:
		if option.id == chosen:
			picked = option
	tactic_box.add_child(UiStyle.label("Tactic" if can_choose else "Tactic: %s" % (picked.name if picked != null else "none"), 17, UiStyle.BRASS_300))
	if can_choose:
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 6)
		row.add_theme_constant_override("v_separation", 6)
		tactic_box.add_child(row)
		var ids: Array[String] = [""]
		var names: Array[String] = [NO_TACTIC]
		for option: TacticDef in options:
			ids.append(option.id)
			names.append(option.name)
		for i: int in ids.size():
			var tactic_id: String = ids[i]
			var button: Button = UiStyle.button(names[i], func() -> void: tactic_chosen.emit(showing, tactic_id))
			button.toggle_mode = true
			button.set_pressed_no_signal(tactic_id == chosen)
			if tactic_id == chosen:
				UiStyle.primary(button)
			tactic_buttons.append(button)
			row.add_child(button)
	tactic_text = UiStyle.label(picked.text if picked != null else "No tactic: it fights by its kit alone.", 14, UiStyle.TEXT_DIM)
	tactic_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tactic_box.add_child(tactic_text)


## Its numbers now and its last log lines, in a fight.
func show_live(unit: UnitState, lines: Array[String]) -> void:
	live.text = UnitInfo.live_text(unit)
	live.visible = true
	recent.text = "Last in the log:\n" + "\n".join(lines) if not lines.is_empty() else ""
	recent.visible = not lines.is_empty()


func close() -> void:
	showing = ""
	visible = false
