class_name RunContent
extends RefCounted
## The run's data, apart from the sim's (docs/plans/rebuild-phase5-run.md):
## the act, the upgrades, the items, camp, the relics, and the duo bonds. It sits over the sim's ContentDb, which it cross-checks
## against: every encounter a day can draw, every path and hero named.

const ACT_FILE: String = "act1.json"
const UPGRADES_FILE: String = "upgrades.json"
const ITEMS_FILE: String = "items.json"
const CAMPS_FILE: String = "camps.json"
const RELICS_FILE: String = "relics.json"
const BONDS_FILE: String = "bonds.json"
const EVENTS_FILE: String = "events.json"
const FILES: Array[String] = [ACT_FILE, UPGRADES_FILE, ITEMS_FILE, CAMPS_FILE, RELICS_FILE, BONDS_FILE, EVENTS_FILE]
## The items' and relics' glyphs (the UI draws them; phase 5b).
const GLYPHS: String = "res://art/ui/items/glyphs/%s.svg"
## Where camp's icons are (camps.json names a file under it).
const ART_UI: String = "res://art/ui/"

var content: ContentDb
var act: ActDef = null
var upgrades: Dictionary[String, UpgradeDef] = {}
## In the file's order (offers draw in this order).
var upgrade_ids: Array[String] = []
var items: Dictionary[String, ItemDef] = {}
var item_ids: Array[String] = []
var camps: CampsDef = null
var relics: Dictionary[String, RelicDef] = {}
var relic_ids: Array[String] = []
var bonds: Dictionary[String, BondDef] = {}
var bond_ids: Array[String] = []
## The Event node's scenes and oaths (phase 5c step 8c).
var events: EventDef = null
var errors: Array[String] = []


## Loads the run's files from `dir`, over `content_db` (already loaded).
static func load_dir(dir: String, content_db: ContentDb) -> RunContent:
	var texts: Dictionary[String, String] = {}
	var missing: Array[String] = []
	for file_name: String in FILES:
		var file_path: String = dir.path_join(file_name)
		if FileAccess.file_exists(file_path):
			texts[file_name] = FileAccess.get_file_as_string(file_path)
		else:
			missing.append("%s: file not found" % file_path)
	var run: RunContent = load_texts(texts, content_db)
	missing.append_array(run.errors)
	run.errors = missing
	return run


static func load_texts(texts: Dictionary[String, String], content_db: ContentDb) -> RunContent:
	var run := RunContent.new()
	run.content = content_db
	var act_data: Variant = run._parse(texts, ACT_FILE)
	if act_data != null:
		var reader: DataReader = DataReader.from_value(act_data, ACT_FILE, run.errors)
		if reader != null:
			run.act = ActDef.read(reader)
	run._read_upgrades(run._parse(texts, UPGRADES_FILE))
	run._read_items(run._parse(texts, ITEMS_FILE))
	var camps_data: Variant = run._parse(texts, CAMPS_FILE)
	if camps_data != null:
		var camps_reader: DataReader = DataReader.from_value(camps_data, CAMPS_FILE, run.errors)
		if camps_reader != null:
			run.camps = CampsDef.read(camps_reader)
	for reader: DataReader in run._entries(run._parse(texts, RELICS_FILE), RELICS_FILE):
		var relic: RelicDef = RelicDef.read(reader)
		if run._claim(relic.id, reader, run.relic_ids):
			run.relics[relic.id] = relic
	for reader: DataReader in run._entries(run._parse(texts, BONDS_FILE), BONDS_FILE):
		var bond: BondDef = BondDef.read(reader)
		if run._claim(bond.id, reader, run.bond_ids):
			run.bonds[bond.id] = bond
	var events_data: Variant = run._parse(texts, EVENTS_FILE)
	if events_data != null:
		var events_reader: DataReader = DataReader.from_value(events_data, EVENTS_FILE, run.errors)
		if events_reader != null:
			run.events = EventDef.read(events_reader)
	run._check()
	return run


func is_valid() -> bool:
	return errors.is_empty() and content != null and content.is_valid()


## The encounters of `tier` in this act that day `day` can draw.
func encounters_for(tier: String, day: int) -> Array[String]:
	var found: Array[String] = []
	for id: String in content.encounter_ids:
		var encounter: EncounterDef = content.encounters[id]
		if encounter.act == act.act and encounter.tier == tier and encounter.days.has(day):
			found.append(id)
	return found


