class_name RunActions
extends RefCounted
## Every change to a run between fights goes through these actions
## (docs/plans/run-state.md). Each one checks it's allowed, applies it, and
## returns a Result; a refused action changes nothing. The UI calls these
## and never edits RunState directly.


class Result:
	var ok: bool = false
	## Why it was refused, in plain words for the UI.
	var error: String = ""
	## What happened, for a run log.
	var note: String = ""
	## Anything else it set off, like a Legendary growing a tier.
	var notes: Array[String] = []


static func _ok(note: String) -> Result:
	var result := Result.new()
	result.ok = true
	result.note = note
	return result


static func _fail(error: String) -> Result:
	var result := Result.new()
	result.error = error
	return result


# --- items --------------------------------------------------------------------

## Moves an item to a hero's row (by hero id) or the stash (RunState.STASH),
## at `index` (clamped). Works within one list too.
static func move_item(state: RunState, content: ContentDb, uid: int, to: String, index: int) -> Result:
	var from_owner: String = state.owner_of(uid)
	if from_owner == RunState.NOWHERE:
		return _fail("that item isn't in the guild")
	if not state.is_owner(to):
		return _fail("no hero \"%s\" in the roster" % to)
	var source: Array[RunItem] = state.list_for(from_owner)
	var destination: Array[RunItem] = state.list_for(to)
	var item: RunItem = state.find_item(uid)
	var from_index: int = source.find(item)
	source.remove_at(from_index)
	destination.insert(clampi(index, 0, destination.size()), item)
	var problem: String = _room_problem(state, content, to)
	if not problem.is_empty():
		destination.erase(item)
		source.insert(from_index, item)
		return _fail(problem)
	return _ok("moved %s to %s" % [_name(content, item), "the stash" if to == RunState.STASH else to])


## Why `owner`'s list breaks a rule after a change (space, one auto-attack
## item), or "".
static func _room_problem(state: RunState, content: ContentDb, owner: String) -> String:
	if owner == RunState.STASH:
		if state.stash_used(content) > content.tuning.stash_slots:
			return "the stash has no room for that (%d slots)" % content.tuning.stash_slots
		return ""
	var target: RunHero = state.hero(owner)
	if target.used_slots(content) > target.slots():
		return "%s has no room for that (%d slots)" % [owner, target.slots()]
	var auto_attacks: int = 0
	for item: RunItem in target.items:
		if content.items[item.item_id].auto_attack:
			auto_attacks += 1
	if auto_attacks > 1:
		return "%s can hold only one auto-attack item" % owner
	return ""


## Throws an item away (any time; selling is only at the Caravan).
static func discard_item(state: RunState, content: ContentDb, uid: int) -> Result:
	var item: RunItem = state.find_item(uid)
	if item == null:
		return _fail("that item isn't in the guild")
	state.list_for(state.owner_of(uid)).erase(item)
	return _ok("threw away %s" % _name(content, item))


## A new item into the stash. Refused without room: make room first, or pass.
## A Legendary always joins at its path's start tier, and only once.
static func add_item(state: RunState, content: ContentDb, item_id: String, tier: int = 0) -> Result:
	if not content.items.has(item_id):
		return _fail("unknown item \"%s\"" % item_id)
	var def: ItemDef = content.items[item_id]
	if def.legendary != null and _holds(state, item_id):
		return _fail("the guild already holds %s" % def.name)
	if state.stash_used(content) + def.size > content.tuning.stash_slots:
		return _fail("the stash has no room for %s" % def.name)
	var item: RunItem = RunItem.make(state.take_uid(), item_id, def.legendary.start_tier if def.legendary != null else clampi(tier, 0, 3))
	state.stash.append(item)
	if def.rarity == "legendary" and not state.legendaries_seen.has(item_id):
		state.legendaries_seen.append(item_id)
	return _ok("took %s (%s)" % [def.name, TuningDef.TIER_LABELS[item.tier]])


