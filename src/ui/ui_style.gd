class_name UiStyle
extends RefCounted
## The look, from the playtester's mock (docs/mockups/hero-panel-layout.pdf,
## sampled from its pages): deep navy panels with thin blue-grey rims, a
## teal accent for what's done or chosen, gold for the primary action and
## what's current, and cream text. Cinzel for names and headings, Alegreya
## for text (both OFL, in art/fonts; the uploaded art's fonts,
## docs/plans/rebuild-phase5b-art.md, Decision 2). Panels and
## buttons are flat rounded boxes. Placeholder until the art rehaul (rebuild
## phase 7), but it follows the mock. The fight keeps its own colors for
## sides and statuses (rift violet for enemies, ember for Rift Collapse).

# --- palette (sampled from the mock) ---
const NAVY_950 := Color("090e14")
const NAVY_900 := Color("0c1019")
const NAVY_850 := Color("121a26")
const NAVY_800 := Color("1b2433")
const NAVY_750 := Color("1f2a3c")
const NAVY_700 := Color("233249")
const NAVY_600 := Color("2b3b55")
const LINE_500 := Color("395265")
const LINE_400 := Color("4d6b80")
const TEAL_400 := Color("3fc8b8")
const TEAL_200 := Color("8ff0e4")
const GOLD_300 := Color("ffd66d")
const GOLD_500 := Color("d9b25a")
const CREAM_100 := Color("faebd5")
const CREAM_300 := Color("d8cfb8")
const SAGE_300 := Color("aec8c9")
const CORAL_300 := Color("ffa084")
const GREEN_400 := Color("8dd67a")
const INK_TEXT := Color("182029")
# The fight's own colors.
const EMBER_500 := Color("e0703a")
const MOSS_500 := Color("6e9a5a")
const RIFT_500 := Color("7a4fd1")
const RIFT_300 := Color("b79cf0")
const SIGIL_300 := Color("a093db")
const FROST_400 := Color("5fb4c9")
const BLOOD_500 := Color("b33a3a")

# --- what the UI uses them for ---
const BACKGROUND := NAVY_950
const PANEL := NAVY_800
const PANEL_RAISED := NAVY_700
const BORDER := LINE_500
const TEXT := CREAM_100
const TEXT_DIM := SAGE_300
const ACCENT := TEAL_400
const ACCENT_TEXT := TEAL_200
const EMBER := EMBER_500
const GOOD := GREEN_400
const BAD := CORAL_300
const SHIELD := FROST_400
const HIGHLIGHT := GOLD_300
## Enemy lines in the fight log (the rift's cold violet).
const ENEMY_TEXT := RIFT_300
## The item language's colors (the mock's page 2): charms gold, tactics
## cream-teal, sigils rift violet.
const CHARM := GOLD_300
const TACTIC := TEAL_200
const SIGIL := SIGIL_300

## Relic rarities, and their frame colors.
const RARITIES: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]
const RARITY: Array[Color] = [LINE_500, GOLD_500, Color("8fc7c9"), Color("9b6fe0"), Color("f0c040")]
## Short status tags for the fight view.
const STATUS_TAGS: Dictionary[String, String] = {"burn": "BRN", "poison": "PSN", "bleed": "BLD", "briar_torn": "BRR"}
## Status colors for the fight view.
const STATUS_COLORS: Dictionary[String, Color] = {"burn": Color("e0703a"), "poison": Color("7ed14f"), "bleed": Color("d14545"), "briar_torn": Color("d14545")}
const ICON_DIR: String = "res://art/ui/icons/%s.svg"
const BODY_FONT: String = "res://art/fonts/Alegreya-Regular.ttf"
## Alegreya has no semibold: its bold stands in.
const SEMIBOLD_FONT: String = "res://art/fonts/Alegreya-Bold.ttf"
const BOLD_FONT: String = "res://art/fonts/Alegreya-Bold.ttf"
const HEADING_FONT: String = "res://art/fonts/Cinzel-Bold.ttf"
## The game's name on the title.
const TITLE_FONT: String = "res://art/fonts/Cinzel-Black.ttf"
## The old body font, for the few characters the new fonts lack.
const FALLBACK_FONT: String = "res://art/fonts/WorkSans-Regular.ttf"
const RADIUS: int = 8

static var _fonts: Dictionary[String, Font] = {}


