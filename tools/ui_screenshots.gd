extends SceneTree
## Renders each screen of a scripted run to PNGs (for checking the layout by
## eye). Needs a display, e.g.:
##   xvfb-run godot --path . -s tools/ui_screenshots.gd -- --out=/tmp/shots
## Uses its own save file, so a real saved run is left alone.

const SAVE_PATH: String = "user://screenshot_run.json"

var _main: Main
var _out: String = "user://screenshots"
var _shot: int = 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(1920, 1080)
	var session: RunSession = RunSession.open(SAVE_PATH)
	session.fixed_seed = 1
	_main = (load("res://src/ui/main.gd") as GDScript).new()
	_main.session = session
	root.add_child(_main)
	_run.call_deferred()


func _run() -> void:
	var session: RunSession = _main.session
	await _snap("title")
	session.new_run(session.next_seed())
	await _snap("run_start_hero")
	session.pick_start_hero(0)
	session.pick_package(0)
	await _snap("caravan")
	for i: int in 2:
		session.buy(i)
	for item: RunItem in session.state.stash.duplicate():
		session.move_item(item.uid, session.state.heroes[0].hero_id, 99)
	await _snap("caravan_bought")
	session.leave_caravan()
	await _snap("stop_choice")
	session.pick_stop(0)
	await _snap("stop")
	session.leave_stop()
	await _snap("fight_preview")
	(_main.screen as FightScreen).start_fight()
	var fight: FightScreen = _main.screen
	fight.player.speed = 4.0
	for frame: int in 30:
		await process_frame
	await _snap("fight_playing")
	fight._on_entries(fight.player.skip_to_end())
	await _snap("fight_end")
	fight._continue()
	await _snap("after_fight")
	session.abandon()
	quit()


func _snap(name: String) -> void:
	for frame: int in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	_shot += 1
	var path: String = _out.path_join("%02d_%s.png" % [_shot, name])
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
