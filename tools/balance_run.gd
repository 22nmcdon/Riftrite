class_name BalanceRun
extends RefCounted
## The headless balance sim: runs parties (tools/sim_parties.json) against
## encounters (data/encounters.json) many times and summarizes the results.
## tools/sim_runner.gd is the command-line wrapper.

const DEFAULT_PARTIES_PATH: String = "res://tools/sim_parties.json"
## A hero item below this share of its party's output gets flagged.
const LOW_SHARE_PERCENT: float = 3.0


class PartyHero:
	var hero_id: String
	var rank: int = 0
	var row: UnitSetup.Row = UnitSetup.Row.FRONT
	var items: Array[LoadoutEntry] = []


class Party:
	var id: String
	var name: String
	## Fielded heroes.
	var heroes: Array[PartyHero] = []
	## Heroes in backup.
	var bench: Array[PartyHero] = []


class Parties:
	var list: Array[Party] = []
	var errors: Array[String] = []


## Totals for one hero item (or enemy item) across all fights.
class ItemTotals:
	var unit_id: String
	var item_name: String
	var hero_side: bool
	var damage: int = 0
	var healing: int = 0
	var shielding: int = 0


class Stats:
	var party_id: String
	var encounter_id: String
	var first_seed: int
	var fights: int = 0
	var wins: int = 0
	var ties: int = 0
	var losses: int = 0
	var ticks_total: int = 0
	var ticks_min: int = -1
	var ticks_max: int = 0
	var level_ups: int = 0
	var biggest_hit: int = 0
	var biggest_hit_text: String = ""
	var items: Array[ItemTotals] = []
	var errors: Array[String] = []
	var _index: Dictionary[String, int] = {}


