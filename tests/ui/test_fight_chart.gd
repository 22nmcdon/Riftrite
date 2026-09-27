extends GutTest
## The fight chart, its tally, the banners, the hidden log, and the
## remembered speed (docs/plans/fight-questions-and-readability.md,
## sections 4 and 5).

const U = preload("res://tests/ui/ui_test_kit.gd")
const K = preload("res://tests/sim/sim_test_kit.gd")
const MainScript = preload("res://src/ui/main.gd")


func _main(session: RunSession) -> Main:
	var main: Main = MainScript.new()
	main.session = session
	add_child_autofree(main)
	return main


## A tally for heroes "a" (basic attack "jab") and "b", against "foe".
func _tally() -> FightTally:
	var sim := CombatSim.new(K.fight([K.unit("a", 100, UnitSetup.Row.FRONT, [], K.basic("jab")), K.unit("b", 100)], [K.dummy("foe", 1000)]), K.content())
	return FightTally.make(sim, {"a": "Aster", "b": "Bram", "foe": "Foe"} as Dictionary[String, String])


func _entry(kind: LogEntry.Kind, source_unit: String, target: String, amount: int, fields: Dictionary = {}) -> LogEntry:
	var entry := LogEntry.new()
	entry.kind = kind
	entry.source_unit = source_unit
	entry.target = target
	entry.amount = amount
	for key: String in fields:
		entry.set(key, fields[key])
	return entry


func test_damage_is_split_by_type_and_credited_to_the_dealer() -> void:
	var tally: FightTally = _tally()
	tally.add(_entry(LogEntry.Kind.DAMAGE, "a", "foe", 10, {"source_item": "jab", "source_item_name": "Jab"}))
	tally.add(_entry(LogEntry.Kind.DAMAGE, "a", "foe", 30, {"source_item": "hatchet", "source_item_name": "Hatchet", "source_infusion_name": "Wrath"}))
	tally.add(_entry(LogEntry.Kind.STATUS_DAMAGE, "a", "foe", 7, {"status": "golden_flame", "status_name": "Golden Flame", "source_item_name": "Torch"}))
	tally.add(_entry(LogEntry.Kind.STATUS_DAMAGE, "a", "foe", 4, {"status": "deathcap", "status_name": "Deathcap"}))
	tally.add(_entry(LogEntry.Kind.STATUS_DAMAGE, "a", "foe", 3, {"status": "hemorrhage", "status_name": "Hemorrhage"}))
	tally.add(_entry(LogEntry.Kind.DAMAGE, "a", "foe", 5, {"source_item": "jab", "source_item_name": "Jab", "source_granted_by": "Cinder Crown"}))
	tally.add(_entry(LogEntry.Kind.DAMAGE, "foe", "a", 99, {"source_item": "idle"}))
	var a: FightTally.Bar = tally.bar(FightTally.Tab.DAMAGE, "a")
	assert_eq(a.by_type, [10, 35, 7, 4, 3] as Array[int], "basic attack, abilities (a grant on the basic attack counts there), Burn, Poison, Bleed families")
	assert_eq(a.total(), 59)
	assert_eq(a.breakdown(), [["Hatchet · Wrath", 30], ["Jab", 10], ["Golden Flame (Torch)", 7], ["Jab (from Cinder Crown)", 5], ["Deathcap", 4], ["Hemorrhage", 3]] as Array[Array])
	assert_eq(tally.bar(FightTally.Tab.DAMAGE, "b").total(), 0)
	assert_null(tally.bar(FightTally.Tab.DAMAGE, "foe"), "the enemies get no bars")


func test_event_effects_on_the_basic_attack_count_as_abilities() -> void:
	var tally: FightTally = _tally()
	tally.add(_entry(LogEntry.Kind.DAMAGE, "a", "foe", 6, {"source_item": "jab", "source_item_name": "Jab", "from_event": true}))
	assert_eq(tally.bar(FightTally.Tab.DAMAGE, "a").by_type, [0, 6, 0, 0, 0] as Array[int])


func test_healing_and_shield_count_for_the_giver() -> void:
	var tally: FightTally = _tally()
	tally.add(_entry(LogEntry.Kind.HEAL, "b", "a", 12, {"source_item_name": "Poultice"}))
	tally.add(_entry(LogEntry.Kind.SHIELD, "b", "b", 20, {"source_item_name": "Buckler"}))
	tally.add(_entry(LogEntry.Kind.HEAL, "foe", "foe", 50))
	var b: FightTally.Bar = tally.bar(FightTally.Tab.SUPPORT, "b")
	assert_eq(b.by_type, [12, 20] as Array[int])
	assert_eq(b.breakdown(), [["Buckler", 20], ["Poultice", 12]] as Array[Array])
	assert_eq(tally.bar(FightTally.Tab.SUPPORT, "a").total(), 0, "healing counts for who gave it, not who got it")


