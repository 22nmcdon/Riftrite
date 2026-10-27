extends GutTest
## How the game loads art (docs/plans/rebuild-phase7a-asset-loading.md),
## against the small files in tests/fixtures/art/: a PNG wins over its SVG,
## a figure draws at its canvas size whatever its resolution, a boss's canvas
## is twice the size, the manifest's points place the bars and the shots,
## portraits fall back to the figure, and an apex or a specialization stands
## as its own figure where it's drawn.

const FigureBounds := preload("res://tools/art/figure_bounds.gd")
const FIXTURES: String = "res://tests/fixtures/art/"
const FIGURES: String = FIXTURES + "figures/"

var _content: ContentDb


func before_all() -> void:
	_content = ContentDb.load_dir("res://data")


func before_each() -> void:
	FigureArt.use_root(FIGURES)


func after_each() -> void:
	FigureArt.use_root(FigureArt.DIR)


func test_a_png_wins_over_its_svg() -> void:
	assert_eq(ArtPath.resolve(FIXTURES + "loader/thing"), FIXTURES + "loader/thing.png")
	assert_eq(ArtPath.resolve(FIXTURES + "loader/thing.svg"), FIXTURES + "loader/thing.png", "a path naming the SVG still takes the PNG")
	assert_eq(ArtPath.resolve(FIXTURES + "loader/only"), FIXTURES + "loader/only.svg", "the SVG without a PNG")
	assert_eq(ArtPath.resolve(FIXTURES + "loader/nothing"), "")
	assert_null(ArtFile.texture(FIXTURES + "loader/nothing"))
	assert_eq(ArtFile.texture(FIXTURES + "loader/thing").get_size(), Vector2(8, 8))


func test_a_figure_at_any_resolution_draws_at_its_canvas() -> void:
	assert_eq(FigureArt.texture("heroes/fix_base").get_size(), Vector2(1200, 2080), "the 4x PNG master, not the SVG")
	assert_eq(FigureArt.pixels_per_unit("heroes/fix_base"), 4.0)
	assert_eq([FigureArt.canvas("heroes/fix_base"), FigureArt.feet("heroes/fix_base")], [FigureArt.CANVAS, FigureArt.FEET])
	assert_eq(FigureArt.bounds("heroes/fix_base"), Rect2(100, 100, 100, 400), "bounds in canvas units")
	assert_eq(FigureBounds.measure(FIGURES + "heroes/fix_base.png", FigureArt.CANVAS), [100, 100, 100, 400] as Array[int],
		"the PNG measured in canvas units")
	assert_eq(FigureBounds.to_json(FigureBounds.measure_all()), FileAccess.get_file_as_string(FIGURES + "bounds.json"))
	var token: UnitToken = _token("heroes/fix_base")
	assert_eq(token.figure_rect(), Rect2(-25, -200, 50, 200), "drawn as the 1x placeholder would be")


func test_a_boss_has_twice_the_canvas() -> void:
	assert_eq(FigureArt.scale_of("enemies/fix_boss"), 2)
	assert_eq([FigureArt.canvas("enemies/fix_boss"), FigureArt.feet("enemies/fix_boss")], [FigureArt.CANVAS * 2.0, FigureArt.FEET * 2.0])
	assert_eq(FigureArt.pixels_per_unit("enemies/fix_boss"), 1.0)
	var boss: UnitToken = _token("enemies/fix_boss")
	assert_eq(boss.figure_rect(), Rect2(-50, -300, 100, 300), "its 600-unit-tall drawing stands 300 px tall at half a pixel a unit")
	assert_eq(boss.head_offset(), Vector2(0, -300), "no manifest head: the top of what's drawn")
	assert_eq(boss.muzzle_offset(), Vector2(0, -150), "no manifest muzzle: the middle of what's drawn")


func test_the_manifest_places_the_bars_and_the_shots() -> void:
	assert_eq([FigureArt.head("heroes/fix_base"), FigureArt.muzzle("heroes/fix_base")], [Vector2(150, 60), Vector2(210, 250)])
	var token: UnitToken = _token("heroes/fix_base")
	assert_eq(token.head_offset(), Vector2(0, -220), "the bars sit at the manifest's head, above what's drawn")
	assert_eq(token.muzzle_offset(), Vector2(30, -125))
	token.facing_left = true
	assert_eq(token.muzzle_offset(), Vector2(-30, -125), "mirrored when it faces left")
	assert_eq(FigureArt.entry("heroes/nobody"), {})


func test_a_portrait_falls_back_to_the_figure() -> void:
	assert_eq(Portrait.art_for("heroes/fix_base", FIXTURES + "portraits/").get_size(), Vector2(64, 64))
	assert_null(Portrait.art_for("heroes/maren_base"), "no portraits are drawn yet")
	var portrait: Portrait = Portrait.make("heroes/fix_base", Vector2(100, 120))
	assert_false(portrait.is_portrait)
	assert_eq(portrait.texture, FigureArt.texture("heroes/fix_base"), "the figure, cropped")
	portrait.free()


func test_an_apex_and_a_specialization_stand_as_their_own_figures() -> void:
	var session: PracticeSession = PracticeSession.make(_content)
	session.set_apex("maren", "hailstorm", PathDef.Stage.APEX)
	var setup: FightSetup = session.setup("hollow_line", PracticeSession.DEFAULT_FORMATION)
	var maren: UnitSetup = setup.heroes.filter(func(hero: UnitSetup) -> bool: return hero.def.id == "maren")[0]
	assert_eq(ArenaView.form_of(maren), "hailstorm", "the apex's figure where it's drawn")
	FigureArt.use_root(FigureArt.DIR)
	assert_eq(ArenaView.form_of(maren), "volley", "else its path's")
	FigureArt.use_root(FIGURES)
	var hound: UnitDef = _content.enemies["rift_hound"].kit
	var ashback: UnitDef = _content.specializations["ashback_hound"].apply(hound)
	var gloam: UnitDef = _content.specializations["gloam_hound"].apply(hound)
	assert_eq(ArenaView.figure_for(ashback, EffectSource.Team.ENEMIES, "base", _content), "enemies/rift_hound_ashback")
	assert_eq(ArenaView.figure_for(gloam, EffectSource.Team.ENEMIES, "base", _content), "enemies/rift_hound", "no Gloam figure: the hound's")
	assert_eq(ArenaView.figure_for(ashback, EffectSource.Team.ENEMIES), "enemies/rift_hound", "without content, the enemy's")


## A token for the figure `key` at half a pixel a canvas unit, facing right.
func _token(key: String) -> UnitToken:
	var token: UnitToken = UnitToken.make("unit", "Unit", EffectSource.Team.HEROES, 100, false, key)
	token.figure_scale = 0.5
	autofree(token)
	return token
