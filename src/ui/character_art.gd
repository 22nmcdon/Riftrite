class_name CharacterArt
extends RefCounted
## The character art from tools/art/characters.py (art/ui/characters): each
## hero's and enemy's figure (body, and what it holds on its own layer so it
## can swing), its round portrait, and rig.json (the hand the held layer
## pivots on, and whether it's a beast). Fight units are named
## "<enemy id>_<n>"; base_id() finds their art.

const DIR: String = "res://art/ui/characters/"
## The figure canvas (pixels at 1x; the art is imported at 2x).
const CANVAS := Vector2(128, 160)

static var _rig: Dictionary = {}
static var _cache: Dictionary[String, Texture2D] = {}


## The art id for a hero id, an enemy id, or a fight unit id ("rift_pup_2").
static func base_id(unit_id: String) -> String:
	if has_art(unit_id):
		return unit_id
	var cut: int = unit_id.rfind("_")
	if cut > 0 and unit_id.substr(cut + 1).is_valid_int():
		return unit_id.substr(0, cut)
	return unit_id


static func has_art(char_id: String) -> bool:
	return rig().has(char_id)


static func rig() -> Dictionary:
	if _rig.is_empty() and FileAccess.file_exists(DIR + "rig.json"):
		_rig = JSON.parse_string(FileAccess.get_file_as_string(DIR + "rig.json"))
	return _rig


static func portrait(char_id: String) -> Texture2D:
	return _texture(char_id, "portrait")


static func body(char_id: String) -> Texture2D:
	return _texture(char_id, "body")


## What the figure holds, or null (beasts hold nothing).
static func held(char_id: String) -> Texture2D:
	return _texture(char_id, "held")


## The held layer's pivot (the hand), in canvas pixels.
static func hand(char_id: String) -> Vector2:
	var hand_point: Array = (rig().get(char_id, {}) as Dictionary).get("hand", [88, 108])
	return Vector2(hand_point[0], hand_point[1])


static func is_beast(char_id: String) -> bool:
	return (rig().get(char_id, {}) as Dictionary).get("beast", false)


static func _texture(char_id: String, part: String) -> Texture2D:
	var key: String = char_id + ":" + part
	if not _cache.has(key):
		var path: String = "%s%s_%s.svg" % [DIR, char_id, part]
		_cache[key] = load(path) as Texture2D if not char_id.is_empty() and ResourceLoader.exists(path) else null
	return _cache[key]
