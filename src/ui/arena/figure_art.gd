class_name FigureArt
extends RefCounted
## The figures the board draws for units (art/figures/, made by
## tools/art/hero_kit.py and tools/art/enemy_kit.py; placeholder art until
## phase 7). Every figure shares one canvas: CANVAS, facing right, its feet
## at FEET. A hero has a figure per form ("brannoc_base", later one per
## path); an enemy has one ("rift_pup"). Summons are enemies, so they have
## theirs.
## What each figure covers of its canvas (what's drawn, not the empty room
## around it) is in art/figures/bounds.json, written by
## tools/art/figure_bounds.gd, so the bars sit on a figure's head and its
## rect is what the pointer hovers. A test checks the file is up to date.

const DIR: String = "res://art/figures/"
const BOUNDS: String = "res://art/figures/bounds.json"
const CANVAS := Vector2(300, 520)
const FEET := Vector2(150, 500)

static var _bounds: Dictionary = {}
static var _cache: Dictionary[String, Texture2D] = {}


## The figure's name for a hero or enemy kit: "heroes/<id>_<form>" or
## "enemies/<id>".
static func key_for(kit_id: String, hero: bool, form: String = "base") -> String:
	return "heroes/%s_%s" % [kit_id, form] if hero else "enemies/%s" % kit_id


static func has_figure(key: String) -> bool:
	return texture(key) != null


## The figure's texture, or null if there's no art for it.
static func texture(key: String) -> Texture2D:
	if not _cache.has(key):
		var path: String = "%s%s.svg" % [DIR, key]
		_cache[key] = load(path) as Texture2D if not key.is_empty() and ResourceLoader.exists(path) else null
	return _cache[key]


## What the figure covers, in canvas pixels (the whole canvas if unknown).
static func bounds(key: String) -> Rect2:
	if _bounds.is_empty() and FileAccess.file_exists(BOUNDS):
		_bounds = JSON.parse_string(FileAccess.get_file_as_string(BOUNDS))
	var rect: Array = _bounds.get(key, [])
	if rect.size() != 4:
		return Rect2(Vector2.ZERO, CANVAS)
	return Rect2(rect[0], rect[1], rect[2], rect[3])


## A figure for a panel: what it covers of its canvas, fitted into `height`
## pixels tall (and `width` wide; 0: 0.6 of the height), or an empty rect
## without art.
static func portrait(key: String, height: float, width: float = 0.0) -> TextureRect:
	var rect := TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(width if width > 0.0 else height * 0.6, height)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art: Texture2D = texture(key)
	if art != null:
		var region := AtlasTexture.new()
		region.atlas = art
		region.region = bounds(key)
		rect.texture = region
	return rect
