extends GutTest
## Unit details (docs/plans/rebuild-phase3-fight-sandbox.md, section 7,
## Decisions 3 and 5): every ability has its sentence, one with a reach names
## it, the numbers lines come from the kit; hovering an enemy fills the side
## panel, and clicking a hero opens its popup only while the fight isn't
## playing.

const K = preload("res://tests/sim/sim_test_kit.gd")
const Chaos = preload("res://tests/sim/chaos_fight.gd")
const U = preload("res://tests/ui/ui_test_kit.gd")

var _content: ContentDb


func before_all() -> void:
	_content = ContentDb.load_dir("res://data")


## Every content kit, by id.
func _kits() -> Dictionary[String, UnitDef]:
	var kits: Dictionary[String, UnitDef] = {}
	for id: String in _content.hero_ids:
		kits[id] = _content.heroes[id].kit
	for id: String in _content.enemy_ids:
		kits[id] = _content.enemies[id].kit
	return kits


## Each ability a kit has, with its sentence: [name, ability, text].
func _abilities(kit: UnitDef) -> Array[Array]:
	var found: Array[Array] = [[kit.basic_attack.name, kit.basic_attack, kit.basic_attack.text]]
	if kit.signature != null:
		found.append([kit.signature.name, kit.signature, kit.signature.text])
	for part: PartDef in kit.passives:
		found.append([part.name, part.ability, part.text])
	return found


func _numbers(kit: UnitDef, who: String = "it") -> Array[String]:
	var found: Array[String] = []
	for line: UnitInfo.Line in UnitInfo.lines(kit, who, _content):
		found.append(line.numbers)
	return found


# --- the text ---------------------------------------------------------------------

func test_every_ability_and_passive_has_its_sentence() -> void:
	var kits: Dictionary[String, UnitDef] = _kits()
	assert_eq(kits.size(), 12)
	for id: String in kits:
		for line: UnitInfo.Line in UnitInfo.lines(kits[id], "it", _content):
			assert_false(line.text.is_empty(), "%s: %s" % [id, line.name])
			assert_true(line.text.ends_with("."), "%s: %s is a sentence" % [id, line.name])


func test_a_sentence_names_every_reach() -> void:
	var checked: int = 0
	for id: String in _kits():
		var kit: UnitDef = _kits()[id]
		for ability: Array in _abilities(kit):
			if ability[1] == null:
				continue
			for reach: int in UnitInfo.reaches(ability[1], kit):
				var named := RegEx.create_from_string("\\b%d hex" % reach)
				assert_not_null(named.search(ability[2]), "%s's %s names %s (Decision 5): %s" % [id, ability[0], UnitInfo.hexes(reach), ability[2]])
				checked += 1
	assert_eq(checked, 18, "every reach in the Act 1 kits")


func test_what_counts_as_a_reach() -> void:
	var kits: Dictionary[String, UnitDef] = _kits()
	assert_eq(UnitInfo.reaches(kits["maren"].basic_attack, kits["maren"]), [4] as Array[int], "a ranged basic attack's range")
	assert_eq(UnitInfo.reaches(kits["brannoc"].basic_attack, kits["brannoc"]), [] as Array[int], "not a melee one's")
	assert_eq(UnitInfo.reaches(kits["brannoc"].signature, kits["brannoc"]), [2] as Array[int], "a signature on himself: only its area")
	assert_eq(UnitInfo.reaches(kits["vell"].signature, kits["vell"]), [3] as Array[int], "a signature with no max_range reaches the unit's range")
	assert_eq(UnitInfo.reaches(kits["cinder_moth"].signature, kits["cinder_moth"]), [5, 2] as Array[int], "its reach, then its area")
	assert_eq(UnitInfo.reaches(kits["rift_pup"].basic_attack, kits["rift_pup"]), [1] as Array[int], "a bonus's within, in hexes")
	assert_eq(UnitInfo.reaches(kits["vell"].passives[0].ability, kits["vell"]), [1] as Array[int], "a passive's area")
	assert_eq(UnitInfo.reaches(kits["brannoc"].passives[1].ability, kits["brannoc"]), [] as Array[int])
	var brute: UnitDef = Chaos.setup().enemies[4].def
	var ring: UnitDef = Chaos.setup().heroes[0].def
	assert_eq(UnitInfo.reaches(ring.signature, ring), [2] as Array[int], "an area's own effects add nothing")
	assert_eq(UnitInfo.reaches(brute.signature, brute), [1] as Array[int], "farthest, with no max_range: its range")
	var nested := EffectDef.new()
	nested.type = EffectDef.Type.DAMAGE
	nested.bonus_within = 3 * HexGrid.HEX
	var area := EffectDef.new()
	area.type = EffectDef.Type.AREA
	area.shape = ring.signature.effects[0].shape
	area.area_effects.append(nested)
	var wide := AbilityDef.new()
	wide.effects.append(area)
	assert_eq(UnitInfo.reaches(wide, ring), [2, 3] as Array[int], "an area's own effects' bonuses too")