## A font, with Work Sans behind it for anything it lacks, and lining
## figures (Alegreya's default old-style ones sit low in "HP 270 / 270").
static func font(path: String) -> Font:
	if not _fonts.has(path):
		var base: FontFile = load(path) as FontFile
		var fallback: Font = load(FALLBACK_FONT) as Font
		var variation := FontVariation.new()
		variation.base_font = base
		variation.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("lnum"): 1}
		variation.fallbacks = [fallback]
		_fonts[path] = variation
	return _fonts[path]


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = font(BODY_FONT)
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_font("bold_font", "RichTextLabel", font(BOLD_FONT))
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER, 1))
	theme.set_stylebox("panel", "Panel", box(PANEL, BORDER, 1))
	# Buttons: dark boxes with a thin rim; the rim lights on hover.
	theme.set_font("font", "Button", font(SEMIBOLD_FONT))
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", HIGHLIGHT)
	theme.set_color("font_hover_pressed_color", "Button", HIGHLIGHT)
	theme.set_color("font_disabled_color", "Button", Color(TEXT_DIM, 0.45))
	theme.set_stylebox("normal", "Button", button_box(NAVY_800, LINE_500))
	theme.set_stylebox("hover", "Button", button_box(NAVY_700, LINE_400))
	theme.set_stylebox("pressed", "Button", button_box(NAVY_700, GOLD_500))
	theme.set_stylebox("hover_pressed", "Button", button_box(NAVY_700, GOLD_300))
	theme.set_stylebox("disabled", "Button", button_box(NAVY_850, Color(LINE_500, 0.5)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("normal", "MenuButton", button_box(NAVY_800, LINE_500))
	theme.set_stylebox("hover", "MenuButton", button_box(NAVY_700, LINE_400))
	theme.set_stylebox("panel", "TooltipPanel", box(NAVY_800, GOLD_500, 1))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_font_size("font_size", "TooltipLabel", 16)
	theme.set_stylebox("separator", "HSeparator", line_box(LINE_500))
	var scroll_grabber: StyleBoxFlat = box(LINE_500, LINE_500, 0)
	scroll_grabber.set_corner_radius_all(4)
	theme.set_stylebox("grabber", "VScrollBar", scroll_grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", box(LINE_400, LINE_400, 0))
	theme.set_stylebox("scroll", "VScrollBar", box(NAVY_850, NAVY_850, 0))
	return theme


## A flat rounded box: `fill`, a `width`-pixel rim of `border`.
static func box(fill: Color, border: Color, width: int = 1, radius: int = RADIUS) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


## A button's box: roomier than a panel's.
static func button_box(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style: StyleBoxFlat = box(fill, border, width)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style


## A 1-pixel line (separators).
static func line_box(color: Color) -> StyleBoxLine:
	var style := StyleBoxLine.new()
	style.color = color
	style.thickness = 1
	return style


## The primary action's look (the mock's gold button with dark text), e.g.
## "Fight", or the tab that's open.
static func primary(button: Button) -> Button:
	button.add_theme_stylebox_override("normal", button_box(GOLD_300, GOLD_300))
	button.add_theme_stylebox_override("hover", button_box(Color("ffe08f"), Color("ffe08f")))
	button.add_theme_stylebox_override("pressed", button_box(GOLD_500, GOLD_500))
	button.add_theme_stylebox_override("hover_pressed", button_box(GOLD_300, GOLD_300))
	button.add_theme_stylebox_override("disabled", button_box(Color(GOLD_500, 0.35), Color(GOLD_500, 0.35)))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK_TEXT)
	button.add_theme_font_override("font", font(BOLD_FONT))
	return button


## Undoes primary(): back to the theme's button.
static func plain(button: Button) -> Button:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.remove_theme_stylebox_override(state)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.remove_theme_color_override(state)
	button.remove_theme_font_override("font")
	return button


## A square icon button (the panel's back, forward, and close).
static func square(button: Button, side: float = 52.0) -> Button:
	button.custom_minimum_size = Vector2(side, side)
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var style: StyleBoxFlat = button_box(NAVY_700 if state != "normal" else NAVY_750, LINE_400 if state == "hover" else LINE_500)
		style.content_margin_left = 0
		style.content_margin_right = 0
		button.add_theme_stylebox_override(state, style)
	button.add_theme_font_size_override("font_size", 22)
	return button


## A small outlined tag (a slot chip, an upgrade taken): `color` rim and
## text; `filled` gives it a dark fill, else it's dim and dashed-looking.
## `icon` (an ItemIcon, say) goes before the text.
static func chip(text: String, color: Color, filled: bool = true, size: int = 14, icon: Control = null) -> PanelContainer:
	var holder := PanelContainer.new()
	var style: StyleBoxFlat = box(NAVY_800 if filled else Color(0, 0, 0, 0), color if filled else Color(LINE_500, 0.8), 1, 4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	holder.add_theme_stylebox_override("panel", style)
	var text_label: Label = label(text, size, color if filled else TEXT_DIM)
	text_label.add_theme_font_override("font", font(BOLD_FONT if filled else BODY_FONT))
	if icon == null:
		holder.add_child(text_label)
		return holder
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(icon)
	text_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text_label)
	holder.add_child(row)
	return holder


## A thin bar: `share` (0 to 1) of it filled with `fill` over a near-black
## track; `lost` (0 to 1) at its end drawn as grey stripes (wounds).
static func bar(share: float, fill: Color, height: float = 12.0, lost: float = 0.0) -> Control:
	var meter := Meter.new()
	meter.share = clampf(share, 0.0, 1.0)
	meter.fill = fill
	meter.lost = clampf(lost, 0.0, 1.0)
	meter.custom_minimum_size = Vector2(0, height)
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return meter


## The bar bar() makes.
class Meter:
	extends Control
	var share: float = 1.0
	var fill: Color = Color.WHITE
	var lost: float = 0.0

	func set_share(value: float) -> void:
		share = clampf(value, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var track := Rect2(Vector2.ZERO, size)
		draw_rect(track, Color("0b0f18"))
		var usable: float = size.x * (1.0 - lost)
		draw_rect(Rect2(0, 0, usable * share, size.y), fill)
		if lost > 0.0:
			var start: float = usable
			draw_rect(Rect2(start, 0, size.x - start, size.y), Color("353b49"))
			var x: float = start
			while x < size.x:
				var top: float = minf(x + size.y, size.x)
				draw_line(Vector2(x, size.y), Vector2(top, size.y - (top - x)), Color("4a5161"), 2.0)
				x += 8.0


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


## A heading or a name in Cinzel.
## A number shortened past 9,999 (phase 8 part 1: endless's enemies grow
## large): 12.4k, 3.1M, 2.0B.
static func short_number(value: int) -> String:
	var size: int = absi(value)
	if size < 10000:
		return str(value)
	var sign: String = "-" if value < 0 else ""
	for unit: Array in [[1000000000, "B"], [1000000, "M"], [1000, "k"]]:
		if size >= unit[0]:
			@warning_ignore("integer_division")
			var tenths: int = size * 10 / int(unit[0])
			@warning_ignore("integer_division")
			return "%s%d.%d%s" % [sign, tenths / 10, tenths % 10, unit[1]]
	return str(value)


static func heading(text: String, size: int = 28, color: Color = HIGHLIGHT) -> Label:
	var node: Label = label(text, size, color)
	node.add_theme_font_override("font", font(HEADING_FONT))
	return node


## A label in bold Alegreya (`semibold` is the same, since Alegreya has none).
static func strong(text: String, size: int = 16, color: Color = TEXT, semibold: bool = false) -> Label:
	var node: Label = label(text, size, color)
	node.add_theme_font_override("font", font(SEMIBOLD_FONT if semibold else BOLD_FONT))
	return node


## Small spaced capitals ("UPGRADES TAKEN", "VOWED").
static func caps(text: String, size: int = 13, color: Color = TEXT_DIM) -> Label:
	var node: Label = label(text.to_upper(), size, color)
	node.add_theme_font_override("font", spaced_bold())
	return node


static var _spaced: FontVariation = null


## Bold Alegreya with a little room between letters.
static func spaced_bold() -> Font:
	if _spaced == null:
		_spaced = FontVariation.new()
		_spaced.base_font = font(BOLD_FONT)
		_spaced.spacing_glyph = 1
	return _spaced


## A dark see-through plate holding `child`, so text reads over the bright
## backdrop.
static func plate(child: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(NAVY_900, 0.72)
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
