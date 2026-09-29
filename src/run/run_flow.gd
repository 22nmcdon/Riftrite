class_name RunFlow
extends RefCounted
## The run's rules (docs/plans/rebuild-phase5-run.md, sections 1 and 3): the
## only thing that changes a RunState, one action at a time. Each action
## checks it's legal now and returns "" if it happened, or why it didn't
## (the state is then untouched). The UI and the run bot both drive it.
## A day: camp, then the route (choose one of today's two fights), then the
## loadout and placement, then the fight (fight() runs it, CombatSim.run on
## fight_setup()'s setup), then after it. A win or a tie pays shards by the
## fight's tier and moves on to after the fight; a loss replays the day (camp
## again, the same options), and the act's losses_to_end-th ends the run.
## Deeds and wounds count from every fight, won or lost; winning the boss
## ends the run won.
## Growth (section 4 and 5): a hero whose vowed deed reaches its threshold
## transforms after that fight, won or lost, for good. Until then its vow can
## be switched between fights. A win offers a pick (Offers.pick): take one
## upgrade, or the act's pick_shards instead; the day can't move on while it
## waits.
## The economy (section 6): items owned wait in the stash; any hero equips
## any item in a free slot between fights (one tactic each). A shop opens at
## camp (the Pedlar or the Magpie): buy its wares, treat a wound, or (the
## Pedlar only) reroll; leaving camp closes it. A fight's kit is the path's,
## then its upgrades, then its loadout in slot order.

## Where a relic choice happens (its stream's visit).
const RELIC_SHRINE: int = 0
const RELIC_AFTER_FIGHT: int = 1
const RELIC_SHOP: int = 2

var run: RunContent
var state: RunState


## A new run from `run_seed`, each hero vowed to one of its own paths
## (`vows`: hero id -> path id, every hero). Null with the reasons in
## `errors` if the vows aren't right.
static func start(run_content: RunContent, run_seed: int, vows: Dictionary[String, String], errors: Array[String]) -> RunFlow:
	var content: ContentDb = run_content.content
	for hero_id: String in content.hero_ids:
		if not vows.has(hero_id):
			errors.append("%s needs a vow" % hero_id)
		elif not content.paths.has(vows[hero_id]) or content.paths[vows[hero_id]].hero != hero_id:
			errors.append("%s can't vow to \"%s\"" % [hero_id, vows[hero_id]])
	for hero_id: String in vows:
		if not content.heroes.has(hero_id):
			errors.append("unknown hero \"%s\"" % hero_id)
	if not errors.is_empty():
		return null
	var state := RunState.new()
	state.seed_value = run_seed
	state.act = run_content.act.act
	state.shards = run_content.act.start_shards
	for hero_id: String in content.hero_ids:
		var hero := RunState.Hero.new()
		hero.id = hero_id
		hero.path = vows[hero_id]
		for path: PathDef in content.heroes[hero_id].paths:
			hero.deeds[path.id] = 0
		for i: int in run_content.act.slots:
			hero.slots.append("")
		state.heroes.append(hero)
	state.options = ActDraw.draw(run_content, run_seed)
	state.magpie_day = Offers.magpie_day(run_content, run_seed, state.act)
	var flow: RunFlow = resume(run_content, state)
	flow._arrive()
	return flow


## A flow over a state already made (a loaded save).
static func resume(run_content: RunContent, run_state: RunState) -> RunFlow:
	var flow := RunFlow.new()
	flow.run = run_content
	flow.state = run_state
	return flow


# --- camp -------------------------------------------------------------------------

## Arrives at camp (a new day, or a day replayed): the place and its options
## are drawn; on the Magpie's day (its first try), he's the only option.
func _arrive() -> void:
	state.phase = RunState.Phase.CAMP
	state.camp_used = ""
	state.hunt = ""
	state.mapping = false
	if state.day == state.magpie_day and state.attempt == 0:
		state.place = ""
		state.camp.assign(["magpie"])
		return
	var drawn: Array = Offers.camp(run, state)
	state.place = drawn[0]
	state.camp.assign(drawn[1])


