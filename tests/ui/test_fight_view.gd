extends GutTest
## What the fight shows (docs/plans/rebuild-phase3-fight-sandbox.md, section
## 5): tokens' bars and status tags from the sim's state, and FightFx's
## shots, swipes, numbers, and signature names from the log.

const K = preload("res://tests/sim/sim_test_kit.gd")
const Chaos = preload("res://tests/sim/chaos_fight.gd")

var _content: ContentDb


func before_all() -> void:
	_content = ContentDb.load_dir("res://data")


func _player(encounter_id: String = "the_pack") -> FightPlayer:
	var errors: Array[String] = []
	return FightPlayer.make(Encounters.setup(_content, encounter_id, PracticeSession.DEFAULT_FORMATION, 3, errors), _content)


func _view(player: FightPlayer) -> ArenaView:
	var view := ArenaView.new()
	add_child_autofree(view)
	view.size = Vector2(1000, 900)
	view.show_setup(player.setup, player.content)
	view.sync_fight(player)
	return view


func _entry(kind: LogEntry.Kind, source: String, target: String, amount: int, extra: Dictionary = {}) -> LogEntry:
	var entry := LogEntry.new()
	entry.kind = kind
	entry.source_unit = source
	entry.target = target
	entry.amount = amount
	for key: String in extra:
		entry.set(key, extra[key])
	return entry


func _kinds(fx: FightFx) -> Array:
	return fx.effects.map(func(effect: FightFx.Fx) -> int: return effect.kind)


# --- tokens -----------------------------------------------------------------------

func test_bars_come_from_the_units_state() -> void:
	var player: FightPlayer = _player()
	var view: ArenaView = _view(player)
	var brannoc: UnitState = player.sim.unit_by_id("brannoc")
	brannoc.hp = 210
	brannoc.shield = 42
	brannoc.mana = brannoc.mana_cap / 4
	view.sync_fight(player)
	var token: UnitToken = view.token("brannoc")
	assert_true(token.in_fight)
	assert_almost_eq(token.hp_share, 0.5, 0.0001)
	assert_almost_eq(token.shield_share, 0.1, 0.0001)
	assert_almost_eq(token.mana_share, 0.25, 0.0001)
	assert_eq(token.cast_share, -1.0, "not casting")
	assert_eq(view.token("rift_hound").mana_share, -1.0, "no mana signature, no mana bar")


func test_status_tags_show_what_the_unit_has() -> void:
	var player: FightPlayer = _player()
	var view: ArenaView = _view(player)
	var hound: UnitState = player.sim.unit_by_id("rift_hound")
	var source: EffectSource = EffectSource.make("vell", "test", "Test")
	Statuses.apply(player.sim, hound, "burn", 4, 0, source)
	Statuses.apply(player.sim, hound, "stun", 0, 40, source)
	Statuses.apply(player.sim, hound, "marked", 0, 40, source)
	view.sync_fight(player)
	var tags: Array = view.token("rift_hound").status_tags.map(func(tag: Array) -> String: return tag[0])
	assert_eq(tags, ["BRN 4", "STUN", "MARK"], "in the unit's status order, damage over time with its stacks")
	assert_eq(view.token("rift_hound").status_tags[0][1], UiStyle.STATUS_COLORS["burn"])
	for kind: int in StatusDef.Kind.values():
		if kind != StatusDef.Kind.DAMAGE_OVER_TIME:
			assert_true(UnitToken.STATUS_TAGS.has(kind) and UnitToken.STATUS_COLORS.has(kind), "every status kind has a tag: %s" % StatusDef.KIND_NAMES[kind])


func test_a_cast_fills_its_bar() -> void:
	var setup: FightSetup = Chaos.setup()
	var content: ContentDb = K.content()
	var player: FightPlayer = FightPlayer.make(setup, content)
	var view: ArenaView = _view(player)
	var seen: Array[float] = []
	while not player.finished() and seen.size() < 5:
		player.advance(0.05)
		view.sync_fight(player)
		for unit: UnitState in player.sim.units:
			if unit.alive and unit.signature != null and unit.signature.casting():
				seen.append(view.token(unit.id).cast_share)
	assert_false(seen.is_empty(), "someone casts in the chaos fight")
	for share: float in seen:
		assert_between(share, 0.0, 1.0)
	assert_true(seen.any(func(share: float) -> bool: return share > 0.0 and share < 1.0), str(seen))