## A day's kind ("normal", "elite", or "boss"): the act's days, then, in an
## endless run (phase 8 part 1), the floor's; "" for a day there's none of.
func day_kind(state: RunState, day: int) -> String:
	if day >= 1 and day <= act.days.size():
		return act.days[day - 1]
	if state.endless and act.endless != null and day > act.days.size():
		return act.endless.kind(day - act.days.size())
	return ""


## The floor `day` is in an endless run (0 for the act's days).
func floor_of(state: RunState, day: int) -> int:
	return maxi(day - act.days.size(), 0) if state.endless else 0


## The fights an endless floor of `kind` draws from (Decision 1): the act's
## easier and harder fights allowed from endless.from_day on for a normal
## floor, its elites, or its boss.
func floor_pool(kind: String) -> Array[String]:
	var found: Array[String] = []
	var tiers: Array[String] = [kind]
	if kind == "normal":
		tiers.assign(["easier", "harder"])
	for id: String in content.encounter_ids:
		var encounter: EncounterDef = content.encounters[id]
		if encounter.act != act.act or not tiers.has(encounter.tier):
			continue
		if kind == "normal" and act.endless != null and not encounter.days.any(func(d: int) -> bool: return d >= act.endless.from_day):
			continue
		found.append(id)
	return found


## Every easier and harder encounter of this act, whatever its days.
func normal_encounters() -> Array[String]:
	var found: Array[String] = []
	for id: String in content.encounter_ids:
		var encounter: EncounterDef = content.encounters[id]
		if encounter.act == act.act and encounter.tier in ["easier", "harder"]:
			found.append(id)
	return found


## The upgrades `hero` can be offered now (phase 5c step 7, section 15.3):
## its hero cards always, its vowed path's taste cards until it transforms,
## and that path's cards once it has; none it has taken but a stacking card,
## and none that would change nothing on its kit now (Decision 37).
func upgrades_for(hero: RunState.Hero) -> Array[String]:
	var found: Array[String] = []
	for id: String in upgrade_ids:
		var upgrade: UpgradeDef = upgrades[id]
		if upgrade.hero != hero.id or (hero.upgrades.has(id) and not upgrade.stacks()):
			continue
		if upgrade.layer == UpgradeDef.Layer.TASTE and (upgrade.path != hero.path or hero.transformed):
			continue
		if upgrade.layer == UpgradeDef.Layer.PATH and (upgrade.path != hero.path or not hero.transformed):
			continue
		if not changes_something(upgrade, hero.transformed, hero_kit(hero)):
			continue
		found.append(id)
	return found


## True if `upgrade` changes something on `kit` (a hero `transformed` or
## not): its mod touches it, and an added passive can fire on it; a growing
## card's counting can count there; a stacking card always does.
func changes_something(upgrade: UpgradeDef, transformed: bool, kit: UnitDef) -> bool:
	if upgrade.stacks():
		return true
	var mod: KitMod = upgrade.mod_for(transformed)
	if mod != null and (mod.affects_besides_passives(kit) or mod.passives.any(func(part: PartDef) -> bool: return _passive_can_fire(part, kit))):
		return true
	return upgrade.grows != null and _can_count(upgrade.grows.counts, kit)


## An added passive's events must be able to happen on `kit`: one that waits
## on statuses the kit applies (on_status), or on hopping (on_hop). Auras and
## other events always can.
func _passive_can_fire(part: PartDef, kit: UnitDef) -> bool:
	if part.kind != PartDef.Kind.ABILITY:
		return true
	var applied: Array[String] = kit.status_ids()
	for effect: EffectDef in part.ability.effects:
		if effect.trigger == EffectDef.Trigger.ON_HOP and kit.hop_cooldown_ticks <= 0:
			continue
		if effect.trigger == EffectDef.Trigger.ON_STATUS and not effect.statuses.is_empty() \
				and not effect.statuses.any(func(status_id: String) -> bool: return applied.has(status_id)):
			continue
		return true
	return false


## A growing card's counting can count on `kit`: what it names is there (its
## abilities, the keywords of the statuses it applies).
func _can_count(counts: DeedDef, kit: UnitDef) -> bool:
	if not counts.from_ability.is_empty() and not counts.from_ability.any(func(ability_id: String) -> bool: return kit.ability_ids().has(ability_id)):
		return false
	if counts.counts == DeedDef.Counts.APPLIED and not counts.keywords.is_empty():
		for status_id: String in kit.status_ids():
			if content.statuses.has(status_id) and counts.keywords.has(content.statuses[status_id].keyword):
				return true
		return false
	return true