## Takes camp option `index` (one a camp). What it does is its one job:
## train (a pick), hunt (a pack to fight now), pedlar and magpie (a shop),
## rest (clears wounds), scout (the next 2 days), map_the_rift (then
## swap_fight), fortify, dig_in (then place_rock), rift_tear (for the next
## fight), shrine (a relic choice).
func choose_camp(index: int) -> String:
	if state.phase != RunState.Phase.CAMP:
		return _not_now("choose a camp option")
	if not state.camp_used.is_empty():
		return "camp's option is already taken today (%s)" % state.camp_used
	if index < 0 or index >= state.camp.size():
		return "there's no camp option %d" % index
	var option: String = state.camp[index]
	match option:
		"train":
			state.pick = _pick_cards(1)
		"hunt":
			state.hunt = Offers.hunt(run, state)
			if state.hunt.is_empty():
				return "there's no pack to hunt today"
		"pedlar", "magpie":
			open_shop(option)
		"rest":
			for hero: RunState.Hero in state.heroes:
				hero.wounds = 0
			state.rested = state.relics.any(func(id: String) -> bool: return run.relics.has(id) and run.relics[id].rest_mod != null)
		"scout":
			for day: int in [state.day + 1, state.day + 2]:
				if day <= run.act.days.size() and not state.scouted.has(day):
					state.scouted.append(day)
		"map_the_rift":
			if state.day >= run.act.days.size() or run.act.days[state.day] == "boss":
				return "there's no fight tomorrow to swap"
			state.mapping = true
		"fortify":
			state.fortify = true
		"dig_in":
			state.dig_in = true
		"rift_tear":
			state.rift_tear = true
		"shrine":
			state.relic_choice = Offers.relics(run, state, RELIC_SHRINE, 2)
	state.camp_used = option
	return ""


## Map the Rift: swaps tomorrow's fight `index` for another of its tier.
func swap_fight(index: int) -> String:
	if not state.mapping:
		return "Map the Rift isn't waiting"
	var tomorrow: Array = state.options[state.day]
	if index < 0 or index >= tomorrow.size():
		return "there's no fight %d tomorrow" % index
	var swapped: String = Offers.swap(run, state, index)
	if swapped.is_empty():
		return "there's no other fight to swap in"
	tomorrow[index] = swapped
	state.mapping = false
	return ""


## Dig In: the rock's hex for the next fight, in the heroes' zone.
func place_rock(hex: Vector2i) -> String:
	if not state.dig_in:
		return "Dig In wasn't taken"
	if state.phase == RunState.Phase.ENDED:
		return _not_now("place a rock")
	var grid: HexGrid = run.content.tuning.make_grid()
	if not grid.has(hex.x, hex.y) or grid.zone(hex.y) != HexGrid.Zone.HEROES:
		return "a rock goes on a hex in your zone"
	state.rock.assign([hex.x, hex.y])
	return ""


## Leaves camp, once nothing there is waiting.
func leave_camp() -> String:
	if state.phase != RunState.Phase.CAMP:
		return _not_now("leave camp")
	var waiting: String = _camp_waiting()
	if not waiting.is_empty():
		return waiting
	close_shop()
	state.phase = RunState.Phase.ROUTE
	return ""


func _camp_waiting() -> String:
	if not state.pick.is_empty():
		return "choose an upgrade or take the shards first"
	if not state.relic_choice.is_empty():
		return "choose a relic or neither first"
	if not state.hunt.is_empty():
		return "fight the Hunt first"
	if state.mapping:
		return "choose which fight to swap first"
	return ""


# --- the day ---------------------------------------------------------------------

## Chooses today's fight: `index` into today's options.
func choose_fight(index: int) -> String:
	if state.phase != RunState.Phase.ROUTE:
		return _not_now("choose a fight")
	var options: Array[String] = state.today()
	if index < 0 or index >= options.size():
		return "there's no fight %d today" % index
	state.chosen = options[index]
	state.phase = RunState.Phase.LOADOUT
	return ""


## The fight waiting now: a Hunt's pack at camp, or the day's chosen fight
## at the loadout ("" if neither).
func fight_encounter() -> String:
	if state.phase == RunState.Phase.CAMP and not state.hunt.is_empty():
		return state.hunt
	if state.phase == RunState.Phase.LOADOUT:
		return state.chosen
	return ""