# --- effects ----------------------------------------------------------------------

func test_a_shot_flies_until_it_lands_or_fizzles() -> void:
	var player: FightPlayer = _player()
	var view: ArenaView = _view(player)
	var shot: LogEntry = _entry(LogEntry.Kind.SHOT, "maren", "rift_hound", 0, {"from_pos": Vector2i(3000, 500), "end_tick": 6})
	view.fx.add_entries([shot] as Array[LogEntry], player)
	assert_eq(_kinds(view.fx), [FightFx.Kind.SHOT])
	assert_eq([view.fx.effects[0].start, view.fx.effects[0].end, view.fx.effects[0].unit_id], [0, 6, "rift_hound"])
	player.advance(0.2)
	view.sync_fight(player)
	assert_eq(view.fx.effects.size(), 1, "still in flight")
	player.advance(0.1)
	view.sync_fight(player)
	assert_eq(view.fx.effects.size(), 1, "drawn time trails the sim by up to a tick (the smoothing)")
	player.advance(0.05)
	view.sync_fight(player)
	assert_eq(view.fx.effects.size(), 0, "landed")
	var other: LogEntry = _entry(LogEntry.Kind.SHOT, "vell", "rift_hound", 0, {"from_pos": Vector2i(4000, 500), "end_tick": 12})
	view.fx.add_entries([other, shot, _entry(LogEntry.Kind.SHOT_FIZZLED, "maren", "rift_hound", 0)] as Array[LogEntry], player)
	assert_eq(view.fx.effects.map(func(effect: FightFx.Fx) -> String: return effect.source_id), ["vell"], "a fizzle takes only its own shooter's shot")
	view.fx.clear()
	view.fx.add_entries([_entry(LogEntry.Kind.SHOT, "maren", "rift_hound", 0, {"tick": 7, "end_tick": 7})] as Array[LogEntry], player)
	assert_eq(view.fx.effects[0].end, 8, "an effect lasts at least a tick")


func test_damage_gets_a_number_and_a_swipe_only_up_close() -> void:
	var player: FightPlayer = _player()
	var view: ArenaView = _view(player)
	var brannoc: UnitState = player.sim.unit_by_id("brannoc")
	var hound: UnitState = player.sim.unit_by_id("rift_hound")
	hound.pos = brannoc.pos + Vector2i(0, 450)
	view.fx.add_entries([_entry(LogEntry.Kind.DAMAGE, "brannoc", "rift_hound", 14)] as Array[LogEntry], player)
	assert_eq(_kinds(view.fx), [FightFx.Kind.SWIPE, FightFx.Kind.NUMBER])
	assert_eq([view.fx.effects[1].text, view.fx.effects[1].big], ["14", false])
	view.fx.clear()
	hound.pos = brannoc.pos + Vector2i(0, 700)
	view.fx.add_entries([_entry(LogEntry.Kind.DAMAGE, "brannoc", "rift_hound", 14)] as Array[LogEntry], player)
	assert_eq(_kinds(view.fx), [FightFx.Kind.NUMBER], "beyond melee reach (half a hex) and a little slack: no swipe")
	view.fx.clear()
	view.fx.add_entries([_entry(LogEntry.Kind.DAMAGE, "maren", "rift_hound", 22, {"crit": true})] as Array[LogEntry], player)
	assert_eq(_kinds(view.fx), [FightFx.Kind.NUMBER], "from across the board: no swipe (its shot showed the way)")
	assert_eq([view.fx.effects[0].text, view.fx.effects[0].big, view.fx.effects[0].color], ["22!", true, FightFx.CRIT_COLOR])