# --- the numbers ------------------------------------------------------------------

func test_the_numbers_lines_of_the_act_1_kits() -> void:
	var kits: Dictionary[String, UnitDef] = _kits()
	assert_eq(_numbers(kits["brannoc"], "Brannoc"), [
		"Every 1.2s · melee · 14 damage (100% ATK)",
		"At 80 mana · 2-hex circle around it · Taunt 3s",
		"x1.5 DEF while taunting",
		"When an ally drops below 40% HP (once a fight) · 60 Shield",
		"Breaking free takes 1s",
	] as Array[String])
	assert_eq(_numbers(kits["maren"]), ["Every 1s · reach 4 hexes · 22 damage (100% ATK)", "At 50 mana · reach 4 hexes · Marked 4s", "Every hop · Stealth 1s", "At most once every 6s"] as Array[String])
	assert_eq(_numbers(kits["vell"]), ["Every 1.5s · reach 3 hexes · 6 damage (100% ATK)", "At 60 mana · reach 3 hexes · heals 40 (20 + 100% MGK)",
		"Every 1s · 1-hex circle around it · heals 1% of max HP"] as Array[String])
	assert_eq(_numbers(kits["rift_pup"]), ["Every 1s · melee · 8 damage (100% ATK), +20% per other Rift Pup within 1 hex"] as Array[String])
	assert_eq(_numbers(kits["ashling"])[1], "As it falls · 1-hex circle around it · 6 Burn")
	assert_eq(_numbers(kits["rift_hound"])[1], "Once, as the fight starts · reach 4 hexes · leaps up to 4 hexes · 18 damage (100% ATK)")
	assert_eq(_numbers(kits["cinder_moth"]), ["Every 1.5s · reach 3 hexes · 8 damage (100% ATK)", "At 40 mana · reach 5 hexes · 2-hex circle at the target (1s warning) · 4 Burn", ""] as Array[String])
	assert_eq(_numbers(kits["cairn_guardian"])[1], "At 60 mana · reach 3 hexes · charges 3 hexes, knocking back 2 hexes")
	assert_eq(_numbers(kits["bog_lurker"])[1], "At 50 mana · reach 5 hexes · pulls 2 hexes · Root 3s")
	assert_eq(_numbers(kits["gloam_witch"])[2], "Every 3rd basic attack · 30 Shield to all allies")
	var names: Array[String] = []
	for line: UnitInfo.Line in UnitInfo.lines(kits["brannoc"], "Brannoc", _content):
		names.append("%s: %s" % [line.kind, line.name])
	assert_eq(names, ["Basic attack: Shield Bash", "Signature: Hold the Line", "Passive: Hold the Line", "Passive: Hearthguard", "Trait: Engage"] as Array[String])


