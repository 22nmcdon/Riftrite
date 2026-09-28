extends GutTest
## The log panel, the fight chart, and the banners (docs/plans/rebuild-phase3-fight-sandbox.md,
## section 6): names instead of ids, lines colored by side, the chatter
## hidden, a unit's lines on a click, the chart's bars from FightTally, and
## banners for a phase, the collapse, and the end; then all of it on
## ArenaScreen as a fight plays, with fake time.

const K = preload("res://tests/sim/sim_test_kit.gd")
const Chaos = preload("res://tests/sim/chaos_fight.gd")
const U = preload("res://tests/ui/ui_test_kit.gd")

var _content: ContentDb


func before_all() -> void:
	_content = ContentDb.load_dir("res://data")


func _player(encounter_id: String = "the_pack") -> FightPlayer:
	var errors: Array[String] = []
	return FightPlayer.make(Encounters.setup(_content, encounter_id, PracticeSession.DEFAULT_FORMATION, 3, errors), _content)


func _entry(kind: LogEntry.Kind, source: String, target: String, amount: int, extra: Dictionary = {}) -> LogEntry:
	var entry := LogEntry.new()
	entry.kind = kind
	entry.source_unit = source
	entry.target = target
	entry.amount = amount
	for key: String in extra:
		entry.set(key, extra[key])
	return entry


func _is_chatter(entry: LogEntry) -> bool:
	return entry.kind in [LogEntry.Kind.MOVE, LogEntry.Kind.STOP, LogEntry.Kind.TARGET]


# --- names ------------------------------------------------------------------------

func test_names_for_heroes_copies_and_summons() -> void:
	var pack: FightPlayer = _player()
	var names: FightNames = FightNames.make(pack.sim, _content)
	assert_eq(names.names, {"brannoc": "Brannoc", "maren": "Maren", "vell": "Vell", "rift_hound": "Rift Hound 1", "rift_hound#2": "Rift Hound 2", "rift_hound#3": "Rift Hound 3"} as Dictionary[String, String],
		"heroes as their tokens say; copies numbered, the first one too")
	assert_eq(names.hero_ids, ["brannoc", "maren", "vell"] as Array[String])
	assert_eq(names.name_of("nobody"), "nobody")
	var gate: FightNames = FightNames.make(_player("sentinel_gate").sim, _content)
	assert_eq(gate.name_of("rift_worn_sentinel"), "Rift-Worn Sentinel", "a single unit gets no number")
	# The chaos fight's brood summons pups as it goes.
	var chaos: FightPlayer = FightPlayer.make(Chaos.setup(), K.content())
	var chaos_names: FightNames = FightNames.make(chaos.sim, K.content())
	var start: int = chaos_names.names.size()
	chaos.skip_to_end()
	assert_gt(chaos.sim.units.size(), start, "the fight summoned")
	chaos_names.learn(chaos.sim)
	assert_eq(chaos_names.names.size(), chaos.sim.units.size(), "summons are named as they join")
	assert_eq(chaos_names.hero_ids.size(), chaos.sim.heroes.size(), "and nobody is named twice")
	assert_eq(chaos_names.name_of("pup"), "Pup", "the first summon of a kit that wasn't there at the start keeps its plain name")
	assert_eq(chaos_names.name_of("pup#2"), "Pup 2")
	assert_eq(chaos_names.name_of(chaos.sim.heroes[0].id), chaos.sim.heroes[0].def.name, "heroes that aren't content go by their kit's name")


