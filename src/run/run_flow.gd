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
## Deeds and wounds count from every fight, won or lost; a won fight (a tie,
## or a Hunt won, too) first heals one wound on each hero (the playtester,
## after gate 3: wounds should hurt a bad streak, not a run of wins).
## Winning the boss ends the run won.
## Growth (section 4 and 5): a hero whose vowed deed reaches its threshold
## transforms after that fight, won or lost, for good. Until then its vow can
## be switched between fights. A win offers a pick (Offers.pick): take one
## upgrade, or the act's pick_shards instead; the day can't move on while it
## waits.
## The economy (section 6): items owned wait in the stash; any hero equips
## any item in a free slot between fights (one tactic and one gambit each).
## A shop opens at camp (the Pedlar or the Magpie): buy its wares, treat a
## wound, or (the Pedlar only) reroll or sell an item back, or (the Magpie
## only) sell or swap a relic; leaving camp closes it. Phase 5c step 6: a run owns one of each item, at a rank; a
## bought copy is a rank up, and fights rank items up by their kind. A fight's kit is the path's,
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
			state.rested = true
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
			state.relic_choice = Offers.relics(run, state, RELIC_SHRINE, 1, "rare")
			state.relic_choice_price = run.act.shrine_price
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
## hero id -> the hexes of the snares it places (a transformed Trapper), or
## of its lantern (First Lantern, phase 5c step 7d).
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
	var ranked_tactics: Dictionary[String, TacticDef] = {}
	var wound_bp: int = content.tuning.wound_bp
	# Stand Together (phase 5c step 6d): the hero sharing its holder's hex
	# gets its gambit's mod too.
	var shared_mods: Dictionary[String, KitMod] = {}
	for hero: RunState.Hero in state.heroes:
		var gambit: KitMod = run.loadout_gambit(hero, state)
		if gambit == null or gambit.place_rule != "share" or not formation.has(hero.id):
			continue
		for other: RunState.Hero in state.heroes:
			if other != hero and formation.has(other.id) and formation[other.id] == formation[hero.id]:
				shared_mods[other.id] = gambit
	for hero: RunState.Hero in state.heroes:
		if not formation.has(hero.id):
			continue
		vows[hero.id] = hero.path
		if hero.transformed:
			transformed.append(hero.id)
		var mods: Array[KitMod] = run.upgrade_mods(hero)
		mods.append_array(run.loadout_mods(state, hero))
		mods.append_array(run.relic_mods(state, run.hero_kit(hero)))
		if shared_mods.has(hero.id):
			mods.append(shared_mods[hero.id])
		if not hunting and state.fortify:
			mods.append(run.camps.fortify_mod)
		var covenant: KitMod = _covenant_mod(hero, formation)
		if covenant != null:
			mods.append(covenant)
		extras[hero.id] = HeroExtras.make(mods, hero.wounds, wound_bp)
		var tallies: Array = run.growth_tallies(state, hero)
		extras[hero.id].tally_keys.assign(tallies[0])
		extras[hero.id].tally_counts.assign(tallies[1])
		var tactic: TacticDef = run.loadout_tactic(hero, state)
		if tactic != null:
			tactics[hero.id] = tactic.id
			ranked_tactics[hero.id] = tactic
	var setup: FightSetup = Encounters.setup(content, encounter_id, formation, fight_seed(), errors, tactics, vows, transformed, extras)
	if setup != null:
		for hero: UnitSetup in setup.heroes:
			if hero.def.placed_lantern and not snares.get(hero.id, []).is_empty():
				# First Lantern (phase 5c step 7d): its one marker.
				hero.lantern = snares[hero.id][0]
			elif hero.def.placed_snares > 0 and snares.has(hero.id):
				hero.snares.assign(snares[hero.id])
			# A tactic at its item's rank (phase 5c step 6c).
			if ranked_tactics.has(hero.id):
				hero.tactic = ranked_tactics[hero.id]
			# Switch Places at the moment the player chose (phase 5c step 6d).
			var chosen: int = state.hero(hero.id).gambit_at if state.hero(hero.id) != null else 0
			if chosen > 0 and hero.def.swap_choice:
				hero.swap_at = chosen * FixedMath.TICKS_PER_SECOND
		_modify_enemies(setup, hunting, errors)
		_relic_rules(setup)
		if not hunting and state.dig_in and state.rock.size() == 2:
			setup.rocks.append(Vector2i(state.rock[0], state.rock[1]))
		errors.append_array(setup.validate(content))
		for hero: RunState.Hero in state.heroes:
			if not formation.has(hero.id):
				errors.append("%s isn't placed" % hero.id)
	return setup if errors.is_empty() else null


