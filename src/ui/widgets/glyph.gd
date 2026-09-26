class_name Glyph
extends Control
## Placeholder icons drawn in code (no image files), following the shape
## language in docs/ui-asset-design.md: round gems with a glyph per essence,
## the four infusion gem forms, status shapes, hex relic tokens, unit
## portraits, and item-kind icons (with an optional cooldown sweep). Easy
## to replace with real art later.

enum Shape { PORTRAIT, GEM, DOT, ITEM, INFUSION, STATUS, HEX }
## Infusion gem forms (docs/ui-asset-design.md, 8.3).
enum Infusion { EMPTY, SINGLE, ALLOY, PURE, TRANSFORMATION }

## Portrait colors by hero class (enemies use ENEMY).
const CLASS_COLORS: Dictionary[String, Color] = {
	"warden": Color("c98b4a"), "striker": Color("d65a4a"), "mender": Color("8dbf76"), "arcanist": Color("9b6fe0"),
}
const ENEMY := Color("7a3b4a")
## The first of an item's tags found here picks its icon.
const ITEM_ICONS: Array[String] = ["ranged", "defense", "healing", "food", "tome", "magic", "charm", "tool", "melee", "weapon"]
## Each essence's glyph (drawn in ink on its gem).
const ESSENCE_GLYPHS: Dictionary[String, String] = {
	"ember": "flame", "venom": "droplet", "wrath": "claws", "stone": "block",
	"verdant": "leaf", "frost": "snowflake", "storm": "bolt", "umbral": "crescent",
}
## Each status's shape, so statuses read without color.
const STATUS_SHAPES: Dictionary[String, String] = {
	"burn": "flame", "golden_flame": "flame_core", "poison": "circle", "bleed": "droplet", "plasma": "diamond",
	"blight": "block", "slow": "hourglass", "freeze": "snowflake", "blind": "bar",
}

var shape: Shape = Shape.DOT
var color: Color = Color.WHITE
## A second color: an alloy's second essence.
var color_b: Color = Color.WHITE
## The portrait's or hex's letter, the item icon's kind (an ITEM_ICONS tag),
## an essence glyph, or a status shape.
var text: String = ""
var infusion: Infusion = Infusion.SINGLE
## ITEM: cooldown progress 0..1 drawn as a radial sweep, or -1 for none.
var progress: float = -1.0
## HEX: draw the rift bleed (cracks).
var cracked: bool = false


static func portrait(letter: String, fill: Color, size: int = 40) -> Glyph:
	return _make(Shape.PORTRAIT, fill, letter.substr(0, 1).to_upper(), size)


## An essence as a round gem with its glyph.
static func gem(essence_id: String, size: int = 16) -> Glyph:
	var glyph: Glyph = _make(Shape.GEM, UiStyle.ESSENCE.get(essence_id, UiStyle.TEXT), ESSENCE_GLYPHS.get(essence_id, ""), size)
	glyph.tooltip_text = essence_id.capitalize()
	return glyph


static func dot(fill: Color, size: int = 12) -> Glyph:
	return _make(Shape.DOT, fill, "", size)


## An item's infusion as one gem (docs/ui-asset-design.md, 8.3).
static func infusion_gem(form: Infusion, essence_ids: Array[String], size: int = 18) -> Glyph:
	var first: String = essence_ids[0] if not essence_ids.is_empty() else ""
	var glyph: Glyph = _make(Shape.INFUSION, UiStyle.ESSENCE.get(first, UiStyle.BORDER), ESSENCE_GLYPHS.get(first, ""), size)
	glyph.infusion = form
	if essence_ids.size() > 1:
		glyph.color_b = UiStyle.ESSENCE.get(essence_ids[1], UiStyle.BORDER)
	return glyph


static func status(status_id: String, size: int = 14) -> Glyph:
	return _make(Shape.STATUS, UiStyle.STATUS_COLORS.get(status_id, UiStyle.EMBER), STATUS_SHAPES.get(status_id, "circle"), size)


## A relic as a hex token: rim in its rarity color, its initial inside.
static func hex(name: String, rim: Color, size: int = 44, rift: bool = false) -> Glyph:
	var glyph: Glyph = _make(Shape.HEX, rim, name.substr(0, 1).to_upper(), size)
	glyph.cracked = rift
	return glyph


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


