class_name RunEndScreen
extends UiScreen
## The run's summary: cleared or fallen, the record, and what was found.


func build() -> void:
	var state: RunState = session.state
	var content: ContentDb = session.content
	heading("The act is won!" if state.phase == "act_end" else "The guild has fallen")
	add_child(UiStyle.label("Day %d · %d wins · %d losses" % [state.day, state.wins, state.losses], 18))
	var synergies: PackedStringArray = PackedStringArray()
	for synergy_id: String in state.discovered:
		synergies.append(content.synergies[synergy_id].name)
	add_child(UiStyle.label("Synergies found: " + (", ".join(synergies) if not synergies.is_empty() else "none"), 16))
	var relics: PackedStringArray = PackedStringArray()
	for relic_id: String in state.relics:
		relics.append(content.relics[relic_id].name)
	add_child(UiStyle.label("Relics: " + (", ".join(relics) if not relics.is_empty() else "none"), 16))
	add_child(UiStyle.button("Back to the title", func() -> void: session.abandon()))