func test_damage_taken_splits_hp_and_shield_by_where_it_came_from() -> void:
	var tally: FightTally = _tally()
	tally.add(_entry(LogEntry.Kind.DAMAGE, "foe", "a", 30, {"source_item_name": "Claw", "absorbed": 12}))
	tally.add(_entry(LogEntry.Kind.STATUS_DAMAGE, "foe", "a", 5, {"status": "burn", "status_name": "Burn"}))
	tally.add(_entry(LogEntry.Kind.COLLAPSE, "", "a", 8))
	tally.add(_entry(LogEntry.Kind.DAMAGE, "a", "foe", 40, {"source_item_name": "Jab"}))
	var a: FightTally.Bar = tally.bar(FightTally.Tab.TAKEN, "a")
	assert_eq(a.by_type, [31, 12] as Array[int], "to HP, and absorbed by Shield")
	assert_eq(a.breakdown(), [["Foe: Claw", 30], ["Rift Collapse", 8], ["Burn", 5]] as Array[Array])
	assert_eq(tally.bar(FightTally.Tab.TAKEN, "b").total(), 0)


func test_a_breakdown_keeps_ties_in_first_seen_order() -> void:
	var tally: FightTally = _tally()
	for item_name: String in ["Cleaver", "Axe", "Bow"]:
		tally.add(_entry(LogEntry.Kind.DAMAGE, "a", "foe", 5, {"source_item_name": item_name}))
	assert_eq(tally.bar(FightTally.Tab.DAMAGE, "a").breakdown(), [["Cleaver", 5], ["Axe", 5], ["Bow", 5]] as Array[Array])


func test_relics_get_their_own_bar_and_heroes_sort_by_total() -> void:
	var tally: FightTally = _tally()
	assert_eq(_ids(tally.sorted(FightTally.Tab.DAMAGE)), ["a", "b"] as Array[String], "team order on a tie; no relic bar until relics act")
	tally.add(_entry(LogEntry.Kind.DAMAGE, "b", "foe", 5, {"source_item_name": "Axe"}))
	tally.add(_entry(LogEntry.Kind.DAMAGE, "", "foe", 9, {"source_item_name": "Ember Idol", "source_relic_side": UnitSetup.Side.HEROES}))
	tally.add(_entry(LogEntry.Kind.DAMAGE, "", "a", 9, {"source_item_name": "Dark Idol", "source_relic_side": UnitSetup.Side.ENEMIES}))
	assert_eq(_ids(tally.sorted(FightTally.Tab.DAMAGE)), ["b", "a", "relics"] as Array[String], "most first, the relics last")
	assert_eq(tally.bar(FightTally.Tab.DAMAGE, FightTally.RELICS).total(), 9, "the enemies' relics aren't ours")
	assert_eq(tally.bar(FightTally.Tab.TAKEN, "a").breakdown(), [["Dark Idol (relic)", 9]] as Array[Array])


func _ids(bars: Array[FightTally.Bar]) -> Array[String]:
	var ids: Array[String] = []
	for bar: FightTally.Bar in bars:
		ids.append(bar.id)
	return ids


func test_a_real_fights_tally_matches_the_damage_meter() -> void:
	var session: RunSession = U.at_fight()
	var main: Main = _main(session)
	var fight: FightScreen = main.screen
	fight.start_fight()
	fight.skip()
	var heroes: Array[String] = []
	for unit: UnitState in fight.player.sim.heroes:
		heroes.append(unit.id)
	var meter: DamageMeter = DamageMeter.from_log(session.last_fight.combat_log, heroes)
	var dealt: int = 0
	for bar: FightTally.Bar in fight.tally.bars[FightTally.Tab.DAMAGE]:
		dealt += bar.total()
	assert_gt(dealt, 0)
	assert_eq(dealt, meter.total_damage(UnitSetup.Side.HEROES), "the chart and the meter read the same log")


# --- the chart ---------------------------------------------------------------------