func test_lines_use_names_and_colors_by_side() -> void:
	var names: FightNames = FightNames.make(_player().sim, _content)
	var bite: LogEntry = _entry(LogEntry.Kind.DAMAGE, "rift_hound#2", "brannoc", 12, {"tick": 26, "source_ability_name": "Bite", "mitigated": 4})
	assert_eq(names.text(bite), "[1.30s] Rift Hound 2 · Bite hits Brannoc for 12 (4 blocked by defense)")
	var first: LogEntry = _entry(LogEntry.Kind.DAMAGE, "rift_hound", "rift_hound#3", 5, {"source_ability_name": "Bite"})
	assert_eq(names.text(first), "[0.00s] Rift Hound 1 · Bite hits Rift Hound 3 for 5", "an id isn't matched inside a longer one")
	assert_eq(names.text(_entry(LogEntry.Kind.FIGHT_END, "", "", 0, {"note": "vellum, novell, and maren_x stay, vell goes"})), "[0.00s] vellum, novell, and maren_x stay, Vell goes", "only whole ids")
	var shot: LogEntry = _entry(LogEntry.Kind.DAMAGE, "maren", "rift_hound", 21, {"source_ability_name": "Longshot"})
	var enemy: String = UiStyle.ENEMY_TEXT.to_html(false)
	var hero: String = UiStyle.TEXT.to_html(false)
	assert_eq(names.bbcode(shot), "[color=#%s][lb]0.00s] Maren · Longshot hits Rift Hound 1 for 21[/color]" % hero, "a hero's line, with its [ escaped")
	assert_string_contains(names.bbcode(bite), "[color=#%s]" % enemy, "an enemy's line")
	var colors: Dictionary = {
		LogEntry.Kind.DEATH: UiStyle.BAD, LogEntry.Kind.HEAL: UiStyle.GOOD, LogEntry.Kind.SHIELD: UiStyle.SHIELD,
		LogEntry.Kind.COLLAPSE: UiStyle.EMBER, LogEntry.Kind.COLLAPSE_RING: UiStyle.EMBER,
		LogEntry.Kind.FIRE: UiStyle.TEXT.darkened(0.3), LogEntry.Kind.AURA: UiStyle.TEXT.darkened(0.3),
	}
	for kind: LogEntry.Kind in colors:
		var line: String = names.bbcode(_entry(kind, "vell", "maren", 5))
		assert_true(line.begins_with("[color=#%s]" % (colors[kind] as Color).to_html(false)), LogEntry.Kind.keys()[kind])
	for kind: LogEntry.Kind in [LogEntry.Kind.FIGHT_START, LogEntry.Kind.FIGHT_END, LogEntry.Kind.PHASE]:
		assert_true(names.bbcode(_entry(kind, "", "rift_hound", 0)).begins_with("[b][color=#%s]" % UiStyle.EMBER.to_html(false)), LogEntry.Kind.keys()[kind])


# --- the log panel ---------------------------------------------------------------

func _panel(player: FightPlayer) -> LogPanel:
	var panel: LogPanel = LogPanel.make()
	add_child_autofree(panel)
	panel.start(FightNames.make(player.sim, player.content))
	return panel


## The lines the panel should show, worked out here rather than by its own
## shows().
func _expected(panel: LogPanel, entries: Array[LogEntry]) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for entry: LogEntry in entries:
		var about: bool = panel.only_unit.is_empty() or panel.only_unit in [entry.source_unit, entry.target]
		if about and (panel.show_chatter or not _is_chatter(entry)):
			lines.append(panel.names.text(entry))
	return "\n".join(lines) + ("\n" if not lines.is_empty() else "")


func test_the_log_hides_the_chatter_until_asked() -> void:
	var player: FightPlayer = _player("hollow_line")
	var panel: LogPanel = _panel(player)
	var entries: Array[LogEntry] = player.take_new()
	entries.append_array(player.skip_to_end())
	panel.add(entries)
	assert_eq(panel.entries.size(), entries.size(), "it keeps every entry")
	assert_true(entries.any(_is_chatter), "the fight walks and picks targets")
	assert_false(panel.shows(entries.filter(_is_chatter)[0]))
	assert_eq(panel.shown_text(), _expected(panel, entries))
	assert_false(panel.shown_text().contains(" walks from "))
	assert_true(U.button(panel, "Show movement") == panel.chatter_toggle)
	panel.chatter_toggle.button_pressed = true
	assert_true(panel.show_chatter)
	assert_string_contains(panel.shown_text(), " walks from ")
	assert_eq(panel.shown_text().count("\n"), entries.size(), "every line, once")
	panel.set_show_chatter(false)
	assert_false(panel.chatter_toggle.button_pressed)
	assert_eq(panel.shown_text(), _expected(panel, entries))


