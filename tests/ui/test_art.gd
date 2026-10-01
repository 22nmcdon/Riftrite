extends GutTest
## The uploaded art in the game (docs/plans/rebuild-phase5b-art.md): every
## piece the data or the UI names is there and loads.

const MainScript = preload("res://src/ui/main.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func test_the_fonts_load() -> void:
	for path: String in [UiStyle.BODY_FONT, UiStyle.SEMIBOLD_FONT, UiStyle.BOLD_FONT, UiStyle.HEADING_FONT, UiStyle.TITLE_FONT, UiStyle.FALLBACK_FONT]:
		assert_true(load(path) is FontFile, path)


## Section 5: each kind has a frame and a color, and every item and relic's
## glyph loads.
func test_every_icon_loads() -> void:
	for kind: String in ItemIcon.KINDS:
		assert_true(ArenaView.art(ItemIcon.FRAMES % ItemIcon.FRAME_OF.get(kind, kind)) is Texture2D, kind)
		assert_true(ItemIcon.TINTS.has(kind), kind)
	for kind: String in ItemDef.KIND_NAMES:
		assert_has(ItemIcon.KINDS, kind)
	for id: String in _run.item_ids:
		var icon: ItemIcon = ItemIcon.for_item(_run.items[id])
		assert_not_null(icon.glyph_texture, id)
		assert_eq(icon.kind, ItemDef.KIND_NAMES[_run.items[id].kind], "%s is in its kind's frame" % id)
		icon.free()
	for id: String in _run.relic_ids:
		var icon: ItemIcon = ItemIcon.for_relic(_run.relics[id])
		assert_not_null(icon.glyph_texture, id)
		icon.free()
	var bare: ItemIcon = ItemIcon.make("sigil", "")
	assert_null(bare.glyph_texture, "an empty slot's bare frame")
	bare.free()


## The hero bar's chips and the day's cards carry the icons.
func test_the_run_shows_the_icons() -> void:
	var main: Main = MainScript.new()
	main.old_save_path = "user://test_art_old.json"
	main.run_save_path = "user://test_art.json"
	add_child_autofree(main)
	main.show_run_start(7)
	(main.screen as RunStartScreen).run_started.emit((main.screen as RunStartScreen).vows, 7)
	var flow: RunFlow = main.run_session.flow
	flow.state.hero("maren").slots[0] = "ember_tipped"
	flow.state.relics.append("hollow_crown")
	flow.state.camp.assign(["pedlar"])
	flow.state.shards = 20
	flow.choose_camp(0)
	var day: RunDayScreen = main.screen as RunDayScreen
	day.refresh()
	var chip_icons: Array = day.hero_bar.cards["maren"].chips.find_children("*", "ItemIcon", true, false)
	assert_eq(chip_icons.size(), 1, "the filled slot's chip has its icon")
	assert_eq((chip_icons[0] as ItemIcon).glyph, "ember_heart")
	var shown: Array[String] = []
	for icon: Node in day.find_children("*", "ItemIcon", true, false):
		shown.append((icon as ItemIcon).kind + ":" + (icon as ItemIcon).glyph)
	assert_has(shown, "relic:hollow_crown", "the top bar's relic")
	for ware: String in flow.state.wares:
		if not ware.is_empty():
			assert_has(shown, "%s:%s" % [ItemDef.KIND_NAMES[flow.run.items[ware].kind], flow.run.items[ware].icon], "the Pedlar's %s" % ware)
	RunSave.erase(main.run_save_path)
	await wait_frames(1)


## Section 6: every camp option and place has its icon, and each shop its
## scene and keeper.
func test_camp_and_the_shops() -> void:
	for option: CampsDef.Option in _run.camps.options.values():
		assert_true(ArenaView.art(RunContent.ART_UI + option.icon) is Texture2D, option.id)
	for place: CampsDef.Place in _run.camps.places:
		assert_true(ArenaView.art(RunContent.ART_UI + place.icon) is Texture2D, place.id)
	for shop: String in ["pedlar", "magpie"]:
		var stage: ShopStage = ShopStage.make(shop)
		assert_not_null(stage.scene, shop)
		assert_not_null(stage.figure, shop)
		assert_true(ShopStage.STANDS.has(shop), shop)
		stage.free()