func test_the_chart_shows_bars_a_legend_and_a_breakdown_on_hover() -> void:
	var tally: FightTally = _tally()
	tally.add(_entry(LogEntry.Kind.DAMAGE, "b", "foe", 30, {"source_item_name": "Axe"}))
	tally.add(_entry(LogEntry.Kind.STATUS_DAMAGE, "b", "foe", 10, {"status": "burn", "status_name": "Burn"}))
	tally.add(_entry(LogEntry.Kind.DAMAGE, "a", "foe", 10, {"source_item": "jab", "source_item_name": "Jab"}))
	var chart: FightChart = autofree(FightChart.make(tally))
	var text: String = U.text_of(chart)
	for type: String in FightTally.TYPES[FightTally.Tab.DAMAGE]:
		assert_string_contains(text, type, "the legend names every type")
	assert_string_contains(text, "Bram\n")
	assert_true(text.find("Bram") < text.find("Aster"), "the biggest bar first")
	var bram: String = chart.breakdown_text(tally.bar(FightTally.Tab.DAMAGE, "b"))
	assert_eq(bram, "Bram: 40 damage\n  Abilities 30 (75%)\n  Burn 10 (25%)\nBy source:\n  Axe 30 (75%)\n  Burn 10 (25%)")
	var strips: Array[Node] = U.find_all(chart, FightChart.StackedBar)
	assert_eq(strips.size(), 2)
	assert_eq((strips[0] as FightChart.StackedBar).amounts, [0, 30, 10, 0, 0] as Array[int])
	assert_eq((strips[0] as FightChart.StackedBar).most, 40, "bars share one scale")
	var rows: Array[Node] = U.find_all(chart, HBoxContainer).filter(func(n: Node) -> bool: return not (n as Control).tooltip_text.is_empty())
	assert_eq((rows[0] as Control).tooltip_text, bram, "hovering a bar shows its breakdown")


func test_the_chart_switches_tabs_and_updates_in_place() -> void:
	var tally: FightTally = _tally()
	var chart: FightChart = autofree(FightChart.make(tally))
	var first_row: Node = U.find_all(chart, FightChart.StackedBar)[0]
	tally.add(_entry(LogEntry.Kind.DAMAGE, "a", "foe", 5, {"source_item_name": "Axe"}))
	chart.refresh()
	assert_eq(U.find_all(chart, FightChart.StackedBar)[0], first_row, "the same order keeps the same rows (an open hover stays open)")
	assert_eq((first_row as FightChart.StackedBar).amounts, [0, 5, 0, 0, 0] as Array[int])
	assert_true(U.press(chart, "Healing and Shield"))
	assert_eq(chart.tab, FightTally.Tab.SUPPORT)
	assert_string_contains(U.text_of(chart), "Shield")
	assert_false(U.text_of(chart).contains("Basic attack"), "the legend follows the tab")
	assert_true(U.press(chart, "Damage taken"))
	assert_string_contains(U.text_of(chart), "Absorbed by Shield")


# --- the fight screen ----------------------------------------------------------------

func test_the_log_is_hidden_until_opened() -> void:
	var main: Main = _main(U.at_fight())
	var fight: FightScreen = main.screen
	fight.start_fight()
	assert_false(fight._log_panel.visible, "the chart and log start hidden")
	fight._log_button.button_pressed = true
	assert_true(fight._log_panel.visible)
	fight.skip()
	assert_gt(fight.chart.tally.bars[FightTally.Tab.DAMAGE][0].total() + fight.chart.tally.bars[FightTally.Tab.DAMAGE][1].total(), 0)
	var event := InputEventKey.new()
	event.keycode = KEY_L
	event.pressed = true
	fight._unhandled_input(event)
	assert_false(fight._log_panel.visible, "L closes it")
	assert_false(fight._log_button.button_pressed)


func test_the_fight_speed_is_remembered() -> void:
	var session: RunSession = U.at_fight()
	assert_eq(session.fight_speed, 1.0, "1x to begin with")
	var fight: FightScreen = _main(session).screen
	fight.start_fight()
	assert_eq(fight.player.speed, 1.0)
	fight.set_speed(2.0)
	assert_eq(session.fight_speed, 2.0, "a changed speed is remembered")
	var later: RunSession = U.at_fight(7)
	later.fight_speed = session.fight_speed
	var next: FightScreen = _main(later).screen
	next.start_fight()
	assert_eq(next.player.speed, 2.0, "the next fight starts there")
	assert_eq(next.banners.speed, 2.0)
	assert_true(next._speed_buttons[2].button_pressed)


func test_the_speed_setting_is_saved() -> void:
	var path: String = "user://test_settings.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var session: RunSession = U.session()
	session.load_settings(path)
	assert_eq(session.fight_speed, 1.0, "no file keeps the default")
	session.set_fight_speed(4.0)
	session.set_fight_speed(3.0)
	assert_eq(session.fight_speed, 4.0, "only the real speeds")
	var fresh: RunSession = U.session()
	fresh.load_settings(path)
	assert_eq(fresh.fight_speed, 4.0, "saved for next time")
	var broken := FileAccess.open(path, FileAccess.WRITE)
	broken.store_string("{\"fight_speed\": 7.0}")
	broken.close()
	var other: RunSession = U.session()
	other.load_settings(path)
	assert_eq(other.fight_speed, 1.0, "a bad setting keeps the default")
	DirAccess.remove_absolute(path)
	var memory: RunSession = U.session()
	memory.set_fight_speed(2.0)
	assert_eq(memory.fight_speed, 2.0, "without a settings file it's remembered in memory")


