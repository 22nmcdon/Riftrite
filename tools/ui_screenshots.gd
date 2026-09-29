extends SceneTree
## Renders each screen to PNGs (for checking the layout by eye). Needs a
## display, e.g.:
##   xvfb-run godot --path . -s tools/ui_screenshots.gd -- --out=/tmp/shots
## The title, then Practice (phase 3): the encounter list, placement, the
## fight with its chart, a hero's popup, the result, an area warning, and
## Rift Collapse with the combat log's popup open.

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
	# Practice, through the real screens.
	_main.show_encounters()
	await _snap("practice_encounters")
	var content: ContentDb = _main.practice.content
	_main.show_arena("sentinel_gate")
	var arena: ArenaScreen = _main.screen as ArenaScreen
	arena._on_hovered("rift_worn_sentinel")
	await _snap("placement_sentinel_gate")
	arena._fight()
	for frame: int in 8 * 30:
		arena._process(1.0 / 30.0)
	await _snap("fight_sentinel_gate_8s")
	# Paused, with Brannoc's popup open.
	arena.toggle_pause()
	arena.view.unit_clicked.emit("brannoc")
	await _snap("fight_sentinel_gate_paused_brannoc")
	arena.toggle_pause()
	arena._process(1.0 / 30.0)
	arena.skip()
	await _snap("fight_sentinel_gate_end")
	# Six pups crowding Brannoc (units are 0.2 hex wide: playtest gate 1).
	_main.show_arena("pup_warren")
	var pups: ArenaScreen = _main.screen as ArenaScreen
	pups._fight()
	pups.target_lines.button_pressed = true
	while not pups.player.finished() and pups.player.sim.tick < 4 * 20:
		pups._process(1.0 / 30.0)
	await _snap("fight_pup_warren_crowd")
	# An area warning up (Moth Cloud's Ember Dust), with every target line.
	var moths: ArenaScreen = ArenaScreen.make(PracticeSession.make(content), "moth_cloud")
	_main.show_screen(moths)
	moths._fight()
	moths.target_lines.button_pressed = true
	while not moths.player.finished() and not moths.view.fx.effects.any(func(fx: FightFx.Fx) -> bool: return fx.kind == FightFx.Kind.AREA):
		moths._process(1.0 / 30.0)
	for frame: int in 12:
		moths._process(1.0 / 30.0)
	await _snap("fight_moth_cloud_warning")
	# Rift Collapse starting (Witch Circle runs past 45s): its banner, and
	# the log's popup open, showing only Maren's lines.
	var witches: ArenaScreen = ArenaScreen.make(PracticeSession.make(content), "witch_circle")
	_main.show_screen(witches)
	witches._fight()
	witches.set_log_open(true)
	witches.view.unit_clicked.emit("maren")
	while not witches.player.finished() and witches.player.sim.tick < 91 * 10:
		witches._process(1.0 / 30.0)
	await _snap("fight_witch_circle_collapse")
	quit(0)


func _snap(name: String) -> void:
	for frame: int in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	_shot += 1
	var path: String = _out.path_join("%02d_%s.png" % [_shot, name])
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