## The kit mods `hero`'s upgrades give it now, in the order taken (a taste
## or path card only while the hero is on that path); a growing one's, its
## steps so far (phase 5c step 4); a stacking one's, each take's locked
## amount (step 7).
func upgrade_mods(hero: RunState.Hero) -> Array[KitMod]:
	var mods: Array[KitMod] = []
	var takes: Dictionary[String, int] = {}
	for upgrade: UpgradeDef in held_upgrades(hero):
		if upgrade.stacks():
			var take: int = takes.get(upgrade.id, 0)
			takes[upgrade.id] = take + 1
			var locked: Array = hero.locked.get(upgrade.id, [])
			if take < locked.size():
				mods.append(upgrade.locked_mod(int(locked[take])))
			continue
		var mod: KitMod = upgrade.mod_for(hero.transformed)
		if mod != null:
			mods.append(mod)
		if upgrade.grows != null:
			var grown: KitMod = upgrade.grows.mod_for(hero.growth.get(upgrade.id, 0))
			if grown != null:
				mods.append(grown)
	return mods


## What taking stacking card `upgrade` now locks in for `hero` (section
## 15.4): its share of the hero's stat now (its kit at its stage with the
## upgrades it holds; not wounds, items, relics, or auras), rounded to the
## nearest point, at least 1. Attack speed's share is of 100 + ATSP, since
## ATSP is a bonus in points, not a rate.
func stack_amount(hero: RunState.Hero, upgrade: UpgradeDef) -> int:
	var kit: UnitDef = hero_kit(hero)
	for mod: KitMod in upgrade_mods(hero):
		kit = mod.apply(kit)
	var stat: int = kit.stats.values[upgrade.stack_stat]
	if upgrade.stack_stat == UnitStats.Stat.ATSP:
		stat += 100
	return maxi(1, (stat * upgrade.stack_pct + 50) / 100)


## The upgrades that count for `hero` now, in the order taken (a taste or
## path card only while the hero is on that path; a stacking card once per
## take).
func held_upgrades(hero: RunState.Hero) -> Array[UpgradeDef]:
	var found: Array[UpgradeDef] = []
	for id: String in hero.upgrades:
		var upgrade: UpgradeDef = upgrades.get(id)
		if upgrade != null and (upgrade.layer == UpgradeDef.Layer.HERO or upgrade.path == hero.path):
			found.append(upgrade)
	return found


## What `hero` counts for the growing cards in a fight (phase 5c step 4):
## "upgrade:<id>" for its own, "relic:<id>" for the team's relics, each with
## how it counts. Returns [keys, counts].
func growth_tallies(state: RunState, hero: RunState.Hero) -> Array:
	var keys: Array[String] = []
	var counts: Array[DeedDef] = []
	for upgrade: UpgradeDef in held_upgrades(hero):
		if upgrade.grows != null:
			keys.append("upgrade:" + upgrade.id)
			counts.append(upgrade.grows.counts)
	for id: String in state.relics:
		if relics.has(id) and relics[id].grows != null and relics[id].grows.counted_in_fights():
			keys.append("relic:" + id)
			counts.append(relics[id].grows.counts)
	# Its tactic's and sigils' ranks count in the fight (phase 5c step 6):
	# the time it stands, and its signature's casts. Charms and gambits count
	# fights, which the run does.
	for item_id: String in hero.slots:
		var item: ItemDef = items.get(item_id)
		if item == null or state.item_ranks.get(item_id, ItemDef.RANKS) >= ItemDef.RANKS:
			continue
		if item.kind == ItemDef.Kind.TACTIC:
			keys.append("item:" + item_id)
			counts.append(ITEM_STANDING)
		elif item.kind == ItemDef.Kind.SIGIL:
			keys.append("item:" + item_id)
			counts.append(ITEM_CASTS)
	return [keys, counts]


## What a tactic's and a sigil's ranks count (built once).
static var ITEM_STANDING: DeedDef = _count_of(DeedDef.Counts.MS_STANDING)
static var ITEM_CASTS: DeedDef = _count_of(DeedDef.Counts.CASTS)


static func _count_of(counts: DeedDef.Counts) -> DeedDef:
	var deed := DeedDef.new()
	deed.counts = counts
	return deed


