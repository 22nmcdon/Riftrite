class_name HeroPopup
extends PanelContainer
## A hero's details in a fight, opened by clicking the hero while the fight
## isn't playing: paused or over (docs/plans/rebuild-phase3-fight-sandbox.md,
## section 7, Decision 3; while placing, the hero panel opens instead:
## docs/plans/rebuild-phase4-paths.md, section 6). Its name and title, role
## (and path), stats, and a line per ability of the kit it fights with
## (UnitInfo); its numbers now and its last few log lines; and the tactic it
## took (TacticPicker). ArenaScreen opens it beside the hero and closes it on a
## click elsewhere, and when the fight plays on.

const WIDTH: float = 380.0

var title: Label
var role: Label
var stats: Label
var live: Label
var recent: Label
var abilities: VBoxContainer
var tactic_box: TacticPicker
## The hero shown ("": closed).
var showing: String = ""
var _column: VBoxContainer


static func make() -> HeroPopup:
	var popup := HeroPopup.new()
	popup.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL_RAISED, UiStyle.GOLD_300, 2))
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
	popup.tactic_box = TacticPicker.make()
	popup._column.add_child(popup.tactic_box)
	popup.recent.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	popup._column.add_child(popup.recent)
	popup.visible = false
	return popup


## `hero` fighting with `kit` (its base kit when null), on `path` at `stage`.
func show_hero(hero: HeroDef, content: ContentDb, kit: UnitDef = null, path: PathDef = null, stage: PathDef.Stage = PathDef.Stage.BASE) -> void:
	var fights_with: UnitDef = kit if kit != null else hero.kit
	showing = hero.id
	title.text = hero.name
	role.text = "%s · %s" % [hero.title.capitalize(), HeroDef.ROLE_NAMES[hero.role].capitalize()]
	if path != null:
		role.text += " · %s, %s" % [path.name, PathDef.STAGE_NAMES[stage]]
	stats.text = UnitInfo.stats_text(fights_with.stats)
	live.visible = false
	recent.visible = false
	_column.remove_child(abilities)
	abilities.free()
	abilities = UnitInfo.column(UnitInfo.lines(fights_with, ArenaView.label_for(fights_with, content), content))
	_column.add_child(abilities)
	_column.move_child(abilities, live.get_index() + 1)
	visible = true


## The tactic it took (`options`: the ones it could take; `chosen`: its id,
## "": none). It can't be changed in a fight.
func show_tactics(options: Array[TacticDef], chosen: String) -> void:
	tactic_box.show_tactics(options, chosen, false)
## Its numbers now and its last log lines, in a fight.
func show_live(unit: UnitState, lines: Array[String]) -> void:
	live.text = UnitInfo.live_text(unit)
	live.visible = true
	recent.text = "Last in the log:\n" + "\n".join(lines) if not lines.is_empty() else ""
	recent.visible = not lines.is_empty()


func close() -> void:
	showing = ""
	visible = false