## The waiting fight from `formation` (hero id -> hex), with every hero as the
## run has it, or null with the reasons in `errors`. A hero's kit is its
## path's at its stage, then its upgrades, its loadout (slot order), the
## relics, the day's camp modifiers (Fortify, a steadying Rest), and its duo
## bonds. Enemies take the relics' enemy mods and a Rift Tear's; Dig In's
## rock joins the encounter's. A Hunt takes no camp modifiers. `snares`:
## hero id -> the hexes of the snares it places (a transformed Trapper).
func fight_setup(formation: Dictionary[String, Vector2i], errors: Array[String], snares: Dictionary[String, Array] = {}) -> FightSetup:
	var encounter_id: String = fight_encounter()
	if encounter_id.is_empty():
		errors.append(_not_now("fight"))
		return null
	var hunting: bool = encounter_id == state.hunt
	var content: ContentDb = run.content
	var vows: Dictionary[String, String] = {}
	var transformed: Array[String] = []
	var extras: Dictionary[String, HeroExtras] = {}
	var tactics: Dictionary[String, String] = {}
	var bonds: Array[BondDef] = run.active_bonds(state)
	var wound_bp: int = content.tuning.wound_bp + run.relic_sum(state, "wound_bp_add")
	for hero: RunState.Hero in state.heroes:
		if not formation.has(hero.id):
			continue
		vows[hero.id] = hero.path
		if hero.transformed:
			transformed.append(hero.id)
		var mods: Array[KitMod] = run.upgrade_mods(hero)
		mods.append_array(run.loadout_mods(hero))
		mods.append_array(run.relic_mods(state))
		if not hunting:
			if state.fortify:
				mods.append(run.camps.fortify_mod)
			if state.rested:
				for id: String in state.relics:
					if run.relics[id].rest_mod != null:
						mods.append(run.relics[id].rest_mod)
		for bond: BondDef in bonds:
			if bond.mods.has(hero.path):
				mods.append(bond.mods[hero.path])
		extras[hero.id] = HeroExtras.make(mods, hero.wounds, wound_bp)
		var tactic: TacticDef = run.loadout_tactic(hero)
		if tactic != null:
			tactics[hero.id] = tactic.id
	var setup: FightSetup = Encounters.setup(content, encounter_id, formation, fight_seed(), errors, tactics, vows, transformed, extras)
	if setup != null:
		for hero: UnitSetup in setup.heroes:
			if hero.def.placed_snares > 0 and snares.has(hero.id):
				hero.snares.assign(snares[hero.id])
		_modify_enemies(setup, hunting, errors)
		if not hunting and state.dig_in and state.rock.size() == 2:
			setup.rocks.append(Vector2i(state.rock[0], state.rock[1]))
		errors.append_array(setup.validate(content))
		for hero: RunState.Hero in state.heroes:
			if not formation.has(hero.id):
				errors.append("%s isn't placed" % hero.id)
	return setup if errors.is_empty() else null


## The kit `hero_id` fights with as things stand between fights: its path's
## at its stage, then its upgrades, loadout, relics, and bonds (camp's
## modifiers for the next fight aside). For showing, not for fights.
func kit_of(hero_id: String) -> UnitDef:
	var hero: RunState.Hero = state.hero(hero_id)
	var kit: UnitDef = run.hero_kit(hero)
	var mods: Array[KitMod] = run.upgrade_mods(hero)
	mods.append_array(run.loadout_mods(hero))
	mods.append_array(run.relic_mods(state))
	for bond: BondDef in run.active_bonds(state):
		if bond.mods.has(hero.path):
			mods.append(bond.mods[hero.path])
	for mod: KitMod in mods:
		kit = mod.apply(kit)
	return kit


## Every enemy and summon kit takes the relics' enemy mods, and a Rift
## Tear's upgrade (not on a Hunt).
func _modify_enemies(setup: FightSetup, hunting: bool, errors: Array[String]) -> void:
	var mods: Array[KitMod] = []
	for id: String in state.relics:
		if run.relics[id].enemy_mod != null:
			mods.append(run.relics[id].enemy_mod)
	if state.rift_tear and not hunting:
		mods.append(run.camps.rift_tear_mod)
	if mods.is_empty():
		return
	var problems: Array[String] = []
	for enemy: UnitSetup in setup.enemies:
		for mod: KitMod in mods:
			enemy.def = mod.apply(enemy.def, problems)
	for i: int in setup.summon_kits.size():
		for mod: KitMod in mods:
			setup.summon_kits[i] = mod.apply(setup.summon_kits[i], problems)
	for problem: String in problems:
		errors.append("an enemy upgrade leaves a kit unsound: %s" % problem)


