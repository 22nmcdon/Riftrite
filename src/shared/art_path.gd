class_name ArtPath
extends RefCounted
## Which file the game loads for an art path (docs/plans/art/asset-contract.md,
## section 2): `<name>.png` if it exists, otherwise `<name>.svg`, so
## commissioned art replaces a placeholder by dropping in a PNG of the same
## name. A path may name either extension, or none. Shared by the UI
## (ArtFile, which loads and caches the textures) and the run (RunContent,
## which checks its data names art that exists), so neither reaches into the
## other.

const KINDS: Array[String] = ["png", "svg"]


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
