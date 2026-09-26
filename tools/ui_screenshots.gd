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
	var session: RunSession = RunSession.open(SAVE_PATH, "")
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
	session.select(session.state.heroes[0].items[0].uid)
	await _snap("caravan_bought")
	await _showcase(session)
	session.leave_caravan()
	await _snap("stop_choice")
	session.pick_stop(0)
	await _snap("stop")
	session.leave_stop()
	await _snap("fight_preview")
	(_main.screen as FightScreen).start_fight()
	var fight: FightScreen = _main.screen
	fight.player.speed = 4.0
	for frame: int in 90:
		await process_frame
	await _snap("fight_playing")
	fight._on_entries(fight.player.skip_to_end())
	await _snap("fight_end")
	fight._continue()
	await _snap("after_fight")
	session.abandon()
	quit()


## A screenshot of the asset-design look: every rarity, each infusion gem
## form, spill arrows at Resonant, an enemy-only item, and relics. It edits
## a throwaway copy of the run for the picture only, then puts it back.
func _showcase(session: RunSession) -> void:
	var saved: Dictionary = session.state.to_dict()
	var state: RunState = session.state
	var content: ContentDb = session.content
	var resonant: int = content.tuning.xp_to_resonant
	state.stash.clear()
	var picks: Array[Array] = [
		["hearth_knife", [] as Array[String], 0], ["twin_daggers", ["ember"] as Array[String], resonant],
		["dusk_tome", ["frost"] as Array[String], 0], ["pack_bond", [] as Array[String], 0],
		["tallow_torch", ["ember"] as Array[String], resonant],
	]
	for pick: Array in picks:
		var item := RunItem.make(state.take_uid(), pick[0], 1)
		item.essence_ids = pick[1]
		item.xp = pick[2]
		state.stash.append(item)
	state.discovered.append_array(["wildfire_torch", "arcanist_trait", "paper_cuts"] as Array[String])
	# The Epic item twice: an alloy and a pure double, both Resonant.
	state.heroes[0].items.clear()
	for essences: Array[String] in [["frost", "storm"] as Array[String], ["venom", "venom"] as Array[String]]:
		var fancy := RunItem.make(state.take_uid(), "night_lantern", 2)
		fancy.essence_ids = essences
		fancy.xp = resonant
		state.heroes[0].items.append(fancy)
	state.pouch.append_array(["ember", "venom", "wrath", "stone", "verdant", "frost", "storm", "umbral"] as Array[String])
	for relic_id: String in content.relic_ids.slice(0, 3) + [content.relic_ids[-1]]:
		state.relics.append(relic_id)
	session.select(-1)
	await _snap("showcase")
	session.state = RunState.from_dict(saved, content)[0]
	session.select(-1)


func _snap(name: String) -> void:
	for frame: int in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	_shot += 1
	var path: String = _out.path_join("%02d_%s.png" % [_shot, name])
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
