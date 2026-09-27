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
	await _snap("run_start_hero_2")
	session.pick_start_hero(0)
	session.pick_start_hero(0)
	await _snap("run_start_package")
	session.pick_package(0)
	await _snap("stop_choice")
	session.pick_stop(0)
	await _snap("shop")
	for i: int in 2:
		session.buy(i)
	for item: RunItem in session.state.stash.duplicate():
		session.move_item(item.uid, session.state.heroes[0].hero_id, 99)
	session.select(session.state.heroes[0].items[0].uid)
	await _snap("shop_bought")
	await _showcase(session)
	session.leave_stop()
	session.pick_stop(1)
	await _snap("stop")
	session.leave_stop()
	await _snap("fight_choice")
	session.pick_fight(0)
	await _snap("fight_preview")
	(_main.screen as FightScreen).start_fight()
	var fight: FightScreen = _main.screen
	fight.player.speed = 4.0
	for frame: int in 90:
		await process_frame
	await _snap("fight_playing")
	fight.set_log_open(true)
	await _snap("fight_chart")
	fight.chart.show_tab(FightTally.Tab.TAKEN)
	await _snap("fight_chart_taken")
	fight.chart.show_tab(FightTally.Tab.DAMAGE)
	fight.set_log_open(false)
	# A few frames apart at 1x, to catch the animations mid-swing.
	fight.set_speed(1.0)
	for shot: int in 3:
		for frame: int in 6:
			await process_frame
		await _snap("fight_action_%d" % shot)
	fight._on_entries(fight.player.skip_to_end())
	await _snap("fight_end")
	fight._continue()
	await _snap("after_fight")
	# An elite day's fight choice (a look only: the day is set by hand).
	session.state.day = 3
	session.state.fight_options = RunFlow.fights_for_day(session.state, session.run, 3)
	session.state.encounter_id = ""
	session.state.phase = "fight_choice"
	_main.refresh()
	await _snap("fight_choice_elite")
	# The run's end (a look only: the phase is set by hand, then the run is
	# abandoned, which deletes this tool's own save).
	session.state.phase = "run_over"
	_main.refresh()
	await _snap("run_end")
	session.abandon()
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
	# The first hero at A: an awakened alloy (Plasma), a Resonant single that
	# spills Ember to the other Blade item, and that item.
	state.heroes[0].rank = 2
	state.heroes[0].needs_specialization = false
	state.heroes[0].specialization_id = ""
	for spec_id: String in content.specialization_ids:
		if content.specializations[spec_id].hero == state.heroes[0].hero_id:
			state.heroes[0].specialization_id = spec_id
			break
	# Deeds: the calling at level 2 with its choice waiting, the
	# specialization at level 1.
	state.heroes[0].calling_progress = content.heroes[state.heroes[0].hero_id].calling.deed.goals[1]
	if not state.heroes[0].specialization_id.is_empty():
		state.heroes[0].spec_progress = content.specializations[state.heroes[0].specialization_id].track.deed.goals[0]
	state.heroes[0].items.clear()
	for loadout: Array in [["night_lantern", ["ember", "storm"] as Array[String]], ["grave_hook", ["ember"] as Array[String]], ["hearth_knife", [] as Array[String]]]:
		var held := RunItem.make(state.take_uid(), loadout[0], 2)
		held.essence_ids = loadout[1]
		held.xp = resonant if not held.essence_ids.is_empty() else 0
		state.heroes[0].items.append(held)
	state.pouch.append_array(["ember", "venom", "wrath", "stone", "verdant", "frost", "storm", "umbral"] as Array[String])
	for relic_id: String in content.relic_ids.slice(0, 3) + [content.relic_ids[-1]]:
		state.relics.append(relic_id)
	session.select(-1)
	await _snap("showcase")
	# The hero sheet open, and the hover card over a stash item.
	session.open_hero(state.heroes[0].hero_id)
	await _snap("showcase_sheet")
	for node: Node in _main.guild_bar().find_children("*", "ItemTile", true, false):
		(node as ItemTile).mouse_entered.emit()
		break
	await _snap("showcase_hover")
	session.select(state.heroes[0].items[2].uid)
	await _snap("showcase_spill_received")
	session.select(-1)
	session.open_hero("")
	# Legendaries: a Devourer that has eaten, and an Essence-hungry one to feed.
	state.stash.clear()
	for legendary_id: String in ["maw_of_the_hollow", "hungering_censer", "tallymans_bow"]:
		RunActions.add_item(state, content, legendary_id)
	state.stash[0].eaten.append_array(["hearth_knife", "rimewood_longbow"] as Array[String])
	state.stash[0].progress = 2
	state.stash[2].progress = 41
	state.stash.append(RunItem.make(state.take_uid(), "hearth_knife", 1))
	session.select(state.stash[0].uid)
	await _snap("legendary_devourer")
	session.select(state.stash[-1].uid)
	await _snap("legendary_feed_to")
	session.select(-1)
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