func test_the_numbers_of_every_other_piece() -> void:
	var setup: FightSetup = Chaos.setup()
	var kits: Array[UnitDef] = []
	for unit: UnitSetup in setup.units():
		if not kits.has(unit.def):
			kits.append(unit.def)
	var all: Array[String] = []
	for kit: UnitDef in kits:
		for line: UnitInfo.Line in UnitInfo.lines(kit, "it", _content):
			all.append("%s: %s" % [line.name, line.numbers])
	assert_eq(all, [
		"Strike: Every 1s · melee · 15 damage (8 + 50% ATK) · Marked 4s · Stun 1s",
		"Hold the Line: Once, below 50% HP · 2-hex ring around it · Taunt 3s · 10 damage",
		"Engage: Breaking free takes 1s",
		"Strike: Every 1.1s · reach 4 hexes · 6 damage · 2 Burn",
		"Mend: At 40 mana · 0.5s cast · reach 6 hexes · heals 60 (40 + 100% MGK) · 20 Shield · cleanses 50% of damage over time",
		"Rally: x1.2 ATK for all allies until 20s",
		"Venom: Burn becomes Poison",
		"Strike: Every 0.9s · melee · 21 damage (10 + 60% ATK) · 1 Burn · Stun 1s",
		"Rush: Every 3rd basic attack · reach 3 hexes · charges 3 hexes, knocking back 1 hex · 15 damage",
		"Feast: Every kill · heals 60",
		"Strike: Every 1s · reach 5 hexes · 15 damage (9 + 50% ATK) · 1 Bleed",
		"Last Rites: Once, when it would fall · Undying 2s",
		"Snare: Every 4th basic attack · pulls 2 hexes",
		"Vanish: Every hop · Stealth 1s",
		"Hop away: At most once every 3s",
		"Strike: Every 1s · melee · 10 damage",
		"Pounce: Once, as the fight starts · reach 5 hexes · leaps up to 5 hexes · 12 damage",
		"Pack: x1.1 ATSP for all allies",
		"Snap: Every 3rd hit taken · knocks back 1 hex",
		"Engage: Breaking free takes 1s",
		"Flying: ",
		"Strike: Every 1s · reach 4 hexes · 7 damage · Slow 2s",
		"Hush: At 30 mana · 1s cast · reach 6 hexes · 1-hex circle at the target (0.5s warning) · Silence 3s · drains 20 mana",
		"Strike: Every 1.5s · reach 3 hexes · 3-hex line at the target · 8 damage · 1 Poison",
		"Brood: Every 4th hit taken · summons 2 pup",
		"Strike: Every 1.4s · melee · 26 damage (16 + 50% ATK)",
		"Drag: Once, at 5s · reach 1 hex · pulls 3 hexes · Root 1.5s",
		"Molt: Below 80% HP · new signature: Call the Brood",
		"Last Ember: Below 50% HP · new signature: Ember Breath · new passive: Cinders",
	] as Array[String], "every line of the chaos fight's kits: every trigger, and most effects")
	var guard := EffectDef.new()
	guard.trigger = EffectDef.Trigger.ON_ALLY_BELOW_HP
	guard.threshold_bp = 3000
	assert_eq(UnitInfo.passive_trigger_text(guard), "When an ally drops below 30% HP (once per ally)")
	var molt: PhaseDef = Chaos.setup().enemies[4].def.phases[0]
	molt.basic_attack = Chaos.setup().heroes[0].def.basic_attack
	assert_eq(UnitInfo.phase_numbers(molt), "Below 80% HP · new signature: Call the Brood · new basic attack: Strike")


func test_small_words() -> void:
	assert_eq([UnitInfo.seconds(20), UnitInfo.seconds(24), UnitInfo.seconds(3), UnitInfo.seconds(0), UnitInfo.seconds(1200)], ["1s", "1.2s", "0.15s", "0s", "60s"])
	assert_eq([UnitInfo.hexes(1), UnitInfo.hexes(2)], ["1 hex", "2 hexes"])
	assert_eq([UnitInfo._nth(1, "kill"), UnitInfo._nth(2, "x"), UnitInfo._nth(3, "x"), UnitInfo._nth(4, "x"), UnitInfo._nth(11, "x"), UnitInfo._nth(12, "x"), UnitInfo._nth(21, "x"), UnitInfo._nth(22, "x"), UnitInfo._nth(113, "x")],
		["kill", "2nd x", "3rd x", "4th x", "11th x", "12th x", "21st x", "22nd x", "113th x"])
	var shield := EffectDef.new()
	shield.type = EffectDef.Type.SHIELD
	shield.amount_bp_of_damage = 2500
	assert_eq(UnitInfo._effect_text(shield, _kits()["maren"], _content), "Shield of 25% of the hit")
	shield.amount_bp_of_damage = 0
	shield.amount = 12
	shield.target = EffectDef.Target.ALL_ENEMIES
	assert_eq(UnitInfo._effect_text(shield, _kits()["maren"], _content), "12 Shield to all enemies")
	var start := EffectDef.new()
	start.type = EffectDef.Type.START_COLLAPSE
	assert_eq(UnitInfo._effect_text(start, _kits()["maren"], _content), "starts Rift Collapse")
	var summon := EffectDef.new()
	summon.type = EffectDef.Type.SUMMON
	summon.summon_kit = "rift_pup"
	summon.count = 2
	assert_eq(UnitInfo._effect_text(summon, _kits()["maren"], _content), "summons 2 Rift Pup")
	var bonus := EffectDef.new()
	bonus.type = EffectDef.Type.DAMAGE
	bonus.amount = 5
	bonus.bonus_bp_per_ally = 1000
	bonus.bonus_within = 2 * HexGrid.HEX
	assert_eq(UnitInfo._effect_text(bonus, _kits()["maren"], _content), "5 damage, +10% per other ally within 2 hexes", "any ally when no kit is named")
	var stun := EffectDef.new()
	stun.type = EffectDef.Type.APPLY_STATUS
	stun.status_id = "engaged"
	assert_eq(UnitInfo._effect_text(stun, _kits()["maren"], _content), "Engaged", "a status with no time of its own")
	assert_eq(UnitInfo.trait_text("flying", "Maren"), "Maren flies over units and rocks, and lands only to attack.")
	assert_eq(UnitInfo.trait_numbers("flying", _kits()["cinder_moth"], _content.tuning), "")
	assert_eq(UnitInfo._unit_name("maren", _content), "Maren Thistledown")
	assert_eq(UnitInfo._unit_name("nobody", _content), "nobody")
	assert_eq(UnitInfo._status_name("nothing", _content), "nothing")


