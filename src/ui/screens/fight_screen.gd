class_name FightScreen
extends UiScreen
## Before the fight: the enemy team and your guild, then "Fight!". The fight
## then plays back (a FightPlayer stepping a fresh sim from the same setup):
## enemies at the top (back row furthest), heroes at the bottom, both front
## rows meeting in the middle, the combat log beside it, and speed controls
## (keys: Space pauses, 1-4 set the speed, S skips, Enter continues at the
## end). At the end: the result and the damage meter, then Continue.

signal finished
## Playback began (Main hides the inspector).
signal started

## True from pressing Fight until Continue (Main leaves the screen alone).
var playing: bool = false
var player: FightPlayer
var names: FightNames
## Every log entry shown so far (the log view may hide item fires).
var shown: Array[LogEntry] = []
var show_fires: bool = false
var _cards: Dictionary[String, UnitCard] = {}
var _log: RichTextLabel
var _pause_button: Button
var _speed_buttons: Array[Button] = []
var _clock: Label
var _end_box: VBoxContainer
var _shown_end: bool = false
var _rift: bool = false


func build() -> void:
	_rift = session.content.encounters[session.state.encounter_id].kind != "normal"
	heading("Today's fight: " + session.content.encounters[session.state.encounter_id].name)
	hint("Last chance to arrange your guild. Hover an enemy's item to read it. During the fight: Space pauses, 1-4 set the speed, S skips to the end.")
	var enemies := HFlowContainer.new()
	enemies.add_theme_constant_override("h_separation", 10)
	for unit: UnitSetup in SetupBuilder.encounter_units(session.content, session.state.encounter_id):
		enemies.add_child(_enemy_preview(unit))
	add_child(enemies)
	var fight_button: Button = UiStyle.primary(UiStyle.button("  Fight!  ", start_fight))
	fight_button.add_theme_font_size_override("font_size", 24)
	fight_button.custom_minimum_size = Vector2(200, 56)
	add_child(fight_button)
	add_child(GuildPanel.make(session))


func _enemy_preview(unit: UnitSetup) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(260, 0)
	card.add_theme_stylebox_override("panel", UiStyle.box(Color("2a2230"), Glyph.ENEMY))
	var box := VBoxContainer.new()
	card.add_child(box)
	if _rift_fight():
		card.add_child(FrameDecor.make(0, true))
	var top := HBoxContainer.new()
	box.add_child(top)
	top.add_child(Glyph.portrait(unit.name, Glyph.ENEMY.lightened(0.25), 44))
	var names_box := VBoxContainer.new()
	top.add_child(names_box)
	names_box.add_child(UiStyle.label(unit.name, 17))
	names_box.add_child(UiStyle.label("%s row" % EncounterDef.ROW_NAMES[unit.row].capitalize(), 14, UiStyle.TEXT_DIM))
	box.add_child(UiStyle.label("HP %d  ATK %d  MGK %d  DEF %d" % [unit.stats.get_stat(UnitStats.Stat.HP), unit.stats.get_stat(UnitStats.Stat.ATK), unit.stats.get_stat(UnitStats.Stat.MGK), unit.stats.get_stat(UnitStats.Stat.DEF)], 14))
	var attack: Label = UiStyle.label("Basic attack: " + unit.basic_attack.name, 14, UiStyle.TEXT_DIM)
	box.add_child(attack)
	for item: ItemSetup in unit.items:
		var line: Label = UiStyle.label("• %s %s" % [item.def.name, TuningDef.TIER_LABELS[item.tier]], 14)
		line.mouse_filter = Control.MOUSE_FILTER_STOP
		Inspector.hover_text(line, ItemInfo.item_text(session.content, item.def.id, item.tier, item.essence_ids, 0, unit.stats))
		box.add_child(line)
	if not unit.phases.is_empty():
		var phase_names: PackedStringArray = PackedStringArray()
		for phase: PhaseDef in unit.phases:
			phase_names.append("%s (below %d%%)" % [phase.name, phase.below_hp_bp / 100])
		box.add_child(UiStyle.label("Phases: " + ", ".join(phase_names), 14, UiStyle.EMBER))
	return card


