class_name EnemyPanel
extends PanelContainer
## The side panel for a hovered enemy (docs/plans/rebuild-phase3-fight-sandbox.md,
## section 7, Decision 3): its name, archetype, threat line, stats, and a
## line per ability (UnitInfo), in placement or during the fight. In a fight
## it also shows the unit's numbers now (show_live). With no enemy shown it
## says how to see one.

const EMPTY_TEXT: String = "Hover an enemy to read it."

var title: Label
var archetype: Label
var threat: Label
var stats: Label
var live: Label
var abilities: VBoxContainer
## The unit shown ("": none).
var showing: String = ""
var _column: VBoxContainer


static func make() -> EnemyPanel:
	var panel := EnemyPanel.new()
	panel.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL, UiStyle.BORDER, 2))
	panel.custom_minimum_size = Vector2(360, 0)
	panel._column = VBoxContainer.new()
	panel._column.add_theme_constant_override("separation", 6)
	panel.add_child(panel._column)
	panel.title = UiStyle.label("", 24, UiStyle.ENEMY_TEXT)
	panel.archetype = UiStyle.label("", 16, UiStyle.TEXT_DIM)
	panel.threat = UiStyle.label("", 18, UiStyle.TEXT)
	panel.stats = UiStyle.label("", 16, UiStyle.TEXT_DIM)
	panel.live = UiStyle.label("", 16, UiStyle.HIGHLIGHT)
	for label: Label in [panel.title, panel.archetype, panel.threat, panel.stats, panel.live]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel._column.add_child(label)
	panel.abilities = VBoxContainer.new()
	panel._column.add_child(panel.abilities)
	panel.clear()
	return panel


## Shows the enemy `unit_id` is (its kit's details).
func show_enemy(unit_id: String, enemy: EnemyDef, content: ContentDb) -> void:
	showing = unit_id
	title.text = enemy.name
	archetype.text = EnemyDef.ARCHETYPE_NAMES[enemy.archetype].capitalize()
	threat.text = enemy.threat
	stats.text = UnitInfo.stats_text(enemy.kit.stats)
	_column.remove_child(abilities)
	abilities.free()
	abilities = UnitInfo.column(UnitInfo.lines(enemy.kit, "it", content))
	_column.add_child(abilities)
	for label: Label in [archetype, threat, stats]:
		label.visible = true
	live.visible = false


## Its numbers now, in a fight (UnitInfo.live_text).
func show_live(unit: UnitState) -> void:
	live.text = UnitInfo.live_text(unit)
	live.visible = true


func clear() -> void:
	showing = ""
	title.text = EMPTY_TEXT
	for label: Label in [archetype, threat, stats, live]:
		label.visible = false
	abilities.visible = false
