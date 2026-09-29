class_name UiScreen
extends VBoxContainer
## A screen of the game. Main shows one at a time; a screen builds itself
## in build().

## False: Main hides the title backdrop behind this screen (the arena needs
## a quiet background to read).
var shows_backdrop: bool = true
## True: Main gives it the whole window, with no margin (a screen with its
## own top bar and hero bar, like the mock's).
var full_bleed: bool = false


func setup() -> UiScreen:
	add_theme_constant_override("separation", 12)
	build()
	return self


## Fills the screen. Screens override this.
func build() -> void:
	pass


func heading(text: String) -> void:
	add_child(UiStyle.heading(text, 30))


## A dim line under a heading saying what to do here (on a plate over the
## backdrop, whose sky is bright).
func hint(text: String) -> void:
	var line: Label = UiStyle.label(text, 16, UiStyle.CREAM_300 if shows_backdrop else UiStyle.TEXT_DIM)
	if not shows_backdrop:
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(line)
		return
	# A plate sized to its line (a wrapping label would shrink it to nothing).
	var holder: PanelContainer = UiStyle.plate(line)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(holder)


## A centered panel (the mock's rounded navy box) holding a column; returns
## the column. `width` 0 lets it size to its content.
func card(_kind: String = "", width: int = 0) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style: StyleBoxFlat = UiStyle.box(UiStyle.PANEL, UiStyle.BORDER, 1, 12)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)
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
