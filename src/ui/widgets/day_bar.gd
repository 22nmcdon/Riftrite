class_name DayBar
extends PanelContainer
## Where the run is: act and day, the day's steps, losses left, gold, keys,
## and the day's fight (with the essence it yields).

const STEPS: Array[Array] = [["caravan", "Caravan"], ["stop_choice", "Stop"], ["fight", "Fight"]]


static func make(session: RunSession) -> DayBar:
	var bar := DayBar.new()
	var state: RunState = session.state
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 24)
	bar.add_child(line)
	var act: ActDef = session.run.act(state.act)
	line.add_child(UiStyle.label("%s · Day %d of %d" % [act.name, state.day, act.days], 18, UiStyle.EMBER))
	var steps: PackedStringArray = PackedStringArray()
	for step: Array in STEPS:
		var here: bool = state.phase == step[0] or (step[0] == "stop_choice" and state.phase == "stop") or (step[0] == "fight" and state.phase == "rewards")
		steps.append("[%s]" % step[1] if here else step[1])
	line.add_child(UiStyle.label(" › ".join(steps), 16))
	line.add_child(UiStyle.label("Losses %d/%d" % [state.losses, RunFlow.LOSSES_TO_END], 16, UiStyle.BAD if state.losses > 0 else UiStyle.TEXT))
	line.add_child(UiStyle.label("Gold %d" % state.gold, 16, UiStyle.HIGHLIGHT))
	line.add_child(UiStyle.label("Keys %d" % state.keys, 16))
	if not state.encounter_id.is_empty():
		var encounter: EncounterDef = session.content.encounters[state.encounter_id]
		var essence: String = RunFlow.team_essence(session.content, encounter)
		var kind: String = "" if encounter.kind == "normal" else " (%s)" % encounter.kind
		var yields: String = "" if essence.is_empty() else " · yields %s" % session.content.essences[essence].name
		line.add_child(UiStyle.label("Today's fight: %s%s%s" % [encounter.name, kind, yields], 16, UiStyle.TEXT_DIM))
	return bar
