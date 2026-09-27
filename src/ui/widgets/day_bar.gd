class_name DayBar
extends PanelContainer
## Where the run is: act and day, the day's steps, losses left, gold, keys,
## and the day's fights (with the essence each yields).


static func make(session: RunSession) -> DayBar:
	var bar := DayBar.new()
	var state: RunState = session.state
	bar.add_theme_stylebox_override("panel", UiStyle.chrome("panel_bar", 16, 8))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 26)
	bar.add_child(line)
	var act: ActDef = session.run.act(state.act)
	var where := HBoxContainer.new()
	where.add_theme_constant_override("separation", 8)
	where.add_child(UiStyle.icon("day", 30))
	where.add_child(UiStyle.heading("%s · Day %d of %d" % [act.name, state.day, act.days], 20, UiStyle.EMBER))
	line.add_child(where)
	# The day's steps (each stop visit, then the fight), the current one lit.
	var steps := HBoxContainer.new()
	steps.add_theme_constant_override("separation", 6)
	var stopping: bool = state.phase == "stop_choice" or state.phase == "stop"
	var names: Array[String] = []
	var lit: Array[bool] = []
	for visit: int in session.run.economy.stops_per_day:
		names.append("Stop %d" % (visit + 1))
		lit.append(stopping and state.visit == visit)
	names.append("Fight")
	lit.append(not stopping)
	for i: int in names.size():
		if i > 0:
			steps.add_child(UiStyle.label("›", 16, UiStyle.TEXT_DIM))
		steps.add_child(UiStyle.label("[%s]" % names[i] if lit[i] else names[i], 17 if lit[i] else 16, UiStyle.HIGHLIGHT if lit[i] else UiStyle.TEXT_DIM))
	line.add_child(steps)
	var losses: HBoxContainer = UiStyle.icon_label("loss", "Losses %d/%d" % [state.losses, RunFlow.LOSSES_TO_END], 16, UiStyle.BAD if state.losses > 0 else UiStyle.TEXT)
	line.add_child(losses)
	line.add_child(UiStyle.icon_label("gold", "%d gold" % state.gold, 17, UiStyle.HIGHLIGHT))
	line.add_child(UiStyle.icon_label("key", "%d key%s" % [state.keys, "" if state.keys == 1 else "s"], 16))
	# The fight picked, or the two to pick from.
	var fights: Array[String] = state.fight_options.duplicate()
	if not state.encounter_id.is_empty():
		fights = [state.encounter_id]
	var parts: PackedStringArray = PackedStringArray()
	for encounter_id: String in fights:
		var encounter: EncounterDef = session.content.encounters[encounter_id]
		var essence: String = RunFlow.team_essence(session.content, encounter)
		var kind: String = "" if encounter.kind == "normal" else " (%s)" % encounter.kind
		var yields: String = "" if essence.is_empty() else ", %s" % session.content.essences[essence].name
		parts.append("%s%s%s" % [encounter.name, kind, yields])
	if not fights.is_empty():
		var shown: EncounterDef = session.content.encounters[fights[0]]
		var kind_icon: String = "fight_%s" % shown.kind if ["normal", "elite", "boss"].has(shown.kind) else "fight_normal"
		line.add_child(UiStyle.icon_label(kind_icon, "Today's fight%s: %s" % ["" if fights.size() == 1 else "s", " or ".join(parts)], 16, UiStyle.TEXT_DIM))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(spacer)
	line.add_child(UiStyle.label("Seed %d" % state.seed_value, 14, UiStyle.TEXT_DIM))
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "Abandon this run? Its save is deleted."
	confirm.ok_button_text = "Abandon"
	confirm.confirmed.connect(session.abandon)
	bar.add_child(confirm)
	line.add_child(UiStyle.button("Abandon run", confirm.popup_centered))
	return bar