## Two copies of the same item at the same tier become one, a tier up, where
## `keep_uid` was. If the new copy has an infusion it replaces the kept one's
## (XP and all); if not, the kept infusion and XP stay. S items and
## Legendaries never combine.
static func combine_items(state: RunState, content: ContentDb, keep_uid: int, new_uid: int) -> Result:
	var keep: RunItem = state.find_item(keep_uid)
	var copy: RunItem = state.find_item(new_uid)
	if keep == null or copy == null or keep_uid == new_uid:
		return _fail("pick two different items the guild holds")
	if keep.item_id != copy.item_id:
		return _fail("only two copies of the same item combine")
	if keep.tier != copy.tier:
		return _fail("only copies at the same tier combine")
	var def: ItemDef = content.items[keep.item_id]
	if def.rarity == "legendary":
		return _fail("Legendaries never combine")
	if keep.tier >= 3:
		return _fail("S items can't combine")
	state.list_for(state.owner_of(new_uid)).erase(copy)
	keep.tier += 1
	if not copy.essence_ids.is_empty():
		keep.essence_ids = copy.essence_ids.duplicate()
		keep.xp = copy.xp
	return _ok("combined two %s into %s" % [def.name, TuningDef.TIER_LABELS[keep.tier]])


# --- essences -----------------------------------------------------------------

static func add_essence(state: RunState, content: ContentDb, essence_id: String) -> Result:
	if not content.essences.has(essence_id):
		return _fail("unknown essence \"%s\"" % essence_id)
	if state.pouch.size() >= content.tuning.pouch_cap:
		return _fail("the essence pouch is full (%d)" % content.tuning.pouch_cap)
	state.pouch.append(essence_id)
	return _ok("took %s" % content.essences[essence_id].name)


static func discard_essence(state: RunState, content: ContentDb, pouch_index: int) -> Result:
	if pouch_index < 0 or pouch_index >= state.pouch.size():
		return _fail("no essence there")
	var essence_id: String = state.pouch[pouch_index]
	state.pouch.remove_at(pouch_index)
	return _ok("threw away %s" % content.essences[essence_id].name)


## Sockets an essence from the pouch into an item (any time between fights).
## Adding a second essence (single -> alloy or pure double) resets XP.
static func infuse(state: RunState, content: ContentDb, uid: int, pouch_index: int) -> Result:
	var item: RunItem = state.find_item(uid)
	if item == null:
		return _fail("that item isn't in the guild")
	if pouch_index < 0 or pouch_index >= state.pouch.size():
		return _fail("no essence there")
	var def: ItemDef = content.items[item.item_id]
	var sockets: int = content.tuning.socket_count(def)
	if item.essence_ids.size() >= sockets:
		return _fail("%s has no free socket (%d)" % [def.name, sockets])
	var essence_id: String = state.pouch[pouch_index]
	state.pouch.remove_at(pouch_index)
	item.essence_ids.append(essence_id)
	if item.essence_ids.size() == 2:
		item.xp = 0
	return _ok("infused %s with %s" % [def.name, content.essences[essence_id].name])


## Removes an item's whole infusion for gold. The essences are destroyed and
## the XP resets. (Step 5 limits this to the Forge.)
static func reforge(state: RunState, content: ContentDb, uid: int) -> Result:
	var item: RunItem = state.find_item(uid)
	if item == null:
		return _fail("that item isn't in the guild")
	if item.essence_ids.is_empty():
		return _fail("%s has no infusion" % _name(content, item))
	if state.gold < content.tuning.reforge_gold:
		return _fail("reforging costs %d gold" % content.tuning.reforge_gold)
	state.gold -= content.tuning.reforge_gold
	item.essence_ids.clear()
	item.xp = 0
	return _ok("reforged %s" % _name(content, item))


# --- Legendary paths ------------------------------------------------------------

