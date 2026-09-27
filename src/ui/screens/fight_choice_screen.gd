class_name FightChoiceScreen
extends UiScreen
## Pick the day's fight (docs/plans/new-day.md): a card per fight, with its
## kind's icon, its name, whether it's the easier or the harder fight (the
## harder pays more gold and has better rewards), the essence it yields, its
## enemies, and an elite's or the boss's mechanic (what it does and what
## answers it). The fight screen after the pick shows the enemies in full.


func build() -> void:
	heading("Choose the day's fight")
	hint("The harder fight pays more gold, and its spoils are rarer. A lost fight replays the day, with the same two fights to choose from.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i: int in session.state.fight_options.size():
		row.add_child(_card(i))
	add_child(row)


func _card(index: int) -> PanelContainer:
	var encounter_id: String = session.state.fight_options[index]
	var encounter: EncounterDef = session.content.encounters[encounter_id]
	var hard: bool = RunFlow.is_hard_fight(session.state, session.run, encounter_id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", UiStyle.chrome("panel_oak", 28, 28))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	column.add_child(top)
	top.add_child(UiStyle.icon(EncounterInfo.kind_icon(encounter), 72))
	var words := VBoxContainer.new()
	top.add_child(words)
	words.add_child(UiStyle.heading(encounter.name, 26, UiStyle.EMBER))
	var kind: String = "Elite, " if encounter.kind == "elite" else ""
	words.add_child(UiStyle.label(kind + ("harder" if hard else "easier"), 18, UiStyle.BAD if hard else UiStyle.GOOD))
	var essence: String = RunFlow.team_essence(session.content, encounter)
	if not essence.is_empty():
		column.add_child(UiStyle.label("Yields %s essence" % session.content.essences[essence].name, 16, UiStyle.ESSENCE.get(essence, UiStyle.TEXT)))
	if hard:
		column.add_child(UiStyle.label("More gold, and rarer spoils", 16, UiStyle.HIGHLIGHT))
	for unit: UnitSetup in SetupBuilder.encounter_units(session.content, encounter_id):
		column.add_child(UiStyle.label("• %s (%s row)" % [unit.name, EncounterDef.ROW_NAMES[unit.row]], 15, UiStyle.TEXT_DIM))
	var mechanic: Control = EncounterInfo.mechanic_box(encounter, 360)
	if mechanic != null:
		column.add_child(mechanic)
	var pick: Button = primary_button("Fight them", func() -> void: session.pick_fight(index), 240)
	pick.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(pick)
	return panel
