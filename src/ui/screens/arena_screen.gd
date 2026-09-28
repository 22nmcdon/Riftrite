class_name ArenaScreen
extends UiScreen
## Placement and the fight on one screen (docs/plans/rebuild-phase3-fight-sandbox.md,
## sections 1, 3, and 4): placement (dragging heroes, the enemy panel on
## hover, Fight), then the fight played live by a FightPlayer on the same
## board.
##   - A move is tried on a copy of the formation and kept only if the sim
##     finds the result legal (PracticeSession.errors); otherwise the hex
##     flashes. Dropping a hero on another swaps them.
##   - Fight remembers the formation for the session (Decision 4) and starts
##     the fight at once, at the session's speed (Decision 2).
##   - During the fight: pause, 0.5x, 1x, 2x, skip to the end, and restart,
##     with keys Space, 1-3, and S. At the end, the outcome, and Place again
##     goes back to placement with the same formation.

signal fight_requested(setup: FightSetup)
signal back_requested

const SIDE_WIDTH: int = 380
const FIGHT_HINT: String = "Space pauses, 1-3 set the speed, S skips to the end. Hover an enemy to read it."

var session: PracticeSession
var encounter: EncounterDef
var formation: Dictionary[String, Vector2i] = {}
var view: ArenaView
var enemy_panel: EnemyPanel
var fight_button: Button
var error_label: Label
var hint_label: Label
## Set while the fight is on screen (placement: null).
var player: FightPlayer = null
var clock_label: Label
var outcome_label: Label
var pause_button: Button
var speed_buttons: Array[Button] = []
var _placement_box: VBoxContainer
var _fight_box: VBoxContainer


static func make(practice: PracticeSession, encounter_id: String) -> ArenaScreen:
	var screen := ArenaScreen.new()
	screen.session = practice
	screen.encounter = practice.content.encounters[encounter_id]
	screen.formation = practice.formation_for(encounter_id)
	return screen


func build() -> void:
	shows_backdrop = false
	heading(encounter.name)
	hint_label = UiStyle.label(placement_hint(), 16, UiStyle.TEXT_DIM)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint_label)
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
	_placement_box = VBoxContainer.new()
	_placement_box.add_theme_constant_override("separation", 12)
	side.add_child(_placement_box)
	error_label = UiStyle.label("", 16, UiStyle.BAD)
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_placement_box.add_child(error_label)
	fight_button = primary_button("Fight", _fight, SIDE_WIDTH)
	_placement_box.add_child(fight_button)
	_fight_box = _build_fight_box()
	_fight_box.visible = false
	side.add_child(_fight_box)
	side.add_child(UiStyle.button("Back", func() -> void: back_requested.emit()))
	set_process(false)
	view.hero_dropped.connect(move_hero)
	view.unit_hovered.connect(_on_hovered)
	view.unit_unhovered.connect(_on_unhovered)
	_show()


## Moves a hero to a hex if the result is legal. Returns true if it moved.
func placement_hint() -> String:
	return "It tests %s. Drag your heroes onto your side's hexes, then Fight. Hover an enemy to read it." % encounter.tests


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
	var fight_setup: FightSetup = current_setup()
	fight_requested.emit(fight_setup)
	start_fight(fight_setup)


# --- the fight ------------------------------------------------------------------

func _build_fight_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	clock_label = UiStyle.label("0.0s", 28, UiStyle.TEXT)
	box.add_child(clock_label)
	var speeds := HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 6)
	box.add_child(speeds)
	pause_button = UiStyle.button("Pause", toggle_pause)
	speeds.add_child(pause_button)
	for speed: float in FightPlayer.SPEEDS:
		var button: Button = UiStyle.button(speed_text(speed), set_speed.bind(speed))
		button.toggle_mode = true
		speed_buttons.append(button)
		speeds.add_child(button)
	var jumps := HBoxContainer.new()
	jumps.add_theme_constant_override("separation", 6)
	box.add_child(jumps)
	jumps.add_child(UiStyle.button("Skip to end", skip))
	jumps.add_child(UiStyle.button("Restart", restart))
	outcome_label = UiStyle.label("", 24, UiStyle.HIGHLIGHT)
	outcome_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(outcome_label)
	box.add_child(UiStyle.button("Place again", place_again))
	return box


## "0.5x", "1x", "2x".
static func speed_text(speed: float) -> String:
	return ("%sx" % str(speed)).replace(".0x", "x")


## Plays `fight_setup` on the board, at the session's speed.
func start_fight(fight_setup: FightSetup) -> void:
	player = FightPlayer.make(fight_setup, session.content)
	player.speed = session.speed
	view.fx.add_entries(player.take_new(), player)
	view.set_mode(ArenaView.Mode.FIGHT)
	hint_label.text = FIGHT_HINT
	_placement_box.visible = false
	_fight_box.visible = true
	outcome_label.text = ""
	_refresh_controls()
	_on_frame()
	set_process(true)


func toggle_pause() -> void:
	if player == null:
		return
	player.paused = not player.paused
	_refresh_controls()


func set_speed(speed: float) -> void:
	session.speed = speed
	if player != null:
		player.speed = speed
	_refresh_controls()


func skip() -> void:
	if player == null:
		return
	view.fx.add_entries(player.skip_to_end(), player)
	_on_frame()


func restart() -> void:
	if player == null:
		return
	player.restart()
	view.fx.clear()
	outcome_label.text = ""
	_on_frame()


## Back to placement with the same formation.
func place_again() -> void:
	player = null
	set_process(false)
	view.set_mode(ArenaView.Mode.PLACEMENT)
	hint_label.text = placement_hint()
	_fight_box.visible = false
	_placement_box.visible = true
	_show()


func _process(delta: float) -> void:
	if player == null:
		return
	view.fx.add_entries(player.advance(delta), player)
	_on_frame()


## Draws the fight as it stands.
func _on_frame() -> void:
	view.sync_fight(player)
	clock_label.text = "%.1fs" % player.fight_seconds()
	if player.finished():
		outcome_label.text = outcome_text(player.sim.outcome, player.fight_seconds())


static func outcome_text(outcome: FightResult.Outcome, seconds: float) -> String:
	match outcome:
		FightResult.Outcome.VICTORY:
			return "Victory in %.1fs" % seconds
		FightResult.Outcome.DEFEAT:
			return "Defeat in %.1fs" % seconds
	return "A tie at %.1fs (it counts as a win)" % seconds


func _refresh_controls() -> void:
	pause_button.text = "Play" if player != null and player.paused else "Pause"
	for i: int in speed_buttons.size():
		speed_buttons[i].set_pressed_no_signal(is_equal_approx(FightPlayer.SPEEDS[i], session.speed))


func _unhandled_input(event: InputEvent) -> void:
	if player == null or not event is InputEventKey or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	match (event as InputEventKey).keycode:
		KEY_SPACE:
			toggle_pause()
		KEY_1, KEY_2, KEY_3:
			set_speed(FightPlayer.SPEEDS[(event as InputEventKey).keycode - KEY_1])
		KEY_S:
			skip()
		_:
			return
	get_viewport().set_input_as_handled()
