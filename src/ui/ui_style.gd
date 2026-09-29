class_name UiStyle
extends RefCounted
## The placeholder look, kept until the art rehaul (rebuild phase 7), from
## docs/archive/ui-asset-design.md and docs/archive/plans/ui-overhaul.md:
## the doc's palette tokens, the fonts (Work Sans for text, Young Serif for
## headings, both OFL, in art/fonts), the chrome art (nine-slice panels and
## button plaques from tools/art/ui_art.py), the UI icons, and one theme.
## A cozy-grim split: oak, brass, and parchment for chrome; slate and rift
## violet for the fight.

# --- palette tokens (docs/archive/ui-asset-design.md, section 3) ---
const INK_900 := Color("14101a")
const INK_700 := Color("2a2233")
const OAK_600 := Color("5b3a29")
const OAK_400 := Color("8a5a3c")
const PARCHMENT_100 := Color("f1e6cc")
const PARCHMENT_300 := Color("d9c79e")
const BRASS_500 := Color("c9993b")
const BRASS_300 := Color("e8c877")
const EMBER_500 := Color("e0703a")
const MOSS_500 := Color("6e9a5a")
const RIFT_500 := Color("7a4fd1")
const RIFT_300 := Color("b79cf0")
const FROST_400 := Color("5fb4c9")
const BLOOD_500 := Color("b33a3a")

# --- what the UI uses them for ---
const BACKGROUND := INK_900
const PANEL := INK_700
const PANEL_WARM := OAK_600
const BORDER := OAK_400
const TEXT := PARCHMENT_100
const TEXT_DIM := Color("a8997c")
## Dark text on parchment (the inspector), per the doc's contrast rule.
const INK_TEXT := INK_900
const EMBER := EMBER_500
## Moss and blood, lightened enough to read as text on ink.
const GOOD := Color("8dbf76")
const BAD := Color("d65a50")
const SHIELD := FROST_400
const HIGHLIGHT := BRASS_300
## Enemy lines in the fight log (the rift's cold violet).
const ENEMY_TEXT := RIFT_300

## Relic rarities, and their frame colors: bare oak, brass, silver-teal,
## violet, gold. Rivets, a crest, and wings back them up (FrameDecor), so
## rarity never relies on color alone.
const RARITIES: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]
const RARITY: Array[Color] = [OAK_400, BRASS_500, Color("8fc7c9"), Color("9b6fe0"), Color("f0c040")]
## Short status tags for the fight view.
const STATUS_TAGS: Dictionary[String, String] = {"burn": "BRN", "poison": "PSN", "bleed": "BLD"}
## Status colors for the fight view.
const STATUS_COLORS: Dictionary[String, Color] = {"burn": Color("e0703a"), "poison": Color("7ed14f"), "bleed": Color("d14545")}
## Chrome art (art/ui/chrome/<name>.svg) and its nine-slice margin in
## pixels (keep in sync with CHROME in tools/art/ui_art.py).
const CHROME_MARGINS: Dictionary[String, int] = {
	"panel_oak": 22, "panel_parchment": 16, "panel_slate": 30, "panel_stall": 24, "panel_bar": 12,
	"button_normal": 14, "button_hover": 14, "button_pressed": 14, "button_disabled": 14,
	"button_primary": 14, "button_primary_hover": 14, "button_primary_pressed": 14,
}
const CHROME_DIR: String = "res://art/ui/chrome/%s.svg"
const ICON_DIR: String = "res://art/ui/icons/%s.svg"
const BODY_FONT: String = "res://art/fonts/WorkSans-Regular.ttf"
const BOLD_FONT: String = "res://art/fonts/WorkSans-Bold.ttf"
const HEADING_FONT: String = "res://art/fonts/YoungSerif-Regular.ttf"


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = load(BODY_FONT) as Font
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", HIGHLIGHT)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER))
	theme.set_stylebox("panel", "Panel", box(PANEL, BORDER))
	# Buttons: brass-rimmed oak plaques.
	theme.set_stylebox("normal", "Button", chrome("button_normal", 14, 8))
	theme.set_stylebox("hover", "Button", chrome("button_hover", 14, 8))
	theme.set_stylebox("pressed", "Button", chrome("button_pressed", 14, 8))
	theme.set_stylebox("hover_pressed", "Button", chrome("button_pressed", 14, 8))
	theme.set_stylebox("disabled", "Button", chrome("button_disabled", 14, 8))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_disabled_color", "Button", TEXT_DIM.darkened(0.2))
	theme.set_stylebox("normal", "MenuButton", chrome("button_hover", 14, 8))
	theme.set_stylebox("hover", "MenuButton", chrome("button_primary_hover", 14, 8))
	theme.set_color("font_pressed_color", "Button", HIGHLIGHT)
	theme.set_stylebox("panel", "TooltipPanel", box(PARCHMENT_100, INK_900, 1))
	theme.set_color("font_color", "TooltipLabel", INK_TEXT)
	theme.set_font_size("font_size", "TooltipLabel", 16)
	return theme


