class_name UiScreen
extends VBoxContainer
## A screen of the game. Main shows one at a time; a screen builds itself
## in build().

## False: Main hides the title backdrop behind this screen (the arena needs
## a quiet background to read).
var shows_backdrop: bool = true


func setup() -> UiScreen:
	add_theme_constant_override("separation", 12)
	build()
	return self


## Fills the screen. Screens override this.
func build() -> void:
	pass


func heading(text: String) -> void:
	add_child(UiStyle.heading(text, 30))


## A dim line under a heading saying what to do here.
func hint(text: String) -> void:
	var line: Label = UiStyle.label(text, 16, UiStyle.TEXT_DIM)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(line)


## A centered panel of chrome art (UiStyle.chrome) holding a column; returns
## the column. `width` 0 lets it size to its content.
func card(chrome_name: String, width: int = 0) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.chrome(chrome_name, 36, 28))
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(width, 0)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	return column


## A big primary button (the screen's main way on).
func primary_button(text: String, action: Callable, width: int = 280) -> Button:
	var button: Button = UiStyle.primary(UiStyle.button(text, action))
	button.add_theme_font_size_override("font_size", 22)
	button.custom_minimum_size = Vector2(width, 56)
	return button
