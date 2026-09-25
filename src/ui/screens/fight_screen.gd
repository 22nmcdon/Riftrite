class_name FightScreen
extends UiScreen
## Before the fight: the enemy team and your guild, then "Fight!". The fight
## then plays back (a FightPlayer stepping a fresh sim from the same setup):
## enemies at the top (back row furthest), heroes at the bottom, both front
## rows meeting in the middle, the combat log beside it, and speed controls.
## At the end: the result and the damage meter, then Continue.

signal finished

## True from pressing Fight until Continue (Main leaves the screen alone).
var playing: bool = false
var player: FightPlayer
var _cards: Dictionary[String, UnitCard] = {}
var _log: RichTextLabel
var _speed_label: Label
var _end_box: VBoxContainer
var _shown_end: bool = false


func build() -> void:
	heading("Today's fight: " + session.content.encounters[session.state.encounter_id].name)
	var enemies := HBoxContainer.new()
	for unit: UnitSetup in SetupBuilder.encounter_units(session.content, session.state.encounter_id):
		var card := PanelContainer.new()
		var box := VBoxContainer.new()
		card.add_child(box)
		box.add_child(UiStyle.label("%s (%s row)" % [unit.name, EncounterDef.ROW_NAMES[unit.row]], 15))
		box.add_child(UiStyle.label("HP %d" % unit.stats.get_stat(UnitStats.Stat.HP), 13, UiStyle.TEXT_DIM))
		for item: ItemSetup in unit.items:
			box.add_child(UiStyle.label("· " + item.def.name, 13, UiStyle.TEXT_DIM))
		enemies.add_child(card)
	add_child(enemies)
	add_child(UiStyle.button("Fight!", start_fight))
	add_child(GuildPanel.make(session))


func start_fight() -> void:
	playing = true
	var result: RunActions.Result = session.fight()
	if not result.ok:
		playing = false
		return
	for child: Node in get_children():
		child.queue_free()
	player = FightPlayer.make(session.last_setup, session.content)
	_build_playback()
	_on_entries(player.take_new())


func _build_playback() -> void:
	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main)
	var field := VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(field)
	var sim: CombatSim = player.sim
	for pair: Array in [[sim.enemies, UnitSetup.Row.BACK], [sim.enemies, UnitSetup.Row.FRONT], [sim.heroes, UnitSetup.Row.FRONT], [sim.heroes, UnitSetup.Row.BACK]]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.custom_minimum_size = Vector2(0, 150)
		for unit: UnitState in pair[0]:
			if unit.row == pair[1]:
				var card: UnitCard = UnitCard.make(unit)
				_cards[unit.id] = card
				row.add_child(card)
		field.add_child(row)
	var bench := HBoxContainer.new()
	for unit: UnitState in sim.bench:
		var card: UnitCard = UnitCard.make(unit)
		_cards[unit.id] = card
		bench.add_child(card)
	field.add_child(bench)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(560, 0)
	main.add_child(side)
	var controls := HBoxContainer.new()
	side.add_child(controls)
	controls.add_child(UiStyle.button("Pause", func() -> void: player.paused = not player.paused))
	for speed: float in FightPlayer.SPEEDS:
		controls.add_child(UiStyle.button("%sx" % String.num(speed).trim_suffix(".0"), set_speed.bind(speed)))
	controls.add_child(UiStyle.button("Skip", func() -> void: _on_entries(player.skip_to_end())))
	_speed_label = UiStyle.label("1x", 14, UiStyle.TEXT_DIM)
	controls.add_child(_speed_label)
	_log = RichTextLabel.new()
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size = Vector2(540, 560)
	side.add_child(_log)
	_end_box = VBoxContainer.new()
	side.add_child(_end_box)


func set_speed(speed: float) -> void:
	player.speed = speed
	_speed_label.text = "%sx" % String.num(speed).trim_suffix(".0")


func _process(delta: float) -> void:
	if player != null and not _shown_end:
		_on_entries(player.advance(delta))


func _on_entries(entries: Array[LogEntry]) -> void:
	for entry: LogEntry in entries:
		_log.append_text(entry.to_text() + "\n")
		if entry.kind == LogEntry.Kind.FIRE and _cards.has(entry.source_unit):
			_cards[entry.source_unit].flash(entry.source_item)
	for card: UnitCard in _cards.values():
		card.refresh()
	if player.finished() and not _shown_end:
		_show_end()


func _show_end() -> void:
	_shown_end = true
	var result: FightResult = session.last_fight
	var outcome: String = "Victory!" if result.outcome == FightResult.Outcome.VICTORY else ("A tie (counts as a victory)" if result.outcome == FightResult.Outcome.TIE else "Defeat")
	_end_box.add_child(UiStyle.label(outcome, 22, UiStyle.GOOD if result.guild_won() else UiStyle.BAD))
	var hero_ids: Array[String] = []
	for unit: UnitState in player.sim.heroes + player.sim.bench:
		hero_ids.append(unit.id)
	_end_box.add_child(DamageMeterView.make(result, hero_ids))
	_end_box.add_child(UiStyle.button("Continue", _continue))


func _continue() -> void:
	playing = false
	finished.emit()