## The kit `hero` fights with before its upgrades and loadout: its path's,
## at its stage (an apex's once vowed to one, phase 8 part 2).
func hero_kit(hero: RunState.Hero) -> UnitDef:
	var path: PathDef = content.paths[hero.path]
	if hero.transformed and not hero.apex.is_empty() and path.apex(hero.apex) != null:
		return path.apex(hero.apex).apex_kit if hero.apex_earned else path.apex(hero.apex).vowed_kit
	return path.transformed_kit if hero.transformed else path.vowed_kit


## The kit mods `hero`'s loadout gives it, in slot order, each at the
## item's rank (a tactic gives none; an item that does nothing on it changes
## nothing anyway).
func loadout_mods(state: RunState, hero: RunState.Hero) -> Array[KitMod]:
	var mods: Array[KitMod] = []
	for item_id: String in hero.slots:
		var mod: KitMod = items[item_id].mod_at(state.item_ranks.get(item_id, 1)) if items.has(item_id) else null
		if mod != null:
			mods.append(mod)
	return mods


## The mod of the gambit `hero` holds, at its rank, or null (phase 5c step
## 6d).
func loadout_gambit(hero: RunState.Hero, state: RunState) -> KitMod:
	for item_id: String in hero.slots:
		var item: ItemDef = items.get(item_id)
		if item != null and item.kind == ItemDef.Kind.GAMBIT:
			return item.mod_at(state.item_ranks.get(item_id, 1))
	return null


## The tactic `hero`'s loadout gives it: the first tactic item it can
## follow, or null. One it can't (Wait to heal without a signature that
## waits) does nothing, with no warning (loadout rule 2).
## At the item's rank (phase 5c step 6c).
func loadout_tactic(hero: RunState.Hero, state: RunState = null) -> TacticDef:
	for item_id: String in hero.slots:
		var item: ItemDef = items.get(item_id)
		if item != null and item.tactic != null and can_follow(item.tactic, hero_kit(hero), hero.id):
			return item.tactic.at_rank(state.item_ranks.get(item_id, 1) if state != null else 1)
	return null


## Whether a hero `hero_id` with `kit` can follow `tactic`.
static func can_follow(tactic: TacticDef, kit: UnitDef, hero_id: String) -> bool:
	return tactic.allows(hero_id) and Tactics.can_follow(tactic, kit)


## The kit mods the run's relics give every hero, in the order taken; a
## growing one's, its steps so far (phase 5c step 4). `kit`: the hero's
## path's kit, for a mod only for some heroes (phase 5c step 5c, mod_for).
func relic_mods(state: RunState, kit: UnitDef = null) -> Array[KitMod]:
	var mods: Array[KitMod] = []
	for id: String in state.relics:
		if not relics.has(id):
			continue
		if relics[id].mod != null and relics[id].mod_fits(kit):
			mods.append(_doubled(relics[id].mod) if counts_twice(state, relics[id]) else relics[id].mod)
		if relics[id].grows != null:
			var grown: KitMod = relics[id].grows.mod_for(state.growth.get(id, 0))
			if grown != null:
				mods.append(grown)
		var worked_out: KitMod = _worked_out(relics[id], state)
		if worked_out != null:
			mods.append(worked_out)
	return mods


## Whether a relic counts twice (phase 5c step 5b): a common, while
## Reliquary is held.
func counts_twice(state: RunState, relic: RelicDef) -> bool:
	return relic.tier == RelicDef.Tier.COMMON and relic_rule(state, "doubles_commons")


## A common's mod under Reliquary: twice over where a step could scale it
## (stats, amounts, auras); unchanged where it couldn't (Brand of Guilt's
## ability, Rift Candle's mana).
static func _doubled(mod: KitMod) -> KitMod:
	return mod.times(2) if mod.step_problem().is_empty() else mod


## The relics' effects as each fight starts (phase 5c step 5b), in the order
## taken, with the share each runs at (doubled for a common under
## Reliquary): [relic, scale_bp] pairs for each effect.
func relic_starts(state: RunState) -> Array[Array]:
	var starts: Array[Array] = []
	for id: String in state.relics:
		if not relics.has(id):
			continue
		var scale: int = 2 * FixedMath.BP_ONE if counts_twice(state, relics[id]) else FixedMath.BP_ONE
		for effect: EffectDef in relics[id].at_start:
			starts.append([relics[id], effect, scale])
	return starts


## The rules the run's relics give the heroes' side (phase 5c step 5c).
func hero_rules(state: RunState) -> SideRules:
	var rules := SideRules.new()
	for id: String in state.relics:
		if relics.has(id) and relics[id].rules != null:
			rules = rules.merged(relics[id].rules)
	return rules