## Feeds an Essence-hungry Legendary the essence its step wants, from the
## pouch (any time between fights).
static func feed_essence(state: RunState, content: ContentDb, uid: int, pouch_index: int) -> Result:
	var item: RunItem = state.find_item(uid)
	if item == null:
		return _fail("that item isn't in the guild")
	var path: LegendaryDef = RunLegendary.path_of(content, item)
	if path == null or path.path != "essence":
		return _fail("only an Essence-hungry Legendary can be fed essences")
	if item.tier >= 3:
		return _fail("%s is fully grown" % _name(content, item))
	if pouch_index < 0 or pouch_index >= state.pouch.size():
		return _fail("no essence there")
	var wanted: String = path.wanted_at(item.tier)
	if state.pouch[pouch_index] != wanted:
		return _fail("%s wants %s" % [_name(content, item), content.essences[wanted].name])
	state.pouch.remove_at(pouch_index)
	var result: Result = _ok("fed %s to %s" % [content.essences[wanted].name, _name(content, item)])
	result.notes = RunLegendary.advance(content, item, 1)
	return result


## Feeds another item to a Devourer (any time between fights). The meal is
## worth its tier + 1, and leaves a trace by its rarity. Never a Legendary.
static func devour_item(state: RunState, content: ContentDb, uid: int, food_uid: int) -> Result:
	var item: RunItem = state.find_item(uid)
	var food: RunItem = state.find_item(food_uid)
	if item == null or food == null:
		return _fail("that item isn't in the guild")
	var path: LegendaryDef = RunLegendary.path_of(content, item)
	if path == null or path.path != "devour":
		return _fail("only a Devourer can eat items")
	if uid == food_uid:
		return _fail("%s can't eat itself" % _name(content, item))
	if not LegendaryDef.EDIBLE_RARITIES.has(content.items[food.item_id].rarity):
		return _fail("a Legendary can't be eaten")
	state.list_for(state.owner_of(food_uid)).erase(food)
	item.eaten.append(food.item_id)
	var result: Result = _ok("%s devours %s" % [_name(content, item), _name(content, food)])
	result.notes = RunLegendary.advance(content, item, RunLegendary.meal_value(food))
	return result


## Whether the guild holds a copy of an item.
static func _holds(state: RunState, item_id: String) -> bool:
	for item: RunItem in state.stash:
		if item.item_id == item_id:
			return true
	for hero: RunHero in state.heroes:
		for item: RunItem in hero.items:
			if item.item_id == item_id:
				return true
	return false


# --- heroes -------------------------------------------------------------------

## A hero joins: from the Caravan, the run start, or a reward. The same hero
## at the same rank combines (rank +1; the one you have keeps their
## specialization and items); a different rank is refused. A new hero joins
## fielded (the first in front, later ones in the back row) if fewer than 5
## are, else benched. A hero at B or above without `specialization_id` must
## pick one.
static func add_hero(state: RunState, content: ContentDb, hero_id: String, rank: int = 0, specialization_id: String = "") -> Result:
	if not content.heroes.has(hero_id):
		return _fail("unknown hero \"%s\"" % hero_id)
	var name: String = content.heroes[hero_id].name
	var existing: RunHero = state.hero(hero_id)
	if existing != null:
		if existing.rank != rank:
			return _fail("%s is already in the guild at another rank" % name)
		if existing.rank >= 3:
			return _fail("%s is already rank S" % name)
		existing.rank += 1
		if existing.rank == 1 and existing.specialization_id.is_empty():
			existing.needs_specialization = true
		var ranked: Result = _ok("%s ranks up to %s" % [name, TuningDef.TIER_LABELS[existing.rank]])
		ranked.notes = RunLegendary.on_rank_up(state, content, existing)
		return ranked
	if state.heroes.size() >= FightSetup.ROSTER_CAP:
		return _fail("the roster is full (%d)" % FightSetup.ROSTER_CAP)
	if not specialization_id.is_empty():
		var problem: String = _spec_problem(content, hero_id, specialization_id)
		if not problem.is_empty():
			return _fail(problem)
		if rank < 1:
			return _fail("a rank-C hero has no specialization")
	var joined: RunHero = RunHero.make(hero_id, clampi(rank, 0, 3))
	joined.specialization_id = specialization_id
	joined.needs_specialization = joined.rank >= 1 and specialization_id.is_empty()
	joined.row = UnitSetup.Row.FRONT if state.heroes.is_empty() else UnitSetup.Row.BACK
	joined.benched = state.fielded_count() >= FightSetup.MAX_FIELDED
	state.heroes.append(joined)
	return _ok("%s joins the guild%s" % [name, " in backup" if joined.benched else ""])


