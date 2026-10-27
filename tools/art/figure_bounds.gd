extends SceneTree
## Writes art/figures/bounds.json: what each figure in art/figures/ covers of
## its canvas (FigureArt). Rerun it whenever the figures change (after
## tools/art/hero_kit.py or enemy_kit.py); a test fails until you do.
## Usage: godot --headless --path . -s tools/art/figure_bounds.gd


func _init() -> void:
	var bounds: Dictionary = measure_all()
	var file: FileAccess = FileAccess.open(FigureArt.BOUNDS, FileAccess.WRITE)
	file.store_string(to_json(bounds))
	file.close()
	print("wrote %s (%d figures)" % [FigureArt.BOUNDS, bounds.size()])
	quit(0)


## Every figure's covered rect, [x, y, width, height] in its canvas units,
## by key ("heroes/maren_base"): of its PNG where there is one, else its SVG.
static func measure_all() -> Dictionary:
	var bounds: Dictionary = {}
	for folder: String in ["heroes", "enemies"]:
		for file_name: String in DirAccess.get_files_at(FigureArt.root + folder):
			if ArtPath.KINDS.has(file_name.get_extension()):
				var key: String = "%s/%s" % [folder, file_name.get_basename()]
				if not bounds.has(key):
					bounds[key] = measure(ArtPath.resolve(FigureArt.root + key), FigureArt.canvas(key))
	return bounds


## The file's text: one figure a line, sorted.
static func to_json(bounds: Dictionary) -> String:
	var keys: Array = bounds.keys()
	keys.sort()
	var lines: PackedStringArray = []
	for key: String in keys:
		lines.append("\t%s: %s" % [JSON.stringify(key), JSON.stringify(bounds[key])])
	return "{\n%s\n}\n" % ",\n".join(lines)


## What a figure file draws on, in canvas units (`canvas` wide): an SVG at
## its own size, a PNG at however many pixels a unit it has, the rect
## widened to whole units.
static func measure(path: String, canvas: Vector2) -> Array[int]:
	var image := Image.new()
	if path.get_extension() == "svg":
		image.load_svg_from_string(FileAccess.get_file_as_string(path), 1.0)
	else:
		image.load(ProjectSettings.globalize_path(path))
	var per_unit: float = image.get_width() / canvas.x
	var used: Rect2i = image.get_used_rect()
	var start := Vector2i(floori(used.position.x / per_unit), floori(used.position.y / per_unit))
	var end := Vector2i(ceili(used.end.x / per_unit), ceili(used.end.y / per_unit))
	return [start.x, start.y, end.x - start.x, end.y - start.y]
