class_name RunEndScreen
extends UiScreen
## The run's summary on a ledger over the title backdrop: cleared or
## fallen, the record, and what was found.


func build() -> void:
	var state: RunState = session.state
	var content: ContentDb = session.content
	var won: bool = state.phase == "act_end"
	alignment = BoxContainer.ALIGNMENT_CENTER
	var page: VBoxContainer = card("panel_parchment", 820)
	var title: Label = UiStyle.heading("The act is won!" if won else "The guild has fallen", 40, UiStyle.MOSS_500.darkened(0.3) if won else UiStyle.BLOOD_500)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(title)
	var record := HBoxContainer.new()
	record.alignment = BoxContainer.ALIGNMENT_CENTER
	record.add_theme_constant_override("separation", 32)
	record.add_child(UiStyle.icon_label("day", "Day %d" % state.day, 20, UiStyle.INK_TEXT))
	record.add_child(UiStyle.icon_label("fight_normal", "%d wins" % state.wins, 20, UiStyle.INK_TEXT))
	record.add_child(UiStyle.icon_label("loss", "%d losses" % state.losses, 20, UiStyle.INK_TEXT))
	page.add_child(record)
	var synergies: PackedStringArray = PackedStringArray()
	for synergy_id: String in state.discovered:
		synergies.append(content.synergies[synergy_id].name)
	var found: Label = UiStyle.label("Synergies found: " + (", ".join(synergies) if not synergies.is_empty() else "none"), 18, UiStyle.INK_TEXT)
	found.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(found)
	var relics: PackedStringArray = PackedStringArray()
	for relic_id: String in state.relics:
		relics.append(content.relics[relic_id].name)
	var held: Label = UiStyle.label("Relics: " + (", ".join(relics) if not relics.is_empty() else "none"), 18, UiStyle.INK_TEXT)
	held.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(held)
	var back: Button = primary_button("Back to the title", func() -> void: session.abandon())
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(back)
