class_name EnemyPanel
extends PanelContainer
## The side panel for a hovered enemy (docs/plans/rebuild-phase3-fight-sandbox.md,
## section 7, Decision 3): its name, archetype, threat line, and stats. Its
## abilities' text comes in step 7. With no enemy shown it says how to see
## one.

const EMPTY_TEXT: String = "Hover an enemy to read it."

var title: Label
var archetype: Label
var threat: Label
var stats: Label
var showing: String = ""


static func make() -> EnemyPanel:
	var panel := EnemyPanel.new()
	panel.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL, UiStyle.BORDER, 2))
	panel.custom_minimum_size = Vector2(360, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	panel.title = UiStyle.label("", 24, UiStyle.ENEMY_TEXT)
	panel.archetype = UiStyle.label("", 16, UiStyle.TEXT_DIM)
	panel.threat = UiStyle.label("", 18, UiStyle.TEXT)
	panel.stats = UiStyle.label("", 16, UiStyle.TEXT_DIM)
	for label: Label in [panel.title, panel.archetype, panel.threat, panel.stats]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(label)
	panel.clear()
	return panel


func show_enemy(enemy: EnemyDef) -> void:
	showing = enemy.id
	title.text = enemy.name
	archetype.text = EnemyDef.ARCHETYPE_NAMES[enemy.archetype].capitalize()
	threat.text = enemy.threat
	stats.text = stats_text(enemy.kit.stats)
	for label: Label in [archetype, threat, stats]:
		label.visible = true


func clear() -> void:
	showing = ""
	title.text = EMPTY_TEXT
	for label: Label in [archetype, threat, stats]:
		label.visible = false


## "HP 210 · ATK 10 · Speed 3 · Range 1": the stats a kit has (zeros left
## out, except HP and ATK).
static func stats_text(unit_stats: UnitStats) -> String:
	var parts: Array[String] = []
	for stat: int in UnitStats.Stat.size():
		var value: int = unit_stats.get_stat(stat)
		if value != 0 or stat == UnitStats.Stat.HP or stat == UnitStats.Stat.ATK:
			parts.append("%s %d" % [UnitStats.LABELS[stat], value])
	return " · ".join(parts)