static func load_parties(content: ContentDb, path: String = DEFAULT_PARTIES_PATH) -> Parties:
	var parties := Parties.new()
	var json := JSON.new()
	if not FileAccess.file_exists(path):
		parties.errors.append("%s: file not found" % path)
		return parties
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		parties.errors.append("%s: invalid JSON on line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return parties
	return parse_parties(content, json.data, path.get_file())


static func parse_parties(content: ContentDb, data: Variant, label: String) -> Parties:
	var parties := Parties.new()
	if typeof(data) != TYPE_ARRAY:
		parties.errors.append("%s: expected a list of parties" % label)
		return parties
	var entries: Array = data
	var ids: Array[String] = []
	for i: int in entries.size():
		var reader: DataReader = DataReader.from_value(entries[i], "%s[%d]" % [label, i], parties.errors)
		if reader == null:
			continue
		var party := Party.new()
		party.id = reader.req_string("id")
		party.name = reader.req_string("name")
		if ids.has(party.id):
			reader.error("duplicate party id \"%s\"" % party.id)
		ids.append(party.id)
		party.heroes = _read_heroes(content, reader, "heroes")
		party.bench = _read_heroes(content, reader, "bench")
		reader.finish()
		# Reuse the content checks for item references (heroes can't carry enemy-only items).
		var checker := ContentDb.new()
		checker.items = content.items
		checker.essences = content.essences
		for hero: PartyHero in party.heroes + party.bench:
			checker.check_loadout(hero.items, "%s (%s).%s" % [label, party.id, hero.hero_id], false)
		parties.errors.append_array(checker.errors)
		parties.list.append(party)
	return parties


static func _read_heroes(content: ContentDb, reader: DataReader, key: String) -> Array[PartyHero]:
	var heroes: Array[PartyHero] = []
	for hero_reader: DataReader in reader.opt_object_array(key):
		var hero := PartyHero.new()
		hero.hero_id = hero_reader.req_string("hero")
		hero.rank = maxi(TuningDef.TIER_NAMES.find(hero_reader.opt_string_choice("rank", "c", TuningDef.TIER_NAMES)), 0)
		hero.row = maxi(EncounterDef.ROW_NAMES.find(hero_reader.opt_string_choice("row", "front", EncounterDef.ROW_NAMES)), 0) as UnitSetup.Row
		hero.items = LoadoutEntry.read_list(hero_reader, "items")
		hero_reader.finish()
		if not content.heroes.has(hero.hero_id):
			hero_reader.error("unknown hero \"%s\"" % hero.hero_id)
		heroes.append(hero)
	return heroes


## The party's fielded heroes (or its bench, with `benched`).
static func party_units(content: ContentDb, party: Party, benched: bool = false) -> Array[UnitSetup]:
	var units: Array[UnitSetup] = []
	for hero: PartyHero in (party.bench if benched else party.heroes):
		units.append(SetupBuilder.hero(content, hero.hero_id, hero.rank, hero.row, hero.items))
	return units


## Runs `fights` fights with seeds first_seed, first_seed + 1, ...
static func run(content: ContentDb, party: Party, encounter_id: String, fights: int, first_seed: int) -> Stats:
	var stats := Stats.new()
	stats.party_id = party.id
	stats.encounter_id = encounter_id
	stats.first_seed = first_seed
	var act: int = content.encounters[encounter_id].act
	var hero_ids: Array[String] = []
	for hero: PartyHero in party.heroes + party.bench:
		hero_ids.append(hero.hero_id)
	for i: int in fights:
		var seed_value: int = first_seed + i
		var setup: FightSetup = FightSetup.make(party_units(content, party), SetupBuilder.encounter_units(content, encounter_id), seed_value, act, party_units(content, party, true))
		var result: FightResult = CombatSim.run(setup, content)
		if not result.errors.is_empty():
			stats.errors = result.errors
			return stats
		_add_fight(stats, result, hero_ids, seed_value)
	return stats


static func _add_fight(stats: Stats, result: FightResult, hero_ids: Array[String], seed_value: int) -> void:
	stats.fights += 1
	match result.outcome:
		FightResult.Outcome.VICTORY:
			stats.wins += 1
		FightResult.Outcome.TIE:
			stats.ties += 1
		FightResult.Outcome.DEFEAT:
			stats.losses += 1
	stats.ticks_total += result.end_tick
	stats.ticks_min = result.end_tick if stats.ticks_min < 0 else mini(stats.ticks_min, result.end_tick)
	stats.ticks_max = maxi(stats.ticks_max, result.end_tick)
	stats.level_ups += result.combat_log.of_kind(LogEntry.Kind.INFUSION_LEVEL).size()
	for entry: LogEntry in result.combat_log.of_kind(LogEntry.Kind.DAMAGE):
		if entry.amount > stats.biggest_hit:
			stats.biggest_hit = entry.amount
			stats.biggest_hit_text = "%s, seed %d" % [entry.source_text(), seed_value]
	var meter: DamageMeter = DamageMeter.from_log(result.combat_log, hero_ids)
	for row: DamageMeter.Row in meter.rows:
		var key: String = "%s/%s" % [row.unit_id, row.item_id]
		if not stats._index.has(key):
			var totals := ItemTotals.new()
			totals.unit_id = row.unit_id
			totals.item_name = row.item_name
			totals.hero_side = row.side == UnitSetup.Side.HEROES
			stats._index[key] = stats.items.size()
			stats.items.append(totals)
		var item: ItemTotals = stats.items[stats._index[key]]
		item.damage += row.damage
		item.healing += row.healing
		item.shielding += row.shielding


static func report(stats: Stats) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("== %s vs %s (%d fights, seeds %d-%d) ==" % [stats.party_id, stats.encounter_id, stats.fights, stats.first_seed, stats.first_seed + stats.fights - 1])
	if not stats.errors.is_empty():
		for message: String in stats.errors:
			lines.append("  setup error: " + message)
		return lines
	if stats.fights == 0:
		return lines
	var per_fight: float = float(stats.fights)
	lines.append("Guild wins: %d%% (%d wins, %d ties, %d losses)" % [roundi(100.0 * (stats.wins + stats.ties) / per_fight), stats.wins, stats.ties, stats.losses])
	lines.append("Fight length: avg %.1fs, min %.1fs, max %.1fs" % [stats.ticks_total / per_fight / FixedMath.TICKS_PER_SECOND, stats.ticks_min / float(FixedMath.TICKS_PER_SECOND), stats.ticks_max / float(FixedMath.TICKS_PER_SECOND)])
	lines.append("Biggest hit: %d (%s)" % [stats.biggest_hit, stats.biggest_hit_text])
	lines.append("Infusion level-ups: %d" % stats.level_ups)
	var hero_output: int = 0
	var enemy_damage: int = 0
	for item: ItemTotals in stats.items:
		if item.hero_side:
			hero_output += item.damage + item.healing + item.shielding
		else:
			enemy_damage += item.damage
	lines.append("Hero output per fight:                        damage  healing  shield  share")
	var flagged: PackedStringArray = PackedStringArray()
	for item: ItemTotals in stats.items:
		if not item.hero_side:
			continue
		var output: int = item.damage + item.healing + item.shielding
		var share: float = 100.0 * output / maxf(hero_output, 1.0)
		var label: String = "%s · %s" % [item.unit_id, item.item_name]
		lines.append("  %-42s %7.1f  %7.1f  %6.1f  %4.1f%%" % [label, item.damage / per_fight, item.healing / per_fight, item.shielding / per_fight, share])
		if share < LOW_SHARE_PERCENT:
			flagged.append("  ! %s barely contributes (%.1f%% of hero output)" % [label, share])
	lines.append_array(flagged)
	lines.append("Enemy damage per fight: %.1f" % (enemy_damage / per_fight))
	return lines