## The relics' effects at the fight's start and Salt Circle (phase 5c step
## 5b), for the sim to run.
func _relic_rules(setup: FightSetup) -> void:
	for start: Array in run.relic_starts(state):
		var relic: RelicDef = start[0]
		setup.relic_effects.append(start[1])
		setup.relic_sources.append(EffectSource.relic(relic.id, relic.name, EffectSource.Team.HEROES))
		setup.relic_scales.append(start[2])
	for id: String in state.relics:
		if run.relics.has(id) and run.relics[id].salt_circle:
			setup.salt_circles += 2 if run.counts_twice(state, run.relics[id]) else 1
	setup.hero_rules = run.hero_rules(state)


## The Hollow Covenant (phase 5c step 5a): what `hero` needs added to reach
## the team's highest HP, ATK, MGK, DEF, CRIT, and attack speed (among the
## heroes placed), worked out from each kit as it stands between fights.
## Null without the relic, or with nothing to add.
func _covenant_mod(hero: RunState.Hero, formation: Dictionary[String, Vector2i]) -> KitMod:
	if not run.relic_rule(state, "covenant"):
		return null
	var mine: UnitStats = _kit_without_covenant(hero.id).stats
	var mod: KitMod = KitMod.make()
	for other: RunState.Hero in state.heroes:
		if not formation.has(other.id) or other == hero:
			continue
		var theirs: UnitStats = _kit_without_covenant(other.id).stats
		for stat: UnitStats.Stat in COVENANT_STATS:
			mod.stats_add[stat] = maxi(mod.stats_add[stat], theirs.get_stat(stat) - mine.get_stat(stat))
	return mod if mod.changes_anything() else null


const COVENANT_STATS: Array[UnitStats.Stat] = [UnitStats.Stat.HP, UnitStats.Stat.ATK, UnitStats.Stat.MGK, UnitStats.Stat.DEF, UnitStats.Stat.CRIT, UnitStats.Stat.ATSP]


func _kit_without_covenant(hero_id: String) -> UnitDef:
	return kit_of(hero_id, false)


## The kit `hero_id` fights with as things stand between fights: its path's
## at its stage, then its upgrades, loadout, relics, and bonds (camp's
## modifiers for the next fight aside). For showing, not for fights.
func kit_of(hero_id: String, with_covenant: bool = true) -> UnitDef:
	var hero: RunState.Hero = state.hero(hero_id)
	var kit: UnitDef = run.hero_kit(hero)
	var mods: Array[KitMod] = run.upgrade_mods(hero)
	mods.append_array(run.loadout_mods(state, hero))
	mods.append_array(run.relic_mods(state, kit))
	if with_covenant:
		var formation: Dictionary[String, Vector2i] = {}
		for other: RunState.Hero in state.heroes:
			formation[other.id] = Vector2i.ZERO
		var covenant: KitMod = _covenant_mod(hero, formation)
		if covenant != null:
			mods.append(covenant)
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


