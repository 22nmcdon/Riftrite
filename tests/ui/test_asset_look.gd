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


func test_only_resonant_infusions_spill() -> void:
	var F := Glyph.Infusion
	var R := Infusions.Level.RESONANT
	var ember: Color = UiStyle.ESSENCE["ember"]
	var one: Array[String] = ["ember"]
	assert_eq(InfusionLook.spill_colors(F.SINGLE, one, Infusions.Level.ATTUNED), [] as Array[Color])
	assert_eq(InfusionLook.spill_colors(F.SINGLE, one, R), [ember, ember] as Array[Color], "a single: both sides")
	assert_eq(InfusionLook.spill_colors(F.PURE, ["ember", "ember"] as Array[String], R), [ember, ember] as Array[Color], "a pure double: the same as a single")
	assert_eq(InfusionLook.spill_colors(F.ALLOY, ["frost", "storm"] as Array[String], R), [UiStyle.ESSENCE["frost"], UiStyle.ESSENCE["storm"]] as Array[Color], "an alloy: first left, second right")
	assert_eq(InfusionLook.spill_colors(F.TRANSFORMATION, one, R), [] as Array[Color], "a transformation never spills")
	assert_true(InfusionLook.shows_no_spill(F.TRANSFORMATION, R))
	assert_false(InfusionLook.shows_no_spill(F.TRANSFORMATION, Infusions.Level.BASE))
	assert_false(InfusionLook.shows_no_spill(F.SINGLE, R))
	assert_eq(InfusionLook.level(_content, one, _content.tuning.xp_to_resonant), R)
	assert_eq(InfusionLook.level(_content, E, 9999), Infusions.Level.BASE, "no infusion, no level")


func test_tiles_carry_the_ladder_the_rift_bleed_and_arrows() -> void:
	var session: RunSession = U.at_caravan()
	var state: RunState = session.state
	var knife := RunItem.make(state.take_uid(), "hearth_knife")
	var daggers := RunItem.make(state.take_uid(), "twin_daggers")
	daggers.essence_ids.append("ember")
	daggers.xp = _content.tuning.xp_to_resonant
	var bond := RunItem.make(state.take_uid(), "pack_bond")
	state.stash.append_array([knife, daggers, bond])
	var main: Main = _main(session)
	var plain: FrameDecor = _decor(_tile(main, knife.uid))
	assert_eq([plain.ornament, plain.cracks, plain.spill], [ItemDef.RARITIES.find(_content.items["hearth_knife"].rarity), false, [] as Array[Color]])
	var resonant: FrameDecor = _decor(_tile(main, daggers.uid))
	assert_eq(resonant.spill, [UiStyle.ESSENCE["ember"], UiStyle.ESSENCE["ember"]] as Array[Color])
	assert_true(_decor(_tile(main, bond.uid)).cracks, "enemy-only items carry the rift bleed")
	var gems: Array[Node] = U.find_all(_tile(main, daggers.uid), Glyph).filter(func(g: Glyph) -> bool: return g.shape == Glyph.Shape.INFUSION)
	assert_eq(gems.size(), 1, "one socket, one gem")
	assert_eq((gems[0] as Glyph).infusion, Glyph.Infusion.SINGLE)


# --- drop feedback ------------------------------------------------------------------

func test_drop_checks_never_touch_the_real_run() -> void:
	var session: RunSession = U.at_caravan()
	var state: RunState = session.state
	var keep := RunItem.make(state.take_uid(), "hearth_knife")
	var copy := RunItem.make(state.take_uid(), "hearth_knife")
	var infused := RunItem.make(state.take_uid(), "dusk_tome")
	infused.essence_ids.append("frost")
	state.stash.append_array([keep, copy, infused])
	state.pouch.append("ember")
	var main: Main = _main(session)
	var before: Dictionary = state.to_dict()
	var keep_tile: ItemTile = _tile(main, keep.uid)
	assert_true(keep_tile._can_drop_data(Vector2.ZERO, {"uid": copy.uid}), "a copy combines")
	assert_eq(keep_tile.get_theme_stylebox("panel").border_color, UiStyle.GOOD)
	var full: ItemTile = _tile(main, infused.uid)
	assert_false(full._can_drop_data(Vector2.ZERO, {"pouch_index": 0}), "no free socket")
	assert_eq(full.get_theme_stylebox("panel").border_color, UiStyle.BAD)
	assert_true(keep_tile._can_drop_data(Vector2.ZERO, {"pouch_index": 0}))
	assert_eq(state.to_dict(), before, "checking changed nothing")
	keep_tile._notification(Control.NOTIFICATION_DRAG_END)
	assert_ne(keep_tile.get_theme_stylebox("panel").border_color, UiStyle.GOOD, "the outline clears after the drag")


func test_drop_zones_check_room() -> void:
	var session: RunSession = U.at_caravan()
	var state: RunState = session.state
	var hero: RunHero = state.heroes[0]
	while hero.used_slots(_content) < hero.slots():
		hero.items.append(RunItem.make(state.take_uid(), "hearth_knife"))
	var extra := RunItem.make(state.take_uid(), "hearth_knife")
	state.stash.append(extra)
	session.open_hero_id = hero.hero_id
	var main: Main = _main(session)
	var zones: Array[Node] = U.find_all(main, DropZone)
	var slot_zone: DropZone = zones.filter(func(z: DropZone) -> bool: return U.text_of(z).contains("free slot"))[0]
	var stash_zone: DropZone = zones.filter(func(z: DropZone) -> bool: return U.text_of(z).contains("stash"))[0]
	var sell_zone: DropZone = zones.filter(func(z: DropZone) -> bool: return U.text_of(z).contains("sell"))[0]
	assert_false(slot_zone._can_drop_data(Vector2.ZERO, {"uid": extra.uid}), "the hero's row is full")
	assert_true(stash_zone._can_drop_data(Vector2.ZERO, {"uid": hero.items[0].uid}))
	assert_true(sell_zone._can_drop_data(Vector2.ZERO, {"uid": extra.uid}))
	assert_eq(state.stash, [extra] as Array[RunItem], "nothing moved")


# --- relics, the inspector, and the fight HUD ----------------------------------------

func test_relics_are_hex_tokens() -> void:
	var session: RunSession = U.at_caravan()
	session.state.relics.append_array(["warding_knot", "rift_eaters_fang"] as Array[String])
	var main: Main = _main(session)
	var hexes: Array[Node] = U.find_all(main.guild_bar(), Glyph).filter(func(g: Glyph) -> bool: return g.shape == Glyph.Shape.HEX)
	assert_eq(hexes.size(), 2)
	assert_eq([(hexes[0] as Glyph).cracked, (hexes[1] as Glyph).cracked], [false, true], "Legendary (boss) relics carry the rift bleed")
	assert_eq((hexes[1] as Glyph).color, UiStyle.rarity_color("legendary"))
	var inspector_style: StyleBoxFlat = main.inspector.get_theme_stylebox("panel")
	assert_eq(inspector_style.bg_color, UiStyle.PARCHMENT_100, "the inspector is parchment")


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