static func box(fill: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


## A nine-slice panel or plaque from the chrome art, with its content
## inset by `pad_x` and `pad_y`.
static func chrome(name: String, pad_x: int = 16, pad_y: int = 12) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(CHROME_DIR % name) as Texture2D
	style.set_texture_margin_all(CHROME_MARGINS[name])
	if name.begins_with("panel"):
		# Panel edges repeat (stitches, grain) rather than stretch.
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	style.content_margin_left = pad_x
	style.content_margin_right = pad_x
	style.content_margin_top = pad_y
	style.content_margin_bottom = pad_y
	return style


## The primary action's look (an ember plaque), e.g. "Fight!".
static func primary(button: Button) -> Button:
	button.add_theme_stylebox_override("normal", chrome("button_primary", 18, 10))
	button.add_theme_stylebox_override("hover", chrome("button_primary_hover", 18, 10))
	button.add_theme_stylebox_override("pressed", chrome("button_primary_pressed", 18, 10))
	button.add_theme_color_override("font_color", PARCHMENT_100)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", Color("5a2410"))
	button.add_theme_constant_override("outline_size", 4)
	return button


## The parchment panel (hover cards): dark text.
static func parchment() -> StyleBoxTexture:
	return chrome("panel_parchment", 18, 14)


## A UI icon (art/ui/icons/<name>.svg): stat_hp, gold, stop_forge, ...
## Stat icons in UnitStats.Stat order.
const STAT_ICONS: Array[String] = ["stat_hp", "stat_atk", "stat_mgk", "stat_def", "stat_crit", "stat_atsp"]


## A unit's stats as a row of icon + number chips.
static func stat_row(stats: UnitStats, size: int = 16) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for stat: int in UnitStats.LABELS.size():
		var chip: HBoxContainer = icon_label(STAT_ICONS[stat], "%d" % stats.get_stat(stat), size)
		chip.tooltip_text = UnitStats.LABELS[stat]
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(chip)
	return row


static func icon(name: String, size: int = 24) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = load(ICON_DIR % name) as Texture2D
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.custom_minimum_size = Vector2(size, size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## A heading in the storybook serif.
static func heading(text: String, size: int = 28, color: Color = EMBER) -> Label:
	var node: Label = label(text, size, color)
	node.add_theme_font_override("font", load(HEADING_FONT) as Font)
	return node


## A dark see-through plate holding `child`, so text reads over the bright
## backdrop.
static func plate(child: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(INK_900, 0.72)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(child)
	return panel


## An icon and a label side by side (a stat, gold, keys).
static func icon_label(icon_name: String, text: String, size: int = 16, color: Color = TEXT, icon_size: int = 0) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(icon(icon_name, icon_size if icon_size > 0 else size + 6))
	var text_label: Label = label(text, size, color)
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(text_label)
	return line


static func rarity_color(rarity: String) -> Color:
	var index: int = RARITIES.find(rarity)
	return RARITY[index] if index >= 0 else BORDER


static func label(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


static func button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	node.pressed.connect(action)
	return node
