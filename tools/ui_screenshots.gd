extends SceneTree
## Renders each screen to PNGs (for checking the layout by eye). Needs a
## display, e.g.:
##   xvfb-run godot --path . -s tools/ui_screenshots.gd -- --out=/tmp/shots
## After the rebuild's gut the title was the only screen; phase 3 adds the
## arena board, then its screens.

var _main: Main
var _out: String = "user://screenshots"
var _shot: int = 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(1920, 1080)
	_main = (load("res://src/ui/main.gd") as GDScript).new()
	# Leave any real save file alone.
	_main.old_save_path = "user://screenshot_no_save.json"
	root.add_child(_main)
	_run.call_deferred()


func _run() -> void:
	await _snap("title")
	await _snap_boards()
	quit(0)


## The arena view on its own (phase 3, step 2): Sentinel Gate's board in
## placement mode, and Moth Cloud's in fight mode, with Brannoc guarding.
func _snap_boards() -> void:
	var content: ContentDb = ContentDb.load_dir("res://data")
	var formation: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(3, 0), "vell": Vector2i(4, 0)}
	for shot: Array in [["sentinel_gate", ArenaView.Mode.PLACEMENT], ["moth_cloud", ArenaView.Mode.FIGHT]]:
		var errors: Array[String] = []
		var backing := ColorRect.new()
		backing.color = UiStyle.BACKGROUND
		backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_main.add_child(backing)
		var view := ArenaView.new()
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backing.add_child(view)
		view.show_setup(Encounters.setup(content, shot[0], formation, 1, errors), content)
		view.set_mode(shot[1])
		await _snap("board_%s" % shot[0])
		backing.queue_free()


func _snap(name: String) -> void:
	for frame: int in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	_shot += 1
	var path: String = _out.path_join("%02d_%s.png" % [_shot, name])
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