func test_clicking_a_unit_keeps_only_its_lines() -> void:
	var player: FightPlayer = _player()
	var panel: LogPanel = _panel(player)
	var entries: Array[LogEntry] = player.take_new()
	entries.append_array(player.skip_to_end())
	panel.add(entries)
	var everyone: String = panel.shown_text()
	assert_false(panel.filter_row.visible)
	panel.filter_to("rift_hound#2")
	assert_true(panel.filter_row.visible)
	assert_eq(panel.filter_label.text, "Only Rift Hound 2")
	var about: Array[LogEntry] = entries.filter(func(entry: LogEntry) -> bool:
		return not _is_chatter(entry) and (entry.source_unit == "rift_hound#2" or entry.target == "rift_hound#2"))
	assert_gt(about.size(), 5)
	assert_true(about.any(func(entry: LogEntry) -> bool: return entry.source_unit != "rift_hound#2"), "lines aimed at it count")
	assert_true(about.any(func(entry: LogEntry) -> bool: return entry.target != "rift_hound#2"), "and its own lines")
	assert_eq(panel.shown_text(), _expected(panel, about))
	panel.add([_entry(LogEntry.Kind.HEAL, "vell", "maren", 3)] as Array[LogEntry])
	assert_eq(panel.shown_text(), _expected(panel, about), "new lines are filtered too")
	panel.filter_to("rift_hound#2")
	assert_false(panel.filter_row.visible, "clicking it again shows everyone")
	assert_string_contains(panel.shown_text(), "heals Maren for 3")
	panel.filter_to("maren")
	assert_true(U.press(panel, "Show everyone"))
	assert_eq(panel.only_unit, "")
	assert_true(panel.shown_text().begins_with(everyone))
	panel.start(panel.names)
	assert_eq([panel.entries.size(), panel.shown_text()], [0, ""], "a new start empties it")


# --- banners ---------------------------------------------------------------------

func test_banner_texts_for_the_big_moments() -> void:
	var names: FightNames = FightNames.make(_player().sim, _content)
	assert_eq(FightBanners.text_for(_entry(LogEntry.Kind.PHASE, "", "rift_hound#2", 0, {"note": "Molt"}), names), "Rift Hound 2: Molt")
	var ring: LogEntry = _entry(LogEntry.Kind.COLLAPSE_RING, "", "", 0, {"note": "crumbled"})
	assert_eq(FightBanners.text_for(ring, names), FightBanners.COLLAPSE_TEXT, "the first ring crumbling")
	ring.note = "warned"
	assert_eq(FightBanners.text_for(ring, names), "", "not its warning")
	ring.note = "crumbled"
	ring.amount = 1
	assert_eq(FightBanners.text_for(ring, names), "", "not the later rings")
	assert_eq(FightBanners.text_for(_entry(LogEntry.Kind.FIGHT_END, "", "", 0, {"note": "Victory"}), names), "Victory")
	assert_eq(FightBanners.text_for(_entry(LogEntry.Kind.DEATH, "", "maren", 0), names), "")


func test_banners_queue_one_at_a_time() -> void:
	var banners: FightBanners = FightBanners.make()
	add_child_autofree(banners)
	banners.push("")
	assert_false(banners.visible, "nothing to say")
	banners.push("One")
	banners.push("Two")
	assert_true(banners.visible)
	assert_eq(banners.label.text, "One")
	banners.advance(1.4)
	assert_eq(banners.label.text, "One", "each stays 1.5s")
	banners.advance(0.2)
	assert_eq(banners.label.text, "Two")
	banners.advance(1.5)
	assert_false(banners.visible)
	banners.speed = 0.5
	banners.push("Slow")
	assert_almost_eq(banners.left, 1.5, 0.0001, "slower than 1x still 1.5s")
	banners.advance(1.5)
	assert_false(banners.visible)
	banners.speed = 2.0
	banners.push("Three")
	assert_almost_eq(banners.left, 0.75, 0.0001, "at 2x, half as long")
	banners.advance(5.0)
	banners.advance(5.0)
	assert_false(banners.visible)
	banners.push("Four")
	banners.push("Five")
	banners.clear()
	assert_false(banners.visible)
	assert_eq(banners.queue, [] as Array[String])


