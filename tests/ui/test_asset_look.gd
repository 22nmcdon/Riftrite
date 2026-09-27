extends GutTest
## The look from docs/ui-asset-design.md: infusion gem forms and spill arrows
## follow the game's rules, the rarity ladder and rift bleed, drop-target
## checks that never touch the real run, hex relics, and the fight HUD.

const U = preload("res://tests/ui/ui_test_kit.gd")
const MainScript = preload("res://src/ui/main.gd")
const E: Array[String] = []

var _content: ContentDb


func before_all() -> void:
	_content = U.K.content()


func _main(session: RunSession) -> Main:
	var main: Main = MainScript.new()
	main.session = session
	add_child_autofree(main)
	return main


func _tile(main: Main, uid: int) -> ItemTile:
	for node: Node in U.find_all(main, ItemTile):
		if (node as ItemTile).uid == uid:
			return node
	return null


func _decor(tile: ItemTile) -> FrameDecor:
	return U.find_all(tile, FrameDecor)[0]


# --- infusion gems and spill arrows ---------------------------------------------

func test_gem_forms() -> void:
	var F := Glyph.Infusion
	assert_eq(InfusionLook.form(_content, "hearth_knife", E, E), F.EMPTY)
	assert_eq(InfusionLook.form(_content, "hearth_knife", ["ember"] as Array[String], E), F.SINGLE)
	assert_eq(InfusionLook.form(_content, "night_lantern", ["frost", "storm"] as Array[String], E), F.ALLOY)
	assert_eq(InfusionLook.form(_content, "night_lantern", ["venom", "venom"] as Array[String], E), F.PURE)
	assert_eq(InfusionLook.form(_content, "tallow_torch", ["ember"] as Array[String], E), F.SINGLE, "a hidden transformation looks like a single")
	assert_eq(InfusionLook.form(_content, "tallow_torch", ["ember"] as Array[String], ["wildfire_torch"] as Array[String]), F.TRANSFORMATION, "once discovered")
	assert_eq(InfusionLook.form(_content, "tallow_torch", ["frost"] as Array[String], ["wildfire_torch"] as Array[String]), F.SINGLE, "only with its essence")


## The mark (docs/plans/infusion-rework.md): rays for a Resonant single, a
## star for an awakened alloy or pure double, nothing otherwise.
func test_infusion_marks_follow_the_sims_rules() -> void:
	var F := Glyph.Infusion
	var M := FrameDecor.Mark
	var R: int = _content.tuning.xp_to_resonant
	var cases: Array = [
		[["ember"], R, F.SINGLE, M.SPILLS, "a Resonant single spills"],
		[["ember"], R - 1, F.SINGLE, M.NONE, "only at Resonant"],
		[["ember", "storm"], R, F.ALLOY, M.AWAKENED, "Plasma awakens"],
		[["ember", "ember"], R, F.PURE, M.AWAKENED, "Inferno awakens"],
		[["ember", "storm"], R - 1, F.ALLOY, M.NONE, "not before Resonant"],
		[["ember", "frost"], R, F.ALLOY, M.NONE, "no named alloy: nothing to awaken"],
		[["ember"], R, F.TRANSFORMATION, M.NONE, "a transformation neither spills nor awakens"],
		[[], 0, F.EMPTY, M.NONE, "empty"],
	]
	for case: Array in cases:
		var essences: Array[String] = []
		essences.assign(case[0])
		assert_eq(InfusionLook.mark(_content, "tallow_torch", essences, case[1], case[2]), case[3], case[4])
	assert_eq(InfusionLook.mark_color(["frost"] as Array[String]), UiStyle.ESSENCE["frost"])
	assert_eq(InfusionLook.level(_content, ["ember"] as Array[String], R), Infusions.Level.RESONANT)
	assert_eq(InfusionLook.level(_content, E, 9999), Infusions.Level.BASE, "no infusion, no level")


func test_tiles_carry_the_ladder_the_rift_bleed_and_marks() -> void:
	var session: RunSession = U.at_shop()
	var state: RunState = session.state
	var knife := RunItem.make(state.take_uid(), "hearth_knife")
	var daggers := RunItem.make(state.take_uid(), "twin_daggers")
	daggers.essence_ids.append("ember")
	daggers.xp = _content.tuning.xp_to_resonant
	var bond := RunItem.make(state.take_uid(), "pack_bond")
	state.stash.append_array([knife, daggers, bond])
	var main: Main = _main(session)
	var plain: FrameDecor = _decor(_tile(main, knife.uid))
	assert_eq([plain.ornament, plain.cracks, plain.mark], [ItemDef.RARITIES.find(_content.items["hearth_knife"].rarity), false, FrameDecor.Mark.NONE])
	var resonant: FrameDecor = _decor(_tile(main, daggers.uid))
	assert_eq([resonant.mark, resonant.mark_hue], [FrameDecor.Mark.SPILLS, UiStyle.ESSENCE["ember"]])
	assert_true(_decor(_tile(main, bond.uid)).cracks, "enemy-only items carry the rift bleed")
	var gems: Array[Node] = U.find_all(_tile(main, daggers.uid), Glyph).filter(func(g: Glyph) -> bool: return g.shape == Glyph.Shape.INFUSION)
	assert_eq(gems.size(), 2, "the essence's gem, and an empty one: a second essence would fuse")
	assert_eq([(gems[0] as Glyph).infusion, (gems[1] as Glyph).infusion], [Glyph.Infusion.SINGLE, Glyph.Infusion.EMPTY])
	var knife_gems: Array[Node] = U.find_all(_tile(main, knife.uid), Glyph).filter(func(g: Glyph) -> bool: return g.shape == Glyph.Shape.INFUSION)
	assert_eq(knife_gems.size(), 2, "every item holds up to two essences")


