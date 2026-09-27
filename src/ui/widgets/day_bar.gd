class_name DayBar
extends PanelContainer
## Where the run is: act and day, the day's steps, losses left, gold, keys,
## and the day's fights (with the essence each yields). Below it, the whole
## act: a mark per day with its kind's icon (normal, elite, boss); hovering a
## day lists its fights, and an elite's or the boss's mechanic
## (docs/plans/fight-questions-and-readability.md, section 1).


static func make(session: RunSession) -> DayBar:
	var bar := DayBar.new()
	var state: RunState = session.state
	bar.add_theme_stylebox_override("panel", UiStyle.chrome("panel_bar", 16, 8))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	bar.add_child(rows)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 26)
	rows.add_child(line)
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
		line.add_child(UiStyle.icon_label(EncounterInfo.kind_icon(shown), "Today's fight%s: %s" % ["" if fights.size() == 1 else "s", " or ".join(parts)], 16, UiStyle.TEXT_DIM))
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
	rows.add_child(act_track(session))
	return bar


## The act's days in a row: a mark per day with its kind's icon, today lit
## and days gone dimmed. Hovering a day lists its fights.
static func act_track(session: RunSession) -> HBoxContainer:
	var track := HBoxContainer.new()
	track.add_theme_constant_override("separation", 6)
	var act: ActDef = session.run.act(session.state.act)
	for day: int in range(1, act.days + 1):
		var kind: String = EncounterInfo.day_kind(session, day)
		var mark := PanelContainer.new()
		mark.name = "Day%d" % day
		var today: bool = day == session.state.day
		var border: Color = UiStyle.HIGHLIGHT if today else (UiStyle.EMBER if kind != "normal" else UiStyle.BORDER)
		mark.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.INK_700, border, 2 if today or kind != "normal" else 1))
		mark.mouse_filter = Control.MOUSE_FILTER_STOP
		mark.tooltip_text = EncounterInfo.day_text(session, day)
		mark.modulate = Color(1, 1, 1, 0.5) if day < session.state.day else Color.WHITE
		var inside := HBoxContainer.new()
		inside.add_theme_constant_override("separation", 4)
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.add_child(inside)
		var icon: Control = UiStyle.icon("fight_%s" % kind, 30 if kind == "boss" else (26 if kind == "elite" else 20))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inside.add_child(icon)
		var words: String = "Day %d" % day
		if kind != "normal":
			words += " · %s" % ("Boss" if kind == "boss" else "Elite")
		var label: Label = UiStyle.label(words, 14, UiStyle.HIGHLIGHT if today else (UiStyle.EMBER if kind != "normal" else UiStyle.TEXT_DIM))
		inside.add_child(label)
		track.add_child(mark)
	return track
