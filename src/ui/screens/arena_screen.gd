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
##     with keys Space, 1-3, and S. Place again goes back to placement with
##     the same formation.
##   - The result (section 1), in place of the controls when the fight ends:
##     the outcome and length, the seed, how each hero came out, and the
##     fight chart; Rematch fights the same placement with the next seed, and
##     Watch again replays this one. Back returns to the encounter list.
##   - The layout: the board in the middle of the screen, heroes at the
##     bottom (ArenaView; phase 5b), with an empty gutter on
##     its left as wide as the side column on its right, so it stays
##     centered, and at the screen's full height. The side column holds the
##     encounter's name and the hint, the enemy panel, the controls, and, in
##     the fight, the fight chart (section 6).
##   - The combat log is a popup over the gutter, opened and closed with its
##     button or L (remembered in the session; closed at first). Clicking a
##     unit filters the log to it. Banners over the board for a phase, the
##     collapse, and the end.
##   - Unit details (section 7, Decision 3): hovering an enemy fills the side
##     panel, at any time (with its numbers now, in a fight); clicking a hero
##     while the fight isn't playing (placement, paused, or over) opens its
##     popup beside it, which a click elsewhere closes, and so does the fight
##     playing on.
##   - Tactics (docs/plans/rebuild-phase3b-tactics.md, section 4): while
##     placing, the hero popup's Tactic row sets the hero's tactic in the
##     session (the board shows it under the hero's name); in a fight it
##     names the one taken, and so does the result.
##   - Paths (docs/plans/rebuild-phase4-paths.md, section 6): clicking a hero
##     while placing opens the hero panel (HeroPanel) instead of the popup:
##     its Path tab vows or transforms the hero, its Loadout tab sets the
##     tactic, both kept in the session. A transformed Trapper's snares are
##     dragged like heroes, and the sim decides what's legal. The result
##     names each hero's path and what the fight put into each deed (the
##     panel shows it too).

signal fight_requested(setup: FightSetup)
signal back_requested
## A run's fight is over and Continue was pressed (phase 5): Main records it.
signal run_fight_done(formation: Dictionary[String, Vector2i], result: FightResult)

const SIDE_WIDTH: int = 380
## The log popup's widest (it reaches past the gutter into the board's
## margin, but never onto the board: _fit_log_popup).
const LOG_WIDTH: int = 480
const FIGHT_HINT: String = "Space pauses, 1-3 set the speed, S skips to the end, L shows the log, T shows every target line. Hover an enemy to read it; click a unit to see only its lines in the log, or pause and click a hero to read them."

var session: PracticeSession
## The run's session when this is a run's fight (null in Practice): the top
## bar is the run's, the result has Continue instead of Rematch, and the
## fight can't be fought again.
var run_session: RunSession = null
var encounter: EncounterDef
var formation: Dictionary[String, Vector2i] = {}
var view: ArenaView
var enemy_panel: EnemyPanel
var hero_popup: HeroPopup
var hero_panel: HeroPanel
## The hero bar along the bottom (the playtester's mock): clicking a hero's
## card opens its panel.
var hero_bar: HeroBar
var seed_label: Label
var fight_button: Button
var error_label: Label
var hint_label: Label
## Set while the fight is on screen (placement: null).
var player: FightPlayer = null
var clock_label: Label
var outcome_label: Label
## The result, shown when the fight ends in place of the controls.
var result_box: VBoxContainer
var result_details: Label
var result_chart: FightChart
var _controls_box: VBoxContainer
var _result_shown: bool = false
var pause_button: Button
var speed_buttons: Array[Button] = []
var target_lines: CheckButton
## The combo readout (for testing only, phase 5c step 9a; part 7, section
## 7): its toggle, what it shows under the chart, and its counts.
var combo_toggle: CheckButton
var combo_readout: Label
var combo: ComboTally
var log_button: Button
## The fight chart, in the side column during the fight.
var chart: FightChart
## The combat log's popup, over the gutter left of the board.
var log_popup: PanelContainer
var log_panel: LogPanel
var banners: FightBanners
var names: FightNames
var tally: FightTally
var _placement_box: VBoxContainer
var _fight_box: VBoxContainer
var _back_button: Button
var _again_row: HBoxContainer
var _place_again: Button