# --- drop feedback ------------------------------------------------------------------

func test_drop_checks_never_touch_the_real_run() -> void:
	var session: RunSession = U.at_shop()
	var state: RunState = session.state
	var keep := RunItem.make(state.take_uid(), "hearth_knife")
	var copy := RunItem.make(state.take_uid(), "hearth_knife")
	var infused := RunItem.make(state.take_uid(), "dusk_tome")
	infused.essence_ids.append_array(["frost", "storm"])
	state.stash.append_array([keep, copy, infused])
	state.pouch.append("ember")
	var main: Main = _main(session)
	var before: Dictionary = state.to_dict()
	var keep_tile: ItemTile = _tile(main, keep.uid)
	assert_true(keep_tile._can_drop_data(Vector2.ZERO, {"uid": copy.uid}), "a copy combines")
	assert_eq(keep_tile.get_theme_stylebox("panel").border_color, UiStyle.GOOD)
	var full: ItemTile = _tile(main, infused.uid)
	assert_false(full._can_drop_data(Vector2.ZERO, {"pouch_index": 0}), "already two essences")
	assert_eq(full.get_theme_stylebox("panel").border_color, UiStyle.BAD)
	assert_true(keep_tile._can_drop_data(Vector2.ZERO, {"pouch_index": 0}))
	assert_eq(state.to_dict(), before, "checking changed nothing")
	keep_tile._notification(Control.NOTIFICATION_DRAG_END)
	assert_ne(keep_tile.get_theme_stylebox("panel").border_color, UiStyle.GOOD, "the outline clears after the drag")


func test_drop_zones_check_room() -> void:
	var session: RunSession = U.at_shop()
	var state: RunState = session.state
	var hero: RunHero = state.heroes[0]
	while hero.used_for(_content, ItemDef.Slot.ABILITY) < hero.slots_for(_content, ItemDef.Slot.ABILITY):
		hero.items.append(RunItem.make(state.take_uid(), "hearth_knife"))
	var extra := RunItem.make(state.take_uid(), "hearth_knife")
	state.stash.append(extra)
	session.open_hero_id = hero.hero_id
	var main: Main = _main(session)
	var zones: Array[Node] = U.find_all(main, DropZone)
	var slot_zone: DropZone = zones.filter(func(z: DropZone) -> bool: return U.text_of(z).contains(" free"))[0]
	var stash_zone: DropZone = zones.filter(func(z: DropZone) -> bool: return U.text_of(z).contains("stash"))[0]
	var sell_zone: DropZone = zones.filter(func(z: DropZone) -> bool: return U.text_of(z).contains("sell"))[0]
	assert_false(slot_zone._can_drop_data(Vector2.ZERO, {"uid": extra.uid}), "the ability slots are full, and a passive slot won't take an ability")
	assert_true(stash_zone._can_drop_data(Vector2.ZERO, {"uid": hero.items[0].uid}))
	assert_true(sell_zone._can_drop_data(Vector2.ZERO, {"uid": extra.uid}))
	assert_eq(state.stash, [extra] as Array[RunItem], "nothing moved")


# --- relics, the inspector, and the fight HUD ----------------------------------------

func test_relics_are_hex_tokens() -> void:
	var session: RunSession = U.at_shop()
	session.state.relics.append_array(["warding_knot", "rift_eaters_fang"] as Array[String])
	var main: Main = _main(session)
	var hexes: Array[Node] = U.find_all(main.guild_bar(), Glyph).filter(func(g: Glyph) -> bool: return g.shape == Glyph.Shape.HEX)
	assert_eq(hexes.size(), 2)
	assert_eq([(hexes[0] as Glyph).cracked, (hexes[1] as Glyph).cracked], [false, true], "Legendary (boss) relics carry the rift bleed")
	assert_eq((hexes[1] as Glyph).color, UiStyle.rarity_color("legendary"))
	var inspector_style: StyleBoxTexture = main.inspector.get_theme_stylebox("panel")
	assert_eq(inspector_style.texture.resource_path, UiStyle.CHROME_DIR % "panel_parchment", "the item panel is parchment")


func test_the_hp_ghost_trails_then_catches_up() -> void:
	var session: RunSession = U.at_fight()
	session.fight()
	var player: FightPlayer = FightPlayer.make(session.last_setup, session.content)
	var unit: UnitState = player.sim.heroes[0]
	var card: UnitCard = UnitCard.make(unit)
	add_child_autofree(card)
	unit.hp -= 100
	card.refresh()
	assert_gt(card._ghost_bar.value, unit.hp, "the ghost trails behind")
	for i: int in 200:
		card.refresh()
	assert_eq(card._ghost_bar.value, float(unit.hp), "then catches up")
	unit.hp += 50
	card.refresh()
	assert_eq(card._ghost_bar.value, float(unit.hp), "a heal snaps it up")


func test_crits_float_bigger() -> void:
	var session: RunSession = U.at_fight()
	session.fight()
	var player: FightPlayer = FightPlayer.make(session.last_setup, session.content)
	var card: UnitCard = UnitCard.make(player.sim.heroes[0])
	add_child_autofree(card)
	card.float_number("-5", UiStyle.BAD)
	card.float_number("-9!", UiStyle.BAD, 0.9, true)
	var labels: Array[Node] = card._overlay.get_children()
	assert_lt((labels[0] as Label).get_theme_font_size("font_size"), (labels[1] as Label).get_theme_font_size("font_size"))
	assert_eq((labels[1] as Label).get_theme_color("font_outline_color"), UiStyle.BRASS_500)


func after_each() -> void:
	if FileAccess.file_exists(U.SAVE_PATH):
		DirAccess.remove_absolute(U.SAVE_PATH)
