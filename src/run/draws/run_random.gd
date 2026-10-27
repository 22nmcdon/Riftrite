class_name RunRandom
extends RefCounted
## Seeded randomness for the run layer. Each offer draws from its own stream,
## seeded by the run seed plus where it happens (what, act, day, attempt,
## visit, reroll), so skipping one stop never changes what a later one offers.

## Stream tags.
const START: int = 1
const FIGHT: int = 3
const SHOP: int = 4
const STOP: int = 6
const REWARDS: int = 7
## Phase 5 (docs/plans/rebuild-phase5-run.md): the act's fight options, the
## after-fight pick, camp menus, the Pedlar, the Magpie, relic choices, and
## a Hunt's pack.
const ACT_DRAW: int = 8
const PICK: int = 9
const CAMP: int = 10
const PEDLAR: int = 11
const MAGPIE: int = 12
const RELIC: int = 13
const HUNT: int = 14
## The day's nodes (phase 5c step 8).
const NODE: int = 15
## Events (phase 5c step 8c): an oath's heroes, and what a choice draws.
const EVENT: int = 16
## Endless (phase 8 part 1): a floor's fight, and the rift modifiers it adds.
const ENDLESS: int = 17
## Which of a day fight's enemies are specialized, and how (phase 8 part 3).
const SPECIALIZE: int = 18
## Which upgrades an elite day fight's enemies carry (phase 8 part 3).
const UPGRADE: int = 19
## What the rift learns puts on a boss's adds (phase 8 part 3).
const LEARN: int = 20
## The item a transmuted item turns into (phase 8 part 6, Grand
## Transmutation).
const TRANSMUTE: int = 21

const MIX: int = 0x2545F4914F6CDD1D


## A fresh RNG for one offer, from the run seed and `parts`.
static func stream(run_seed: int, parts: Array[int]) -> SimRng:
	var h: int = run_seed
	for part: int in parts:
		h = _mix(h ^ part)
	return SimRng.new(h)


## Scrambles 64 bits (wrapping integer math, so it's the same everywhere).
static func _mix(value: int) -> int:
	var x: int = value
	x ^= x >> 31
	x *= MIX
	x ^= x >> 29
	x *= MIX
	x ^= x >> 32
	return x
