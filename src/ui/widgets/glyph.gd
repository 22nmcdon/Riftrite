class_name Glyph
extends Control
## Placeholder icons drawn in code (no image files), so they're easy to
## replace with real art later: unit portraits (a colored disc with an
## initial), essence gems, status dots, and item-kind icons picked from the
## item's tags.

enum Shape { PORTRAIT, GEM, DOT, ITEM }

## Portrait colors by hero class (enemies use ENEMY).
const CLASS_COLORS: Dictionary[String, Color] = {
	"warden": Color("c98b4a"), "striker": Color("d65a4a"), "mender": Color("6cc08a"), "arcanist": Color("8a7ae0"),
}
const ENEMY := Color("7a3b4a")
## The first of an item's tags found here picks its icon.
const ITEM_ICONS: Array[String] = ["ranged", "defense", "healing", "food", "tome", "magic", "charm", "tool", "melee", "weapon"]

var shape: Shape = Shape.DOT
var color: Color = Color.WHITE
## The portrait's letter, or the item icon's kind (an ITEM_ICONS tag).
var text: String = ""


static func portrait(letter: String, fill: Color, size: int = 40) -> Glyph:
	return _make(Shape.PORTRAIT, fill, letter.substr(0, 1).to_upper(), size)


static func gem(essence_id: String, size: int = 16) -> Glyph:
	return _make(Shape.GEM, UiStyle.ESSENCE.get(essence_id, UiStyle.TEXT), "", size)


static func dot(fill: Color, size: int = 12) -> Glyph:
	return _make(Shape.DOT, fill, "", size)


## An icon for an item, from its tags (a plain dot when none match).
static func item(def: ItemDef, fill: Color, size: int = 22) -> Glyph:
	var kind: String = ""
	for tag: String in ITEM_ICONS:
		if def.tags.has(tag):
			kind = tag
			break
	return _make(Shape.ITEM, fill, kind, size)


static func _make(glyph_shape: Shape, fill: Color, glyph_text: String, size: int) -> Glyph:
	var glyph := Glyph.new()
	glyph.shape = glyph_shape
	glyph.color = fill
	glyph.text = glyph_text
	glyph.custom_minimum_size = Vector2(size, size)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return glyph


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var c: Vector2 = size / 2.0
	match shape:
		Shape.PORTRAIT:
			draw_circle(c, s / 2.0, color.darkened(0.45))
			draw_circle(c, s / 2.0 - 3.0, color)
			var font: Font = ThemeDB.fallback_font
			var font_size: int = int(s * 0.55)
			var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(font, Vector2(c.x - width / 2.0, c.y + font_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiStyle.BACKGROUND)
		Shape.GEM:
			var r: float = s / 2.0
			var points := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, 0), c + Vector2(0, r), c + Vector2(-r * 0.8, 0)])
			draw_colored_polygon(points, color)
			draw_colored_polygon(PackedVector2Array([points[0], points[1], c]), color.lightened(0.35))
		Shape.DOT:
			draw_circle(c, s / 2.0, color)
		Shape.ITEM:
			_draw_item(c, s / 2.0)


func _draw_item(c: Vector2, r: float) -> void:
	var w: float = maxf(r / 5.0, 1.5)
	match text:
		"melee", "weapon":
			draw_line(c + Vector2(-r * 0.7, r * 0.7), c + Vector2(r * 0.75, -r * 0.75), color, w)
			draw_line(c + Vector2(-r * 0.6, -r * 0.05), c + Vector2(-r * 0.05, r * 0.6), color, w)
		"ranged":
			draw_arc(c + Vector2(-r * 0.3, 0), r * 0.9, -PI / 2.6, PI / 2.6, 12, color, w)
			draw_line(c + Vector2(r * 0.25, -r * 0.7), c + Vector2(r * 0.25, r * 0.7), color, w / 2.0)
		"defense":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.75, -r * 0.7), c + Vector2(r * 0.75, -r * 0.7), c + Vector2(r * 0.6, r * 0.2), c + Vector2(0, r * 0.85), c + Vector2(-r * 0.6, r * 0.2)]), color)
		"healing", "food":
			draw_rect(Rect2(c - Vector2(r * 0.22, r * 0.75), Vector2(r * 0.44, r * 1.5)), color)
			draw_rect(Rect2(c - Vector2(r * 0.75, r * 0.22), Vector2(r * 1.5, r * 0.44)), color)
		"tome", "magic":
			draw_rect(Rect2(c - Vector2(r * 0.65, r * 0.75), Vector2(r * 1.3, r * 1.5)), color)
			draw_line(c + Vector2(-r * 0.35, -r * 0.75), c + Vector2(-r * 0.35, r * 0.75), UiStyle.BACKGROUND, w / 1.5)
		"charm":
			draw_arc(c + Vector2(0, r * 0.15), r * 0.6, 0, TAU, 20, color, w)
			draw_circle(c + Vector2(0, -r * 0.6), r * 0.25, color)
		"tool":
			draw_line(c + Vector2(0, -r * 0.3), c + Vector2(0, r * 0.8), color, w)
			draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.8), Vector2(r * 1.4, r * 0.55)), color)
		_:
			draw_circle(c, r * 0.5, color)
