extends GutTest
## RunRandom: every offer draws from its own stream, seeded by the run seed
## and where it happens, so skipping one choice never changes a later one.


func _draws(rng: SimRng, count: int = 8) -> Array[int]:
	var values: Array[int] = []
	for i: int in count:
		values.append(rng.range_int(1000))
	return values


func test_the_same_place_gives_the_same_stream() -> void:
	assert_eq(_draws(RunRandom.stream(7, [RunRandom.FIGHT, 1, 3])), _draws(RunRandom.stream(7, [RunRandom.FIGHT, 1, 3])))


func test_each_place_and_seed_gives_its_own_stream() -> void:
	var base: Array[int] = _draws(RunRandom.stream(7, [RunRandom.FIGHT, 1, 3]))
	assert_ne(base, _draws(RunRandom.stream(8, [RunRandom.FIGHT, 1, 3])), "another seed")
	assert_ne(base, _draws(RunRandom.stream(7, [RunRandom.FIGHT, 1, 4])), "another day")
	assert_ne(base, _draws(RunRandom.stream(7, [RunRandom.REWARDS, 1, 3])), "another kind of offer")
	assert_ne(base, _draws(RunRandom.stream(7, [RunRandom.FIGHT, 3, 1])), "the order of the parts matters")