## The stats a relic gives from the run as it stands (phase 5c step 5a):
## Reliquary Lamp's per relic held, Gilded Rift's per shards held.
func _worked_out(relic: RelicDef, state: RunState) -> KitMod:
	var mod: KitMod = null
	if relic.per_relic_bp > 0:
		mod = KitMod.make()
		for stat: UnitStats.Stat in [UnitStats.Stat.HP, UnitStats.Stat.ATK, UnitStats.Stat.MGK, UnitStats.Stat.DEF, UnitStats.Stat.CRIT, UnitStats.Stat.ATSP]:
			mod.stats_bp[stat] = FixedMath.BP_ONE + relic.per_relic_bp * state.relics.size()
	if relic.per_shards > 0:
		@warning_ignore("integer_division")
		var steps: int = state.shards / relic.per_shards
		if steps > 0:
			mod = KitMod.make() if mod == null else mod
			for stat: UnitStats.Stat in [UnitStats.Stat.ATK, UnitStats.Stat.MGK]:
				mod.stats_bp[stat] += relic.per_shards_bp * steps
	return mod


## The bonds on for the run's heroes: both paths vowed and transformed.
func active_bonds(state: RunState) -> Array[BondDef]:
	return _bonds_where(state, true)


## The bond relics the shops may show (phase 5c step 5d): those of the bonds
## on, not yet held, in the bonds' order.
func bond_relics(state: RunState) -> Array[String]:
	var found: Array[String] = []
	for bond: BondDef in active_bonds(state):
		if not state.relics.has(bond.relic):
			found.append(bond.relic)
	return found


## The bonds that stir: both paths vowed, not both transformed (shown as "?").
func stirring_bonds(state: RunState) -> Array[BondDef]:
	var stirring: Array[BondDef] = _bonds_where(state, false)
	return stirring.filter(func(bond: BondDef) -> bool: return not active_bonds(state).has(bond))


func _bonds_where(state: RunState, transformed: bool) -> Array[BondDef]:
	var found: Array[BondDef] = []
	for id: String in bond_ids:
		var bond: BondDef = bonds[id]
		var on: bool = true
		for path_id: String in bond.paths:
			var hero: RunState.Hero = state.hero(content.paths[path_id].hero) if content.paths.has(path_id) else null
			if hero == null or hero.path != path_id or (transformed and not hero.transformed):
				on = false
		if on:
			found.append(bond)
	return found


## The run's rules from its relics: the sum of one of RelicDef's numbers (a
## common's twice under Reliquary).
func relic_sum(state: RunState, key: String) -> int:
	var total: int = 0
	for id: String in state.relics:
		if relics.has(id):
			total += int(relics[id].get(key)) * (2 if counts_twice(state, relics[id]) else 1)
	return total


func relic_rule(state: RunState, key: String) -> bool:
	return state.relics.any(func(id: String) -> bool: return relics.has(id) and bool(relics[id].get(key)))


func _claim(id: String, reader: DataReader, ids: Array[String]) -> bool:
	if id.is_empty():
		return false
	if ids.has(id):
		reader.error("duplicate id \"%s\"" % id)
		return false
	ids.append(id)
	return true


func _entries(data: Variant, file_name: String) -> Array[DataReader]:
	var readers: Array[DataReader] = []
	if data == null:
		return readers
	if typeof(data) != TYPE_ARRAY:
		errors.append("%s: expected a list of entries" % file_name)
		return readers
	var entries: Array = data
	for i: int in entries.size():
		var label: String = "%s[%d]" % [file_name, i]
		if typeof(entries[i]) == TYPE_DICTIONARY and typeof(entries[i].get("id")) == TYPE_STRING:
			label += " (%s)" % entries[i]["id"]
		var reader: DataReader = DataReader.from_value(entries[i], label, errors)
		if reader != null:
			readers.append(reader)
	return readers


func _read_items(data: Variant) -> void:
	for reader: DataReader in _entries(data, ITEMS_FILE):
		var item: ItemDef = ItemDef.read(reader)
		if item.id.is_empty():
			continue
		if items.has(item.id):
			reader.error("duplicate id \"%s\"" % item.id)
			continue
		items[item.id] = item
		item_ids.append(item.id)