## Records a fought fight: the formation, deeds, wounds (a win heals one
## on each hero first, then each hero who fell takes one), transformations
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
	_grow(result)
	_rank_items(formation, result, won)
	if won:
		for hero: RunState.Hero in state.heroes:
			hero.wounds = maxi(hero.wounds - 1, 0)
	# A wound for each hero down at the fight's end (Decision 23: one Second
	# Dawn raised, standing at the end, takes none).
	for hero_id: String in result.down_at_end():
		var fallen: RunState.Hero = state.hero(hero_id)
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
		state.streak = 0
		state.losses += 1
		state.chosen = ""
		if state.losses >= run.act.losses_to_end:
			_end(RunState.Outcome.LOST)
		else:
			state.attempt += 1
			_arrive()
		return
	var tier: String = run.content.encounters[state.chosen].tier
	state.shards += run.act.pay[tier] + run.relic_sum(state, "pay_add") + (run.relic_sum(state, "elite_pay_add") if tier == "elite" else 0)
	_streak(result)
	if tier == "elite":
		_grow_by_run("elite_wins")
	state.phase = RunState.Phase.AFTER
	state.relic_choice_price = 0
	if run.act.days[state.day - 1] == "boss":
		# The boss relic choice (Decision 18), then the run's end (finish_day).
		state.relic_choice = Offers.relics(run, state, RELIC_AFTER_FIGHT, run.act.boss_relics, "boss")
		if state.relic_choice.is_empty():
			_end(RunState.Outcome.WON)
		return
	state.pick = _pick_cards(0)
	if tier == "elite":
		state.relic_choice = Offers.relics(run, state, RELIC_AFTER_FIGHT, 2, "rare", run.act.elite_epic_pct)
	elif torn:
		state.relic_choice = Offers.relics(run, state, RELIC_AFTER_FIGHT, 2, "rare")


## Bounty Board (phase 5c step 5a): a won day fight with no hero falling adds
## to the streak, anything else ends it; a streak relic pays once.
func _streak(result: FightResult) -> void:
	var fell: bool = result.combat_log.entries.any(func(entry: LogEntry) -> bool: return entry.kind == LogEntry.Kind.DEATH and state.hero(entry.target) != null)
	state.streak = 0 if fell else state.streak + 1
	for id: String in state.relics:
		var relic: RelicDef = run.relics.get(id)
		if relic != null and relic.streak_wins > 0 and state.streak >= relic.streak_wins and not state.streaks_paid.has(id):
			state.shards += relic.streak_shards
			state.streaks_paid.append(id)


## Adds one to every held relic that grows with what the run counts as
## `what` (Tally of the Dead: "elite_wins").
func _grow_by_run(what: String) -> void:
	for id: String in state.relics:
		var relic: RelicDef = run.relics.get(id)
		if relic == null or relic.grows == null or relic.grows.run_counts != what:
			continue
		var before: int = state.growth.get(id, 0)
		state.growth[id] = before + 1
		if relic.grows.steps(state.growth[id]) > relic.grows.steps(before) and not state.grew.has(":" + id):
			state.grew.append(":" + id)


## A pick's cards at `visit` (Widened Offering adds some), and how many of
## them to take (The Hollow Throne: 2).
func _pick_cards(visit: int) -> Array[String]:
	state.picks_left = 1 + run.relic_sum(state, "take_picks_add")
	return Offers.pick(run, state, visit, run.relic_sum(state, "pick_cards_add"))


# --- relics -----------------------------------------------------------------------

## Takes relic `index` of the waiting choice: it's the run's for good.
func take_relic(index: int) -> String:
	if state.relic_choice.is_empty():
		return "there's no relic choice waiting"
	if index < 0 or index >= state.relic_choice.size():
		return "there's no relic %d" % index
	if state.shards < state.relic_choice_price:
		return "it costs %d shards; there are %d" % [state.relic_choice_price, state.shards]
	state.shards -= state.relic_choice_price
	_gain_relic(state.relic_choice[index])
	state.relic_choice.clear()
	state.relic_choice_price = 0
	return ""


## Turns down the waiting relic choice.
func decline_relic() -> String:
	if state.relic_choice.is_empty():
		return "there's no relic choice waiting"
	state.relic_choice.clear()
	state.relic_choice_price = 0
	return ""


## Buys the open shop's relic `index`.
func buy_relic(index: int = 0) -> String:
	if state.shop.is_empty() or index < 0 or index >= state.shop_relics.size() or state.shop_relics[index].is_empty():
		return "there's no relic for sale"
	var price: int = relic_price(index)
	if state.shards < price:
		return "it costs %d shards; there are %d" % [price, state.shards]
	state.shards -= price
	_gain_relic(state.shop_relics[index])
	state.shop_relics[index] = ""
	return ""


