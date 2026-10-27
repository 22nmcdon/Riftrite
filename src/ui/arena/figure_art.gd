class_name FigureArt
extends RefCounted
## The figures the board draws for units (art/figures/; placeholder SVGs
## made by tools/art/hero_kit.py and tools/art/enemy_kit.py until the
## commissioned PNGs replace them, docs/plans/art/asset-contract.md, section 3).
## Every figure shares one canvas: CANVAS game units, facing right, its feet
## at FEET; a figure the manifest marks `"scale": 2` (a boss) has a canvas
## twice the size and is drawn twice as tall. A file may hold any number of
## pixels per canvas unit (the SVGs 1, the PNG masters 4): it's drawn
## stretched to its canvas. A hero has a folder with a figure per form
## ("brannoc/base", one per path, one per apex as they're drawn); an enemy has one
## ("rift_pup"), and may have one per specialization ("rift_hound_ashback").
## Summons are enemies, so they have theirs.
## What each figure covers of its canvas (what's drawn, not the empty room
## around it), in canvas units, is in art/figures/bounds.json, written by
## tools/art/figure_bounds.gd, so the bars sit on a figure's head and its
## rect is what the pointer hovers. A test checks the file is up to date.
## The manifest (art/figures/figures.json, by hand from what the artist
## supplies) gives each figure's points in its canvas units: `head` (where
## the bars sit), `muzzle` (where its shots leave), `hand` and `parts` (for
## cut-out animation later), and `scale`. A missing point falls back to the
## drawn box: the head at its top middle, the muzzle at its middle.

const DIR: String = "res://art/figures/"
const BOUNDS_FILE: String = "bounds.json"
const MANIFEST_FILE: String = "figures.json"
const BOUNDS: String = DIR + BOUNDS_FILE
const MANIFEST: String = DIR + MANIFEST_FILE
const CANVAS := Vector2(300, 520)
const FEET := Vector2(150, 500)
## The manifest's fields.
const FIELDS: Array[String] = ["head", "hand", "muzzle", "scale", "parts"]

## Where the figures are read from: DIR, or a test's fixtures (use_root).
static var root: String = DIR
## bounds.json and figures.json as read (once a root).
static var _bounds: Dictionary = {}
static var _manifest: Dictionary = {}
static var _read: bool = false


## Reads figures, bounds.json, and figures.json from `folder` from now on
## (tests point it at their fixtures, then back at DIR).
static func use_root(folder: String) -> void:
	root = folder
	_read = false


static func _read_files() -> void:
	if _read:
		return
	_read = true
	_bounds = _json(root + BOUNDS_FILE)
	_manifest = _json(root + MANIFEST_FILE)


static func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return parsed if parsed is Dictionary else {}


## The figure's name for a hero or enemy kit: "heroes/<id>/<form>" or
## "enemies/<id>".
static func key_for(kit_id: String, hero: bool, form: String = "base") -> String:
	return "heroes/%s/%s" % [kit_id, form] if hero else "enemies/%s" % kit_id


static func has_figure(key: String) -> bool:
	return texture(key) != null


## The figure's texture (its PNG, else its SVG), or null if there's no art
## for it.
static func texture(key: String) -> Texture2D:
	return ArtFile.texture(root + key) if not key.is_empty() else null


## The figure's manifest entry ({} without one).
static func entry(key: String) -> Dictionary:
	_read_files()
	return _manifest.get(key, {})


## 1, or 2 for a figure the manifest marks as a boss's.
static func scale_of(key: String) -> int:
	return int(entry(key).get("scale", 1))


## The figure's canvas and where its feet are on it, in game units.
static func canvas(key: String) -> Vector2:
	return CANVAS * scale_of(key)


static func feet(key: String) -> Vector2:
	return FEET * scale_of(key)


## The file's pixels per canvas unit (1 for the placeholder SVGs, 4 for a
## PNG master; 1 without art).
static func pixels_per_unit(key: String) -> float:
	var art: Texture2D = texture(key)
	return art.get_width() / canvas(key).x if art != null else 1.0


## What the figure covers, in its canvas units (the whole canvas if unknown).
static func bounds(key: String) -> Rect2:
	_read_files()
	var rect: Array = _bounds.get(key, [])
	if rect.size() != 4:
		return Rect2(Vector2.ZERO, canvas(key))
	return Rect2(rect[0], rect[1], rect[2], rect[3])


## A manifest point in canvas units, or `fallback` without one.
static func point(key: String, field: String, fallback: Vector2) -> Vector2:
	var at: Variant = entry(key).get(field)
	return Vector2(at[0], at[1]) if at is Array and (at as Array).size() == 2 else fallback


## Where the bars sit: the manifest's head, else the drawn box's top middle.
static func head(key: String) -> Vector2:
	var drawn: Rect2 = bounds(key)
	return point(key, "head", Vector2(drawn.get_center().x, drawn.position.y))


## Where its shots leave: the manifest's muzzle, else the drawn box's middle.
static func muzzle(key: String) -> Vector2:
	return point(key, "muzzle", bounds(key).get_center())