func test_heals_shields_statuses_and_the_collapse_float_numbers() -> void:
	var player: FightPlayer = _player()
	var view: ArenaView = _view(player)
	view.fx.add_entries([
		_entry(LogEntry.Kind.HEAL, "vell", "maren", 40),
		_entry(LogEntry.Kind.SHIELD, "brannoc", "maren", 60),
		_entry(LogEntry.Kind.STATUS_DAMAGE, "rift_hound", "maren", 3, {"status": "burn"}),
		_entry(LogEntry.Kind.COLLAPSE, "", "maren", 10),
		_entry(LogEntry.Kind.DAMAGE, "rift_hound", "maren", 0),
		_entry(LogEntry.Kind.HEAL, "vell", "nobody", 5)] as Array[LogEntry], player)
	assert_eq(view.fx.effects.map(func(effect: FightFx.Fx) -> Array: return [effect.text, effect.color]),
		[["+40", FightFx.HEAL_COLOR], ["+60", UiStyle.SHIELD], ["3", UiStyle.STATUS_COLORS["burn"]], ["10", FightFx.COLLAPSE_COLOR]],
		"nothing for 0, or for a unit that isn't there")
	player.advance(FightFx.NUMBER_TICKS / 20.0 - 0.05)
	view.sync_fight(player)
	assert_eq(view.fx.effects.size(), 4)
	player.advance(0.1)
	view.sync_fight(player)
	assert_eq(view.fx.effects.size(), 0, "numbers last %d ticks" % FightFx.NUMBER_TICKS)


func test_a_signature_shows_its_name_and_a_basic_attack_doesnt() -> void:
	var player: FightPlayer = _player()
	var view: ArenaView = _view(player)
	view.fx.add_entries([
		_entry(LogEntry.Kind.FIRE, "brannoc", "", 0, {"source_ability": "hold_the_line", "source_ability_name": "Hold the Line"}),
		_entry(LogEntry.Kind.FIRE, "brannoc", "", 0, {"source_ability": "shield_bash", "source_ability_name": "Shield Bash"})] as Array[LogEntry], player)
	assert_eq(view.fx.effects.map(func(effect: FightFx.Fx) -> Array: return [effect.kind, effect.text, effect.unit_id]), [[FightFx.Kind.POPUP, "Hold the Line", "brannoc"]])


func test_a_big_batch_clears_instead_of_animating() -> void:
	var player: FightPlayer = _player()
	var view: ArenaView = _view(player)
	view.fx.add_entries([_entry(LogEntry.Kind.HEAL, "vell", "maren", 40)] as Array[LogEntry], player)
	assert_eq(view.fx.effects.size(), 1)
	var many: Array[LogEntry] = []
	for i: int in FightFx.MAX_ANIMATED + 1:
		many.append(_entry(LogEntry.Kind.HEAL, "vell", "maren", 1))
	view.fx.add_entries(many, player)
	assert_eq(view.fx.effects.size(), 0)


func test_every_shot_of_a_whole_fight_is_drawn() -> void:
	var player: FightPlayer = _player("hollow_line")
	var view: ArenaView = _view(player)
	var shots: int = 0
	while not player.finished():
		var entries: Array[LogEntry] = player.advance(1.0 / 30.0)
		view.fx.add_entries(entries, player)
		view.sync_fight(player)
		for entry: LogEntry in entries:
			if entry.kind == LogEntry.Kind.SHOT and entry.end_tick > player.sim.tick:
				shots += 1
				assert_true(view.fx.effects.any(func(effect: FightFx.Fx) -> bool: return effect.kind == FightFx.Kind.SHOT and effect.start == entry.tick and effect.unit_id == entry.target),
					entry.to_text())
		if is_failing():
			return
	assert_gt(shots, 10)
	await wait_process_frames(1)


# --- the second pass: areas, moves, deaths, summons, phases, auras, the collapse --

func test_an_area_is_warned_until_it_lands_then_flashes() -> void:
	var player: FightPlayer = _player("moth_cloud")
	var view: ArenaView = _view(player)
	view.fx.add_entries([
		_entry(LogEntry.Kind.AREA_WARNING, "cinder_moth", "", 0, {"shape": "circle 2", "from_pos": Vector2i(3000, 2000), "to_pos": Vector2i(3000, 2000), "end_tick": 20}),
		_entry(LogEntry.Kind.AREA_LANDED, "vell", "", 0, {"shape": "cone 3", "from_pos": Vector2i(3000, 500), "to_pos": Vector2i(3000, 3500), "end_tick": 0})] as Array[LogEntry], player)
	var areas: Array = view.fx.effects.map(func(fx: FightFx.Fx) -> Array: return [fx.kind, fx.shape, fx.size, fx.from, fx.to, fx.end, fx.color])
	assert_eq(areas, [
		[FightFx.Kind.AREA, "circle", 2, Vector2(3000, 2000), Vector2(3000, 2000), 20, FightFx.ENEMY_AREA],
		[FightFx.Kind.LANDED, "cone", 3, Vector2(3000, 500), Vector2(3000, 3500), FightFx.LANDED_TICKS, FightFx.HERO_AREA]],
		"a warning lasts until it lands, a flash a few ticks; colored by the caster's side")