# --- during a fight ---------------------------------------------------------------

func test_live_numbers_and_recent_lines() -> void:
	var errors: Array[String] = []
	var player: FightPlayer = FightPlayer.make(Encounters.setup(_content, "the_pack", PracticeSession.DEFAULT_FORMATION, 3, errors), _content)
	var brannoc: UnitState = player.sim.unit_by_id("brannoc")
	assert_eq(UnitInfo.live_text(brannoc), "HP 420/420 · Mana 30/80")
	player.advance(3.0)
	brannoc.shield = 25
	var text: String = UnitInfo.live_text(brannoc)
	assert_true(text.begins_with("HP %d/420 · Shield 25 · Mana %d/80" % [brannoc.hp, brannoc.mana / Mana.SCALE]), text)
	var hound: UnitState = player.sim.unit_by_id("rift_hound")
	assert_eq(UnitInfo.live_text(hound), "HP %d/%d" % [hound.hp, hound.max_hp], "no mana bar, no mana")
	var marked: bool = false
	while not marked and not player.finished():
		player.advance(0.05)
		for unit: UnitState in player.sim.enemies:
			if unit.alive and unit.statuses.size() > 0:
				assert_string_contains(UnitInfo.live_text(unit), "\nMarked")
				marked = true
	assert_true(marked, "Maren marks someone")
	var names: FightNames = FightNames.make(player.sim, _content)
	var fresh: FightPlayer = FightPlayer.make(player.setup, _content)
	fresh.advance(0.3)
	var about: Array[LogEntry] = fresh.sim.combat_log.entries.filter(func(entry: LogEntry) -> bool: return "brannoc" in [entry.source_unit, entry.target])
	assert_true(about.slice(about.size() - 4).any(func(entry: LogEntry) -> bool: return UnitInfo.CHATTER.has(entry.kind)), "his last lines include walking or targeting")
	assert_true(about.any(func(entry: LogEntry) -> bool: return entry.target == "brannoc" and entry.source_unit != "brannoc"), "and hits on him")
	var early: Array[String] = []
	for entry: LogEntry in about:
		if not UnitInfo.CHATTER.has(entry.kind):
			early.append(names.text(entry))
	assert_eq(UnitInfo.recent_lines("brannoc", fresh.sim.combat_log, names, 10), early.slice(maxi(early.size() - 10, 0)), "the chatter left out, lines aimed at him kept")
	var lines: Array[String] = UnitInfo.recent_lines("maren", player.sim.combat_log, names)
	assert_eq(lines.size(), 3)
	var expected: Array[String] = []
	for entry: LogEntry in player.sim.combat_log.entries:
		if not UnitInfo.CHATTER.has(entry.kind) and "maren" in [entry.source_unit, entry.target]:
			expected.append(names.text(entry))
	assert_eq(lines, expected.slice(expected.size() - 3), "its last three lines, oldest first")
	assert_eq(UnitInfo.recent_lines("maren", player.sim.combat_log, names, 1), expected.slice(expected.size() - 1))
	var burning: FightPlayer = FightPlayer.make(Encounters.setup(_content, "moth_cloud", PracticeSession.DEFAULT_FORMATION, 3, errors), _content)
	var burn_text: String = ""
	while burn_text.is_empty() and not burning.finished():
		burning.advance(0.05)
		for hero: UnitState in burning.sim.heroes:
			for status: StatusState in hero.statuses:
				if status.def.id == "burn" and hero.alive:
					burn_text = UnitInfo.live_text(hero)
					assert_string_contains(burn_text, "\n%d Burn" % status.total_stacks(), "damage over time with its stacks")
	assert_false(burn_text.is_empty(), "the moths burn someone")
	player.skip_to_end()
	for unit: UnitState in player.sim.units:
		if not unit.alive:
			assert_eq(UnitInfo.live_text(unit), "Fallen")