## What the open shop's relic `index` costs: its tier's price (the Magpie's
## at his discount, rounded down), with the Pedlar's price_add.
func relic_price(index: int = 0) -> int:
	if index < 0 or index >= state.shop_relics.size() or state.shop_relics[index].is_empty():
		return 0
	var price: int = run.act.relic_prices[RelicDef.TIER_NAMES[run.relics[state.shop_relics[index]].tier]]
	if state.shop == "magpie":
		@warning_ignore("integer_division")
		return price * run.act.magpie_relic_pct / 100
	# A bond relic is free (phase 5c step 5d), whatever the prices.
	return 0 if price == 0 else _marked_up(price)


## What the Magpie pays for `relic_id` (its tier's relic_sell).
func relic_sell_price(relic_id: String) -> int:
	return run.act.relic_sell.get(RelicDef.TIER_NAMES[run.relics[relic_id].tier], 0)


## Sells a relic the run holds to the Magpie, the only one who buys them
## (phase 5c step 6e, magpie.md). What it counted is lost with it.
func sell_relic(relic_id: String) -> String:
	if state.shop != "magpie":
		return "only the Magpie buys relics"
	if not state.relics.has(relic_id):
		return "the run doesn't hold \"%s\"" % relic_id
	_lose_relic(relic_id)
	state.shards += relic_sell_price(relic_id)
	return ""


## The Magpie's swap, once a visit: `relic_id` for a relic of its tier the
## run doesn't hold, free.
func swap_relic(relic_id: String) -> String:
	if state.shop != "magpie":
		return "only the Magpie swaps relics"
	if state.magpie_swapped:
		return "he swaps once a visit"
	if not state.relics.has(relic_id):
		return "the run doesn't hold \"%s\"" % relic_id
	var other: String = Offers.magpie_swap(run, state, relic_id)
	if other.is_empty():
		return "he has nothing to swap for %s" % run.relics[relic_id].name
	_lose_relic(relic_id)
	_gain_relic(other)
	state.magpie_swapped = true
	return ""


## The run lets go of a relic: its growth goes, and a loadout slot it gave
## goes from each hero (what was in it back to the stash).
func _lose_relic(relic_id: String) -> void:
	state.relics.erase(relic_id)
	state.growth.erase(relic_id)
	for i: int in run.relics[relic_id].slots_add:
		for hero: RunState.Hero in state.heroes:
			var last: String = hero.slots.pop_back()
			if not last.is_empty():
				state.stash.append(last)


func _gain_relic(relic_id: String) -> void:
	state.relics.append(relic_id)
	if run.relics[relic_id].grows != null:
		state.growth[relic_id] = 0
	for i: int in run.relics[relic_id].slots_add:
		for hero: RunState.Hero in state.heroes:
			hero.slots.append("")


## Adds what a fight counted to the growing cards (phase 5c step 4; won or
## lost, a Hunt too), and notes the ones that stepped up (`grew`).
func _grow(result: FightResult) -> void:
	state.grew.clear()
	for hero: RunState.Hero in state.heroes:
		for upgrade: UpgradeDef in run.held_upgrades(hero):
			if upgrade.grows == null:
				continue
			var before: int = hero.growth.get(upgrade.id, 0)
			hero.growth[upgrade.id] = before + _faster(result.tally_amount(hero.id, "upgrade:" + upgrade.id))
			if upgrade.grows.steps(hero.growth[upgrade.id]) > upgrade.grows.steps(before):
				state.grew.append("%s:%s" % [hero.id, upgrade.id])
	for id: String in state.relics:
		var relic: RelicDef = run.relics.get(id)
		if relic == null or relic.grows == null or not relic.grows.counted_in_fights():
			continue
		var before: int = state.growth.get(id, 0)
		var counted: int = 0
		for hero: RunState.Hero in state.heroes:
			counted += result.tally_amount(hero.id, "relic:" + id)
		state.growth[id] = before + _faster(counted)
		var stepped: int = relic.grows.steps(state.growth[id]) - relic.grows.steps(before)
		if stepped > 0:
			state.grew.append(":" + id)
			state.shards += stepped * relic.grows.each_shards