static func choose_specialization(state: RunState, content: ContentDb, hero_id: String, specialization_id: String) -> Result:
	var target: RunHero = state.hero(hero_id)
	if target == null:
		return _fail("no hero \"%s\" in the roster" % hero_id)
	if not target.needs_specialization:
		return _fail("%s has no specialization to pick" % hero_id)
	var problem: String = _spec_problem(content, hero_id, specialization_id)
	if not problem.is_empty():
		return _fail(problem)
	target.specialization_id = specialization_id
	target.needs_specialization = false
	return _ok("%s becomes a %s" % [hero_id, content.specializations[specialization_id].name])


static func _spec_problem(content: ContentDb, hero_id: String, specialization_id: String) -> String:
	if not content.specializations.has(specialization_id):
		return "unknown specialization \"%s\"" % specialization_id
	if content.specializations[specialization_id].hero != hero_id:
		return "%s isn't one of %s's specializations" % [content.specializations[specialization_id].name, hero_id]
	return ""


## Moves a hero to a roster slot. Slot 0 is always a field slot.
static func move_hero(state: RunState, hero_id: String, index: int) -> Result:
	var target: RunHero = state.hero(hero_id)
	if target == null:
		return _fail("no hero \"%s\" in the roster" % hero_id)
	var to: int = clampi(index, 0, state.heroes.size() - 1)
	var from: int = state.heroes.find(target)
	state.heroes.remove_at(from)
	state.heroes.insert(to, target)
	if state.heroes[0].benched:
		state.heroes.remove_at(to)
		state.heroes.insert(from, target)
		return _fail("the first roster slot is always a field slot")
	return _ok("moved %s to slot %d" % [hero_id, to + 1])


static func set_row(state: RunState, hero_id: String, row: UnitSetup.Row) -> Result:
	var target: RunHero = state.hero(hero_id)
	if target == null:
		return _fail("no hero \"%s\" in the roster" % hero_id)
	target.row = row
	return _ok("%s moves to the %s row" % [hero_id, EncounterDef.ROW_NAMES[row]])


## Puts a hero in a backup slot or a field slot: 1-5 fielded, and slot 0 is
## always a field slot.
static func set_benched(state: RunState, hero_id: String, benched: bool) -> Result:
	var target: RunHero = state.hero(hero_id)
	if target == null:
		return _fail("no hero \"%s\" in the roster" % hero_id)
	if target.benched == benched:
		return _ok("no change")
	if benched and state.heroes[0] == target:
		return _fail("the first roster slot is always a field slot")
	if not benched and state.fielded_count() >= FightSetup.MAX_FIELDED:
		return _fail("at most %d heroes can be fielded" % FightSetup.MAX_FIELDED)
	target.benched = benched
	return _ok("%s moves to %s" % [hero_id, "backup" if benched else "the field"])


# --- gold and relics ----------------------------------------------------------

static func gain_gold(state: RunState, amount: int) -> Result:
	if amount < 0:
		return _fail("use spend_gold to spend")
	state.gold += amount
	return _ok("+%d gold" % amount)


static func spend_gold(state: RunState, amount: int) -> Result:
	if amount < 0 or amount > state.gold:
		return _fail("not enough gold (%d of %d)" % [state.gold, amount])
	state.gold -= amount
	return _ok("-%d gold" % amount)


## Takes a relic for good (turning one down just means not calling this).
static func add_relic(state: RunState, content: ContentDb, relic_id: String) -> Result:
	if not content.relics.has(relic_id):
		return _fail("unknown relic \"%s\"" % relic_id)
	if state.relics.has(relic_id):
		return _fail("the guild already holds %s" % content.relics[relic_id].name)
	state.relics.append(relic_id)
	return _ok("took %s" % content.relics[relic_id].name)


static func _name(content: ContentDb, item: RunItem) -> String:
	return content.items[item.item_id].name
