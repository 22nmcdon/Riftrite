class_name RunState
extends RefCounted
## Everything a run holds between fights (docs/plans/run-state.md). Pure
## logic like the sim: no nodes, integers only, deterministic from the seed.
## Change it only through RunActions; check it with check().

const SAVE_VERSION: int = 1
## Owner names for items: a hero id, STASH, or NOWHERE (not in the guild).
const STASH: String = "stash"
const NOWHERE: String = ""

var seed_value: int = 1
## Draws each fight's seed (and, from step 5, offers). Its state is saved.
var rng: SimRng
var act: int = 1
var day: int = 1
var step: int = 0
var attempt: int = 0
var gold: int = 0
var keys: int = 0
## The roster in slot order. Slot 0 is always a field slot; within each row,
## fielded heroes stand left to right in this order.
var heroes: Array[RunHero] = []
## Unequipped items, in order; sizes count against tuning.stash_slots.
var stash: Array[RunItem] = []
## Essence ids waiting to be socketed (cap: tuning.pouch_cap).
var pouch: Array[String] = []
## Relic ids held, in the order taken.
var relics: Array[String] = []
var wins: int = 0
var losses: int = 0
## Synergy ids found this run, in the order found.
var discovered: Array[String] = []
## Legendary item ids already offered or taken (at most once per run).
var legendaries_seen: Array[String] = []
var next_uid: int = 1

# --- where the run is (RunFlow) -------------------------------------------------
## One of RunFlow's phases ("start_hero", "caravan", ...).
var phase: String = ""
## What the player is being offered right now (heroes, packages, Caravan
## wares, stops, loot, rewards), as plain dictionaries (see RunFlow).
var offers: Array[Dictionary] = []
## The stop being visited: what it does ("loot", "event", "fight",
## "upgrade", ...; RunFlow.STOP_KINDS), and which node it is (a node or event
## id, or "upgrade"), or "".
var stop_kind: String = ""
var stop_node: String = ""
## A skirmish stop's enemies (an encounter id), or "".
var stop_encounter: String = ""
## Whether this stop's one-time action (retrain, upgrade) is spent.
var stop_used: bool = false
## Today's fight.
var encounter_id: String = ""
## Rerolls in this Caravan visit.
var reroll_count: int = 0
## Essence shards by essence id (shards_per_essence make an essence).
var shards: Dictionary[String, int] = {}


static func make(run_seed: int) -> RunState:
	var state := RunState.new()
	state.seed_value = run_seed
	state.rng = SimRng.new(run_seed)
	return state


func hero(hero_id: String) -> RunHero:
	for candidate: RunHero in heroes:
		if candidate.hero_id == hero_id:
			return candidate
	return null


## Who holds an item: a hero id, STASH, or NOWHERE.
func owner_of(uid: int) -> String:
	for candidate: RunHero in heroes:
		for item: RunItem in candidate.items:
			if item.uid == uid:
				return candidate.hero_id
	for item: RunItem in stash:
		if item.uid == uid:
			return STASH
	return NOWHERE


func find_item(uid: int) -> RunItem:
	var owner: String = owner_of(uid)
	if owner == NOWHERE:
		return null
	for item: RunItem in list_for(owner):
		if item.uid == uid:
			return item
	return null


## True for STASH or a hero in the roster.
func is_owner(owner: String) -> bool:
	return owner == STASH or hero(owner) != null


## The item list an owner holds: a hero's row, or the stash. Check is_owner
## first; an unknown owner gets an empty list.
func list_for(owner: String) -> Array[RunItem]:
	if owner == STASH:
		return stash
	var target: RunHero = hero(owner)
	if target == null:
		var none: Array[RunItem] = []
		return none
	return target.items


func fielded_count() -> int:
	var count: int = 0
	for candidate: RunHero in heroes:
		if not candidate.benched:
			count += 1
	return count


func stash_used(content: ContentDb) -> int:
	var used: int = 0
	for item: RunItem in stash:
		if content.items.has(item.item_id):
			used += content.items[item.item_id].size
	return used


func take_uid() -> int:
	next_uid += 1
	return next_uid - 1


# --- invariants ---------------------------------------------------------------