func start_fight() -> void:
	playing = true
	var result: RunActions.Result = session.fight()
	if not result.ok:
		playing = false
		return
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	player = FightPlayer.make(session.last_setup, session.content)
	names = FightNames.make(player.sim)
	started.emit()
	_build_playback()
	_on_entries(player.take_new())


func _build_playback() -> void:
	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 16)
	add_child(main)
	var field := VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_constant_override("separation", 8)
	main.add_child(field)
	if not session.last_discoveries.is_empty() or not session.last_growth.is_empty():
		field.add_child(_discovery_banner())
	var sim: CombatSim = player.sim
	var rows: Array[Array] = [
		[sim.enemies, UnitSetup.Row.BACK, "Enemy back row"], [sim.enemies, UnitSetup.Row.FRONT, "Enemy front row"],
		[sim.heroes, UnitSetup.Row.FRONT, "Your front row"], [sim.heroes, UnitSetup.Row.BACK, "Your back row"],
	]
	for i: int in rows.size():
		if i == 2:
			var divider := ColorRect.new()
			divider.color = UiStyle.EMBER.darkened(0.5)
			divider.custom_minimum_size = Vector2(0, 3)
			field.add_child(divider)
		var units: Array[UnitState] = []
		for unit: UnitState in rows[i][0]:
			if unit.row == rows[i][1]:
				units.append(unit)
		if units.is_empty():
			continue
		field.add_child(UiStyle.label(rows[i][2], 14, UiStyle.TEXT_DIM))
		field.add_child(_card_row(units))
	if not sim.bench.is_empty():
		field.add_child(UiStyle.label("In backup", 14, UiStyle.TEXT_DIM))
		field.add_child(_card_row(sim.bench))
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(600, 0)
	main.add_child(side)
	var controls := HBoxContainer.new()
	side.add_child(controls)
	_pause_button = UiStyle.button("Pause", toggle_pause)
	controls.add_child(_pause_button)
	var group := ButtonGroup.new()
	for speed: float in FightPlayer.SPEEDS:
		var button: Button = UiStyle.button("%sx" % String.num(speed).trim_suffix(".0"), set_speed.bind(speed))
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = speed == player.speed
		_speed_buttons.append(button)
		controls.add_child(button)
	controls.add_child(UiStyle.button("Skip", skip))
	_clock = UiStyle.label("0.0s", 18, UiStyle.HIGHLIGHT)
	controls.add_child(_clock)
	var fires: Button = UiStyle.button("Item fires: hidden", func() -> void: pass)
	fires.toggle_mode = true
	fires.toggled.connect(func(on: bool) -> void:
		fires.text = "Item fires: shown" if on else "Item fires: hidden"
		_set_show_fires(on))
	side.add_child(fires)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size = Vector2(580, 520)
	_log.add_theme_font_size_override("normal_font_size", 15)
	_log.add_theme_font_size_override("bold_font_size", 15)
	side.add_child(_log)
	_end_box = VBoxContainer.new()
	side.add_child(_end_box)


## "Synergy discovered!" for each synergy this fight found for the first
## time, and a line for each Legendary that grew a tier.
func _discovery_banner() -> Control:
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.OAK_600, UiStyle.BRASS_300, 3))
	var box := VBoxContainer.new()
	banner.add_child(box)
	for synergy_id: String in session.last_discoveries:
		var line: Label = UiStyle.label("✦ Synergy discovered: %s" % session.content.synergies[synergy_id].name, 20, UiStyle.BRASS_300)
		line.mouse_filter = Control.MOUSE_FILTER_STOP
		line.tooltip_text = ItemInfo.synergy_text(session.content, synergy_id)
		box.add_child(line)
	for note: String in session.last_growth:
		box.add_child(UiStyle.label("✦ %s" % note, 20, UiStyle.rarity_color("legendary").lightened(0.3)))
	return banner


func _card_row(units: Array[UnitState]) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for unit: UnitState in units:
		var card: UnitCard = UnitCard.make(unit, names.name_of(unit.id), unit.side == UnitSetup.Side.ENEMIES and _rift_fight())
		_cards[unit.id] = card
		row.add_child(card)
	return row