## The loadout's ranks (phase 5c step 6): each item equipped on a hero who
## fought counts toward its next rank by its kind (ActDef.item_ranks):
## charms won fights, gambits fights, tactics the ms its hero stood, sigils
## its signature's casts (the last two from the fight's tallies). Reaching
## the need ranks it up; the count goes on from what's left over.
func _rank_items(formation: Dictionary[String, Vector2i], result: FightResult, won: bool) -> void:
	state.ranked.clear()
	for hero: RunState.Hero in state.heroes:
		if not formation.has(hero.id):
			continue
		for item_id: String in hero.slots:
			var item: ItemDef = run.items.get(item_id)
			if item == null or state.item_ranks.get(item_id, 1) >= ItemDef.RANKS:
				continue
			var counted: int = 0
			match item.kind:
				ItemDef.Kind.CHARM:
					counted = 1 if won else 0
				ItemDef.Kind.GAMBIT:
					counted = 1
				_:
					counted = result.tally_amount(hero.id, "item:" + item_id)
			if counted > 0:
				_count_item(item, counted)


func _count_item(item: ItemDef, counted: int) -> void:
	var needs: Array = run.act.item_ranks[ItemDef.KIND_NAMES[item.kind]]
	state.item_counts[item.id] = state.item_counts.get(item.id, 0) + counted
	while state.item_ranks.get(item.id, 1) < ItemDef.RANKS and state.item_counts[item.id] >= int(needs[state.item_ranks.get(item.id, 1) - 1]):
		state.item_counts[item.id] -= int(needs[state.item_ranks[item.id] - 1])
		state.item_ranks[item.id] += 1
		if not state.ranked.has(item.id):
			state.ranked.append(item.id)
	if state.item_ranks[item.id] >= ItemDef.RANKS:
		state.item_counts[item.id] = 0


## What `item_id` has counted toward its next rank, and what that rank needs
## (0 at rank III).
func rank_progress(item_id: String) -> Vector2i:
	var rank: int = state.item_ranks.get(item_id, 1)
	if rank >= ItemDef.RANKS or not run.items.has(item_id):
		return Vector2i(0, 0)
	var needs: Array = run.act.item_ranks[ItemDef.KIND_NAMES[run.items[item_id].kind]]
	return Vector2i(state.item_counts.get(item_id, 0), int(needs[rank - 1]))


## What's counted, made faster by Rift-Bound Heart's growth_bp while held.
func _faster(counted: int) -> int:
	for id: String in state.relics:
		if run.relics.has(id) and run.relics[id].growth_bp > 0:
			counted = FixedMath.apply_bp(counted, run.relics[id].growth_bp)
	return counted


## Takes card `index` of the waiting pick: the upgrade is its hero's for good
## (a stacking card locks in its amount now).
func take_pick(index: int) -> String:
	if state.pick.is_empty():
		return "there's no pick waiting"
	if index < 0 or index >= state.pick.size():
		return "there's no card %d" % index
	var upgrade: UpgradeDef = run.upgrades[state.pick[index]]
	var hero: RunState.Hero = state.hero(upgrade.hero)
	if upgrade.stacks():
		# Locked in from the hero's stat now (section 15.4).
		var amount: int = run.stack_amount(hero, upgrade)
		if not hero.locked.has(upgrade.id):
			hero.locked[upgrade.id] = []
		hero.locked[upgrade.id].append(amount)
	hero.upgrades.append(upgrade.id)
	if upgrade.grows != null:
		state.hero(upgrade.hero).growth[upgrade.id] = 0
	state.pick.remove_at(index)
	state.picks_left -= 1
	if state.picks_left <= 0:
		state.pick.clear()
	return ""