func test_pushes_leaps_charges_and_hops_slide() -> void:
	var player: FightPlayer = _player()
	var view: ArenaView = _view(player)
	var from := Vector2i(1000, 1000)
	var to := Vector2i(3000, 1000)
	view.fx.add_entries([
		_entry(LogEntry.Kind.PUSH, "rift_hound", "maren", 0, {"from_pos": from, "to_pos": to}),
		_entry(LogEntry.Kind.LEAP, "rift_hound", "vell", 0, {"from_pos": from, "to_pos": to}),
		_entry(LogEntry.Kind.CHARGE, "brannoc", "rift_hound#2", 0, {"from_pos": from, "to_pos": to}),
		_entry(LogEntry.Kind.HOP, "rift_hound#3", "maren", 0, {"from_pos": from, "to_pos": from})] as Array[LogEntry], player)
	assert_eq(view.fx.moves.keys(), ["maren", "rift_hound", "brannoc"], "a push moves its target; a leap or charge its maker; a hop that went nowhere nothing")
	assert_eq(view.fx.moved_position("maren", Vector2.ZERO, 0.0), Vector2(from))
	assert_almost_eq(view.fx.moved_position("maren", Vector2.ZERO, FightFx.MOVE_TICKS / 2.0), Vector2(2000, 1000), Vector2(0.01, 0.01))
	assert_eq(view.fx.moved_position("vell", Vector2(7, 7), 1.0), Vector2(7, 7), "not sliding: where it's drawn otherwise")
	assert_eq(view.fx.moved_position("maren", Vector2(7, 7), float(FightFx.MOVE_TICKS)), Vector2(7, 7), "a slide that's over (a frame can outlast it): where it stands now, not where it landed")
	view.sync_fight(player)
	assert_almost_eq(view.token("brannoc").drawn_at, Vector2(from), Vector2(0.01, 0.01), "the token slides from where it was")
	player.advance(FightFx.MOVE_TICKS / 20.0 + 0.1)
	view.sync_fight(player)
	assert_eq(view.fx.moves.size(), 0, "slides take %d ticks" % FightFx.MOVE_TICKS)


func test_deaths_summons_and_phases_are_marked() -> void:
	var player: FightPlayer = _player()
	var view: ArenaView = _view(player)
	view.fx.add_entries([
		_entry(LogEntry.Kind.DEATH, "", "rift_hound", 0, {"to_pos": Vector2i(2000, 4000)}),
		_entry(LogEntry.Kind.SUMMON, "rift_hound", "rift_hound#2", 0, {"to_pos": Vector2i(2500, 4000)}),
		_entry(LogEntry.Kind.SUMMON, "rift_hound", "rift_pup", 0, {"note": "no room"}),
		_entry(LogEntry.Kind.PHASE, "rift_hound", "rift_hound", 0, {"note": "Molt"})] as Array[LogEntry], player)
	assert_eq(view.fx.effects.map(func(fx: FightFx.Fx) -> Array: return [fx.kind, fx.unit_id, fx.text, fx.end - fx.start]), [
		[FightFx.Kind.GHOST, "rift_hound", "", FightFx.GHOST_TICKS], [FightFx.Kind.PULSE, "rift_hound#2", "", FightFx.PULSE_TICKS],
		[FightFx.Kind.POPUP, "rift_hound", "Molt", FightFx.PHASE_TICKS]], "a dropped summon shows nothing")
	assert_true(view.fx.effects[2].big)


