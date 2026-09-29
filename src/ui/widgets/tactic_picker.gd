class_name TacticPicker
extends VBoxContainer
## A hero's tactic (docs/plans/rebuild-phase3b-tactics.md, section 4), in the
## hero panel's Loadout tab while placing and in the hero popup in a fight:
## while it can be changed, a button for no tactic and one for each the hero
## can take (a press asks for it: chosen); otherwise, the one it took. Either
## way, with the tactic's sentence and its numbers line (UnitInfo).

## A tactic was picked ("": none).
signal chosen(tactic_id: String)

const NO_TACTIC: String = "None"

## The tactic buttons while it can be changed (the first is "None").
var tactic_buttons: Array[Button] = []
var tactic_text: Label
## The tactic's numbers line (UnitInfo.tactic_numbers; empty with none).
var tactic_numbers: Label


static func make() -> TacticPicker:
	var row := TacticPicker.new()
	row.add_theme_constant_override("separation", 4)
	return row


## `options` the tactics the hero can take, `picked_id` its tactic's id
## ("": none), and whether it can be changed now.
func show_tactics(options: Array[TacticDef], picked_id: String, can_choose: bool) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	tactic_buttons.clear()
	visible = not options.is_empty()
	if options.is_empty():
		return
	var picked: TacticDef = null
	for option: TacticDef in options:
		if option.id == picked_id:
			picked = option
	add_child(UiStyle.label("Tactic" if can_choose else "Tactic: %s" % (picked.name if picked != null else "none"), 17, UiStyle.GOLD_300))
	if can_choose:
		var buttons := HFlowContainer.new()
		buttons.add_theme_constant_override("h_separation", 6)
		buttons.add_theme_constant_override("v_separation", 6)
		add_child(buttons)
		var ids: Array[String] = [""]
		var names: Array[String] = [NO_TACTIC]
		for option: TacticDef in options:
			ids.append(option.id)
			names.append(option.name)
		for i: int in ids.size():
			var tactic_id: String = ids[i]
			var button: Button = UiStyle.button(names[i], func() -> void: chosen.emit(tactic_id))
			button.toggle_mode = true
			button.set_pressed_no_signal(tactic_id == picked_id)
			if tactic_id == picked_id:
				UiStyle.primary(button)
			tactic_buttons.append(button)
			buttons.add_child(button)
	tactic_text = UiStyle.label(picked.text if picked != null else "No tactic: it fights by its kit alone.", 14, UiStyle.TEXT_DIM)
	tactic_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(tactic_text)
	tactic_numbers = UiStyle.label(UnitInfo.tactic_numbers(picked) if picked != null else "", 13, UiStyle.TEXT_DIM)
	tactic_numbers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tactic_numbers.visible = picked != null
	add_child(tactic_numbers)
