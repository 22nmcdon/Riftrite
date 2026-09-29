extends RefCounted
## Seeded fights with the heroes on their paths (phase 4), for the tests that
## need the real paths in play: the determinism test (each repeats exactly),
## the log's audit, and the log kinds the chaos fight leaves to them (ZONE,
## SNARE, WALL, GUARD, and the Warded status). Every path appears, vowed or
## transformed, across them.

const FORMATION: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(3, 0), "vell": Vector2i(2, 1)}


## One fight: the encounter, each hero's path, who's transformed, where they
## stand, and Maren's placed snares (when she's a transformed Trapper).
static func setup(content: ContentDb, encounter_id: String, vows: Dictionary[String, String], transformed: Array[String],
		formation: Dictionary[String, Vector2i] = FORMATION, snares: Array[Vector2i] = [], fight_seed: int = 7) -> FightSetup:
	var errors: Array[String] = []
	var fight: FightSetup = Encounters.setup(content, encounter_id, formation, fight_seed, errors, {}, vows, transformed)
	assert(errors.is_empty(), str(errors))
	for hero: UnitSetup in fight.heroes:
		if hero.def.placed_snares > 0:
			hero.snares = snares
	return fight


## Every path in play: three fights with the heroes transformed, one with
## them vowed.
static func all(content: ContentDb) -> Array[FightSetup]:
	var everyone: Array[String] = ["brannoc", "maren", "vell"]
	return [
		setup(content, "the_pack", {"brannoc": "hearthwall", "maren": "trapper", "vell": "wardweaver"} as Dictionary[String, String], everyone,
			FORMATION, [Vector2i(2, 3), Vector2i(4, 3)] as Array[Vector2i]),
		setup(content, "hollow_line", {"brannoc": "ironbrand", "maren": "volley", "vell": "lanternbearer"} as Dictionary[String, String], everyone,
			{"brannoc": Vector2i(3, 2), "maren": Vector2i(4, 0), "vell": Vector2i(3, 1)} as Dictionary[String, Vector2i]),
		setup(content, "witch_circle", {"brannoc": "last_watch", "maren": "deadeye", "vell": "vigil_keeper"} as Dictionary[String, String], everyone,
			{"brannoc": Vector2i(3, 2), "maren": Vector2i(0, 0), "vell": Vector2i(5, 1)} as Dictionary[String, Vector2i]),
		setup(content, "sentinel_gate", {"brannoc": "last_watch", "maren": "trapper", "vell": "vigil_keeper"} as Dictionary[String, String], [] as Array[String]),
	]
