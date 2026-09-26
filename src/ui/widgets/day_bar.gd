class_name DayBar
extends PanelContainer
## Where the run is: act and day, the day's steps, losses left, gold, keys,
## and the day's fight (with the essence it yields).

const STEPS: Array[Array] = [["caravan", "Caravan"], ["stop_choice", "Stop"], ["fight", "Fight"]]


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
	# The day's steps, the current one lit.
	var steps := HBoxContainer.new()
	steps.add_theme_constant_override("separation", 6)
	for i: int in STEPS.size():
		var step: Array = STEPS[i]
		var here: bool = state.phase == step[0] or (step[0] == "stop_choice" and state.phase == "stop") or (step[0] == "fight" and state.phase == "rewards")
		if i > 0:
			steps.add_child(UiStyle.label("›", 16, UiStyle.TEXT_DIM))
		steps.add_child(UiStyle.label("[%s]" % step[1] if here else step[1], 17 if here else 16, UiStyle.HIGHLIGHT if here else UiStyle.TEXT_DIM))
	line.add_child(steps)
	var losses: HBoxContainer = UiStyle.icon_label("loss", "Losses %d/%d" % [state.losses, RunFlow.LOSSES_TO_END], 16, UiStyle.BAD if state.losses > 0 else UiStyle.TEXT)
	line.add_child(losses)
	line.add_child(UiStyle.icon_label("gold", "%d gold" % state.gold, 17, UiStyle.HIGHLIGHT))
	line.add_child(UiStyle.icon_label("key", "%d key%s" % [state.keys, "" if state.keys == 1 else "s"], 16))
	if not state.encounter_id.is_empty():
		var encounter: EncounterDef = session.content.encounters[state.encounter_id]
		var essence: String = RunFlow.team_essence(session.content, encounter)
		var kind: String = "" if encounter.kind == "normal" else " (%s)" % encounter.kind
		var yields: String = "" if essence.is_empty() else " · yields %s" % session.content.essences[essence].name
		var kind_icon: String = "fight_%s" % encounter.kind if ["normal", "elite", "boss"].has(encounter.kind) else "fight_normal"
		line.add_child(UiStyle.icon_label(kind_icon, "Today's fight: %s%s%s" % [encounter.name, kind, yields], 16, UiStyle.TEXT_DIM))
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
