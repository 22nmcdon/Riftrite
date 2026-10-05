class_name EncounterListScreen
extends UiScreen
## Practice's list of fights (docs/plans/rebuild-phase3-fight-sandbox.md,
## section 1): every encounter in encounters.json's order (Act 1's, then
## Act 2's since phase 8 part 3), a card each with its name, what it tests,
## its act (from Act 2) and days, and its enemies (how many, name,
## archetype, and threat line). Picking one goes to its placement.

signal encounter_picked(encounter_id: String)
signal back_requested

const COLUMNS: int = 3
const CARD_WIDTH: int = 580

var content: ContentDb


static func make(content_db: ContentDb) -> EncounterListScreen:
	var screen := EncounterListScreen.new()
	screen.content = content_db
	return screen


func build() -> void:
	heading("Practice")
	hint("Pick a fight. Act 2's are built for transformed heroes: transform them in their panels. Your heroes start where you last placed them.")
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	add_child(grid)
	for encounter_id: String in content.encounter_ids:
		grid.add_child(_card(content.encounters[encounter_id]))
	add_child(UiStyle.button("Back", func() -> void: back_requested.emit()))


func _card(encounter: EncounterDef) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL, UiStyle.BORDER, 2))
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)
	column.add_child(UiStyle.label(encounter.name, 24, UiStyle.HIGHLIGHT))
	var tests: Label = UiStyle.label("Tests %s · %s" % [encounter.tests, when_text(encounter)], 16, UiStyle.TEXT_DIM)
	tests.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(tests)
	for line: String in enemy_lines(encounter, content):
		var enemy: Label = UiStyle.label(line, 15, UiStyle.ENEMY_TEXT)
		enemy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(enemy)
	var pick: Button = UiStyle.primary(UiStyle.button("Place your heroes", func() -> void: encounter_picked.emit(encounter.id)))
	pick.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(pick)
	return card


## Its days, after its act from Act 2 on: "Days 1-3", "Act 2 · Days 1-2".
static func when_text(encounter: EncounterDef) -> String:
	return days_text(encounter.days) if encounter.act <= 1 else "Act %d · %s" % [encounter.act, days_text(encounter.days)]


## "Day 3", "Days 1-3", or "Days 1, 3" (not in a row).
static func days_text(days: Array[int]) -> String:
	if days.size() == 1:
		return "Day %d" % days[0]
	if days[-1] - days[0] == days.size() - 1:
		return "Days %d-%d" % [days[0], days[-1]]
	var parts: PackedStringArray = PackedStringArray()
	for day: int in days:
		parts.append(str(day))
	return "Days " + ", ".join(parts)


## One line per kind of enemy, in the order they're first placed:
## "3 × Rift Hound (flanker): Pounces on your weakest back-liner".
static func enemy_lines(encounter: EncounterDef, content_db: ContentDb) -> Array[String]:
	var order: Array[String] = []
	var counts: Dictionary[String, int] = {}
	for placed: EncounterDef.Placed in encounter.enemies:
		if not counts.has(placed.enemy):
			order.append(placed.enemy)
		counts[placed.enemy] = counts.get(placed.enemy, 0) + 1
	var lines: Array[String] = []
	for enemy_id: String in order:
		var enemy: EnemyDef = content_db.enemies[enemy_id]
		lines.append("%d × %s (%s): %s" % [counts[enemy_id], enemy.name, EnemyDef.ARCHETYPE_NAMES[enemy.archetype], enemy.threat])
	return lines
