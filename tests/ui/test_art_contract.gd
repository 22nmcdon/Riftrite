extends GutTest
## The art in art/ keeps docs/plans/asset-contract.md (built in phase 7a,
## docs/plans/rebuild-phase7a-asset-loading.md): every manifest entry names a
## figure and keeps its points inside its canvas, every PNG has the
## contract's size, and every texture imports with mipmaps.

## The contract's PNG sizes by folder (a figure's by its scale).
const SIZES: Dictionary[String, Vector2i] = {
	"res://art/portraits/": Vector2i(1024, 1024),
	"res://art/ui/items/glyphs/": Vector2i(512, 512),
	"res://art/ui/statuses/": Vector2i(256, 256),
	"res://art/ui/icons/": Vector2i(256, 256),
}
const FIGURE_MASTER := Vector2i(1200, 2080)


func test_the_project_imports_textures_with_mipmaps() -> void:
	var defaults: Dictionary = ProjectSettings.get_setting("importer_defaults/texture", {})
	assert_true(defaults.get("mipmaps/generate", false), "a dropped PNG imports with mipmaps untouched")
	for path: String in _files("res://art/", "import"):
		if path.begins_with("res://art/look-tests/") or path.begins_with("res://art/fonts/"):
			continue
		assert_string_contains(FileAccess.get_file_as_string(path), "mipmaps/generate=true", false)


func test_every_manifest_entry_is_sound() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FigureArt.MANIFEST))
	assert_true(parsed is Dictionary, "figures.json is an object, by figure")
	var manifest: Dictionary = parsed if parsed is Dictionary else {}
	for key: String in manifest:
		var entry: Dictionary = manifest[key]
		assert_true(FigureArt.has_figure(key), "%s names a figure" % key)
		for field: String in entry:
			assert_has(FigureArt.FIELDS, field, "%s: %s is a manifest field" % [key, field])
		assert_has([1, 2], int(entry.get("scale", 1)), "%s: scale 1 or 2" % key)
		var canvas := Rect2(Vector2.ZERO, FigureArt.canvas(key))
		for field: String in ["head", "hand", "muzzle"]:
			if entry.has(field):
				assert_true(_inside(entry[field], canvas), "%s: %s inside its canvas" % [key, field])
		var parts: Dictionary = entry.get("parts", {})
		for part: String in parts:
			assert_true(_inside(parts[part], canvas), "%s: part %s's pivot inside its canvas" % [key, part])


func test_every_png_has_the_contracts_size() -> void:
	var checked: int = 0
	for path: String in _files(FigureArt.DIR, "png"):
		var key: String = path.trim_prefix(FigureArt.DIR).get_basename()
		assert_eq(_size(path), FIGURE_MASTER * FigureArt.scale_of(key), path)
		checked += 1
	for folder: String in SIZES:
		for path: String in _files(folder, "png"):
			assert_eq(_size(path), SIZES[folder], path)
			checked += 1
	if checked == 0:
		pass_test("no commissioned PNGs yet")


static func _inside(point: Variant, canvas: Rect2) -> bool:
	return point is Array and (point as Array).size() == 2 and canvas.grow(0.5).has_point(Vector2(point[0], point[1]))


static func _size(path: String) -> Vector2i:
	var image := Image.new()
	image.load(ProjectSettings.globalize_path(path))
	return image.get_size()


## Every file under `folder` (and its folders) ending in `extension`.
static func _files(folder: String, extension: String) -> Array[String]:
	var found: Array[String] = []
	if not DirAccess.dir_exists_absolute(folder):
		return found
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.get_extension() == extension:
			found.append(folder + file_name)
	for sub: String in DirAccess.get_directories_at(folder):
		found.append_array(_files(folder + sub + "/", extension))
	return found
