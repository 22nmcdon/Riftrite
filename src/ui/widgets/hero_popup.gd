class_name HeroPopup
extends PanelContainer
## A hero's details, opened by clicking the hero while the fight isn't
## playing: in placement, paused, or over (docs/plans/rebuild-phase3-fight-sandbox.md,
## section 7, Decision 3). Its name and title, role, stats, and a line per
## ability (UnitInfo); in a fight, also its numbers now and its last few log
## lines. ArenaScreen opens it beside the hero and closes it on a click
## elsewhere, and when the fight plays on.

const WIDTH: float = 380.0

var title: Label
var role: Label
var stats: Label
var live: Label
var recent: Label
var abilities: VBoxContainer
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


## Its numbers now and its last log lines, in a fight.
func show_live(unit: UnitState, lines: Array[String]) -> void:
	live.text = UnitInfo.live_text(unit)
	live.visible = true
	recent.text = "Last in the log:\n" + "\n".join(lines) if not lines.is_empty() else ""
	recent.visible = not lines.is_empty()


func close() -> void:
	showing = ""
	visible = false
