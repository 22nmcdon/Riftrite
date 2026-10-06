class_name EncounterListScreen
extends UiScreen
## Practice's list of fights (docs/plans/rebuild-phase3-fight-sandbox.md,
## section 1): every encounter in encounters.json's order (Act 1's, then
## Act 2's since phase 8 part 3), a card each with its name, what it tests,
## its act (from Act 2) and days, and its enemies (how many, name,
## archetype, and threat line). Picking one goes to its placement.
## Above them, the team (phase 8 part 4, Decision 6): a toggle per hero,
## three on; a hero whose paths aren't built yet fights at base.

signal encounter_picked(encounter_id: String)
signal back_requested

const COLUMNS: int = 3
const CARD_WIDTH: int = 580

var content: ContentDb
## Practice's session, whose team the row sets (none: no row).
var session: PracticeSession = null
## The heroes toggled on (the session's team once there are three).
var picked: Array[String] = []
var team_buttons: Dictionary[String, Button] = {}
var _team_note: Label
var _place_buttons: Array[Button] = []


static func make(content_db: ContentDb, practice: PracticeSession = null) -> EncounterListScreen:
	var screen := EncounterListScreen.new()
	screen.content = content_db
	screen.session = practice
	if practice != null:
		screen.picked = practice.team.duplicate()
	return screen


func build() -> void:
	heading("Practice")
	hint("Pick a fight. Act 2's are built for transformed heroes, Act 3's for heroes at an apex: set them in their panels. Your heroes start where you last placed them.")
	if session != null:
		_team_row()
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
	_place_buttons.append(pick)
	pick.disabled = picked.size() != HeroTeam.SIZE
	return card


func _team_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var title: Label = UiStyle.label("Team:", 18, UiStyle.TEXT_DIM)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	for hero_id: String in content.hero_ids:
		var button: Button = UiStyle.button(hero_id.capitalize(), toggle_hero.bind(hero_id))
		button.toggle_mode = true
		if not HeroTeam.ready(content, hero_id):
			button.tooltip_text = "%s's paths aren't built yet: they fight at base." % hero_id.capitalize()
		team_buttons[hero_id] = button
		row.add_child(button)
	_team_note = UiStyle.label("", 16, UiStyle.TEXT_DIM)
	_team_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_team_note)
	_show_team()


## Toggles `hero_id` on or off the team (on only while fewer than three are).
func toggle_hero(hero_id: String) -> void:
	if picked.has(hero_id):
		picked.erase(hero_id)
	elif picked.size() < HeroTeam.SIZE:
		picked.append(hero_id)
	if picked.size() == HeroTeam.SIZE:
		session.set_team(picked)
	_show_team()


func _show_team() -> void:
	for hero_id: String in team_buttons:
		var button: Button = team_buttons[hero_id]
		button.set_pressed_no_signal(picked.has(hero_id))
		if picked.has(hero_id):
			UiStyle.primary(button)
		else:
			UiStyle.plain(button)
		button.disabled = not picked.has(hero_id) and picked.size() >= HeroTeam.SIZE
	var at_base: Array[String] = []
	for hero_id: String in picked:
		if not HeroTeam.ready(content, hero_id):
			at_base.append(hero_id.capitalize())
	if picked.size() != HeroTeam.SIZE:
		_team_note.text = "Pick %d more." % (HeroTeam.SIZE - picked.size())
	elif not at_base.is_empty():
		_team_note.text = "%s fight%s at base: paths aren't built yet." % [" and ".join(at_base), "s" if at_base.size() == 1 else ""]
	else:
		_team_note.text = ""
	for pick: Button in _place_buttons:
		pick.disabled = picked.size() != HeroTeam.SIZE


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
