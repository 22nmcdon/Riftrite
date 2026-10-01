extends GutTest
## Every Act 1 encounter plays to its end on ArenaScreen, with fake time
## (docs/plans/rebuild-phase3-fight-sandbox.md, sections 10 and 11, step 9):
## no errors, the same fight the sim runs on its own, every log line in the
## log panel, and every kind of log entry it produced shown on the board.
## This is the plan's own bar before the playtest.

## How each kind of log entry shows, besides its line in the log panel.
## Every kind is here, so a new one can't go unshown: add it with its form.
const FORMS: Dictionary[LogEntry.Kind, String] = {
	LogEntry.Kind.FIGHT_START: "the clock starts",
	LogEntry.Kind.FIRE: "a signature's name over the unit",
	LogEntry.Kind.DAMAGE: "a number, and a swipe in melee",
	LogEntry.Kind.HEAL: "a green number",
	LogEntry.Kind.SHIELD: "a frost number, and the Shield on the HP bar",
	LogEntry.Kind.COLLAPSE: "an ember number",
	LogEntry.Kind.DEATH: "a ghost where it fell, and its token gone",
	LogEntry.Kind.FIGHT_END: "the end's banner, and the result",
	LogEntry.Kind.STATUS_APPLIED: "a tag under the unit's bars",
	LogEntry.Kind.STATUS_DAMAGE: "a number in the status's color",
	LogEntry.Kind.STATUS_ENDED: "the tag goes",
	LogEntry.Kind.STATUS_REDUCED: "the tag's stacks drop",
	LogEntry.Kind.AURA: "a ring on the holder",
	LogEntry.Kind.SYNERGY: "(not in the rebuild yet)",
	LogEntry.Kind.PHASE: "the phase's name over the unit, and a banner",
	LogEntry.Kind.DEED_LEVEL: "(not in the rebuild yet)",
	LogEntry.Kind.MOVE: "the token walks",
	LogEntry.Kind.STOP: "the token stops",
	LogEntry.Kind.TARGET: "target lines (hover, or T)",
	LogEntry.Kind.SHOT: "a shot in flight",
	LogEntry.Kind.SHOT_FIZZLED: "the shot goes",
	LogEntry.Kind.CAST: "a cast bar",
	LogEntry.Kind.CAST_CANCELLED: "the cast bar goes",
	LogEntry.Kind.SAVED: "the HP bar holds at 1",
	LogEntry.Kind.MANA_DRAIN: "the mana bar drops",
	LogEntry.Kind.BREAK_FREE: "the ENG tag goes",
	LogEntry.Kind.PUSH: "the token slides",
	LogEntry.Kind.LEAP: "the token slides",
	LogEntry.Kind.CHARGE: "the token slides",
	LogEntry.Kind.HOP: "the token slides",
	LogEntry.Kind.AREA_WARNING: "the area fills until it lands",
	LogEntry.Kind.AREA_LANDED: "a flash",
	LogEntry.Kind.COLLAPSE_RING: "the ring striped, then dark, and a banner at the first",
	LogEntry.Kind.SUMMON: "a pulse, and a new token",
	LogEntry.Kind.TACTIC: "what the tactic did, over the hero (\"Holds its ground\")",
	LogEntry.Kind.ZONE: "the zone on the ground while it lasts (from the sim's zones)",
	LogEntry.Kind.SNARE: "a snare mark on the ground until it's sprung (from the sim's snares)",
	LogEntry.Kind.WALL: "a thick line while it stands (from the sim's walls)",
	LogEntry.Kind.GUARD: "a brass number on the guard",
	LogEntry.Kind.LIFESTEAL: "a number in the lifesteal colour",
	LogEntry.Kind.STATUS_EXTENDED: "the tag stays longer",
	LogEntry.Kind.RISE: "the token returns, with a pulse and \"Rises\"",
	LogEntry.Kind.RESISTED: "\"Resisted\" over the hero",
}
## What the board must have shown at some frame, for each kind a fight
## produced (the rest are checked elsewhere, or read from the unit's state).
const EVIDENCE: Dictionary[LogEntry.Kind, String] = {
	LogEntry.Kind.SHOT: "shot",
	LogEntry.Kind.DAMAGE: "number",
	LogEntry.Kind.HEAL: "number",
	LogEntry.Kind.LIFESTEAL: "number",
	LogEntry.Kind.SHIELD: "number",
	LogEntry.Kind.STATUS_DAMAGE: "number",
	LogEntry.Kind.COLLAPSE: "number",
	LogEntry.Kind.FIRE: "popup",
	LogEntry.Kind.PHASE: "popup",
	LogEntry.Kind.TACTIC: "popup",
	LogEntry.Kind.AREA_WARNING: "area",
	LogEntry.Kind.AREA_LANDED: "landed",
	LogEntry.Kind.DEATH: "ghost",
	LogEntry.Kind.SUMMON: "pulse",
	LogEntry.Kind.PUSH: "slide",
	LogEntry.Kind.LEAP: "slide",
	LogEntry.Kind.CHARGE: "slide",
	LogEntry.Kind.HOP: "slide",
	LogEntry.Kind.AURA: "aura",
	LogEntry.Kind.COLLAPSE_RING: "warned ring",
	LogEntry.Kind.STATUS_APPLIED: "status tag",
	LogEntry.Kind.FIGHT_END: "banner",
}
const FX_EVIDENCE: Dictionary[FightFx.Kind, String] = {
	FightFx.Kind.SHOT: "shot", FightFx.Kind.NUMBER: "number", FightFx.Kind.POPUP: "popup", FightFx.Kind.AREA: "area",
	FightFx.Kind.LANDED: "landed", FightFx.Kind.GHOST: "ghost", FightFx.Kind.PULSE: "pulse", FightFx.Kind.SWIPE: "swipe",
}

