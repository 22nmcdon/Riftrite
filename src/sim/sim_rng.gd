class_name SimRng
extends RefCounted
## The combat sim's only source of randomness (CLAUDE.md rule 1).
##
## xoshiro128** by Blackman and Vigna, written out here instead of using
## Godot's RandomNumberGenerator so a seed replays the same fight on every
## Godot version. All arithmetic stays under 2^40, so nothing ever overflows
## GDScript's 64-bit ints. Tests pin the output against a reference
## implementation.

const MASK_32: int = 0xFFFFFFFF
## Fallback seed word if a seed folds to zero (the state must never be all zero).
const GOLDEN_32: int = 0x9E3779B9

var _s0: int
var _s1: int
var _s2: int
var _s3: int


func _init(seed_value: int) -> void:
	# Fold the seed to 32 bits, then expand it into four state words.
	var x: int = ((seed_value & MASK_32) ^ ((seed_value >> 32) & MASK_32) ^ GOLDEN_32) & MASK_32
	if x == 0:
		x = GOLDEN_32
	x = _xorshift32(x)
	_s0 = x
	x = _xorshift32(x)
	_s1 = x
	x = _xorshift32(x)
	_s2 = x
	x = _xorshift32(x)
	_s3 = x


## Sets the raw state. Only for tests that check against reference vectors.
func set_state(s0: int, s1: int, s2: int, s3: int) -> void:
	_s0 = s0 & MASK_32
	_s1 = s1 & MASK_32
	_s2 = s2 & MASK_32
	_s3 = s3 & MASK_32


## Next raw 32-bit value (0 to 2^32 - 1).
func next_u32() -> int:
	var result: int = (_rotl(((_s1 * 5) & MASK_32), 7) * 9) & MASK_32
	var t: int = (_s1 << 9) & MASK_32
	_s2 ^= _s0
	_s3 ^= _s1
	_s1 ^= _s2
	_s0 ^= _s3
	_s2 ^= t
	_s3 = _rotl(_s3, 11)
	return result


## Uniform integer in [0, count). Rejection sampling keeps it unbiased.
func range_int(count: int) -> int:
	assert(count > 0 and count <= MASK_32, "SimRng.range_int: count out of range")
	@warning_ignore("integer_division")
	var limit: int = ((MASK_32 + 1) / count) * count
	var value: int = next_u32()
	while value >= limit:
		value = next_u32()
	return value % count


## True with the given chance in basis points (10000 = always).
## Chances of 0 or less, or 10000 or more, don't consume a random number.
func roll_bp(chance_bp: int) -> bool:
	if chance_bp <= 0:
		return false
	if chance_bp >= FixedMath.BP_ONE:
		return true
	return range_int(FixedMath.BP_ONE) < chance_bp


static func _rotl(value: int, bits: int) -> int:
	return ((value << bits) | (value >> (32 - bits))) & MASK_32


static func _xorshift32(value: int) -> int:
	var x: int = value
	x ^= (x << 13) & MASK_32
	x ^= x >> 17
	x ^= (x << 5) & MASK_32
	return x & MASK_32