## Every rule a run must keep, as plain-language errors (empty if fine).
## Actions keep these; loading a save checks them.
func check(content: ContentDb) -> Array[String]:
	var errors: Array[String] = []
	if gold < 0 or keys < 0:
		errors.append("gold and keys can't be negative")
	if heroes.size() > FightSetup.ROSTER_CAP:
		errors.append("%d heroes; the roster cap is %d" % [heroes.size(), FightSetup.ROSTER_CAP])
	if not heroes.is_empty():
		if heroes[0].benched:
			errors.append("the first roster slot is always a field slot")
		if fielded_count() > FightSetup.MAX_FIELDED:
			errors.append("%d heroes fielded; the limit is %d" % [fielded_count(), FightSetup.MAX_FIELDED])
	var seen_heroes: Array[String] = []
	var seen_uids: Array[int] = []
	for candidate: RunHero in heroes:
		_check_hero(candidate, content, errors)
		if seen_heroes.has(candidate.hero_id):
			errors.append("%s is in the roster twice" % candidate.hero_id)
		seen_heroes.append(candidate.hero_id)
		for item: RunItem in candidate.items:
			_check_item(item, content, candidate.hero_id, errors, seen_uids)
	for item: RunItem in stash:
		_check_item(item, content, "the stash", errors, seen_uids)
	_check_legendaries_once(content, errors)
	if stash_used(content) > content.tuning.stash_slots:
		errors.append("the stash holds %d slots of items; it has %d" % [stash_used(content), content.tuning.stash_slots])
	if pouch.size() > content.tuning.pouch_cap:
		errors.append("the pouch holds %d essences; the cap is %d" % [pouch.size(), content.tuning.pouch_cap])
	for essence_id: String in pouch:
		if not content.essences.has(essence_id):
			errors.append("the pouch has an unknown essence \"%s\"" % essence_id)
	for i: int in relics.size():
		if not content.relics.has(relics[i]):
			errors.append("unknown relic \"%s\"" % relics[i])
		elif relics.find(relics[i]) < i:
			errors.append("relic \"%s\" is held twice" % relics[i])
	return errors


func _check_hero(candidate: RunHero, content: ContentDb, errors: Array[String]) -> void:
	var who: String = candidate.hero_id
	if not content.heroes.has(who):
		errors.append("unknown hero \"%s\"" % who)
	if not candidate.specialization_id.is_empty():
		var spec: SpecializationDef = content.specializations.get(candidate.specialization_id, null)
		if spec == null:
			errors.append("%s: unknown specialization \"%s\"" % [who, candidate.specialization_id])
		elif spec.hero != who:
			errors.append("%s: specialization \"%s\" belongs to %s" % [who, spec.id, spec.hero])
		if candidate.rank < 1:
			errors.append("%s: a rank-C hero has no specialization" % who)
	if candidate.needs_specialization and (candidate.rank < 1 or not candidate.specialization_id.is_empty()):
		errors.append("%s: only a rank-B+ hero without one can need a specialization" % who)
	if candidate.used_slots(content) > candidate.slots():
		errors.append("%s: items take %d slots but they have %d" % [who, candidate.used_slots(content), candidate.slots()])
	var auto_attacks: int = 0
	for item: RunItem in candidate.items:
		if content.items.has(item.item_id) and content.items[item.item_id].auto_attack:
			auto_attacks += 1
	if auto_attacks > 1:
		errors.append("%s: holds %d auto-attack items; the limit is one" % [who, auto_attacks])


func _check_item(item: RunItem, content: ContentDb, where: String, errors: Array[String], seen_uids: Array[int]) -> void:
	if seen_uids.has(item.uid):
		errors.append("item uid %d is used twice" % item.uid)
	seen_uids.append(item.uid)
	if item.uid <= 0 or item.uid >= next_uid:
		errors.append("item uid %d is out of range" % item.uid)
	if not content.items.has(item.item_id):
		errors.append("%s: unknown item \"%s\"" % [where, item.item_id])
		return
	var def: ItemDef = content.items[item.item_id]
	if item.tier < 0 or item.tier > 3:
		errors.append("%s: %s tier must be C-S" % [where, def.name])
	if item.essence_ids.size() > content.tuning.socket_count(def):
		errors.append("%s: %s has %d essences but only %d socket(s)" % [where, def.name, item.essence_ids.size(), content.tuning.socket_count(def)])
	for essence_id: String in item.essence_ids:
		if not content.essences.has(essence_id):
			errors.append("%s: %s has an unknown essence \"%s\"" % [where, def.name, essence_id])
	if item.xp < 0 or (item.xp > 0 and item.essence_ids.is_empty()):
		errors.append("%s: %s has %d XP but no infusion" % [where, def.name, item.xp])
	var path: LegendaryDef = def.legendary
	if path == null:
		if item.progress != 0 or not item.eaten.is_empty():
			errors.append("%s: %s has no upgrade path, so no path progress" % [where, def.name])
		return
	if item.tier < path.start_tier:
		errors.append("%s: %s starts at %s, so it can't be below it" % [where, def.name, TuningDef.TIER_LABELS[path.start_tier]])
	if item.progress < 0 or (item.tier >= 3 and item.progress != 0):
		errors.append("%s: %s has %d path progress (never negative, 0 at S)" % [where, def.name, item.progress])
	if not item.eaten.is_empty() and path.path != "devour":
		errors.append("%s: only a Devourer eats items" % where)
	for eaten_id: String in item.eaten:
		if not content.items.has(eaten_id):
			errors.append("%s: %s ate an unknown item \"%s\"" % [where, def.name, eaten_id])


## A Legendary is held at most once, and counts as seen.
func _check_legendaries_once(content: ContentDb, errors: Array[String]) -> void:
	var held: Array[String] = []
	var lists: Array = [stash]
	for candidate: RunHero in heroes:
		lists.append(candidate.items)
	for list: Array in lists:
		for item: RunItem in list:
			if not content.items.has(item.item_id) or content.items[item.item_id].legendary == null:
				continue
			if held.has(item.item_id):
				errors.append("%s is held twice (a Legendary appears once per run)" % content.items[item.item_id].name)
			held.append(item.item_id)
			if not legendaries_seen.has(item.item_id):
				errors.append("%s is held but not marked as seen" % content.items[item.item_id].name)


