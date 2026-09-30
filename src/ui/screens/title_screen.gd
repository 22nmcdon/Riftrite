class_name TitleScreen
extends UiScreen
## The title, over the backdrop: Continue (when a run is saved), New run
## (phase 5: Act 1, day by day), and Practice (the Act 1 fights one at a
## time, phase 3).

signal practice_requested
signal run_requested
signal continue_requested

const REBUILD_NOTE: String = "Act 1 of the rift is open: seven days, and Old Mother Ash at the end."

## Main sets this when a run is saved.
var can_continue: bool = false


func build() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 18)
	var logo: Label = UiStyle.heading("Riftrite", 112, UiStyle.EMBER)
	logo.add_theme_font_override("font", UiStyle.font(UiStyle.TITLE_FONT))
	logo.add_theme_color_override("font_outline_color", UiStyle.NAVY_900)
	logo.add_theme_constant_override("outline_size", 18)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	logo.add_theme_constant_override("shadow_offset_y", 6)
	add_child(logo)
	# The words go on a plate: the backdrop's sky is bright.
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 10)
	words.add_child(UiStyle.label("A guild of heroes, and the rifts below the Hollow.", 22, UiStyle.CREAM_100))
	words.add_child(UiStyle.label(REBUILD_NOTE, 18, UiStyle.CREAM_300))
	for line: Control in words.get_children():
		(line as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(UiStyle.plate(words))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	add_child(gap)
	if can_continue:
		add_child(primary_button("Continue the run", func() -> void: continue_requested.emit()))
	var new_run: Button = UiStyle.button("New run", func() -> void: run_requested.emit())
	if not can_continue:
		UiStyle.primary(new_run)
	new_run.custom_minimum_size = Vector2(280, 56)
	new_run.add_theme_font_size_override("font_size", 22)
	add_child(new_run)
	add_child(UiStyle.button("Practice", func() -> void: practice_requested.emit()))
	add_child(UiStyle.button("Quit", _quit))
	for child: Control in get_children():
		child.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _quit() -> void:
	get_tree().quit()
