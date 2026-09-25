class_name ValueBreakdown
extends RefCounted
## How one of an item's numbers is built, kept so the UI can show base and
## final values side by side:
##   scaled = base + (each stat x its ratio)
##   final  = scaled x every multiplier (tier, essences, ...), rounded once.


class Multiplier:
	var label: String
	var bp: int


var base: int = 0
## One entry per scaling stat: [stat, ratio_bp, contribution].
var stat_parts: Array[Array] = []
var scaled: int = 0
var multipliers: Array[Multiplier] = []
var final: int = 0
## The exact final value in basis points of one unit (final is this rounded).
## Used where small numbers must not round away, like a 0.6x spill of 1 stack.
var final_bp: int = 0


static func compute(base_amount: int, scaling: Array[int], stats: UnitStats, boosts: Array[Multiplier]) -> ValueBreakdown:
	var value := ValueBreakdown.new()
	value.base = base_amount
	value.scaled = base_amount
	for stat: int in scaling.size():
		if scaling[stat] == 0:
			continue
		var part: int = FixedMath.apply_bp(stats.get_stat(stat as UnitStats.Stat), scaling[stat])
		value.stat_parts.append([stat, scaling[stat], part])
		value.scaled += part
	var combined_bp: int = FixedMath.BP_ONE
	for boost: Multiplier in boosts:
		if boost.bp == FixedMath.BP_ONE:
			continue
		value.multipliers.append(boost)
		combined_bp = FixedMath.apply_bp(combined_bp, boost.bp)
	value.final = FixedMath.apply_bp(value.scaled, combined_bp)
	value.final_bp = value.scaled * combined_bp
	return value


static func multiplier(label: String, bp: int) -> Multiplier:
	var boost := Multiplier.new()
	boost.label = label
	boost.bp = bp
	return boost


## For example "38 (base 4 + 60% ATK 21 = 25, x1.5 B tier)", or just "10".
func to_text() -> String:
	if stat_parts.is_empty() and multipliers.is_empty():
		return str(final)
	var parts: Array[String] = []
	var sum: String = "base %d" % base
	for part: Array in stat_parts:
		sum += " + %s %s %d" % [_percent(part[1]), UnitStats.LABELS[part[0]], part[2]]
	if not stat_parts.is_empty():
		sum += " = %d" % scaled
	parts.append(sum)
	for boost: Multiplier in multipliers:
		parts.append("x%s %s" % [_ratio(boost.bp), boost.label])
	return "%d (%s)" % [final, ", ".join(parts)]


## 6000 -> "60%", 6250 -> "62.5%" (integer formatting only).
static func _percent(bp: int) -> String:
	@warning_ignore("integer_division")
	var whole: int = bp / 100
	var rest: int = bp % 100
	if rest == 0:
		return "%d%%" % whole
	return "%d.%s%%" % [whole, str(rest).pad_zeros(2).trim_suffix("0")]


## 15000 -> "1.5", 19531 -> "1.9531".
static func _ratio(bp: int) -> String:
	@warning_ignore("integer_division")
	var whole: int = bp / FixedMath.BP_ONE
	var rest: int = bp % FixedMath.BP_ONE
	if rest == 0:
		return str(whole)
	var digits: String = str(rest).pad_zeros(4)
	while digits.ends_with("0"):
		digits = digits.trim_suffix("0")
	return "%d.%s" % [whole, digits]