func _read_upgrades(data: Variant) -> void:
	for reader: DataReader in _entries(data, UPGRADES_FILE):
		var upgrade: UpgradeDef = UpgradeDef.read(reader)
		if upgrade.id.is_empty():
			continue
		if upgrades.has(upgrade.id):
			reader.error("duplicate id \"%s\"" % upgrade.id)
			continue
		upgrades[upgrade.id] = upgrade
		upgrade_ids.append(upgrade.id)


func _check() -> void:
	if content == null:
		return
	if act != null:
		for day: int in range(1, act.days.size() + 1):
			if act.days[day - 1] == "normal" and encounters_for("easier", day).size() + encounters_for("harder", day).size() < 2:
				errors.append("%s: day %d needs at least two fights to offer" % [ACT_FILE, day])
	for path_id: String in content.path_ids:
		if content.paths[path_id].deed.threshold <= 0:
			errors.append("paths.json (%s): a run needs the deed's threshold" % path_id)
	for id: String in upgrade_ids:
		_check_upgrade(upgrades[id], "%s (%s)" % [UPGRADES_FILE, id])
	for hero_id: String in content.hero_ids:
		_check_all_upgrades(hero_id)
	for id: String in item_ids:
		_check_item(items[id], "%s (%s)" % [ITEMS_FILE, id])
		_check_icon(items[id].icon, "%s (%s)" % [ITEMS_FILE, id])
	var hero_kits: Array[UnitDef] = []
	for path_id: String in content.path_ids:
		hero_kits.append_array([content.paths[path_id].vowed_kit, content.paths[path_id].transformed_kit])
		hero_kits.append_array(content.paths[path_id].apex_kits())
	var enemy_kits: Array[UnitDef] = []
	for enemy_id: String in content.enemy_ids:
		enemy_kits.append(content.enemies[enemy_id].kit)
	for id: String in relic_ids:
		var relic: RelicDef = relics[id]
		_check_icon(relic.icon, "%s (%s)" % [RELICS_FILE, id])
		_check_mod(relic.mod, hero_kits, "%s (%s)" % [RELICS_FILE, id])
		_check_mod(relic.enemy_mod, enemy_kits, "%s (%s): enemy_mod" % [RELICS_FILE, id])
		for effect: EffectDef in relic.at_start:
			if effect.type == EffectDef.Type.APPLY_STATUS and not content.statuses.has(effect.status_id):
				errors.append("%s (%s): at_start: unknown status \"%s\"" % [RELICS_FILE, id, effect.status_id])
		if relic.grows != null and relic.grows.each.changes_anything():
			_check_mod(relic.grows.each.times(50), hero_kits, "%s (%s): grows" % [RELICS_FILE, id])
			if not relic.grows.counts.from_ability.is_empty():
				errors.append("%s (%s): a relic grows by what the whole team does, so it counts no hero's ability" % [RELICS_FILE, id])
	if camps != null:
		for option: CampsDef.Option in camps.options.values() + camps.nodes.values():
			if not ResourceLoader.exists(ART_UI + option.icon):
				errors.append("%s (%s): no icon art/ui/%s" % [CAMPS_FILE, option.id, option.icon])
		for place: CampsDef.Place in camps.places:
			if not ResourceLoader.exists(ART_UI + place.icon):
				errors.append("%s (%s): no icon art/ui/%s" % [CAMPS_FILE, place.id, place.icon])
		_check_mod(camps.fortify_mod, hero_kits, "%s: fortify_mod" % CAMPS_FILE)
		_check_mod(camps.rift_tear_mod, enemy_kits, "%s: rift_tear_mod" % CAMPS_FILE)
		for modifier_id: String in camps.modifier_ids:
			var modifier: CampsDef.Modifier = camps.modifiers[modifier_id]
			_check_mod(modifier.mod, enemy_kits, "%s: rift modifier %s" % [CAMPS_FILE, modifier_id])
			_check_mod(modifier.hero_mod, hero_kits, "%s: rift modifier %s" % [CAMPS_FILE, modifier_id])
			for mod: KitMod in [modifier.mod, modifier.hero_mod]:
				if mod == null or hero_kits.is_empty() or hero_kits[0] == null:
					continue
				for status_id: String in mod.apply(hero_kits[0]).status_ids():
					if not content.statuses.has(status_id):
						errors.append("%s: rift modifier %s: unknown status \"%s\"" % [CAMPS_FILE, modifier_id, status_id])
		if act != null:
			for day: int in range(1, act.days.size()):
				if act.days[day - 1] == "normal" and encounters_for("hunt", day).is_empty():
					errors.append("%s: day %d needs a hunt pack (an encounter of tier hunt)" % [CAMPS_FILE, day])
	if events != null:
		for key: String in events.next_fight_mods:
			_check_mod(events.next_fight_mods[key], hero_kits, "%s: next_fight_mods %s" % [EVENTS_FILE, key])
		for oath: EventDef.Oath in events.oaths:
			_check_mod(oath.mod, hero_kits, "%s (%s)" % [EVENTS_FILE, oath.id])
	for id: String in bond_ids:
		_check_bond(bonds[id], "%s (%s)" % [BONDS_FILE, id])
	for id: String in relic_ids:
		if relics[id].tier == RelicDef.Tier.BOND and not bond_ids.any(func(bond_id: String) -> bool: return bonds[bond_id].relic == id):
			errors.append("%s (%s): a bond relic needs its bond" % [RELICS_FILE, id])