static func make(practice: PracticeSession, encounter_id: String) -> ArenaScreen:
	var screen := ArenaScreen.new()
	screen.session = practice
	screen.run_session = practice as RunSession
	screen.encounter = practice.content.encounters[encounter_id]
	screen.full_bleed = true
	screen.formation = practice.formation_for(encounter_id)
	practice.fit_snares(encounter_id, screen.formation)
	return screen


func build() -> void:
	shows_backdrop = false
	add_theme_constant_override("separation", 0)
	# Above the hero bar: the top bar and the screen, with the hero panel
	# over both when it's open.
	var upper := Control.new()
	upper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(upper)
	# The rift's sky behind everything above the hero bar (phase 5b).
	var sky := TextureRect.new()
	sky.texture = ArenaView.art(ArenaView.ART_DIR + "backdrop.svg")
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upper.add_child(sky)
	var upper_column := VBoxContainer.new()
	upper_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upper_column.add_theme_constant_override("separation", 0)
	upper.add_child(upper_column)
	upper_column.add_child(_build_top_bar())
	var body := MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 16)
	upper_column.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	# As wide as the side column, so the board sits in the middle of the
	# screen; the log pops up over it.
	var gutter := Control.new()
	gutter.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gutter)
	view = ArenaView.new()
	view.custom_minimum_size = Vector2(600, 600)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(view)
	# The side column scrolls if it's taller than the room above the hero bar.
	# On a navy panel, so it reads over the sky.
	var side_panel := PanelContainer.new()
	side_panel.add_theme_stylebox_override("panel", UiStyle.box(Color(UiStyle.NAVY_900, 0.88), Color(UiStyle.LINE_500, 0.6), 1, 12))
	row.add_child(side_panel)
	var side_scroll := ScrollContainer.new()
	side_scroll.custom_minimum_size = Vector2(SIDE_WIDTH + 12, 0)
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_panel.add_child(side_scroll)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	side.add_theme_constant_override("separation", 12)
	side_scroll.add_child(side)
	# The name and the hint go at the top of the side column, so the board
	# has the screen's whole height.
	side.add_child(UiStyle.heading(encounter.name, 30))
	hint_label = UiStyle.label(placement_hint(), 15, UiStyle.TEXT_DIM)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(hint_label)
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
	_back_button = UiStyle.button("Back to the day" if run_session != null else "Back", func() -> void: back_requested.emit())
	side.add_child(_back_button)
	log_popup = _build_log_popup()
	gutter.add_child(log_popup)
	view.resized.connect(_fit_log_popup)
	banners = FightBanners.make()
	banners.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banners.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banners.position.y = 24
	banners.z_index = 2
	view.add_child(banners)
	hero_popup = HeroPopup.make()
	hero_popup.z_index = 3
	view.add_child(hero_popup)
	set_process(false)
	view.hero_dropped.connect(move_hero)
	view.unit_hovered.connect(_on_hovered)
	view.unit_unhovered.connect(_on_unhovered)
	view.unit_clicked.connect(_on_clicked)
	view.ground_clicked.connect(hero_popup.close)
	# Its wrapped lines only know their height once laid out: place it again
	# then.
	hero_popup.minimum_size_changed.connect(_place_popup, CONNECT_DEFERRED)
	view.snare_dropped.connect(move_snare)
	view.hex_clicked.connect(_place_rock)
	hero_panel = HeroPanel.make(session)
	hero_panel.z_index = 5
	upper.add_child(hero_panel)
	hero_bar = HeroBar.make(session)
	add_child(hero_bar)
	hero_bar.card_clicked.connect(open_panel)
	hero_panel.closed.connect(func() -> void: hero_bar.select(""))
	# Deferred: choosing rebuilds the panel, buttons and all, so not while
	# the pressed button is still sending its signal.
	hero_panel.path_chosen.connect(choose_path, CONNECT_DEFERRED)
	hero_panel.tactic_chosen.connect(choose_tactic, CONNECT_DEFERRED)
	_show()


## Moves a hero to a hex if the result is legal. Returns true if it moved.
func placement_hint() -> String:
	if run_session != null:
		var dig_in: String = " Dig In: click a hex of your zone for your rock." if run_session.state().dig_in and run_session.state().hunt.is_empty() else ""
		return "It tests %s. Drag your heroes onto your side's hexes, then Fight. Hover an enemy to read it; click a hero's card below to read them.%s" % [encounter.tests, dig_in]
	return "It tests %s. Drag your heroes onto your side's hexes, then Fight. Hover an enemy to read it; click a hero's card below to choose their path and tactic." % encounter.tests