# --- on the screen ----------------------------------------------------------------

func _screen(encounter_id: String = "the_pack") -> ArenaScreen:
	var screen: ArenaScreen = ArenaScreen.make(PracticeSession.make(_content), encounter_id)
	add_child_autofree(screen)
	screen.size = Vector2(1900, 1000)
	screen.setup()
	await wait_process_frames(2)
	return screen


func _click(screen: ArenaScreen, unit_id: String) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	click.position = screen.view.token(unit_id).center() if not unit_id.is_empty() else Vector2(2, 2)
	screen.view._gui_input(click)


func test_hovering_an_enemy_shows_its_abilities() -> void:
	var screen: ArenaScreen = await _screen("moth_cloud")
	screen.view.token("cinder_moth").mouse_entered.emit()
	var text: String = U.text_of(screen.enemy_panel)
	for line: UnitInfo.Line in UnitInfo.lines(_content.enemies["cinder_moth"].kit, "it", _content):
		assert_string_contains(text, "%s · %s" % [line.name, line.kind.to_lower()])
		assert_string_contains(text, line.text)
		if not line.numbers.is_empty():
			assert_string_contains(text, line.numbers)
	for label: Node in U.find_all(screen.enemy_panel.abilities, Label):
		assert_false((label as Label).text.is_empty(), "no empty line for Flying's numbers")
	assert_false(screen.enemy_panel.live.visible, "no live numbers while placing")
	screen._fight()
	screen._process(2.0)
	assert_true(screen.enemy_panel.live.visible)
	assert_eq(screen.enemy_panel.live.text, UnitInfo.live_text(screen.player.sim.unit_by_id("cinder_moth")), "its numbers now")
	screen._process(1.0)
	assert_eq(screen.enemy_panel.live.text, UnitInfo.live_text(screen.player.sim.unit_by_id("cinder_moth")), "kept up each frame")
	screen.view.token("cinder_moth").mouse_exited.emit()
	screen.view.token("rift_pup").mouse_entered.emit()
	assert_eq(screen.enemy_panel.title.text, "Rift Pup")
	assert_false(U.text_of(screen.enemy_panel).contains("Ember Dust"), "the last enemy's lines are gone")
	screen.place_again()
	assert_eq(screen.enemy_panel.showing, "", "placing again clears it")