## An icon's glyph must be in the art (docs/plans/rebuild-phase5b-art.md,
## section 5).
func _check_icon(icon: String, where: String) -> void:
	if not ResourceLoader.exists(GLYPHS % icon):
		errors.append("%s: no glyph \"%s\" in art/ui/items/glyphs/" % [where, icon])


## A mod must be sound on every kit it can meet.
func _check_mod(mod: KitMod, kits: Array[UnitDef], where: String) -> void:
	if mod == null:
		return
	for change: KitMod.AbilityChange in mod.changes:
		for status_id: String in change.statuses:
			if not content.statuses.has(status_id):
				errors.append("%s: unknown status \"%s\" in an \"on\" entry" % [where, status_id])
	for kit: UnitDef in kits:
		if kit == null:
			continue
		var problems: Array[String] = []
		mod.apply(kit, problems)
		for problem: String in problems:
			errors.append("%s: on %s, %s" % [where, kit.id, problem])


## A bond's two paths must exist and belong to two different heroes, and its
## relic must be a bond relic (phase 5c step 5d).
func _check_bond(bond: BondDef, where: String) -> void:
	if not relics.has(bond.relic):
		errors.append("%s: unknown relic \"%s\"" % [where, bond.relic])
	elif relics[bond.relic].tier != RelicDef.Tier.BOND:
		errors.append("%s: its relic \"%s\" must be of the bond tier" % [where, bond.relic])
	if bond.paths.size() != 2:
		return
	for path_id: String in bond.paths:
		if not content.paths.has(path_id):
			errors.append("%s: unknown path \"%s\"" % [where, path_id])
			return
	if content.paths[bond.paths[0]].hero == content.paths[bond.paths[1]].hero:
		errors.append("%s: a bond links two different heroes' paths" % where)


## A tactic item's tactic must exist; each rank's mod must be sound on every
## hero kit it can meet, and change something on some hero's (a check on the
## data, never shown to players).
func _check_item(item: ItemDef, where: String) -> void:
	if item.kind == ItemDef.Kind.TACTIC:
		if not content.tactics.has(item.tactic_id):
			errors.append("%s: unknown tactic \"%s\"" % [where, item.tactic_id])
			return
		item.tactic = content.tactics[item.tactic_id]
		return
	for rank: int in item.ranks.size():
		var mod: KitMod = item.ranks[rank]
		var works: bool = false
		for path_id: String in content.path_ids:
			var path: PathDef = content.paths[path_id]
			var kits: Array[UnitDef] = [path.vowed_kit, path.transformed_kit]
			kits.append_array(path.apex_kits())
			for kit: UnitDef in kits:
				if kit == null:
					continue
				var problems: Array[String] = []
				mod.apply(kit, problems)
				for problem: String in problems:
					errors.append("%s: rank %s on %s's kit, %s" % [where, ItemDef.RANK_NAMES[rank], path_id, problem])
				works = works or mod.affects(kit)
		if not works:
			errors.append("%s: rank %s does nothing on any hero" % [where, ItemDef.RANK_NAMES[rank]])


