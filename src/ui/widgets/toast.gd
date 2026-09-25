class_name Toast
extends Label
## A short message that fades out (a refused action's reason, or a note).


func show_message(text: String, color: Color = UiStyle.BAD) -> void:
	self.text = text
	add_theme_color_override("font_color", color)
	modulate.a = 1.0
	visible = true
	var tween: Tween = create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
