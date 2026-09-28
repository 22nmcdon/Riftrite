extends GutTest
## The game boots to the title (docs/plans/rebuild-build-order.md, phase 0);
## its way in is Practice (phase 3, tested in test_practice_flow.gd).

const MainScript = preload("res://src/ui/main.gd")
const SAVE: String = "user://test_old_run.json"


func after_each() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)


func _main() -> Main:
	var main: Main = MainScript.new()
	main.old_save_path = SAVE
	add_child_autofree(main)
	return main


func test_the_game_boots_to_the_title() -> void:
	var main: Main = _main()
	assert_true(main.screen is TitleScreen)
	var texts: Array[String] = []
	for node: Node in main.screen.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	assert_has(texts, "Riftrite")
	assert_has(texts, TitleScreen.REBUILD_NOTE)
	var buttons: Array[String] = []
	for node: Node in main.screen.find_children("*", "Button", true, false):
		buttons.append((node as Button).text)
	assert_eq(buttons, ["Practice", "Quit"] as Array[String], "Practice, and no run to start or continue yet")


func test_the_main_scene_is_the_title() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://src/ui/main.tscn")
	var scene: Node = (load("res://src/ui/main.tscn") as PackedScene).instantiate()
	assert_true(scene is Main)
	scene.free()


func test_a_save_from_before_the_rebuild_is_dropped() -> void:
	var file: FileAccess = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string("{\"version\": 2}")
	file.close()
	_main()
	assert_false(FileAccess.file_exists(SAVE), "the old save can't be loaded, so it's dropped quietly")


func test_no_save_is_fine() -> void:
	_main()
	assert_false(FileAccess.file_exists(SAVE))