## Passes on the waiting pick for the act's pick_shards.
func take_shards() -> String:
	if state.pick.is_empty():
		return "there's no pick waiting"
	state.shards += run.act.pick_shards
	state.pick.clear()
	state.picks_left = 1
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
## whatever was there goes back to the stash. A hero holds one tactic and
## one gambit.
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
	var kind: ItemDef.Kind = run.items[item_id].kind
	if kind == ItemDef.Kind.TACTIC or kind == ItemDef.Kind.GAMBIT:
		for i: int in hero.slots.size():
			if i != slot and run.items.has(hero.slots[i]) and run.items[hero.slots[i]].kind == kind:
				return "%s already holds a %s" % [hero_id, ItemDef.KIND_NAMES[kind]]
	state.stash.erase(item_id)
	if not hero.slots[slot].is_empty():
		state.stash.append(hero.slots[slot])
	hero.slots[slot] = item_id
	return ""


## Switch Places at rank II (phase 5c step 6d): when `hero_id` swaps, 5, 10,
## or 15 seconds in.
func set_gambit_at(hero_id: String, seconds: int) -> String:
	var hero: RunState.Hero = state.hero(hero_id)
	if hero == null:
		return "unknown hero \"%s\"" % hero_id
	var gambit: KitMod = run.loadout_gambit(hero, state)
	if gambit == null or not gambit.swap_choice:
		return "%s holds no gambit whose moment it can choose" % hero_id
	if not GAMBIT_MOMENTS.has(seconds):
		return "it swaps at 5, 10, or 15 seconds"
	hero.gambit_at = seconds
	return ""


const GAMBIT_MOMENTS: Array[int] = [5, 10, 15]


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

## Opens a shop at camp ("pedlar" or "magpie"), its wares and relics drawn
## now (camp's option opens it; tests open one directly). Phase 5c step 5a:
## every shop shows a relic (more with shop_relics_add); the boss day's
## Pedlar is the pre-boss shop (a legendary first, rerolls from
## boss_reroll); the Magpie's are epic or legendary, one look. As a shop
## opens, the relics' shop_shards and miser pay.
func open_shop(kind: String) -> String:
	if state.phase != RunState.Phase.CAMP:
		return _not_now("open a shop")
	match kind:
		"pedlar":
			state.wares = Offers.pedlar(run, state, 0)
		"magpie":
			state.wares = Offers.magpie(run, state)
		_:
			return "there's no shop \"%s\"" % kind
	state.shop = kind
	state.rerolls = 0
	state.magpie_swapped = false
	state.shop_relics = _draw_shop_relics()
	state.shards += run.relic_sum(state, "shop_shards")
	if run.relic_rule(state, "miser"):
		@warning_ignore("integer_division")
		state.shards += mini(state.shards / 5, 6)
	return ""


func _draw_shop_relics() -> Array[String]:
	var count: int = 1 + run.relic_sum(state, "shop_relics_add") + (1 if pre_boss_shop() else 0)
	return Offers.shop_relics(run, state, state.rerolls, count, state.shop == "magpie", pre_boss_shop())


## True if the open shop is the pre-boss shop: the boss day's Pedlar.
func pre_boss_shop() -> bool:
	return state.shop == "pedlar" and state.day >= 1 and state.day <= run.act.days.size() and run.act.days[state.day - 1] == "boss"


func close_shop() -> void:
	state.shop = ""
	state.wares.clear()
	state.rerolls = 0
	state.shop_relics.clear()


## What ware `item_id` costs at the open shop: its kind's price at the
## Pedlar (with relics' price_add), the Magpie's charm price at his stall.
func price_of(item_id: String) -> int:
	if state.shop == "magpie":
		return run.act.magpie_charm_price
	return _marked_up(run.act.item_prices[ItemDef.KIND_NAMES[run.items[item_id].kind]])


## What the Pedlar pays for `item_id`: half its kind's price, rounded down,
## whatever its rank (loadout rule 9).
func sell_price(item_id: String) -> int:
	@warning_ignore("integer_division")
	return run.act.item_prices[ItemDef.KIND_NAMES[run.items[item_id].kind]] / 2


