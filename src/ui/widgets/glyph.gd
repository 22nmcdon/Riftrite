class_name Glyph
extends Control
## Placeholder icons drawn in code, from the old UI look (now in
## docs/archive/): status shapes, hex relic tokens, and unit portraits
## (character art when there is some). The art rehaul (rebuild phase 7)
## replaces them.

enum Shape { PORTRAIT, DOT, STATUS, HEX }

const ENEMY := Color("7a3b4a")
## Each status's shape, so statuses read without color.
const STATUS_SHAPES: Dictionary[String, String] = {"burn": "flame", "poison": "circle", "bleed": "droplet"}

var shape: Shape = Shape.DOT
var color: Color = Color.WHITE
## The portrait's or hex's letter, or a status shape.
var text: String = ""
## HEX: draw the rift bleed (cracks).
var cracked: bool = false
## PORTRAIT or HEX: the art, drawn instead of the code-drawn look (null:
## none).
var art: Texture2D = null
## PORTRAIT art's tint (grey for a fallen unit).
var modulate_art: Color = Color.WHITE

## Relic art already looked up: "relic:<id>" -> texture, or null when there's none.
static var _art_cache: Dictionary[String, Texture2D] = {}


## A round portrait: the character's art when `char_id` has some
## (CharacterArt), else their initial on their color.
static func portrait(letter: String, fill: Color, size: int = 40, char_id: String = "") -> Glyph:
	var glyph: Glyph = _make(Shape.PORTRAIT, fill, letter.substr(0, 1).to_upper(), size)
	glyph.art = CharacterArt.portrait(CharacterArt.base_id(char_id)) if not char_id.is_empty() else null
	if glyph.art != null:
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return glyph


static func dot(fill: Color, size: int = 12) -> Glyph:
	return _make(Shape.DOT, fill, "", size)


static func status(status_id: String, size: int = 14) -> Glyph:
	return _make(Shape.STATUS, UiStyle.STATUS_COLORS.get(status_id, UiStyle.EMBER), STATUS_SHAPES.get(status_id, "circle"), size)


## Where relic art lives; `%s` is the relic's id.
const RELIC_ART: String = "res://art/ui/relics/relic_%s.svg"


## A relic as a hex token: rim in its rarity color, and its art inside (or
## its initial, without art).
static func hex(name: String, rim: Color, size: int = 44, rift: bool = false, relic_id: String = "") -> Glyph:
	var glyph: Glyph = _make(Shape.HEX, rim, name.substr(0, 1).to_upper(), size)
	glyph.cracked = rift
	glyph.art = relic_art(relic_id)
	if glyph.art != null:
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return glyph


## A relic's art as a texture, or null when it has none.
static func relic_art(relic_id: String) -> Texture2D:
	if relic_id.is_empty():
		return null
	var key: String = "relic:" + relic_id
	if not _art_cache.has(key):
		var art_path: String = RELIC_ART % relic_id
		_art_cache[key] = load(art_path) as Texture2D if ResourceLoader.exists(art_path) else null
	return _art_cache[key]


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
	var r: float = s / 2.0
	match shape:
		Shape.PORTRAIT when art != null:
			draw_texture_rect(art, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, modulate_art)
		Shape.PORTRAIT:
			draw_circle(c, r, color.darkened(0.45))
			draw_circle(c, r - 3.0, color)
			_letter(c, s * 0.55, UiStyle.INK_900)
		Shape.DOT:
			draw_circle(c, r, color)
		Shape.STATUS:
			_shape(text, c, r, color)
		Shape.HEX:
			_draw_hex(c, r)


func _letter(c: Vector2, font_size_f: float, ink: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = int(font_size_f)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(c.x - width / 2.0, c.y + font_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


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
	if art != null:
		var inner_r: float = r * 0.78
		draw_texture_rect(art, Rect2(c - Vector2(inner_r, inner_r), Vector2(inner_r, inner_r) * 2.0), false)
	else:
		_letter(c, r * 0.95, UiStyle.PARCHMENT_100)


## The status shapes.
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

