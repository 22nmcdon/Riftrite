class_name TitleScreen
extends UiScreen
## The title, over the backdrop. While the rebuild is under way
## (docs/plans/rebuild-build-order.md) the way in is Practice: the Act 1
## fights, one at a time (phase 3). The run comes with phase 5.

signal practice_requested

const REBUILD_NOTE: String = "The rift is being rebuilt. Until the run returns, practice its fights."


func build() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 18)
	var logo: Label = UiStyle.heading("Riftrite", 112, UiStyle.EMBER)
	logo.add_theme_color_override("font_outline_color", UiStyle.INK_900)
	logo.add_theme_constant_override("outline_size", 18)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	logo.add_theme_constant_override("shadow_offset_y", 6)
	add_child(logo)
	var tagline: Label = UiStyle.label("A guild of heroes, and the rifts below the Hollow.", 22, UiStyle.PARCHMENT_300)
	tagline.add_theme_color_override("font_outline_color", UiStyle.INK_900)
	tagline.add_theme_constant_override("outline_size", 6)
	add_child(tagline)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	add_child(gap)
	var note: Label = UiStyle.label(REBUILD_NOTE, 18, UiStyle.TEXT_DIM)
	note.add_theme_color_override("font_outline_color", UiStyle.INK_900)
	note.add_theme_constant_override("outline_size", 6)
	add_child(note)
	add_child(primary_button("Practice", func() -> void: practice_requested.emit()))
	add_child(UiStyle.button("Quit", _quit))
	for child: Control in get_children():
		child.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _quit() -> void:
	get_tree().quit()