## Sets the cooldown sweep (ITEM) and redraws when it changed.
func set_progress(value: float) -> void:
	if not is_equal_approx(value, progress):
		progress = value
		queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var c: Vector2 = size / 2.0
	var r: float = s / 2.0
	match shape:
		Shape.PORTRAIT:
			draw_circle(c, r, color.darkened(0.45))
			draw_circle(c, r - 3.0, color)
			_letter(c, s * 0.55, UiStyle.INK_900)
		Shape.GEM:
			_gem(c, r, color, text)
		Shape.DOT:
			draw_circle(c, r, color)
		Shape.ITEM:
			if progress >= 0.0:
				draw_circle(c, r, UiStyle.INK_900)
				_pie(c, r, progress, Color(UiStyle.EMBER_500, 0.55))
			_draw_item(c, r * (0.8 if progress >= 0.0 else 1.0))
		Shape.INFUSION:
			_draw_infusion(c, r)
		Shape.STATUS:
			_shape(text, c, r, color)
		Shape.HEX:
			_draw_hex(c, r)


func _letter(c: Vector2, font_size_f: float, ink: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = int(font_size_f)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(c.x - width / 2.0, c.y + font_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


## A round gem: dark rim, hue, a highlight, and the glyph in ink.
func _gem(c: Vector2, r: float, hue: Color, glyph: String) -> void:
	draw_circle(c, r, UiStyle.INK_900)
	draw_circle(c, r - 1.5, hue)
	draw_circle(c + Vector2(-r * 0.35, -r * 0.35), r * 0.22, Color(1, 1, 1, 0.35))
	if not glyph.is_empty():
		_shape(glyph, c, r * 0.55, UiStyle.INK_900)


func _draw_infusion(c: Vector2, r: float) -> void:
	match infusion:
		Infusion.EMPTY:
			draw_arc(c, r * 0.7, 0, TAU, 20, UiStyle.BORDER, 2.0)
		Infusion.SINGLE:
			_gem(c, r, color, text)
		Infusion.ALLOY:
			draw_circle(c, r, UiStyle.INK_900)
			draw_colored_polygon(_half_disc(c, r - 1.5, PI / 2.0), color)
			draw_colored_polygon(_half_disc(c, r - 1.5, -PI / 2.0), color_b)
			draw_line(c + Vector2(0, -r), c + Vector2(0, r), UiStyle.INK_900, 1.5)
		Infusion.PURE:
			draw_arc(c, r * 0.95, 0, TAU, 24, Color(color.lightened(0.4), 0.6), 2.0)
			var points := PackedVector2Array()
			for i: int in 8:
				points.append(c + Vector2.from_angle(TAU * i / 8.0 + PI / 8.0) * r * 0.8)
			draw_colored_polygon(points, color)
			draw_polyline(points + PackedVector2Array([points[0]]), UiStyle.INK_900, 1.0)
			draw_circle(c, r * 0.3, color.lightened(0.6))
		Infusion.TRANSFORMATION:
			_gem(c, r * 0.85, color, text)
			# A small padlock at the bottom right: it never spills.
			var lock: Vector2 = c + Vector2(r * 0.45, r * 0.45)
			draw_arc(lock + Vector2(0, -r * 0.18), r * 0.18, PI, TAU, 8, UiStyle.PARCHMENT_100, 2.0)
			draw_rect(Rect2(lock - Vector2(r * 0.27, r * 0.15), Vector2(r * 0.54, r * 0.4)), UiStyle.PARCHMENT_100)


## A half disc facing `angle` (PI/2 = left half, -PI/2 = right half).
func _half_disc(c: Vector2, r: float, angle: float) -> PackedVector2Array:
	var points := PackedVector2Array([c])
	for i: int in 13:
		points.append(c + Vector2.from_angle(angle + PI / 2.0 + PI * i / 12.0) * r)
	return points


## A filled pie from 12 o'clock clockwise, for `share` (0..1) of the circle.
func _pie(c: Vector2, r: float, share: float, fill: Color) -> void:
	if share <= 0.0:
		return
	var points := PackedVector2Array([c])
	var steps: int = maxi(int(share * 32.0), 1)
	for i: int in steps + 1:
		points.append(c + Vector2.from_angle(-PI / 2.0 + TAU * share * i / steps) * r)
	draw_colored_polygon(points, fill)


func _draw_hex(c: Vector2, r: float) -> void:
	var points := PackedVector2Array()
	for i: int in 6:
		points.append(c + Vector2.from_angle(TAU * i / 6.0) * r)
	var inner := PackedVector2Array()
	for point: Vector2 in points:
		inner.append(c + (point - c) * 0.84)
	draw_colored_polygon(points, color)
	draw_colored_polygon(inner, UiStyle.OAK_600 if not cracked else UiStyle.INK_700)
	if cracked:
		draw_polyline(PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.2), c + Vector2(-r * 0.3, -r * 0.05), c + Vector2(-r * 0.2, r * 0.35)]), UiStyle.RIFT_300, 1.5)
	_letter(c, r * 0.95, UiStyle.PARCHMENT_100)