## The seed of the waiting fight (this attempt's; a Hunt has its own).
func fight_seed() -> int:
	var what: int = RunRandom.HUNT if fight_encounter() == state.hunt and not state.hunt.is_empty() else RunRandom.FIGHT
	return RunRandom.stream(state.seed_value, [what, state.act, state.day, state.attempt]).range_int(1 << 30) + 1


## Fights the waiting fight from `formation` and records it. Returns the
## result, or null with the reasons in `errors`.
func fight(formation: Dictionary[String, Vector2i], errors: Array[String], snares: Dictionary[String, Array] = {}) -> FightResult:
	var setup: FightSetup = fight_setup(formation, errors, snares)
	if setup == null:
		return null
	var result: FightResult = CombatSim.run(setup, run.content)
	record(formation, result)
	return result


## Records a fought fight: the formation, deeds, wounds, transformations
## (and bonds found), then the outcome. A Hunt pays its shards on a win and
## is done, won or lost (its loss isn't a loss). The day's fight: a win pays
## by its tier (plus relics), offers the pick, and (an elite, or a Rift
## Tear) a relic choice; a loss replays the day, or ends the run. Either way
## the day's camp modifiers are spent. fight() calls it; tests call it with
## a result of their own.
func record(formation: Dictionary[String, Vector2i], result: FightResult) -> void:
	var hunting: bool = fight_encounter() == state.hunt and not state.hunt.is_empty()
	var encounter_id: String = state.hunt if hunting else state.chosen
	var won: bool = result.outcome != FightResult.Outcome.DEFEAT
	state.formation = formation.duplicate()
	state.just_transformed.clear()
	var fought := RunState.Fought.new()
	fought.day = state.day
	fought.attempt = state.attempt
	fought.encounter = encounter_id
	fought.outcome = result.outcome
	@warning_ignore("integer_division")
	fought.seconds = result.end_tick / FixedMath.TICKS_PER_SECOND
	state.fought.append(fought)
	for hero: RunState.Hero in state.heroes:
		for path_id: String in hero.deeds:
			hero.deeds[path_id] += result.deed_amount(hero.id, path_id)
	for entry: LogEntry in result.combat_log.entries:
		if entry.kind == LogEntry.Kind.DEATH:
			var fallen: RunState.Hero = state.hero(entry.target)
			if fallen != null:
				fallen.wounds = mini(fallen.wounds + 1, run.content.tuning.max_wounds)
	for hero: RunState.Hero in state.heroes:
		if not hero.transformed and hero.deeds.get(hero.path, 0) >= run.content.paths[hero.path].deed.threshold:
			hero.transformed = true
			state.just_transformed.append(hero.id)
	for bond: BondDef in run.active_bonds(state):
		if not state.bonds_found.has(bond.id):
			state.bonds_found.append(bond.id)
	if hunting:
		state.hunt = ""
		if won:
			state.shards += run.act.pay["hunt"]
		return
	var torn: bool = state.rift_tear
	state.fortify = false
	state.dig_in = false
	state.rock.clear()
	state.rift_tear = false
	state.rested = false
	if not won:
		state.losses += 1
		state.chosen = ""
		if state.losses >= run.act.losses_to_end:
			_end(RunState.Outcome.LOST)
		else:
			state.attempt += 1
			_arrive()
		return
	var tier: String = run.content.encounters[state.chosen].tier
	state.shards += run.act.pay[tier] + run.relic_sum(state, "pay_add")
	if run.act.days[state.day - 1] == "boss":
		_end(RunState.Outcome.WON)
		return
	state.phase = RunState.Phase.AFTER
	state.pick = _pick_cards(0)
	if tier == "elite" or torn:
		state.relic_choice = Offers.relics(run, state, RELIC_AFTER_FIGHT, 2)


## A pick's cards at `visit`, as many as the relics allow.
func _pick_cards(visit: int) -> Array[String]:
	var cards: Array[String] = Offers.pick(run, state, visit)
	for id: String in state.relics:
		var most: int = run.relics[id].pick_cards
		if most > 0 and cards.size() > most:
			cards.resize(most)
	return cards


