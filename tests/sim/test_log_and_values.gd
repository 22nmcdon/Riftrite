extends GutTest
## The log lines, effect sources, and value breakdowns kept through the
## rebuild's gut. Every log line names its source (CLAUDE.md rule 4).


func _entry(kind: LogEntry.Kind, source: EffectSource, target: String = "", amount: int = 0) -> LogEntry:
	var entry := LogEntry.new()
	entry.tick = 25
	entry.kind = kind
	entry.set_source(source)
	entry.target = target
	entry.amount = amount
	return entry


func test_sources_name_the_unit_and_ability() -> void:
	var source: EffectSource = EffectSource.make("brannoc", "hold_the_line", "Hold the Line")
	assert_eq(source.describe(), "brannoc · Hold the Line")
	assert_eq(EffectSource.relic("warding_knot", "Warding Knot", EffectSource.Team.HEROES).describe(), "relic · Warding Knot")
	assert_eq(EffectSource.relic("gloam_totem", "Gloam Totem", EffectSource.Team.ENEMIES).describe(), "enemy relic · Gloam Totem")
	var bond: EffectSource = EffectSource.relic("light_and_iron", "Light and Iron", EffectSource.Team.HEROES)
	bond.synergy = true
	assert_eq(bond.describe(), "bond · Light and Iron")
	assert_true(source.same_as(EffectSource.make("brannoc", "hold_the_line", "Hold the Line")))
	assert_false(source.same_as(EffectSource.make("maren", "hold_the_line", "Hold the Line")))


func test_a_log_entry_keeps_its_source() -> void:
	var entry: LogEntry = _entry(LogEntry.Kind.DAMAGE, EffectSource.make("maren", "longshot", "Longshot"), "rift_hound", 14)
	entry.crit = true
	entry.mitigated = 3
	entry.absorbed = 5
	assert_eq([entry.source_unit, entry.source_ability, entry.source_ability_name], ["maren", "longshot", "Longshot"])
	assert_eq(entry.to_text(), "[1.25s] maren · Longshot hits rift_hound for 14 (crit, 3 blocked by defense, 5 absorbed by shield)")
	assert_true(entry.source().same_as(EffectSource.make("maren", "longshot", "Longshot")))
	var relic: LogEntry = _entry(LogEntry.Kind.SHIELD, EffectSource.relic("warding_knot", "Warding Knot", EffectSource.Team.HEROES), "vell", 20)
	assert_eq(relic.to_text(), "[1.25s] relic · Warding Knot gives vell 20 shield")
	assert_eq(relic.source().relic_side, EffectSource.Team.HEROES)


func test_the_log_reads_in_order() -> void:
	var log := CombatLog.new()
	log.add(_entry(LogEntry.Kind.HEAL, EffectSource.make("vell", "mend", "Mend"), "maren", 30))
	log.add(_entry(LogEntry.Kind.DEATH, EffectSource.new(), "rift_hound"))
	assert_eq(log.to_lines().size(), 2)
	assert_eq(log.of_kind(LogEntry.Kind.HEAL).size(), 1)
	assert_string_contains(log.to_text(), "vell · Mend heals maren for 30")


func test_value_breakdowns() -> void:
	var stats: UnitStats = UnitStats.make(300, 20)
	var scaling: Array[int] = [0, 6000, 0, 0, 0, 0]
	var boosts: Array[ValueBreakdown.Multiplier] = [ValueBreakdown.multiplier("Marked", 11500)]
	var value: ValueBreakdown = ValueBreakdown.compute(4, scaling, stats, boosts)
	assert_eq([value.base, value.scaled, value.final], [4, 16, 18])
	assert_eq(value.to_text(), "18 (base 4 + 60% ATK 12 = 16, x1.15 Marked)")
	var plain: ValueBreakdown = ValueBreakdown.compute(10, [0, 0, 0, 0, 0, 0] as Array[int], stats, [] as Array[ValueBreakdown.Multiplier])
	assert_eq(plain.to_text(), "10")


func test_fight_results() -> void:
	var result := FightResult.new()
	assert_true(result.guild_won(), "a tie counts as a guild victory")
	result.outcome = FightResult.Outcome.DEFEAT
	assert_false(result.guild_won())
	result.outcome = FightResult.Outcome.VICTORY
	result.errors.append("bad setup")
	assert_false(result.guild_won(), "a fight that didn't run isn't a win")