## Dig In (a run): a click on a hex of the heroes' zone sets the rock there.
func _place_rock(hex: Vector2i) -> void:
	if run_session == null or player != null or not run_session.state().dig_in or not run_session.state().hunt.is_empty():
		return
	if not run_session.act(run_session.flow.place_rock.bind(hex)).is_empty():
		view.flash_hex(hex)
	_show()


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


## Moves one of a hero's placed snares to a hex if the result is legal.
## Returns true if it moved.
func move_snare(hero_id: String, index: int, hex: Vector2i) -> bool:
	if player != null or not session.move_snare(encounter.id, formation, hero_id, index, hex):
		view.flash_hex(hex)
		return false
	_show()
	return true


func current_setup() -> FightSetup:
	return session.setup(encounter.id, formation, session.seed_value)


## The top bar, as in the mock: where you are on the left in gold (here,
## Practice and the encounter), and the seed on the right.
func _build_top_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	var style: StyleBoxFlat = UiStyle.box(UiStyle.NAVY_900, UiStyle.NAVY_900, 0, 0)
	style.border_color = Color("121a21")
	style.border_width_bottom = 2
	style.content_margin_left = 38
	style.content_margin_right = 38
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	bar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	bar.add_child(row)
	if run_session != null:
		RunDayScreen.fill_top_bar(row, run_session, encounter.name)
	else:
		row.add_child(UiStyle.heading("Practice", 34, UiStyle.HIGHLIGHT))
		var where: Label = UiStyle.label("Act %d · %s" % [encounter.act, encounter.name], 20, UiStyle.TEXT_DIM)
		where.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(where)
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(gap)
	seed_label = UiStyle.label("", 18, UiStyle.TEXT_DIM)
	seed_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(seed_label)
	return bar


## Opens a hero's panel from its card in the hero bar (clicking it again
## closes it). In a fight it pauses first, and the panel is for reading.
func open_panel(hero_id: String) -> void:
	if hero_panel.visible and hero_panel.showing == hero_id:
		hero_panel.close()
		return
	if playing():
		toggle_pause()
	hero_popup.close()
	hero_panel.editable = player == null and run_session == null
	hero_panel.open(hero_id)
	hero_bar.select(hero_id)


func _show() -> void:
	view.show_setup(current_setup(), session.content)
	hero_bar.refresh()
	seed_label.text = "Seed %d" % (current_setup().seed_value if run_session != null and current_setup() != null else session.seed_value)
	var errors: Array[String] = session.errors(encounter.id, formation)
	error_label.text = errors[0] if not errors.is_empty() else ""
	fight_button.disabled = not errors.is_empty()


func _on_hovered(unit_id: String) -> void:
	var kit_id: String = _kit_of(unit_id)
	if session.content.enemies.has(kit_id):
		enemy_panel.show_enemy(unit_id, session.content.enemies[kit_id], session.content)
		_show_live()


## The kit a unit on the board is: from the fight when there is one (so
## summons count), else from the placement.
func _kit_of(unit_id: String) -> String:
	if player != null:
		var unit: UnitState = player.sim.unit_by_id(unit_id)
		return unit.def.id if unit != null else ""
	for placed: UnitSetup in current_setup().units():
		if placed.id == unit_id:
			return placed.def.id
	return ""


## Whether the fight is on screen and moving (not paused, not over).
func playing() -> bool:
	return player != null and not player.paused and not player.finished()


## Opens a hero's panel while placing (as its card in the hero bar does), or
## its popup beside its token in a fight.
func open_hero(unit_id: String) -> void:
	var hero_id: String = _kit_of(unit_id)
	if player == null:
		open_panel(hero_id)
		return
	var placed: UnitSetup = null
	for hero: UnitSetup in player.setup.heroes:
		if hero.id == unit_id:
			placed = hero
	hero_popup.show_hero(session.content.heroes[hero_id], session.content, placed.def, placed.path, placed.stage)
	# The fight's tactic: it can't change mid-fight.
	hero_popup.show_tactics(session.tactics_for(hero_id), placed.tactic.id if placed.tactic != null else "")
	hero_popup.set_meta("unit_id", unit_id)
	_show_live()
	_place_popup()