# --- relics -----------------------------------------------------------------------

## Takes relic `index` of the waiting choice: it's the run's for good.
func take_relic(index: int) -> String:
	if state.relic_choice.is_empty():
		return "there's no relic choice waiting"
	if index < 0 or index >= state.relic_choice.size():
		return "there's no relic %d" % index
	_gain_relic(state.relic_choice[index])
	state.relic_choice.clear()
	return ""


## Turns down the waiting relic choice.
func decline_relic() -> String:
	if state.relic_choice.is_empty():
		return "there's no relic choice waiting"
	state.relic_choice.clear()
	return ""


## Buys the open shop's relic.
func buy_relic() -> String:
	if state.shop.is_empty() or state.shop_relic.is_empty():
		return "there's no relic for sale"
	var price: int = relic_price()
	if state.shards < price:
		return "it costs %d shards; there are %d" % [price, state.shards]
	state.shards -= price
	_gain_relic(state.shop_relic)
	state.shop_relic = ""
	return ""


## What the open shop's relic costs.
func relic_price() -> int:
	return _marked_up(run.act.relic_price)


func _gain_relic(relic_id: String) -> void:
	state.relics.append(relic_id)
	for i: int in run.relics[relic_id].slots_add:
		for hero: RunState.Hero in state.heroes:
			hero.slots.append("")


## Takes card `index` of the waiting pick: the upgrade is its hero's for good.
func take_pick(index: int) -> String:
	if state.pick.is_empty():
		return "there's no pick waiting"
	if index < 0 or index >= state.pick.size():
		return "there's no card %d" % index
	var upgrade: UpgradeDef = run.upgrades[state.pick[index]]
	state.hero(upgrade.hero).upgrades.append(upgrade.id)
	state.pick.clear()
	return ""


## Passes on the waiting pick for the act's pick_shards.
func take_shards() -> String:
	if state.pick.is_empty():
		return "there's no pick waiting"
	state.shards += run.act.pick_shards
	state.pick.clear()
	return ""


## Switches `hero_id`'s vow to another of its paths, between fights, until it
## transforms. Every path's deed keeps what it had.
func switch_vow(hero_id: String, path_id: String) -> String:
	if state.phase == RunState.Phase.ENDED:
		return _not_now("switch a vow")
	var hero: RunState.Hero = state.hero(hero_id)
	if hero == null:
		return "unknown hero \"%s\"" % hero_id
	if hero.transformed:
		return "%s has transformed, so the vow is set" % hero_id
	if not hero.deeds.has(path_id):
		return "%s can't vow to \"%s\"" % [hero_id, path_id]
	if hero.path == path_id:
		return "%s is already vowed to %s" % [hero_id, path_id]
	hero.path = path_id
	return ""


# --- the loadout ------------------------------------------------------------------

## Puts `item_id` from the stash into `hero_id`'s slot `slot`, between fights;
## whatever was there goes back to the stash. A hero holds one tactic.
func equip(hero_id: String, slot: int, item_id: String) -> String:
	if state.phase == RunState.Phase.ENDED:
		return _not_now("change a loadout")
	var hero: RunState.Hero = state.hero(hero_id)
	if hero == null:
		return "unknown hero \"%s\"" % hero_id
	if slot < 0 or slot >= hero.slots.size():
		return "%s has no slot %d" % [hero_id, slot]
	if not state.stash.has(item_id):
		return "\"%s\" isn't in the stash" % item_id
	if run.items[item_id].kind == ItemDef.Kind.TACTIC:
		for i: int in hero.slots.size():
			if i != slot and run.items.has(hero.slots[i]) and run.items[hero.slots[i]].kind == ItemDef.Kind.TACTIC:
				return "%s already holds a tactic" % hero_id
	state.stash.erase(item_id)
	if not hero.slots[slot].is_empty():
		state.stash.append(hero.slots[slot])
	hero.slots[slot] = item_id
	return ""


## Takes what's in `hero_id`'s slot `slot` back to the stash.
func unequip(hero_id: String, slot: int) -> String:
	if state.phase == RunState.Phase.ENDED:
		return _not_now("change a loadout")
	var hero: RunState.Hero = state.hero(hero_id)
	if hero == null:
		return "unknown hero \"%s\"" % hero_id
	if slot < 0 or slot >= hero.slots.size() or hero.slots[slot].is_empty():
		return "%s has nothing in slot %d" % [hero_id, slot]
	state.stash.append(hero.slots[slot])
	hero.slots[slot] = ""
	return ""