# --- the chart -------------------------------------------------------------------

func _tally() -> FightTally:
	var setup: FightSetup = _player().setup
	return FightTally.make(setup, {"brannoc": "Brannoc", "maren": "Maren", "vell": "Vell"} as Dictionary[String, String])


func test_the_chart_shows_bars_a_legend_and_a_breakdown_on_hover() -> void:
	var tally: FightTally = _tally()
	tally.add(_entry(LogEntry.Kind.DAMAGE, "maren", "rift_hound", 30, {"source_ability": "marking_shot", "source_ability_name": "Marking Shot"}))
	tally.add(_entry(LogEntry.Kind.STATUS_DAMAGE, "maren", "rift_hound", 10, {"status": "burn", "status_name": "Burn"}))
	tally.add(_entry(LogEntry.Kind.DAMAGE, "brannoc", "rift_hound", 10, {"source_ability": "shield_bash", "source_ability_name": "Shield Bash"}))
	var chart: FightChart = FightChart.make(tally)
	add_child_autofree(chart)
	var text: String = U.text_of(chart)
	for type: String in FightTally.TYPES[FightTally.Tab.DAMAGE]:
		assert_string_contains(text, type, "the legend names every type")
	assert_true(text.find("Maren") < text.find("Brannoc") and text.find("Brannoc") < text.find("Vell"), "the biggest bar first")
	var maren: String = chart.breakdown_text(tally.bar(FightTally.Tab.DAMAGE, "maren"))
	assert_eq(maren, "Maren: 40 damage\n  Abilities 30 (75%)\n  Burn 10 (25%)\nBy source:\n  Marking Shot 30 (75%)\n  Burn 10 (25%)")
	var strips: Array[Node] = U.find_all(chart, FightChart.StackedBar)
	assert_eq(strips.size(), 3)
	assert_eq((strips[0] as FightChart.StackedBar).amounts, [0, 30, 10, 0, 0] as Array[int])
	assert_eq((strips[1] as FightChart.StackedBar).amounts, [10, 0, 0, 0, 0] as Array[int], "Shield Bash is Brannoc's basic attack")
	assert_eq((strips[0] as FightChart.StackedBar).most, 40, "bars share one scale")
	var rows: Array[Node] = U.find_all(chart, HBoxContainer).filter(func(n: Node) -> bool: return not (n as Control).tooltip_text.is_empty())
	assert_eq((rows[0] as Control).tooltip_text, maren, "hovering a bar shows its breakdown")
	assert_string_contains(text, "40")


func test_the_chart_switches_tabs_and_updates_in_place() -> void:
	var tally: FightTally = _tally()
	var chart: FightChart = FightChart.make(tally)
	add_child_autofree(chart)
	var first_row: Node = U.find_all(chart, FightChart.StackedBar)[0]
	tally.add(_entry(LogEntry.Kind.DAMAGE, "brannoc", "rift_hound", 5, {"source_ability": "shield_bash", "source_ability_name": "Shield Bash"}))
	chart.refresh()
	assert_eq(U.find_all(chart, FightChart.StackedBar)[0], first_row, "the same order keeps the same rows (an open hover stays open)")
	assert_eq((first_row as FightChart.StackedBar).amounts, [5, 0, 0, 0, 0] as Array[int])
	tally.add(_entry(LogEntry.Kind.DAMAGE, "vell", "rift_hound", 9, {"source_ability_name": "Lantern Glow"}))
	chart.refresh()
	assert_eq(U.find_all(chart, FightChart.StackedBar).size(), 3, "a new order rebuilds the rows, the old ones gone")
	assert_true(U.text_of(chart).find("Vell") < U.text_of(chart).find("Brannoc"))
	assert_true(U.press(chart, "Healing and Shield"))
	assert_eq(chart.tab, FightTally.Tab.SUPPORT)
	assert_string_contains(U.text_of(chart), "Shield")
	assert_false(U.text_of(chart).contains("Basic attack"), "the legend follows the tab")
	assert_true(U.press(chart, "Damage taken"))
	assert_string_contains(U.text_of(chart), "Absorbed by Shield")
	var empty: FightChart = FightChart.make(null)
	add_child_autofree(empty)
	assert_eq(U.find_all(empty, FightChart.StackedBar).size(), 0, "no tally yet, no bars")
	empty.set_tally(tally)
	assert_eq(U.find_all(empty, FightChart.StackedBar).size(), 3)


