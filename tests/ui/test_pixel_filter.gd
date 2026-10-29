extends GutTest
## Pixel art, for testing (PixelFilter; docs/plans/art/art-style-guide.md,
## Question SF): the toggle is off by default and remembered, the filter
## covers the board and the sky to its left but not the side column, it sits
## above the board's units and effects and under what must stay sharp, it
## takes no input, and the fight is the same with it on (rule 2).

var _content: ContentDb


func before_all() -> void:
	_content = ContentDb.load_dir("res://data")


func _screen(session: PracticeSession, encounter_id: String = "the_pack") -> ArenaScreen:
	var screen: ArenaScreen = ArenaScreen.make(session, encounter_id)
	add_child_autofree(screen)
	screen.size = Vector2(1900, 1000)
	screen.setup()
	await wait_process_frames(2)
	return screen


func test_it_is_off_by_default_and_for_testing() -> void:
	var screen: ArenaScreen = await _screen(PracticeSession.make(_content))
	assert_false(screen.pixel_toggle.button_pressed)
	assert_false(screen.pixel_filter.visible)
	assert_string_contains(screen.pixel_toggle.text, "for testing")
	assert_true(screen.pixel_toggle.is_visible_in_tree(), "shown while placing, not only in the fight")


func test_it_covers_the_board_not_the_side_column() -> void:
	var screen: ArenaScreen = await _screen(PracticeSession.make(_content))
	screen.pixel_toggle.button_pressed = true
	await wait_process_frames(2)
	var covered: Rect2 = screen.pixel_filter.get_global_rect()
	var board: Rect2 = screen.view.get_global_rect()
	assert_true(screen.pixel_filter.visible)
	assert_true(covered.encloses(board), "the whole board")
	assert_lt(covered.position.x, board.position.x, "and the sky to its left")
	assert_lt(covered.end.x, screen.enemy_panel.get_global_rect().position.x, "not the side column")
	assert_eq(screen.pixel_filter.mouse_filter, Control.MOUSE_FILTER_IGNORE, "it takes no input")


func test_it_sits_over_the_board_and_under_the_sharp_things() -> void:
	var screen: ArenaScreen = await _screen(PracticeSession.make(_content))
	var z: int = screen.pixel_filter.z_index
	assert_gt(z, screen.view.fx.z_index, "over the units and effects")
	for sharp: Control in [screen.banners, screen.hero_popup, screen.log_popup, screen.hero_panel]:
		assert_gt(sharp.z_index, z, "%s stays sharp" % sharp.name)


func test_the_blocks_are_the_screen_over_360_rows() -> void:
	assert_eq(PixelFilter.block_for(1080), 3, "640 x 360 at 1080p")
	assert_eq(PixelFilter.block_for(1440), 4)
	assert_eq(PixelFilter.block_for(720), 2)
	assert_eq(PixelFilter.block_for(480), 2, "never under 2")


func test_the_session_remembers_it() -> void:
	var session := PracticeSession.make(_content)
	var first: ArenaScreen = await _screen(session)
	first.pixel_toggle.button_pressed = true
	assert_true(session.pixel_art)
	var next: ArenaScreen = await _screen(session, "pup_warren")
	assert_true(next.pixel_toggle.button_pressed, "the next fight starts with it on")
	assert_true(next.pixel_filter.visible)
	next.pixel_toggle.button_pressed = false
	assert_false(session.pixel_art)
	assert_false(next.pixel_filter.visible)


func test_the_fight_is_the_same_with_it_on() -> void:
	var plain: ArenaScreen = await _screen(PracticeSession.make(_content))
	plain._fight()
	plain.skip()
	var pixels: ArenaScreen = await _screen(PracticeSession.make(_content))
	pixels.pixel_toggle.button_pressed = true
	pixels._fight()
	for frame: int in 60 * 3:
		pixels._process(1.0 / 60.0)
	pixels.skip()
	assert_eq(pixels.player.sim.combat_log.to_text(), plain.player.sim.combat_log.to_text())