## The shared small shapes: essence glyphs and status shapes.
func _shape(kind: String, c: Vector2, r: float, fill: Color) -> void:
	var w: float = maxf(r / 3.5, 1.2)
	match kind:
		"flame", "flame_core":
			# Three tongues, so it never reads as a droplet.
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r * 0.25, -r * 0.3), c + Vector2(r * 0.6, -r * 0.6), c + Vector2(r * 0.7, r * 0.3),
				c + Vector2(r * 0.4, r * 0.85), c + Vector2(-r * 0.4, r * 0.85), c + Vector2(-r * 0.7, r * 0.3), c + Vector2(-r * 0.6, -r * 0.6),
				c + Vector2(-r * 0.25, -r * 0.3)]), fill)
			if kind == "flame_core":
				draw_circle(c + Vector2(0, r * 0.4), r * 0.3, UiStyle.BRASS_300)
		"droplet":
			draw_circle(c + Vector2(0, r * 0.3), r * 0.6, fill)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.55, r * 0.15), c + Vector2(-r * 0.55, r * 0.15)]), fill)
		"claws":
			for i: int in 3:
				var x: float = (i - 1) * r * 0.55
				draw_line(c + Vector2(x - r * 0.3, r * 0.8), c + Vector2(x + r * 0.3, -r * 0.8), fill, w)
		"block":
			draw_rect(Rect2(c - Vector2(r * 0.7, r * 0.7), Vector2(r * 1.4, r * 1.4)), fill)
		"leaf":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, r * 0.8), c + Vector2(-r * 0.5, -r * 0.3), c + Vector2(r * 0.8, -r * 0.8), c + Vector2(r * 0.4, r * 0.4)]), fill)
			draw_line(c + Vector2(-r * 0.8, r * 0.8), c + Vector2(r * 0.4, -r * 0.4), UiStyle.INK_900 if fill != UiStyle.INK_900 else UiStyle.PARCHMENT_100, w * 0.5)
		"snowflake":
			for i: int in 3:
				var d: Vector2 = Vector2.from_angle(PI * i / 3.0 + PI / 2.0) * r
				draw_line(c - d, c + d, fill, w)
		"bolt":
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.3, -r), c + Vector2(-r * 0.5, r * 0.15), c + Vector2(-r * 0.05, r * 0.15), c + Vector2(-r * 0.3, r), c + Vector2(r * 0.5, -r * 0.15), c + Vector2(r * 0.05, -r * 0.15)]), fill)
		"crescent":
			draw_arc(c, r * 0.7, PI * 0.35, PI * 1.65, 16, fill, w * 1.6)
		"circle":
			draw_circle(c, r * 0.8, fill)
		"diamond":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.75, 0), c + Vector2(0, r), c + Vector2(-r * 0.75, 0)]), fill)
		"hourglass":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, -r), c + Vector2(r * 0.7, -r), c]), fill)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, r), c + Vector2(r * 0.7, r), c]), fill)
		"bar":
			draw_rect(Rect2(c - Vector2(r * 0.9, r * 0.3), Vector2(r * 1.8, r * 0.6)), fill)
		_:
			draw_circle(c, r * 0.5, fill)


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