var _content: ContentDb


func before_all() -> void:
	_content = ContentDb.load_dir("res://data")


func test_every_kind_of_log_entry_has_a_form() -> void:
	for kind: int in LogEntry.Kind.size():
		assert_true(FORMS.has(kind as LogEntry.Kind), "%s needs a form on the board" % LogEntry.Kind.keys()[kind])


func test_every_encounter_plays_to_its_end() -> void:
	var produced: Dictionary[LogEntry.Kind, bool] = {}
	var seen_anywhere: Dictionary[String, bool] = {}
	for encounter_id: String in _content.encounter_ids:
		var session: PracticeSession = PracticeSession.make(_content)
		session.speed = 2.0
		var screen: ArenaScreen = ArenaScreen.make(session, encounter_id)
		add_child_autofree(screen)
		screen.size = Vector2(1900, 1000)
		screen.setup()
		await wait_process_frames(1)
		screen._fight()
		var seen: Dictionary[String, bool] = {}
		var frames: int = 0
		while not screen.player.finished() and frames < 20000:
			screen._process(1.0 / 30.0)
			_look(screen, seen)
			frames += 1
		screen._process(0.1)
		_look(screen, seen)
		assert_true(screen.player.finished(), "%s ends" % encounter_id)
		var played: String = screen.player.sim.combat_log.to_text()
		assert_eq(played, CombatSim.run(screen.player.setup, _content).combat_log.to_text(), "%s: the screen plays the sim's own fight" % encounter_id)
		assert_eq(screen.log_panel.entries, screen.player.sim.combat_log.entries, "%s: every entry reached the log panel" % encounter_id)
		screen.log_panel.set_show_chatter(true)
		assert_eq(screen.log_panel.shown_text().count("\n"), screen.player.sim.combat_log.entries.size(), "%s: a line for each" % encounter_id)
		assert_true(screen.result_box.visible, "%s: the result" % encounter_id)
		var whole: FightTally = FightTally.of_fight(screen.player.setup, screen.player.sim.combat_log)
		for tab: int in FightTally.TYPES.size():
			for i: int in whole.bars[tab].size():
				assert_eq(screen.result_chart.tally.bars[tab][i].by_type, whole.bars[tab][i].by_type, "%s: the chart counts the whole log" % encounter_id)
		for entry: LogEntry in screen.player.sim.combat_log.entries:
			produced[entry.kind] = true
			if EVIDENCE.has(entry.kind):
				assert_true(seen.has(EVIDENCE[entry.kind]), "%s: %s showed as %s" % [encounter_id, LogEntry.Kind.keys()[entry.kind], FORMS[entry.kind]])
		seen_anywhere.merge(seen)
		remove_child(screen)
		screen.free()
		if is_failing():
			return
	for kind: LogEntry.Kind in [LogEntry.Kind.SHOT, LogEntry.Kind.DAMAGE, LogEntry.Kind.AREA_WARNING, LogEntry.Kind.PUSH, LogEntry.Kind.LEAP,
			LogEntry.Kind.CHARGE, LogEntry.Kind.HOP, LogEntry.Kind.AURA, LogEntry.Kind.COLLAPSE_RING, LogEntry.Kind.DEATH, LogEntry.Kind.STATUS_DAMAGE]:
		assert_true(produced.has(kind), "Act 1 has %s" % LogEntry.Kind.keys()[kind])
	assert_true(seen_anywhere.has("swipe"), "melee swipes")
	assert_true(seen_anywhere.has("collapse banner"), "the collapse's banner")


## Notes what the board shows this frame.
func _look(screen: ArenaScreen, seen: Dictionary[String, bool]) -> void:
	var fx: FightFx = screen.view.fx
	for effect: FightFx.Fx in fx.effects:
		seen[FX_EVIDENCE[effect.kind]] = true
	if not fx.moves.is_empty():
		seen["slide"] = true
	if not fx.auras.is_empty():
		seen["aura"] = true
	if fx.warned_safe.size != Vector2i.ZERO:
		seen["warned ring"] = true
	for token: UnitToken in screen.view.tokens:
		if not token.status_tags.is_empty():
			seen["status tag"] = true
	if screen.banners.visible:
		seen["banner"] = true
		if screen.banners.label.text == FightBanners.COLLAPSE_TEXT:
			seen["collapse banner"] = true