## An upgrade's hero or path must exist, and its mod must apply soundly to
## every kit it can meet: a hero card's, the vowed and transformed kits of
## every path (it must change at least one; Decision 37 keeps it from the
## pick where it changes nothing); a taste card's, its path's vowed kit and,
## with its transformed mod, the transformed one, changing both (Decision
## 35); a path card's, the transformed kit, changing it.
func _check_upgrade(upgrade: UpgradeDef, where: String) -> void:
	var meets: Array[Array] = []
	var must_change: bool = true
	if upgrade.layer == UpgradeDef.Layer.HERO:
		if not content.heroes.has(upgrade.hero):
			errors.append("%s: unknown hero \"%s\"" % [where, upgrade.hero])
			return
		must_change = false
		for path: PathDef in content.heroes[upgrade.hero].paths:
			meets.append([path.id + " vowed", path.vowed_kit, false])
			meets.append([path.id + " transformed", path.transformed_kit, true])
			for kit: UnitDef in path.apex_kits():
				meets.append([path.id + " apex", kit, true])
			_check_growth_counts(upgrade.grows, [path.vowed_kit, path.transformed_kit], where)
	else:
		if not content.paths.has(upgrade.path):
			errors.append("%s: unknown path \"%s\"" % [where, upgrade.path])
			return
		var path: PathDef = content.paths[upgrade.path]
		upgrade.hero = path.hero
		if upgrade.layer == UpgradeDef.Layer.TASTE:
			meets.append([path.id + " vowed", path.vowed_kit, false])
		meets.append([path.id + " transformed", path.transformed_kit, true])
		for kit: UnitDef in path.apex_kits():
			meets.append([path.id + " apex", kit, true])
		_check_growth_counts(upgrade.grows, [path.vowed_kit, path.transformed_kit] if upgrade.layer == UpgradeDef.Layer.TASTE else [path.transformed_kit], where)
	if upgrade.stacks():
		return
	var changes_any: bool = false
	for meet: Array in meets:
		var kit: UnitDef = meet[1]
		if kit == null:
			continue
		var transformed: bool = meet[2]
		var mods: Array[KitMod] = [upgrade.mod_for(transformed)]
		if upgrade.grows != null:
			# A growing card's step, many times over, on every kit it meets.
			mods.append(upgrade.grows.each.times(50))
		for mod: KitMod in mods:
			if mod == null:
				continue
			var problems: Array[String] = []
			mod.apply(kit, problems)
			for problem: String in problems:
				errors.append("%s: on %s, %s" % [where, meet[0], problem])
		var changes: bool = changes_something(upgrade, transformed, kit)
		changes_any = changes_any or changes
		if must_change and not changes:
			errors.append("%s: does nothing on %s" % [where, meet[0]])
	if not changes_any:
		errors.append("%s: does nothing on any of its hero's kits" % where)


## A growing card's counting names abilities its holder has (in one of
## `kits`).
func _check_growth_counts(growth: GrowthDef, kits: Array, where: String) -> void:
	if growth == null:
		return
	for ability_id: String in growth.counts.from_ability:
		var found: bool = false
		for kit: Variant in kits:
			if kit != null and (kit as UnitDef).ability_ids().has(ability_id):
				found = true
		if not found:
			errors.append("%s: grows by what \"%s\" does, which its hero doesn't have" % [where, ability_id])


## Every upgrade a hero could hold at once, on each path and stage, together.
func _check_all_upgrades(hero_id: String) -> void:
	for path: PathDef in content.heroes[hero_id].paths:
		for transformed: bool in [false, true]:
			var hero := RunState.Hero.new()
			hero.id = hero_id
			hero.path = path.id
			hero.transformed = transformed
			# Every card it could hold here: its own, and the path's taste
			# and path cards (a taste card carries on once transformed), a
			# stacking card taken twice.
			for id: String in upgrade_ids:
				var upgrade: UpgradeDef = upgrades[id]
				if upgrade.hero == hero_id and (upgrade.layer == UpgradeDef.Layer.HERO or upgrade.layer == UpgradeDef.Layer.TASTE and upgrade.path == path.id
						or upgrade.path == path.id and transformed):
					hero.upgrades.append(id)
					if upgrade.stacks():
						hero.upgrades.append(id)
						hero.locked[id] = [1, 1]
			var kit: UnitDef = path.transformed_kit if transformed else path.vowed_kit
			if kit == null:
				continue
			var problems: Array[String] = []
			for mod: KitMod in upgrade_mods(hero):
				kit = mod.apply(kit, problems)
			for problem: String in problems:
				errors.append("%s: %s's upgrades together on %s %s: %s" % [UPGRADES_FILE, hero_id, path.id, "transformed" if transformed else "vowed", problem])


func _parse(texts: Dictionary[String, String], file_name: String) -> Variant:
	if not texts.has(file_name):
		return null
	var json := JSON.new()
	if json.parse(texts[file_name]) != OK:
		errors.append("%s: invalid JSON at line %d: %s" % [file_name, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