func test_auras_are_ringed_while_they_hold() -> void:
	var player: FightPlayer = _player()
	var view: ArenaView = _view(player)
	var starts: LogEntry = _entry(LogEntry.Kind.AURA, "brannoc", "", 0, {"source_ability": "hold_the_line_guard", "note": "starts: x1.5 DEF"})
	view.fx.add_entries([starts] as Array[LogEntry], player)
	assert_eq(view.fx.auras, {"brannoc:hold_the_line_guard": "brannoc"})
	view.fx.add_entries([_entry(LogEntry.Kind.AURA, "brannoc", "", 0, {"source_ability": "hold_the_line_guard", "note": "ends"})] as Array[LogEntry], player)
	assert_eq(view.fx.auras, {})
	view.fx.add_entries([starts, _entry(LogEntry.Kind.PUSH, "rift_hound", "maren", 0, {"from_pos": Vector2i(0, 0), "to_pos": Vector2i(900, 0)}),
		_entry(LogEntry.Kind.COLLAPSE_RING, "", "", 0, {"note": "warned", "from_pos": Vector2i(500, 500), "to_pos": Vector2i(900, 900)})] as Array[LogEntry], player)
	view.fx.clear()
	assert_eq([view.fx.auras, view.fx.moves, view.fx.warned_safe], [{}, {}, Rect2i()], "a restart clears everything")


func test_the_ring_about_to_crumble_is_marked_until_it_does() -> void:
	var player: FightPlayer = _player()
	var view: ArenaView = _view(player)
	var left: Rect2i = player.sim.grid.safe_rect(1)
	view.fx.add_entries([_entry(LogEntry.Kind.COLLAPSE_RING, "", "", 0, {"note": "warned", "from_pos": left.position, "to_pos": left.end})] as Array[LogEntry], player)
	assert_eq(view.fx.warned_safe, left)
	view.sync_fight(player)
	assert_eq(view.fx.warned_safe, left, "still warned")
	player.sim.safe = left
	view.sync_fight(player)
	assert_eq(view.fx.warned_safe, Rect2i(), "crumbled: the dark ground shows it now")
	view.fx.add_entries([_entry(LogEntry.Kind.COLLAPSE_RING, "", "", 0, {"note": "crumbled", "from_pos": left.position, "to_pos": left.end})] as Array[LogEntry], player)
	assert_eq(view.fx.warned_safe, Rect2i())


func test_target_lines_follow_hover_and_the_toggle() -> void:
	var session: PracticeSession = PracticeSession.make(_content)
	var screen: ArenaScreen = ArenaScreen.make(session, "the_pack")
	add_child_autofree(screen)
	screen.size = Vector2(1800, 1000)
	screen.setup()
	screen._fight()
	screen.view.token("maren").mouse_entered.emit()
	assert_eq(screen.view.fx.hovered, "maren")
	screen.view.token("maren").mouse_exited.emit()
	assert_eq(screen.view.fx.hovered, "")
	assert_false(screen.view.fx.all_targets)
	var key := InputEventKey.new()
	key.keycode = KEY_T
	key.pressed = true
	screen._unhandled_input(key)
	assert_true(screen.view.fx.all_targets)
	screen.target_lines.button_pressed = false
	assert_false(screen.view.fx.all_targets)


## The chaos fight has every kind of thing on the board: it's played with
## every frame drawn, so every drawing path runs.
func test_a_whole_chaos_fight_is_drawn() -> void:
	var setup: FightSetup = Chaos.setup()
	var content: ContentDb = K.content()
	var player: FightPlayer = FightPlayer.make(setup, content)
	var view := ArenaView.new()
	add_child_autofree(view)
	view.size = Vector2(1000, 900)
	view.show_setup(setup, content)
	view.set_mode(ArenaView.Mode.FIGHT)
	view.fx.all_targets = true
	var seen: Dictionary[int, bool] = {}
	while not player.finished():
		view.fx.add_entries(player.advance(0.1), player)
		view.sync_fight(player)
		for fx: FightFx.Fx in view.fx.effects:
			seen[fx.kind] = true
		if not view.fx.moves.is_empty():
			seen[-1] = true
		await wait_process_frames(1)
	for kind: int in FightFx.Kind.values():
		assert_true(seen.has(kind), "the chaos fight shows a %s" % FightFx.Kind.keys()[kind])
	assert_true(seen.has(-1), "and a slide")
