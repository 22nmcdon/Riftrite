extends SceneTree
## Renders each screen to PNGs (for checking the layout by eye). Needs a
## display, e.g.:
##   xvfb-run godot --path . -s tools/ui_screenshots.gd -- --out=/tmp/shots
## The title, then Practice (phase 3): the encounter list, placement (and
## the hero panel's tabs, paths and snares on the board), the fight with its chart, a hero's popup, the result, an area warning, and
## Rift Collapse with the combat log's popup open. Then the run (phase 5):
## vowing, camp, the Pedlar, the route (the act map), the loadout, a run's
## fight and its result, the pick after it, a relic choice, a hero's panel,
## the Magpie, an event and an oath, Act 2's route and a fight on its water,
## Act 3's boss day (its learned picks) and the Heart's fight over the void,
## and the end.

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
	# Maren's panel (phase 4): the Path tab, vowed to Deadeye; the Kit tab
	# transformed; the Loadout tab, taking Hold your ground (phase 3b).
	arena.open_panel("maren")
	arena.choose_path("maren", "deadeye", PathDef.Stage.VOWED)
	await _snap("panel_path_maren_vowed")
	arena.choose_path("maren", "deadeye", PathDef.Stage.TRANSFORMED)
	arena.hero_panel.show_tab(HeroPanel.Tab.KIT)
	await _snap("panel_kit_maren_transformed")
	arena.hero_panel.show_tab(HeroPanel.Tab.LOADOUT)
	arena.choose_tactic("maren", "hold_ground")
	await _snap("panel_loadout_maren")
	arena.choose_tactic("maren", "")
	arena.choose_path("maren", "", PathDef.Stage.BASE)
	arena.hero_panel.close()
	# A transformed Trapper's snares and a vowed Brannoc on the board.
	arena.choose_path("maren", "trapper", PathDef.Stage.TRANSFORMED)
	arena.choose_path("brannoc", "hearthwall", PathDef.Stage.VOWED)
	await _snap("placement_paths_snares")
	arena.choose_path("maren", "", PathDef.Stage.BASE)
	arena.choose_path("brannoc", "", PathDef.Stage.BASE)
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
	await _run_screens()
	RunSave.erase(_main.run_save_path)
	quit(0)


## A run from seed 7 through the real screens (phase 5), then into Act 2
## (phase 8 part 3).
func _run_screens() -> void:
	_main.show_run_start(7)
	var start: RunStartScreen = _main.screen as RunStartScreen
	start.choose("brannoc", "hearthwall")
	start.choose("maren", "deadeye")
	await _snap("run_vows")
	start.run_started.emit(start.vows, start.run_seed, false)
	var flow: RunFlow = _main.run_session.flow
	await _snap("run_route")
	flow.choose_fight(0)
	flow.state.shards = 12
	_main.show_day()
	await _snap("run_loadout")
	_main.show_run_fight()
	var arena: ArenaScreen = _main.screen as ArenaScreen
	await _snap("run_placement")
	arena._fight()
	for frame: int in 6 * 30:
		arena._process(1.0 / 30.0)
	await _snap("run_fight_6s")
	arena.skip()
	await _snap("run_fight_end")
	arena.continue_run()
	var day: RunDayScreen = _main.screen as RunDayScreen
	if flow.state.pick.is_empty():
		flow.state.pick = Offers.pick(flow.run, flow.state, 0)
		day.refresh()
	flow.state.relic_choice = Offers.relics(flow.run, flow.state, RunFlow.RELIC_SHRINE, 2)
	day.refresh()
	await _snap("run_pick_and_relic")
	day.open_panel("maren")
	await _snap("run_panel_maren")
	day.hero_panel.close()
	# After the fight, the Pedlar; then the day's nodes.
	flow.state.pick.clear()
	flow.state.relic_choice.clear()
	flow.state.phase = RunState.Phase.AFTER
	flow.finish_day()
	day.refresh()
	await _snap("run_pedlar")
	flow.buy(0)
	flow.buy(1)
	if not flow.state.stash.is_empty():
		flow.equip("maren", 0, flow.state.stash[0])
	flow.leave_shop()
	flow.state.nodes.assign(["camp", "rift_tear", "magpie"])
	day.refresh()
	await _snap("run_nodes")
	flow.choose_node(0)
	flow.state.camp.assign(["rest", "train", "fortify"])
	day.refresh()
	await _snap("run_camp")
	# The Magpie's stall (phase 5b's shop scenes).
	flow.state.phase = RunState.Phase.NODES
	flow.state.node = ""
	flow.choose_node(2)
	day.refresh()
	await _snap("run_magpie")
	# An event's scene, and a Bloodied Oath (phase 5c step 8c).
	flow.close_shop()
	flow.state.phase = RunState.Phase.NODES
	flow.state.nodes.assign(["event:kneeling_knight", "oath"])
	flow.choose_node(0)
	day.refresh()
	await _snap("run_event")
	flow.state.phase = RunState.Phase.NODES
	flow.choose_node(1)
	day.refresh()
	await _snap("run_oath")
	# Act 2, the Glassmere (phase 8 part 3): every hero transformed, the
	# route on day 4 (its fights specialized), and a fight on the water.
	for hero: RunState.Hero in flow.state.heroes:
		hero.transformed = true
	flow.state.apex_open = true
	flow._next_act()
	for hero: RunState.Hero in flow.state.heroes:
		flow.vow_apex(hero.id, flow.run.content.paths[hero.path].apexes[0].id)
	flow.state.day = 4
	flow._start_day()
	day.refresh()
	await _snap("act2_route")
	flow.choose_fight(0)
	_main.show_day()
	_main.show_run_fight()
	var wet: ArenaScreen = _main.screen as ArenaScreen
	wet._fight()
	for frame: int in 8 * 30:
		wet._process(1.0 / 30.0)
	await _snap("act2_fight_8s")
	wet.skip()
	wet.continue_run()
	day = _main.screen as RunDayScreen
	# Act 3, the Shattered Crown (8c-6d): every hero at their apex, the boss
	# day's card (what the rift learned from the fights so far), and the
	# Heart's fight over the void.
	for hero: RunState.Hero in flow.state.heroes:
		hero.apex_earned = true
	flow._next_act()
	flow.state.day = 7
	flow._start_day()
	day.refresh()
	await _snap("act3_boss_route")
	flow.choose_fight(0)
	_main.show_day()
	_main.show_run_fight()
	var void_fight: ArenaScreen = _main.screen as ArenaScreen
	void_fight._fight()
	for frame: int in 10 * 30:
		void_fight._process(1.0 / 30.0)
	await _snap("act3_heart_10s")
	void_fight.skip()
	void_fight.continue_run()
	day = _main.screen as RunDayScreen
	flow.state.phase = RunState.Phase.ENDED
	flow.state.outcome = RunState.Outcome.WON
	day.refresh()
	await _snap("run_end")


func _snap(name: String) -> void:
	for frame: int in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	_shot += 1
	var path: String = _out.path_join("%02d_%s.png" % [_shot, name])
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
