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


## Every figure's covered rect, [x, y, width, height] in canvas pixels, by
## key ("heroes/maren_base").
static func measure_all() -> Dictionary:
	var bounds: Dictionary = {}
	for folder: String in ["heroes", "enemies"]:
		var files: PackedStringArray = DirAccess.get_files_at(FigureArt.DIR + folder)
		for file_name: String in files:
			if file_name.get_extension() == "svg":
				var key: String = "%s/%s" % [folder, file_name.get_basename()]
				bounds[key] = measure(FileAccess.get_file_as_string("%s%s.svg" % [FigureArt.DIR, key]))
	return bounds


## The file's text: one figure a line, sorted.
static func to_json(bounds: Dictionary) -> String:
	var keys: Array = bounds.keys()
	keys.sort()
	var lines: PackedStringArray = []
	for key: String in keys:
		lines.append("\t%s: %s" % [JSON.stringify(key), JSON.stringify(bounds[key])])
	return "{\n%s\n}\n" % ",\n".join(lines)


## The pixels an SVG draws on, at 1x.
static func measure(svg: String) -> Array[int]:
	var image := Image.new()
	image.load_svg_from_string(svg, 1.0)
	var used: Rect2i = image.get_used_rect()
	return [used.position.x, used.position.y, used.size.x, used.size.y]