# --- shops ------------------------------------------------------------------------

## Opens a shop at camp ("pedlar" or "magpie"), its wares drawn now (camp's
## option opens it; tests open one directly). The Pedlar now and then, and
## the Magpie always, also sells a relic.
func open_shop(kind: String) -> String:
	if state.phase != RunState.Phase.CAMP:
		return _not_now("open a shop")
	state.shop_relic = ""
	match kind:
		"pedlar":
			state.wares = Offers.pedlar(run, state, 0)
			if RunRandom.stream(state.seed_value, [RunRandom.PEDLAR, state.act, state.day, state.attempt, -1]).range_int(100) < run.camps.pedlar_relic_pct:
				state.shop_relic = _first(Offers.relics(run, state, RELIC_SHOP, 1))
		"magpie":
			state.wares = Offers.magpie(run, state)
			state.shop_relic = _first(Offers.relics(run, state, RELIC_SHOP, 1))
		_:
			return "there's no shop \"%s\"" % kind
	state.shop = kind
	state.rerolls = 0
	return ""


static func _first(ids: Array[String]) -> String:
	return ids[0] if not ids.is_empty() else ""


func close_shop() -> void:
	state.shop = ""
	state.wares.clear()
	state.rerolls = 0
	state.shop_relic = ""


## What ware `item_id` costs at the open shop (the Magpie's markup, rounded up).
func price_of(item_id: String) -> int:
	return _marked_up(run.items[item_id].price)


## A price at the open shop: the Magpie's markup (rounded up), or the
## Pedlar's, with the relics' price_add.
func _marked_up(price: int) -> int:
	if state.shop == "magpie":
		@warning_ignore("integer_division")
		return (price * run.act.magpie_markup_pct + 99) / 100
	return price + run.relic_sum(state, "price_add")


## Buys ware `index` into the stash.
func buy(index: int) -> String:
	if state.shop.is_empty():
		return "no shop is open"
	if index < 0 or index >= state.wares.size() or state.wares[index].is_empty():
		return "there's no ware %d" % index
	var price: int = price_of(state.wares[index])
	if state.shards < price:
		return "it costs %d shards; there are %d" % [price, state.shards]
	state.shards -= price
	state.stash.append(state.wares[index])
	state.wares[index] = ""
	return ""


## The Pedlar lays out a fresh set, for the act's reroll price.
func reroll() -> String:
	if state.shop != "pedlar":
		return "only the Pedlar rerolls"
	if state.shards < run.act.reroll_price:
		return "a reroll costs %d shards; there are %d" % [run.act.reroll_price, state.shards]
	state.shards -= run.act.reroll_price
	state.rerolls += 1
	state.wares = Offers.pedlar(run, state, state.rerolls)
	return ""


## Treats one of `hero_id`'s wounds, wherever a shop is open.
func treat_wound(hero_id: String) -> String:
	if state.shop.is_empty():
		return "no shop is open"
	var hero: RunState.Hero = state.hero(hero_id)
	if hero == null:
		return "unknown hero \"%s\"" % hero_id
	if hero.wounds == 0:
		return "%s has no wounds" % hero_id
	if state.shards < run.act.wound_price:
		return "treating a wound costs %d shards; there are %d" % [run.act.wound_price, state.shards]
	state.shards -= run.act.wound_price
	hero.wounds -= 1
	return ""


## Moves on to the next day's camp once nothing is waiting after the fight.
func finish_day() -> String:
	if state.phase != RunState.Phase.AFTER:
		return _not_now("move on to the next day")
	if not state.pick.is_empty():
		return "choose an upgrade or take the shards first"
	if not state.relic_choice.is_empty():
		return "choose a relic or neither first"
	state.day += 1
	state.attempt = 0
	state.chosen = ""
	state.just_transformed.clear()
	_arrive()
	return ""


func _end(outcome: RunState.Outcome) -> void:
	state.outcome = outcome
	state.phase = RunState.Phase.ENDED


func _not_now(what: String) -> String:
	return "can't %s now (the day is at %s)" % [what, RunState.PHASE_NAMES[state.phase]]