# --- banners -------------------------------------------------------------------------

func test_banner_texts_for_the_big_moments() -> void:
	var session: RunSession = U.at_fight()
	var fight: FightScreen = _main(session).screen
	fight.start_fight()
	var names: FightNames = fight.names
	var hero: String = fight.player.sim.heroes[0].id
	var foe: String = fight.player.sim.enemies[0].id
	var heroes: Array[String] = [hero]
	assert_eq(FightBanners.text_for(_entry(LogEntry.Kind.PHASE, "", foe, 0, {"note": "Last Ember"}), heroes, names), "%s: Last Ember" % names.name_of(foe))
	assert_eq(FightBanners.text_for(_entry(LogEntry.Kind.DEED_LEVEL, "", hero, 2, {"note": "Shieldbearer 2: Rally"}), heroes, names), "✦ %s: Shieldbearer 2" % names.name_of(hero))
	assert_eq(FightBanners.text_for(_entry(LogEntry.Kind.DEED_LEVEL, "", foe, 2, {"note": "x 2"}), heroes, names), "", "only the guild's deeds")
	var resonant: LogEntry = _entry(LogEntry.Kind.INFUSION_LEVEL, hero, "", 150, {"note": "Resonant (150 XP)", "source_item_name": "Hatchet", "source_infusion_name": "Wrath"})
	assert_eq(FightBanners.text_for(resonant, heroes, names), "✦ Hatchet is Resonant (Wrath)")
	resonant.note = "Resonant and awakens (150 XP)"
	resonant.source_infusion_name = "Plasma"
	assert_eq(FightBanners.text_for(resonant, heroes, names), "✦ Hatchet awakens: Plasma")
	resonant.source_unit = foe
	assert_eq(FightBanners.text_for(resonant, heroes, names), "", "only the guild's infusions")
	resonant.source_unit = hero
	resonant.note = "Attuned (60 XP)"
	assert_eq(FightBanners.text_for(resonant, heroes, names), "", "Attuned isn't a banner")
	assert_eq(FightBanners.text_for(_entry(LogEntry.Kind.DAMAGE, hero, foe, 5), heroes, names), "")


func test_banners_queue_one_at_a_time() -> void:
	var banners: FightBanners = autofree(FightBanners.make())
	add_child(banners)
	banners.push("")
	assert_false(banners.visible, "nothing to say")
	banners.push("One")
	banners.push("Two")
	assert_true(banners.visible)
	assert_eq(banners._label.text, "One")
	banners._process(1.0)
	assert_eq(banners._label.text, "One", "each stays about 1.5s")
	banners._process(0.6)
	assert_eq(banners._label.text, "Two")
	banners.push("Three")
	banners.speed = 4.0
	banners._process(1.6)
	assert_eq(banners._label.text, "Three")
	banners._process(0.7)
	assert_false(banners.visible, "at 4x each is shorter (but at least 0.6s)")
	banners.push("Three")
	banners.clear()
	assert_false(banners.visible)


func test_the_fight_screen_shows_a_phase_banner_as_it_plays() -> void:
	var fight: FightScreen = _main(U.at_fight()).screen
	fight.start_fight()
	var foe: String = fight.player.sim.enemies[0].id
	var phase: LogEntry = _entry(LogEntry.Kind.PHASE, "", foe, 0, {"note": "Blood Frenzy"})
	fight._on_entries([phase] as Array[LogEntry])
	assert_true(fight.banners.visible)
	assert_eq(fight.banners._label.text, "%s: Blood Frenzy" % fight.names.name_of(foe))


func test_a_discovery_gets_a_banner_as_the_fight_starts() -> void:
	for run_seed: int in range(1, 30):
		var session: RunSession = U.at_fight(run_seed)
		var fight: FightScreen = _main(session).screen
		fight.start_fight()
		if session.last_discoveries.is_empty():
			continue
		var expected: String = "✦ Synergy discovered: %s" % session.content.synergies[session.last_discoveries[0]].name
		assert_true(fight.banners.visible)
		assert_eq(fight.banners._label.text, expected)
		return
	fail_test("no seed discovered a synergy in its first fight")