## Beside its hero: to the right, or to the left near the board's right
## edge (a hero who walked there in the fight), and kept on the board.
func _place_popup() -> void:
	if not hero_popup.visible:
		return
	hero_popup.reset_size()
	var hero_token: UnitToken = view.token(hero_popup.get_meta("unit_id"))
	var beside: Rect2 = hero_token.get_rect()
	var at: Vector2 = Vector2(beside.end.x + 12.0, beside.position.y)
	if at.x + hero_popup.size.x > view.size.x:
		at.x = beside.position.x - 12.0 - hero_popup.size.x
	at.x = clampf(at.x, 0.0, maxf(view.size.x - hero_popup.size.x, 0.0))
	at.y = clampf(at.y, 0.0, maxf(view.size.y - hero_popup.size.y, 0.0))
	hero_popup.position = at


## The shown enemy's and hero's numbers now, in a fight.
func _show_live() -> void:
	if player == null:
		return
	if not enemy_panel.showing.is_empty():
		enemy_panel.show_live(player.sim.unit_by_id(enemy_panel.showing))
	if hero_popup.visible:
		var hero_id: String = hero_popup.get_meta("unit_id")
		hero_popup.show_live(player.sim.unit_by_id(hero_id), UnitInfo.recent_lines(hero_id, player.sim.combat_log, names))


func _on_unhovered(unit_id: String) -> void:
	if not enemy_panel.showing.is_empty() and view.token(unit_id) != null and not view.token(unit_id).is_hero():
		enemy_panel.clear()


## Clicking a unit during the fight filters the log to it; clicking a hero
## while the fight is paused or over opens its popup (anything else closes
## it). While placing, a hero's panel opens from the hero bar, not the board.
func _on_clicked(unit_id: String) -> void:
	if player != null:
		log_panel.filter_to(unit_id)
	if player != null and not playing() and session.content.heroes.has(_kit_of(unit_id)):
		open_hero(unit_id)
	else:
		hero_popup.close()


## Sets a hero's tactic while placing ("": none), and shows it.
func choose_tactic(hero_id: String, tactic_id: String) -> void:
	if player != null:
		return
	session.set_tactic(hero_id, tactic_id)
	_show()
	if hero_panel.visible and hero_panel.showing == hero_id:
		hero_panel.show_hero(hero_id)
		hero_bar.select(hero_id)


## Puts a hero on a path at a stage while placing (base: no path), and
## shows it.
func choose_path(hero_id: String, path_id: String, stage: PathDef.Stage) -> void:
	if player != null:
		return
	session.set_path(hero_id, path_id, stage)
	session.fit_snares(encounter.id, formation)
	_show()
	if hero_panel.visible and hero_panel.showing == hero_id:
		hero_panel.show_hero(hero_id)


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
	_controls_box = VBoxContainer.new()
	_controls_box.add_theme_constant_override("separation", 10)
	box.add_child(_controls_box)
	var speeds := HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 6)
	_controls_box.add_child(speeds)
	pause_button = UiStyle.button("Pause", toggle_pause)
	speeds.add_child(pause_button)
	for speed: float in FightPlayer.SPEEDS:
		var button: Button = UiStyle.button(speed_text(speed), set_speed.bind(speed))
		button.toggle_mode = true
		speed_buttons.append(button)
		speeds.add_child(button)
	var jumps := HBoxContainer.new()
	jumps.add_theme_constant_override("separation", 6)
	_controls_box.add_child(jumps)
	jumps.add_child(UiStyle.button("Skip to end", skip))
	jumps.add_child(UiStyle.button("Restart", restart))
	target_lines = CheckButton.new()
	target_lines.text = "Target lines (for testing)"
	target_lines.toggled.connect(func(on: bool) -> void: view.fx.all_targets = on)
	_controls_box.add_child(target_lines)
	combo_toggle = CheckButton.new()
	combo_toggle.text = "Combo readout (for testing)"
	combo_toggle.toggled.connect(set_combo_readout)
	_controls_box.add_child(combo_toggle)
	chart = FightChart.make(null)
	_controls_box.add_child(chart)
	combo_readout = UiStyle.label("", 14, UiStyle.TEXT_DIM)
	combo_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	combo_readout.visible = false
	_controls_box.add_child(combo_readout)
	result_box = VBoxContainer.new()
	result_box.add_theme_constant_override("separation", 10)
	result_box.visible = false
	box.add_child(result_box)
	outcome_label = UiStyle.label("", 28, UiStyle.HIGHLIGHT)
	outcome_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_box.add_child(outcome_label)
	result_details = UiStyle.label("", 16, UiStyle.TEXT)
	result_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_box.add_child(result_details)
	result_chart = FightChart.make(null)
	result_box.add_child(result_chart)
	var again := HBoxContainer.new()
	again.add_theme_constant_override("separation", 6)
	result_box.add_child(again)
	if run_session != null:
		again.add_child(UiStyle.primary(UiStyle.button("Continue", continue_run)))
	else:
		again.add_child(UiStyle.primary(UiStyle.button("Rematch", rematch)))
	again.add_child(UiStyle.button("Watch again", restart))
	_again_row = again
	var more := HBoxContainer.new()
	more.add_theme_constant_override("separation", 6)
	box.add_child(more)
	log_button = UiStyle.button("Combat log (L)", func() -> void: pass)
	log_button.toggle_mode = true
	log_button.toggled.connect(set_log_open)
	more.add_child(log_button)
	_place_again = UiStyle.button("Place again", place_again)
	_place_again.visible = run_session == null
	more.add_child(_place_again)
	return box


