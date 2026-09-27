class_name EncounterInfo
extends RefCounted
## What the UI says about a fight ahead (docs/plans/fight-questions-and-
## readability.md, sections 1 and 2): an elite's or the boss's mechanic
## (what it does, and what answers it), and a day's fights for the day bar.

const KINDS: Array[String] = ["normal", "elite", "boss"]


## The icon for an encounter's kind (normal, elite, boss).
static func kind_icon(encounter: EncounterDef) -> String:
	return "fight_%s" % (encounter.kind if KINDS.has(encounter.kind) else "normal")


## "The Hunt: ... \nWhat answers it: ...", or "" for a fight without one.
static func mechanic_text(encounter: EncounterDef) -> String:
	if encounter.mechanic_name.is_empty():
		return ""
	return "%s: %s\nWhat answers it: %s" % [encounter.mechanic_name, encounter.mechanic_text, encounter.mechanic_counter]


## A boxed mechanic for fight cards and the enemy preview, or null.
static func mechanic_box(encounter: EncounterDef, width: float = 0.0) -> Control:
	if encounter.mechanic_name.is_empty():
		return null
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.INK_700, UiStyle.EMBER, 2))
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.add_child(UiStyle.label(encounter.mechanic_name, 18, UiStyle.EMBER))
	for line: String in [encounter.mechanic_text, "What answers it: " + encounter.mechanic_counter]:
		var label: Label = UiStyle.label(line, 15, UiStyle.TEXT if line == encounter.mechanic_text else UiStyle.HIGHLIGHT)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if width > 0.0:
			label.custom_minimum_size = Vector2(width, 0)
		column.add_child(label)
	return panel


## One line for a fight: "Cairn Watch (elite, harder), Stone essence".
static func fight_line(session: RunSession, encounter_id: String, day: int) -> String:
	var encounter: EncounterDef = session.content.encounters[encounter_id]
	var words: PackedStringArray = PackedStringArray()
	if encounter.kind != "normal":
		words.append(encounter.kind)
	var fights: Array[String] = RunFlow.fights_for_day(session.state, session.run, day)
	if fights.size() > 1:
		words.append("harder" if session.run.act(session.state.act).is_hard(encounter_id, day) else "easier")
	var line: String = encounter.name
	if not words.is_empty():
		line += " (%s)" % ", ".join(words)
	var essence: String = RunFlow.team_essence(session.content, encounter)
	if not essence.is_empty():
		line += ", %s essence" % session.content.essences[essence].name
	return line


## The hover text for a day on the day bar: its fights, each with its
## enemies, and an elite's or the boss's mechanic.
static func day_text(session: RunSession, day: int) -> String:
	var fights: Array[String] = RunFlow.fights_for_day(session.state, session.run, day)
	var kind: String = day_kind(session, day)
	var title: String = "Day %d" % day
	if kind != "normal":
		title += ": %s" % ("the boss" if kind == "boss" else "elites")
	var lines: PackedStringArray = PackedStringArray([title])
	for encounter_id: String in fights:
		var encounter: EncounterDef = session.content.encounters[encounter_id]
		lines.append("")
		lines.append(fight_line(session, encounter_id, day))
		var enemies: PackedStringArray = PackedStringArray()
		for slot: EncounterDef.Slot in encounter.units:
			enemies.append(session.content.enemies[slot.enemy_id].name)
		lines.append("  " + ", ".join(enemies))
		var mechanic: String = mechanic_text(encounter)
		if not mechanic.is_empty():
			for line: String in mechanic.split("\n"):
				lines.append("  " + line)
	return "\n".join(lines)


## A day's kind: the boss day, an elite day, or a normal one.
static func day_kind(session: RunSession, day: int) -> String:
	var act: ActDef = session.run.act(session.state.act)
	if act.is_boss_day(day):
		return "boss"
	return "elite" if act.is_elite_day(day) else "normal"
