extends GutTest


func test_apply_bp_exact() -> void:
	assert_eq(FixedMath.apply_bp(100, 3000), 30)
	assert_eq(FixedMath.apply_bp(100, FixedMath.BP_ONE), 100)
	assert_eq(FixedMath.apply_bp(14, 15000), 21)
	assert_eq(FixedMath.apply_bp(0, 3000), 0)
	assert_eq(FixedMath.apply_bp(100, 0), 0)


func test_apply_bp_rounds_half_away_from_zero() -> void:
	assert_eq(FixedMath.apply_bp(5, 3000), 2, "1.5 rounds up")
	assert_eq(FixedMath.apply_bp(-5, 3000), -2, "-1.5 rounds down")
	assert_eq(FixedMath.apply_bp(1, 4999), 0, "0.4999 rounds to 0")
	assert_eq(FixedMath.apply_bp(-1500, 3000), -450, "negative modifiers scale exactly")


func test_apply_bp_is_symmetric() -> void:
	for value: int in [1, 3, 7, 13, 999]:
		for bp: int in [1, 3333, 5000, 15000]:
			assert_eq(FixedMath.apply_bp(-value, bp), -FixedMath.apply_bp(value, bp))


func test_ticks() -> void:
	assert_eq(FixedMath.MS_PER_TICK, 50)
	assert_eq(FixedMath.ms_to_ticks(3000), 60)
	assert_eq(FixedMath.ms_to_ticks(45000), 900)
	assert_true(FixedMath.is_whole_ticks(1250))
	assert_false(FixedMath.is_whole_ticks(1225))
