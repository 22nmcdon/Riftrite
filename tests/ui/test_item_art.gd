extends GutTest
## Item art (docs/ui-asset-design.md, 8.1 and 15): each file in
## art/ui/items/ belongs to a real item and is imported so it stays smooth
## when drawn small; an item with art shows it, and one without keeps its
## drawn kind icon.

const U = preload("res://tests/ui/ui_test_kit.gd")
const ART_DIR: String = "res://art/ui/items/"

var _content: ContentDb


func before_all() -> void:
	_content = U.K.content()


func _art_files() -> Array[String]:
	var files: Array[String] = []
	for file: String in DirAccess.get_files_at(ART_DIR):
		if file.ends_with(".svg"):
			files.append(file)
	return files


func test_there_is_item_art() -> void:
	assert_gt(_art_files().size(), 0)


func test_every_art_file_names_a_real_item() -> void:
	for file: String in _art_files():
		assert_true(file.begins_with("item_"), file)
		var item_id: String = file.trim_prefix("item_").trim_suffix(".svg")
		assert_true(_content.items.has(item_id), "%s: no item called %s" % [file, item_id])


func test_art_is_imported_large_with_mipmaps() -> void:
	for file: String in _art_files():
		var settings := ConfigFile.new()
		assert_eq(settings.load(ART_DIR + file + ".import"), OK, file + " has no .import (run godot --headless --import)")
		assert_eq(settings.get_value("params", "mipmaps/generate", false), true, file + ": run tools/art/item_icons.py")
		assert_eq(settings.get_value("params", "svg/scale", 1.0), 2.0, file + ": run tools/art/item_icons.py")
		var texture: Texture2D = load(ART_DIR + file)
		assert_eq(texture.get_width(), 128, file)


func test_items_with_art_show_it_and_others_keep_the_drawn_icon() -> void:
	var with_art: Glyph = autofree(Glyph.item(_content.items["oak_buckler"], Color.WHITE))
	assert_not_null(with_art.art)
	assert_eq(with_art.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	var without: Glyph = autofree(Glyph.item(_content.items["night_lantern"], Color.WHITE))
	assert_null(without.art, "night_lantern has no art yet: it keeps its kind icon")
	assert_eq(without.text, "healing")