func test_clicking_a_hero_opens_the_popup_only_while_the_fight_isnt_playing() -> void:
	var screen: ArenaScreen = await _screen()
	assert_false(screen.hero_popup.visible)
	_click(screen, "vell")
	await wait_process_frames(2)
	assert_true(screen.hero_popup.visible, "in placement")
	assert_eq(screen.hero_popup.showing, "vell")
	assert_eq([screen.hero_popup.title.text, screen.hero_popup.role.text, screen.hero_popup.stats.text],
		["Sister Vell", "The Mender · Support", "HP 300 · ATK 6 · MGK 20 · DEF 10 · Speed 2 · Range 3"])
	var text: String = U.text_of(screen.hero_popup)
	for line: UnitInfo.Line in UnitInfo.lines(_content.heroes["vell"].kit, "Vell", _content):
		assert_string_contains(text, line.text)
		assert_string_contains(text, line.numbers)
	assert_false(screen.hero_popup.live.visible, "no fight, no live numbers")
	var popup: HeroPopup = screen.hero_popup
	assert_eq([popup.live.get_index() + 1, popup.tactic_box.get_index() - 1, popup.recent.get_index() - 2], [popup.abilities.get_index(), popup.abilities.get_index(), popup.abilities.get_index()],
		"the lines between the numbers now and the tactic, then the log")
	var token: UnitToken = screen.view.token("vell")
	var rect := Rect2(screen.hero_popup.position, screen.hero_popup.size)
	assert_true(Rect2(Vector2.ZERO, screen.view.size).encloses(rect), "inside the board")
	assert_false(rect.has_point(token.center()), "beside the hero, not over it")
	assert_gte(token.size.x, UnitToken.HIT_PX * 2.0, "a small unit still has a grabbable rect")
	assert_lt(token.radius_px, UnitToken.HIT_PX, "0.2 hex units draw smaller than that")
	assert_eq(screen.view.token_at(token.center() + Vector2(UnitToken.HIT_PX - 1.0, 0.0)), token, "a click just off its circle still finds it")
	_click(screen, "")
	assert_false(screen.hero_popup.visible, "a click on the board closes it")
	_click(screen, "maren")
	_click(screen, "rift_hound")
	assert_false(screen.hero_popup.visible, "clicking an enemy closes it")
	_click(screen, "brannoc")
	screen._fight()
	assert_false(screen.hero_popup.visible, "the fight starting closes it")
	_click(screen, "maren")
	assert_false(screen.hero_popup.visible, "while the fight plays, a click on a hero only filters the log")
	assert_eq(screen.log_panel.only_unit, "maren")
	screen._process(2.0)
	screen.toggle_pause()
	_click(screen, "maren")
	assert_true(screen.hero_popup.visible, "paused")
	var maren: UnitState = screen.player.sim.unit_by_id("maren")
	assert_eq(screen.hero_popup.live.text, UnitInfo.live_text(maren))
	assert_true(screen.hero_popup.recent.visible)
	assert_eq(screen.hero_popup.recent.text, "Last in the log:\n" + "\n".join(UnitInfo.recent_lines("maren", screen.player.sim.combat_log, screen.names)))
	screen.toggle_pause()
	screen._process(0.1)
	assert_false(screen.hero_popup.visible, "playing on closes it")
	screen.skip()
	var standing: String = ""
	for hero: UnitState in screen.player.sim.heroes:
		if hero.alive:
			standing = hero.id
	var fallen: String = ""
	for unit: UnitState in screen.player.sim.units:
		if not unit.alive:
			fallen = unit.id
	assert_ne(fallen, "", "someone fell")
	var fallen_token: UnitToken = screen.view.token(fallen)
	assert_ne(screen.view.token_at(fallen_token.center()), fallen_token, "a fallen unit's token takes no clicks")
	_click(screen, standing)
	assert_true(screen.hero_popup.visible, "over")
	assert_eq(screen.hero_popup.live.text, UnitInfo.live_text(screen.player.sim.unit_by_id(standing)))
	screen.place_again()
	assert_false(screen.hero_popup.visible, "placing again closes it")


func test_the_popup_opens_on_the_left_near_the_right_edge() -> void:
	var screen: ArenaScreen = await _screen()
	_click(screen, "vell")
	await wait_process_frames(2)
	var token: UnitToken = screen.view.token("vell")
	assert_gt(screen.hero_popup.position.x, token.center().x, "to the right of a hero with room there")
	# A hero who walked to the board's right edge (the heroes start on the
	# left): no room to the right.
	token.place_at(screen.view, Vector2(3500, 6900))
	screen._place_popup()
	assert_lt(screen.hero_popup.position.x + screen.hero_popup.size.x, token.center().x, "to the left of the hero")
	assert_gte(screen.hero_popup.position.x, 0.0, "on the board")
	screen._show()
	assert_false(screen.hero_popup.recent.visible)
	screen._fight()
	screen.toggle_pause()
	_click(screen, "vell")
	assert_eq(UnitInfo.recent_lines("vell", screen.player.sim.combat_log, screen.names), [] as Array[String])
	assert_true(screen.hero_popup.live.visible)
	assert_false(screen.hero_popup.recent.visible, "nothing in the log about her yet")


func test_hovering_a_summon_reads_it_from_the_fight() -> void:
	var screen: ArenaScreen = await _screen()
	screen._fight()
	var sim: CombatSim = screen.player.sim
	var hound: UnitState = sim.unit_by_id("rift_hound")
	var joined: UnitState = UnitState.make_summon(hound.def, hound.side, sim.next_unit_id(hound.def.id), sim.units.size(), sim.tuning.unit_radius)
	joined.pos = Vector2i(3000, 6000)
	sim.add_unit(joined)
	sim.units_joined()
	screen._process(0.05)
	screen.view.token(joined.id).mouse_entered.emit()
	assert_eq([screen.enemy_panel.showing, screen.enemy_panel.title.text], [joined.id, "Rift Hound"], "a unit that wasn't placed")
	assert_eq(screen.enemy_panel.live.text, UnitInfo.live_text(joined))
