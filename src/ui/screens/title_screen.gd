class_name TitleScreen
extends UiScreen
## Start a new run, or continue the saved one, over the title backdrop.


func build() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 18)
	var logo: Label = UiStyle.heading("Riftrite", 112, UiStyle.EMBER)
	logo.add_theme_color_override("font_outline_color", UiStyle.INK_900)
	logo.add_theme_constant_override("outline_size", 18)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	logo.add_theme_constant_override("shadow_offset_y", 6)
	add_child(logo)
	var tagline: Label = UiStyle.label("A guild, a pouch of essences, and the rifts below the Hollow.", 22, UiStyle.PARCHMENT_300)
	tagline.add_theme_color_override("font_outline_color", UiStyle.INK_900)
	tagline.add_theme_constant_override("outline_size", 6)
	add_child(tagline)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	add_child(gap)
	add_child(primary_button("New run", _new_run))
	if session.has_save():
		var resume: Button = UiStyle.button("Continue", _continue)
		resume.custom_minimum_size = Vector2(280, 52)
		resume.add_theme_font_size_override("font_size", 20)
		add_child(resume)
	for child: Control in get_children():
		child.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _new_run() -> void:
	session.new_run(session.next_seed())


func _continue() -> void:
	var problem: String = session.continue_run()
	if not problem.is_empty():
		session.changed.emit(RunActions._fail("couldn't load the run: " + problem))
