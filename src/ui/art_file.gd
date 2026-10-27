class_name ArtFile
extends RefCounted
## Every art file the game loads (docs/plans/asset-contract.md, section 2;
## docs/plans/rebuild-phase7a-asset-loading.md): `<name>.png` if it exists,
## otherwise `<name>.svg`, so commissioned art replaces a placeholder by
## dropping in a PNG of the same name. A path may name either extension, or
## none; textures are cached.

const KINDS: Array[String] = ["png", "svg"]

static var _cache: Dictionary[String, Texture2D] = {}


## The file the game loads for `path`: its PNG if there is one, else its
## SVG, else "".
static func resolve(path: String) -> String:
	var stem: String = path.get_basename() if KINDS.has(path.get_extension()) else path
	for kind: String in KINDS:
		var file: String = "%s.%s" % [stem, kind]
		if ResourceLoader.exists(file):
			return file
	return ""


static func exists(path: String) -> bool:
	return not resolve(path).is_empty()


## The texture for `path` (see resolve), or null if there's no art for it.
static func texture(path: String) -> Texture2D:
	if not _cache.has(path):
		var file: String = resolve(path)
		_cache[path] = load(file) as Texture2D if not file.is_empty() else null
	return _cache[path]