## Sells an item the run owns to the Pedlar, from the stash or a slot. Its
## rank goes with it.
func sell(item_id: String) -> String:
	if state.shop != "pedlar":
		return "only the Pedlar buys items"
	if not state.item_ranks.has(item_id):
		return "the run doesn't own \"%s\"" % item_id
	if state.stash.has(item_id):
		state.stash.erase(item_id)
	else:
		for hero: RunState.Hero in state.heroes:
			var slot: int = hero.slots.find(item_id)
			if slot >= 0:
				hero.slots[slot] = ""
	state.item_ranks.erase(item_id)
	state.item_counts.erase(item_id)
	state.shards += sell_price(item_id)
	return ""


## Gives the run `item_id` at `rank` (1 to 3): into the stash if it's new,
## else its owned copy a rank up (or to `rank`, if that's higher), its count
## starting again.
func _gain_item(item_id: String, rank: int = 1) -> void:
	if not state.item_ranks.has(item_id):
		state.stash.append(item_id)
		state.item_ranks[item_id] = rank
	else:
		state.item_ranks[item_id] = mini(maxi(state.item_ranks[item_id] + 1, rank), ItemDef.RANKS)
	state.item_counts[item_id] = 0


## A price at the Pedlar, with the relics' price_add (never below 1).
func _marked_up(price: int) -> int:
	return maxi(price + run.relic_sum(state, "price_add"), 1)


## Buys ware `index` into the stash, or, owned, a rank up (a bought copy
## skips a rank).
func buy(index: int) -> String:
	if state.shop.is_empty():
		return "no shop is open"
	if index < 0 or index >= state.wares.size() or state.wares[index].is_empty():
		return "there's no ware %d" % index
	var price: int = price_of(state.wares[index])
	if state.shards < price:
		return "it costs %d shards; there are %d" % [price, state.shards]
	state.shards -= price
	# The Magpie's charms come at rank II (phase 5c step 6e).
	_gain_item(state.wares[index], 2 if state.shop == "magpie" else 1)
	state.wares[index] = ""
	return ""


## What the open shop's next reroll costs (phase 5c step 5a): the first
## reroll_price (boss_reroll_price in the pre-boss shop), each after it 1
## more (flat_rerolls: never more); free_reroll makes the first free.
func reroll_price() -> int:
	if state.rerolls == 0 and run.relic_rule(state, "free_reroll"):
		return 0
	var base: int = run.act.boss_reroll_price if pre_boss_shop() else run.act.reroll_price
	return base + (0 if run.relic_rule(state, "flat_rerolls") else state.rerolls)


## The Pedlar lays out fresh wares and relics (Decision 19), for the next
## reroll's price. The Magpie is one look.
func reroll() -> String:
	if state.shop != "pedlar":
		return "only the Pedlar rerolls"
	var price: int = reroll_price()
	if state.shards < price:
		return "a reroll costs %d shards; there are %d" % [price, state.shards]
	state.shards -= price
	state.rerolls += 1
	state.wares = Offers.pedlar(run, state, state.rerolls)
	state.shop_relics = _draw_shop_relics()
	return ""


## What treating a wound costs (with wound_price_add, never below 0).
func wound_price() -> int:
	return maxi(run.act.wound_price + run.relic_sum(state, "wound_price_add"), 0)


## Treats one of `hero_id`'s wounds, wherever a shop is open.
func treat_wound(hero_id: String) -> String:
	if state.shop.is_empty():
		return "no shop is open"
	var hero: RunState.Hero = state.hero(hero_id)
	if hero == null:
		return "unknown hero \"%s\"" % hero_id
	if hero.wounds == 0:
		return "%s has no wounds" % hero_id
	if state.shards < wound_price():
		return "treating a wound costs %d shards; there are %d" % [wound_price(), state.shards]
	state.shards -= wound_price()
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
	if run.act.days[state.day - 1] == "boss":
		_end(RunState.Outcome.WON)
		return ""
	state.day += 1
	state.attempt = 0
	state.chosen = ""
	state.just_transformed.clear()
	state.grew.clear()
	_arrive()
	return ""


func _end(outcome: RunState.Outcome) -> void:
	state.outcome = outcome
	state.phase = RunState.Phase.ENDED


func _not_now(what: String) -> String:
	return "can't %s now (the day is at %s)" % [what, RunState.PHASE_NAMES[state.phase]]
