class_name ArtFile
extends RefCounted
## Every art file the game loads (docs/plans/rebuild-phase7a-asset-loading.md):
## the file ArtPath names (a PNG before its SVG), loaded once and cached.

static var _cache: Dictionary[String, Texture2D] = {}


## The texture for `path`, or null if there's no art for it.
static func texture(path: String) -> Texture2D:
	if not _cache.has(path):
		var file: String = ArtPath.resolve(path)
		_cache[path] = load(file) as Texture2D if not file.is_empty() else null
	return _cache[path]