## The combat log's popup: the log, and a button that closes it. It fills
## the gutter's height.
func _build_log_popup() -> PanelContainer:
	var popup := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiStyle.NAVY_800, 0.97)
	style.border_color = UiStyle.LINE_500
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10.0)
	popup.add_theme_stylebox_override("panel", style)
	popup.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	popup.offset_right = LOG_WIDTH
	popup.z_index = 4
	popup.visible = false
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	popup.add_child(column)
	log_panel = LogPanel.make()
	column.add_child(log_panel)
	var close := UiStyle.button("Close", set_log_open.bind(false))
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(close)
	return popup


## "0.5x", "1x", "2x".
static func speed_text(speed: float) -> String:
	return ("%sx" % str(speed)).replace(".0x", "x")


## Plays `fight_setup` on the board, at the session's speed.
func start_fight(fight_setup: FightSetup) -> void:
	player = FightPlayer.make(fight_setup, session.content)
	player.speed = session.speed
	hero_panel.close()
	seed_label.text = "Seed %d" % fight_setup.seed_value
	view.set_mode(ArenaView.Mode.FIGHT)
	hint_label.text = FIGHT_HINT
	_placement_box.visible = false
	_fight_box.visible = true
	# A run's fight is fought once: no way back to placement.
	_back_button.visible = run_session == null
	set_log_open(session.log_open)
	_begin()
	_refresh_controls()
	set_process(true)


## The fight from its start (a new fight, or a restart): names, the chart's
## tally, and the log start over with the lines logged so far.
func _begin() -> void:
	names = FightNames.make(player.sim, session.content)
	tally = FightTally.make(player.setup, names.names)
	chart.set_tally(tally)
	var hero_ids: Array[String] = []
	for unit: UnitSetup in player.setup.heroes:
		hero_ids.append(unit.id)
	combo = ComboTally.of_log(CombatLog.new(), session.content.tuning.chain_limit, hero_ids)
	log_panel.start(names)
	banners.clear()
	banners.speed = player.speed
	view.fx.clear()
	outcome_label.text = ""
	_result_shown = false
	player.take_new()
	var so_far: Array[LogEntry] = []
	so_far.assign(player.sim.combat_log.entries)
	_on_entries(so_far)
	_on_frame()


## Hands log entries on: to the board's effects, the chart's tally, the log,
## and the banners (after a skip, only the last banner).
func _on_entries(entries: Array[LogEntry]) -> void:
	if entries.is_empty():
		return
	names.learn(player.sim)
	view.fx.add_entries(entries, player)
	var skipped: bool = entries.size() > FightFx.MAX_ANIMATED
	var last_banner: String = ""
	combo.add_all(entries)
	for entry: LogEntry in entries:
		tally.add(entry)
		var banner: String = FightBanners.text_for(entry, names)
		if not skipped:
			banners.push(banner)
		elif not banner.is_empty():
			last_banner = banner
	if skipped:
		banners.clear()
		banners.push(last_banner)
	log_panel.add(entries)
	if chart.is_visible_in_tree():
		chart.refresh()
	if combo_readout.visible:
		_refresh_combo()