# --- on the screen ---------------------------------------------------------------

func _screen(encounter_id: String = "the_pack", session: PracticeSession = null) -> ArenaScreen:
	var practice: PracticeSession = session if session != null else PracticeSession.make(_content)
	var screen: ArenaScreen = ArenaScreen.make(practice, encounter_id)
	add_child_autofree(screen)
	screen.size = Vector2(1900, 1000)
	screen.setup()
	await wait_process_frames(2)
	return screen


func _key(screen: ArenaScreen, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	screen._unhandled_input(event)


func test_the_log_and_chart_follow_the_fight() -> void:
	var session: PracticeSession = PracticeSession.make(_content)
	var screen: ArenaScreen = await _screen("the_pack", session)
	assert_false(screen.log_column.visible, "no log while placing")
	screen._fight()
	assert_true(screen.log_column.visible, "open by default in a fight")
	assert_true(screen.log_button.button_pressed)
	assert_true(screen.log_panel.shown_text().begins_with("[0.00s] Fight begins"))
	for frame: int in 60 * 5:
		screen._process(1.0 / 60.0)
	var log: Array[LogEntry] = screen.player.sim.combat_log.entries
	assert_eq(screen.log_panel.entries, log, "every entry handed out went to the log")
	assert_eq(screen.log_panel.shown_text(), _expected(screen.log_panel, log))
	var whole: FightTally = FightTally.of_fight(screen.player.setup, screen.player.sim.combat_log)
	for tab: int in FightTally.TYPES.size():
		for i: int in 3:
			assert_eq(screen.tally.bars[tab][i].by_type, whole.bars[tab][i].by_type, "the chart counts the same log")
	var strips: Array[Node] = U.find_all(screen.chart, FightChart.StackedBar)
	var top: FightTally.Bar = screen.tally.sorted(FightTally.Tab.DAMAGE)[0]
	assert_gt(top.total(), 0)
	assert_eq((strips[0] as FightChart.StackedBar).amounts, top.by_type, "the chart is refreshed as it plays")
	_key(screen, KEY_L)
	assert_false(screen.log_column.visible)
	assert_false(screen.log_button.button_pressed)
	assert_false(session.log_open, "remembered in the session")
	screen._process(1.0)
	assert_eq(screen.log_panel.entries, screen.player.sim.combat_log.entries, "a hidden log still keeps up")
	screen.log_button.button_pressed = true
	assert_true(screen.log_column.visible)
	assert_eq((U.find_all(screen.chart, FightChart.StackedBar)[0] as FightChart.StackedBar).amounts, screen.tally.sorted(FightTally.Tab.DAMAGE)[0].by_type, "opening it catches the chart up")
	screen.log_button.button_pressed = false
	screen.place_again()
	screen._fight()
	assert_false(screen.log_column.visible, "the next fight keeps it hidden")


func test_skip_restart_and_place_again() -> void:
	var screen: ArenaScreen = await _screen()
	screen._fight()
	screen._process(1.0)
	assert_false(screen.view.fx.effects.is_empty(), "shots and numbers on the board")
	screen.restart()
	assert_eq(screen.view.fx.effects.size(), 0, "a restart clears the board's effects")
	screen._process(1.0)
	screen.skip()
	assert_ne(screen.outcome_label.text, "")
	var log: Array[LogEntry] = screen.player.sim.combat_log.entries
	assert_eq(screen.log_panel.entries, log, "a skip fills in the whole log")
	assert_eq(screen.tally.bars[FightTally.Tab.DAMAGE][1].total(), FightTally.of_fight(screen.player.setup, screen.player.sim.combat_log).bars[FightTally.Tab.DAMAGE][1].total())
	assert_true(screen.banners.visible)
	assert_eq(screen.banners.label.text, "Victory", "only the end's banner after a skip")
	assert_eq(screen.banners.queue, [] as Array[String])
	screen.restart()
	assert_false(screen.banners.visible)
	assert_eq(screen.outcome_label.text, "")
	assert_eq(screen.log_panel.shown_text(), "[0.00s] Fight begins (seed %d, act 1)\n" % screen.player.setup.seed_value, "the log starts over")
	assert_eq(screen.tally.bars[FightTally.Tab.DAMAGE][0].total(), 0)
	assert_eq(screen.chart.tally, screen.tally)
	screen._process(0.5)
	assert_eq(screen.log_panel.entries, screen.player.sim.combat_log.entries)
	screen.skip()
	screen.place_again()
	assert_false(screen.log_column.visible)
	assert_false(screen.banners.visible)


func test_clicking_a_unit_filters_the_log() -> void:
	var screen: ArenaScreen = await _screen()
	screen.view.unit_clicked.emit("maren")
	assert_eq(screen.log_panel.only_unit, "", "nothing to filter while placing")
	screen._fight()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = screen.view.token("rift_hound#3").center()
	screen.view._gui_input(click)
	assert_eq(screen.log_panel.only_unit, "", "not on the press")
	click.pressed = false
	screen.view._gui_input(click)
	assert_eq(screen.log_panel.only_unit, "rift_hound#3", "on the release")
	click.button_index = MOUSE_BUTTON_RIGHT
	click.position = screen.view.token("maren").center()
	screen.view._gui_input(click)
	assert_eq(screen.log_panel.only_unit, "rift_hound#3", "only the left button")
	screen._process(3.0)
	assert_eq(screen.log_panel.shown_text(), _expected(screen.log_panel, screen.player.sim.combat_log.entries))
	assert_false(screen.log_panel.shown_text().contains("Rift Hound 1 ·"))


func test_a_summon_is_named_as_it_joins() -> void:
	var screen: ArenaScreen = await _screen()
	screen._fight()
	var sim: CombatSim = screen.player.sim
	var hound: UnitState = sim.unit_by_id("rift_hound")
	var joined: UnitState = UnitState.make_summon(hound.def, hound.side, sim.next_unit_id(hound.def.id), sim.units.size(), sim.tuning.unit_radius)
	joined.pos = Vector2i(3000, 6000)
	sim.add_unit(joined)
	sim.units_joined()
	screen._on_entries([_entry(LogEntry.Kind.SUMMON, "rift_hound", joined.id, 0, {"to_pos": joined.pos, "source_ability_name": "Howl"})] as Array[LogEntry])
	assert_string_contains(screen.log_panel.shown_text(), "Rift Hound 1 · Howl summons Rift Hound 4 at")


func test_banners_as_the_fight_plays() -> void:
	var session: PracticeSession = PracticeSession.make(_content)
	session.speed = 0.5
	var screen: ArenaScreen = await _screen("witch_circle", session)
	screen._fight()
	assert_eq(screen.banners.speed, 0.5, "banners start at the remembered speed")
	screen.set_speed(1.0)
	while not screen.player.finished() and screen.player.sim.tick < 45 * 20:
		screen._process(1.0 / 30.0)
	assert_true(screen.banners.visible)
	assert_eq(screen.banners.label.text, FightBanners.COLLAPSE_TEXT, "the rift collapses at 45s")
	screen.toggle_pause()
	screen._process(5.0)
	assert_true(screen.banners.visible, "a banner waits while the fight is paused")
	screen.toggle_pause()
	screen._process(1.6)
	assert_false(screen.banners.visible)
	var phase: LogEntry = _entry(LogEntry.Kind.PHASE, "", "gloam_witch", 0, {"note": "Molt"})
	screen._on_entries([phase] as Array[LogEntry])
	assert_eq(screen.banners.label.text, "Gloam Witch: Molt")
	assert_string_contains(screen.log_panel.shown_text(), "Gloam Witch enters Molt")
	screen.set_speed(2.0)
	assert_eq(screen.banners.speed, 2.0, "banners keep up with the speed")
	screen.skip()
	screen._process(1.0)
	assert_false(screen.banners.visible, "the end's banner goes too")
	assert_ne(screen.outcome_label.text, "", "the outcome stays at the side")
