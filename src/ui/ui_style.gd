class_name UiStyle
extends RefCounted
## The placeholder look, from docs/ui-asset-design.md: the doc's palette
## tokens, one theme, and a cozy-grim split (oak, brass, and parchment for
## chrome; ink and rift violet for the fight). Real art comes later.

# --- palette tokens (docs/ui-asset-design.md, section 3) ---
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

## Frame colors by rarity (ItemDef.RARITIES order): bare oak, brass,
## silver-teal, violet, gold. Rivets, a crest, and wings back them up
## (FrameDecor), so rarity never relies on color alone.
const RARITY: Array[Color] = [OAK_400, BRASS_500, Color("8fc7c9"), Color("9b6fe0"), Color("f0c040")]
## Essence hues (each also has its own glyph; see Glyph).
const ESSENCE: Dictionary[String, Color] = {
	"ember": Color("e0703a"), "venom": Color("7ed14f"), "wrath": Color("d14545"), "stone": Color("a8906c"),
	"verdant": Color("6e9a5a"), "frost": Color("5fb4c9"), "storm": Color("e8c877"), "umbral": Color("7a4fd1"),
}
## Short status tags for the fight view.
const STATUS_TAGS: Dictionary[String, String] = {
	"burn": "BRN", "poison": "PSN", "bleed": "BLD", "golden_flame": "GLD", "plasma": "PLS",
	"blight": "BLT", "slow": "SLW", "freeze": "FRZ", "blind": "BLN",
}
## Status colors for the fight view.
const STATUS_COLORS: Dictionary[String, Color] = {
	"burn": Color("e0703a"), "poison": Color("7ed14f"), "bleed": Color("d14545"), "golden_flame": Color("e8c877"),
	"plasma": Color("c37bff"), "blight": Color("5f8f3a"), "slow": Color("8fb8e8"), "freeze": Color("8fe8f0"), "blind": Color("9a9a9a"),
	"deathcap": Color("5c9a3a"), "rime": Color("b8e4f5"), "searfire": Color("ff5a2a"), "caustic": Color("c8d84a"),
	"nightshade": Color("8a5ab8"), "hemorrhage": Color("a82a3a"),
}
## Pixels per item slot.
const SLOT_WIDTH: int = 100
const TILE_HEIGHT: int = 96


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", HIGHLIGHT)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER))
	theme.set_stylebox("panel", "Panel", box(PANEL, BORDER))
	# Buttons: brass on oak.
	theme.set_stylebox("normal", "Button", box(PANEL_WARM, BRASS_500))
	theme.set_stylebox("hover", "Button", box(PANEL_WARM.lightened(0.1), BRASS_300))
	theme.set_stylebox("pressed", "Button", box(PANEL_WARM.darkened(0.2), BRASS_300))
	theme.set_stylebox("disabled", "Button", box(PANEL.darkened(0.2), BORDER.darkened(0.3)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("normal", "MenuButton", box(PANEL_WARM, HIGHLIGHT))
	theme.set_stylebox("hover", "MenuButton", box(PANEL_WARM.lightened(0.1), EMBER))
	theme.set_stylebox("hover_pressed", "Button", box(PANEL_WARM.darkened(0.2), HIGHLIGHT))
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


## The primary action's look (ember), e.g. "Fight!".
static func primary(button: Button) -> Button:
	button.add_theme_stylebox_override("normal", box(EMBER_500.darkened(0.35), EMBER_500))
	button.add_theme_stylebox_override("hover", box(EMBER_500.darkened(0.2), BRASS_300))
	button.add_theme_stylebox_override("pressed", box(EMBER_500.darkened(0.45), BRASS_300))
	return button


## The parchment panel (the inspector, tooltips): ink border, dark text.
static func parchment() -> StyleBoxFlat:
	var style: StyleBoxFlat = box(PARCHMENT_100, OAK_400, 3)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


static func rarity_color(rarity: String) -> Color:
	var index: int = ItemDef.RARITIES.find(rarity)
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