## Elite and boss fights carry the rift bleed on their enemies. (Read
## before the fight: afterwards the run may have moved on.)
func _rift_fight() -> bool:
	return _rift


func toggle_pause() -> void:
	player.paused = not player.paused
	_pause_button.text = "Resume" if player.paused else "Pause"


func set_speed(speed: float) -> void:
	player.speed = speed
	for i: int in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(FightPlayer.SPEEDS[i] == speed)


func skip() -> void:
	_on_entries(player.skip_to_end())


func _set_show_fires(on: bool) -> void:
	show_fires = on
	_log.clear()
	for entry: LogEntry in shown:
		_write(entry)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if player == null or key == null or not key.pressed or key.echo:
		return
	# Continue can take this screen out of the tree, so hold the viewport.
	var viewport: Viewport = get_viewport()
	match key.keycode:
		KEY_SPACE:
			toggle_pause()
		KEY_1, KEY_2, KEY_3, KEY_4:
			set_speed(FightPlayer.SPEEDS[key.keycode - KEY_1])
		KEY_S:
			skip()
		KEY_ENTER, KEY_KP_ENTER:
			if _shown_end:
				_continue()
		_:
			return
	viewport.set_input_as_handled()


func _process(delta: float) -> void:
	if player != null and not _shown_end:
		_on_entries(player.advance(delta))


func _on_entries(entries: Array[LogEntry]) -> void:
	var animate: bool = entries.size() < 40
	for entry: LogEntry in entries:
		shown.append(entry)
		_write(entry)
		if animate:
			_animate(entry)
	for card: UnitCard in _cards.values():
		card.refresh()
	_clock.text = "%.1fs" % (player.sim.tick / float(FixedMath.TICKS_PER_SECOND))
	if player.finished() and not _shown_end:
		_show_end()


func _write(entry: LogEntry) -> void:
	if entry.kind == LogEntry.Kind.FIRE and not show_fires:
		return
	_log.append_text(names.bbcode(entry) + "\n")


## Card effects for an entry: item flashes and floating numbers.
func _animate(entry: LogEntry) -> void:
	# Numbers float for less time at higher speeds, so they don't pile up.
	var seconds: float = 0.9 / maxf(player.speed, 1.0)
	match entry.kind:
		LogEntry.Kind.FIRE:
			if _cards.has(entry.source_unit):
				_cards[entry.source_unit].flash(entry.source_item)
		LogEntry.Kind.DAMAGE, LogEntry.Kind.STATUS_DAMAGE, LogEntry.Kind.COLLAPSE:
			if _cards.has(entry.target):
				_cards[entry.target].float_number(("-%d!" if entry.crit else "-%d") % entry.amount, UiStyle.BAD.lightened(0.2), seconds, entry.crit)
				_cards[entry.target].hit()
		LogEntry.Kind.HEAL:
			if _cards.has(entry.target):
				_cards[entry.target].float_number("+%d" % entry.amount, UiStyle.GOOD, seconds)
		LogEntry.Kind.SHIELD:
			if _cards.has(entry.target):
				_cards[entry.target].float_number("+%d shield" % entry.amount, UiStyle.SHIELD, seconds)


func _show_end() -> void:
	_shown_end = true
	for card: UnitCard in _cards.values():
		card.clear_floats()
	var result: FightResult = session.last_fight
	var outcome: String = "Victory!" if result.outcome == FightResult.Outcome.VICTORY else ("A tie (counts as a victory)" if result.outcome == FightResult.Outcome.TIE else "Defeat")
	_end_box.add_child(UiStyle.label(outcome, 28, UiStyle.GOOD if result.guild_won() else UiStyle.BAD))
	if not result.guild_won():
		var losses: String = "The run is over." if session.state.phase == "run_over" else "The day starts over (with bonus gold). One more loss ends the run."
		_end_box.add_child(UiStyle.label(losses, 16, UiStyle.TEXT_DIM))
	_end_box.add_child(DamageMeterView.make(result, names))
	var button: Button = UiStyle.button("Continue (Enter)", _continue)
	button.size_flags_horizontal = Control.SIZE_FILL
	button.custom_minimum_size = Vector2(0, 48)
	_end_box.add_child(button)


func _continue() -> void:
	playing = false
	finished.emit()
