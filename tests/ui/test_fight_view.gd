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
	hound.pos = brannoc.pos + Vector2i(0, 900)
	view.fx.add_entries([_entry(LogEntry.Kind.DAMAGE, "brannoc", "rift_hound", 14)] as Array[LogEntry], player)
	assert_eq(_kinds(view.fx), [FightFx.Kind.SWIPE, FightFx.Kind.NUMBER])
	assert_eq([view.fx.effects[1].text, view.fx.effects[1].big], ["14", false])
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