## Shows or hides the combo readout (for testing): the engines under the
## chart, and the damage rule's notes in the log.
func set_combo_readout(on: bool) -> void:
	combo_toggle.set_pressed_no_signal(on)
	combo_readout.visible = on
	log_panel.set_show_rule(on)
	if on and combo != null:
		_refresh_combo()


func _refresh_combo() -> void:
	var tallies: Array[FightResult.Deed] = []
	if player.sim.finished:
		tallies = CombatSim.result_of(player.sim).tallies
	combo_readout.text = combo_text(combo, names, tallies, _growth_label)


## A growing card's name and step size from its tally key ("upgrade:<id>",
## "relic:<id>"), or "" for one that isn't a growing card (a run's).
func _growth_label(key: String) -> String:
	var run_session := session as RunSession
	if run_session == null:
		return ""
	var id: String = key.get_slice(":", 1)
	var grows: GrowthDef = null
	var label: String = ""
	if key.begins_with("upgrade:") and run_session.run.upgrades.has(id):
		grows = run_session.run.upgrades[id].grows
		label = run_session.run.upgrades[id].name
	elif key.begins_with("relic:") and run_session.run.relics.has(id):
		grows = run_session.run.relics[id].grows
		label = run_session.run.relics[id].name
	return "" if grows == null else "%s (a step is %d)" % [label, grows.per]


## The readout's text: the fight's chains at the limit; each hero's engines
## (fires, from chains, deepest, what they added), the most first; then,
## once it's over, each growing card's count this fight (snowball tags).
static func combo_text(combo_tally: ComboTally, fight_names: FightNames, tallies: Array[FightResult.Deed], growth_label: Callable) -> String:
	var lines: Array[String] = ["Combos (for testing): %d at the chain limit" % combo_tally.at_limit]
	for engine: ComboTally.EngineRow in combo_tally.hero_engines():
		var engine_name: String = engine.name
		if not engine.unit_id.is_empty():
			engine_name = engine_name.replace(engine.unit_id, fight_names.name_of(engine.unit_id))
		var added: Array[String] = []
		for part: Array in [[engine.damage, "dmg"], [engine.healing, "heal"], [engine.shield, "shield"]]:
			if int(part[0]) > 0:
				added.append("%d %s" % [part[0], part[1]])
		lines.append("%s: %d fires, %d from chains, deepest %d%s" % [engine_name, engine.fires, engine.from_chains, engine.deepest,
			(" · " + ", ".join(added)) if not added.is_empty() else ""])
	for tally: FightResult.Deed in tallies:
		var label: String = growth_label.call(tally.path)
		if not label.is_empty():
			lines.append("Snowball: %s, %s +%d this fight" % [fight_names.name_of(tally.hero), label, tally.amount])
	return "\n".join(lines)


## Opens or closes the combat log's popup (remembered in the session).
func set_log_open(open: bool) -> void:
	session.log_open = open
	log_popup.visible = open and player != null
	log_button.set_pressed_no_signal(open)
	_fit_log_popup()


## As wide as LOG_WIDTH, or as the room left of the board if that's less
## (never narrower than the gutter).
func _fit_log_popup() -> void:
	var gutter: Control = log_popup.get_parent() as Control
	var board_left: float = view.position.x - gutter.position.x + view.to_pixel(view.drawn_rect.position).x
	log_popup.offset_right = clampf(board_left - 8.0, gutter.size.x, LOG_WIDTH)


func toggle_pause() -> void:
	if player == null:
		return
	player.paused = not player.paused
	_refresh_controls()


func set_speed(speed: float) -> void:
	session.speed = speed
	banners.speed = speed
	if player != null:
		player.speed = speed
	_refresh_controls()


func skip() -> void:
	if player == null:
		return
	_on_entries(player.skip_to_end())
	_on_frame()


## A run's fight is over: hands its result on (it's exactly RunFlow's
## fight, played tick by tick).
func continue_run() -> void:
	if run_session == null or player == null or not player.finished():
		return
	set_process(false)
	run_fight_done.emit(formation.duplicate(), CombatSim.result_of(player.sim))


