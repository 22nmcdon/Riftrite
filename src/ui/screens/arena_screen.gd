class_name ArenaScreen
extends UiScreen
## Placement and the fight on one screen (docs/plans/rebuild-phase3-fight-sandbox.md,
## sections 1 and 3). Step 3 builds placement: the board, dragging heroes,
## the enemy panel on hover, and the Fight button; the fight itself comes
## in step 4.
##   - A move is tried on a copy of the formation and kept only if the sim
##     finds the result legal (PracticeSession.errors); otherwise the hex
##     flashes. Dropping a hero on another swaps them.
##   - Fight remembers the formation for the session (Decision 4).

signal fight_requested(setup: FightSetup)
signal back_requested

const SIDE_WIDTH: int = 380

var session: PracticeSession
var encounter: EncounterDef
var formation: Dictionary[String, Vector2i] = {}
var view: ArenaView
var enemy_panel: EnemyPanel
var fight_button: Button
var error_label: Label


static func make(practice: PracticeSession, encounter_id: String) -> ArenaScreen:
	var screen := ArenaScreen.new()
	screen.session = practice
	screen.encounter = practice.content.encounters[encounter_id]
	screen.formation = practice.formation_for(encounter_id)
	return screen


func build() -> void:
	shows_backdrop = false
	heading(encounter.name)
	hint("It tests %s. Drag your heroes onto your side's hexes, then Fight. Hover an enemy to read it." % encounter.tests)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	view = ArenaView.new()
	view.custom_minimum_size = Vector2(900, 820)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(view)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	side.add_theme_constant_override("separation", 12)
	row.add_child(side)
	enemy_panel = EnemyPanel.make()
	side.add_child(enemy_panel)
	error_label = UiStyle.label("", 16, UiStyle.BAD)
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(error_label)
	fight_button = primary_button("Fight", _fight, SIDE_WIDTH)
	side.add_child(fight_button)
	side.add_child(UiStyle.button("Back", func() -> void: back_requested.emit()))
	view.hero_dropped.connect(move_hero)
	view.unit_hovered.connect(_on_hovered)
	view.unit_unhovered.connect(_on_unhovered)
	_show()


## Moves a hero to a hex if the result is legal. Returns true if it moved.
func move_hero(hero_id: String, hex: Vector2i) -> bool:
	if formation.get(hero_id, Vector2i(-1, -1)) == hex:
		return false
	var trial: Dictionary[String, Vector2i] = PracticeSession.moved(formation, hero_id, hex)
	if not session.errors(encounter.id, trial).is_empty():
		view.flash_hex(hex)
		return false
	formation = trial
	_show()
	return true


func current_setup() -> FightSetup:
	return session.setup(encounter.id, formation)


func _show() -> void:
	view.show_setup(current_setup(), session.content)
	var errors: Array[String] = session.errors(encounter.id, formation)
	error_label.text = errors[0] if not errors.is_empty() else ""
	fight_button.disabled = not errors.is_empty()


func _on_hovered(unit_id: String) -> void:
	for placed: UnitSetup in current_setup().enemies:
		if placed.id == unit_id:
			enemy_panel.show_enemy(session.content.enemies[placed.def.id])


func _on_unhovered(unit_id: String) -> void:
	if not enemy_panel.showing.is_empty() and view.token(unit_id) != null and not view.token(unit_id).is_hero():
		enemy_panel.clear()


func _fight() -> void:
	if fight_button.disabled:
		return
	session.remember(formation)
	fight_requested.emit(current_setup())