# --- save and load --------------------------------------------------------------

func to_dict() -> Dictionary:
	var hero_list: Array = []
	for candidate: RunHero in heroes:
		hero_list.append(candidate.to_dict())
	var stash_list: Array = []
	for item: RunItem in stash:
		stash_list.append(item.to_dict())
	return {
		"version": SAVE_VERSION,
		"seed": seed_value,
		"rng": rng.get_state(),
		"act": act, "day": day, "step": step, "attempt": attempt,
		"gold": gold, "keys": keys,
		"heroes": hero_list,
		"stash": stash_list,
		"pouch": pouch.duplicate(),
		"relics": relics.duplicate(),
		"wins": wins, "losses": losses,
		"discovered": discovered.duplicate(),
		"legendaries_seen": legendaries_seen.duplicate(),
		"next_uid": next_uid,
		"phase": phase,
		"offers": offers.duplicate(true),
		"stop_kind": stop_kind,
		"stop_node": stop_node,
		"stop_encounter": stop_encounter,
		"stop_used": stop_used,
		"encounter": encounter_id,
		"reroll_count": reroll_count,
		"shards": _sorted_shards(),
	}


func _sorted_shards() -> Dictionary:
	var result: Dictionary = {}
	var ids: Array = shards.keys()
	ids.sort()
	for essence_id: String in ids:
		result[essence_id] = shards[essence_id]
	return result


## Rebuilds a run from to_dict()'s output. Returns [state, errors]; the state
## is only usable when errors is empty (bad data, or broken run rules).
static func from_dict(data: Variant, content: ContentDb) -> Array:
	var errors: Array[String] = []
	var state := RunState.new()
	var reader: DataReader = DataReader.from_value(data, "save", errors)
	if reader == null:
		return [state, errors]
	var version: int = reader.req_int("version", 1)
	if version != SAVE_VERSION:
		reader.error("version %d isn't supported (expected %d)" % [version, SAVE_VERSION])
	state.seed_value = reader.req_int("seed")
	state.rng = SimRng.new(state.seed_value)
	var rng_state: Array[int] = reader.req_int_array("rng")
	if rng_state.size() == 4:
		state.rng.set_state(rng_state[0], rng_state[1], rng_state[2], rng_state[3])
	else:
		reader.error("rng needs 4 numbers")
	state.act = reader.req_int("act", 1)
	state.day = reader.req_int("day", 1)
	state.step = reader.req_int("step", 0)
	state.attempt = reader.req_int("attempt", 0)
	state.gold = reader.req_int("gold")
	state.keys = reader.req_int("keys")
	for hero_reader: DataReader in reader.opt_object_array("heroes"):
		state.heroes.append(RunHero.from_dict(hero_reader))
	for item_reader: DataReader in reader.opt_object_array("stash"):
		state.stash.append(RunItem.from_dict(item_reader))
	state.pouch = reader.req_string_array("pouch")
	state.relics = reader.req_string_array("relics")
	state.wins = reader.req_int("wins", 0)
	state.losses = reader.req_int("losses", 0)
	state.discovered = reader.req_string_array("discovered")
	state.legendaries_seen = reader.req_string_array("legendaries_seen")
	state.next_uid = reader.req_int("next_uid", 1)
	state.phase = reader.opt_string("phase", "")
	if not state.phase.is_empty() and not RunFlow.PHASES.has(state.phase):
		reader.error("unknown phase \"%s\"" % state.phase)
	for offer_reader: DataReader in reader.opt_object_array("offers"):
		state.offers.append(RunFlow.read_offer(offer_reader))
	state.stop_kind = reader.opt_string("stop_kind", "")
	if not state.stop_kind.is_empty() and not RunFlow.STOP_KINDS.has(state.stop_kind):
		reader.error("unknown stop \"%s\"" % state.stop_kind)
	state.stop_node = reader.opt_string("stop_node", "")
	state.stop_encounter = reader.opt_string("stop_encounter", "")
	if not state.stop_encounter.is_empty() and not content.encounters.has(state.stop_encounter):
		reader.error("unknown encounter \"%s\"" % state.stop_encounter)
	state.stop_used = reader.opt_bool("stop_used", false)
	state.encounter_id = reader.opt_string("encounter", "")
	if not state.encounter_id.is_empty() and not content.encounters.has(state.encounter_id):
		reader.error("unknown encounter \"%s\"" % state.encounter_id)
	state.reroll_count = reader.opt_int("reroll_count", 0, 0)
	if reader.has("shards"):
		var shard_reader: DataReader = reader.req_object("shards")
		if shard_reader != null:
			for essence_id: String in shard_reader.map_keys():
				state.shards[essence_id] = shard_reader.req_int(essence_id, 0)
			shard_reader.finish()
	reader.finish()
	if errors.is_empty():
		errors.append_array(state.check(content))
	return [state, errors]