## The same placement again, with the next seed (seeds only change crits).
func rematch() -> void:
	session.seed_value += 1
	start_fight(current_setup())


func restart() -> void:
	if player == null:
		return
	player.restart()
	_begin()


## Back to placement with the same formation.
func place_again() -> void:
	player = null
	set_process(false)
	view.set_mode(ArenaView.Mode.PLACEMENT)
	hint_label.text = placement_hint()
	_fight_box.visible = false
	_placement_box.visible = true
	log_popup.visible = false
	banners.clear()
	hero_popup.close()
	hero_panel.close()
	enemy_panel.clear()
	_show()


func _process(delta: float) -> void:
	if player == null:
		return
	if not player.paused:
		banners.advance(delta)
	_on_entries(player.advance(delta))
	_on_frame()


## Draws the fight as it stands.
func _on_frame() -> void:
	view.sync_fight(player)
	hero_bar.refresh(player.sim)
	if playing():
		hero_popup.close()
		hero_panel.close()
	_show_live()
	clock_label.text = "%.1fs" % player.fight_seconds()
	_controls_box.visible = not player.finished()
	result_box.visible = player.finished()
	if player.finished() and not _result_shown:
		_show_result()


## Fills in the result once the fight is over.
func _show_result() -> void:
	_result_shown = true
	outcome_label.text = outcome_text(player.sim.outcome, player.fight_seconds())
	result_details.text = result_text(player.sim, names)
	session.remember_deeds(player.sim)
	result_chart.set_tally(tally)


## "Seed 2 (it only changes crits)", then how each hero came out:
## "Brannoc 120/420 HP · Maren fell · Vell 300/300 HP", then the paths and
## tactics taken, if any: "Paths: Maren, Deadeye (vowed)", "Tactics: Maren,
## Hold your ground", then, for each hero on a path, what the fight put into
## its three deeds, the vowed path first: "Maren: Deadeye 1,240 · Trapper
## 0.0s · Volley 35" (the hero panel shows every hero's).
static func result_text(sim: CombatSim, fight_names: FightNames) -> String:
	var heroes: Array[String] = []
	var paths: Array[String] = []
	var tactics: Array[String] = []
	var deeds: Array[String] = []
	var amounts: Array[FightResult.Deed] = sim.deed_amounts()
	for i: int in sim.heroes.size():
		var hero: UnitState = sim.heroes[i]
		var placed: UnitSetup = sim.setup.heroes[i]
		var hero_name: String = fight_names.name_of(hero.id)
		heroes.append("%s %s" % [hero_name, "%d/%d HP" % [hero.hp, hero.max_hp] if hero.alive else "fell"])
		if placed.path != null:
			paths.append("%s, %s (%s)" % [hero_name, placed.path.name, PathDef.STAGE_NAMES[placed.stage]])
		if hero.tactic != null:
			tactics.append("%s, %s" % [hero_name, hero.tactic.name])
		var order: Array[PathDef] = placed.deed_paths.duplicate()
		if placed.path != null and order.has(placed.path):
			order.erase(placed.path)
			order.push_front(placed.path)
		var parts: Array[String] = []
		for path: PathDef in order:
			var amount: int = 0
			for deed: FightResult.Deed in amounts:
				if deed.hero == hero.id and deed.path == path.id:
					amount = deed.amount
			parts.append("%s %s" % [path.name, UnitInfo.deed_amount_text(path.deed, amount)])
		if placed.path != null and not parts.is_empty():
			deeds.append("%s: %s" % [hero_name, " · ".join(parts)])
	var text: String = "Seed %d (it only changes crits)\n%s" % [sim.setup.seed_value, " · ".join(heroes)]
	text += "\nPaths: %s" % " · ".join(paths) if not paths.is_empty() else ""
	text += "\nTactics: %s" % " · ".join(tactics) if not tactics.is_empty() else ""
	return text + ("\nDeeds this fight:\n%s" % "\n".join(deeds) if not deeds.is_empty() else "")


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
		KEY_T:
			target_lines.button_pressed = not target_lines.button_pressed
		KEY_L:
			set_log_open(not log_popup.visible)
		_:
			return
	get_viewport().set_input_as_handled()
