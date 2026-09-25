class_name UiStyle
extends RefCounted
## The placeholder look: one theme and a small cozy-grim palette (warm
## browns and ember orange against dark rift blues). Real art comes later.

const BACKGROUND := Color("141a26")
const PANEL := Color("232b3a")
const PANEL_WARM := Color("3a2c22")
const BORDER := Color("5a4a3a")
const TEXT := Color("efe6d8")
const TEXT_DIM := Color("a89f92")
const EMBER := Color("e8813a")
const GOOD := Color("7fc97a")
const BAD := Color("e05a4f")
const SHIELD := Color("8fb8e8")
const HIGHLIGHT := Color("ffd35c")

## Border colors by rarity (ItemDef.RARITIES order).
const RARITY: Array[Color] = [Color("9a9a9a"), Color("5fb85f"), Color("4f8fe0"), Color("a65fe0"), Color("f0a93a")]
## Socket dots by essence.
const ESSENCE: Dictionary[String, Color] = {
	"ember": Color("f0703a"), "venom": Color("7ed14f"), "wrath": Color("d64545"), "stone": Color("a8906c"),
	"verdant": Color("4fd18a"), "frost": Color("8fd3ff"), "storm": Color("c3a6ff"), "umbral": Color("7a5fa6"),
}
## Short status tags for the fight view.
const STATUS_TAGS: Dictionary[String, String] = {
	"burn": "BRN", "poison": "PSN", "bleed": "BLD", "golden_flame": "GLD", "plasma": "PLS",
	"blight": "BLT", "slow": "SLW", "freeze": "FRZ", "blind": "BLN",
}
## Pixels per item slot.
const SLOT_WIDTH: int = 74
const TILE_HEIGHT: int = 64


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", HIGHLIGHT)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER))
	theme.set_stylebox("panel", "Panel", box(PANEL, BORDER))
	theme.set_stylebox("normal", "Button", box(PANEL_WARM, BORDER))
	theme.set_stylebox("hover", "Button", box(PANEL_WARM.lightened(0.1), EMBER))
	theme.set_stylebox("pressed", "Button", box(PANEL_WARM.darkened(0.2), EMBER))
	theme.set_stylebox("disabled", "Button", box(PANEL.darkened(0.2), BORDER.darkened(0.3)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
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
