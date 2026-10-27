class_name EffectHits
extends RefCounted
## Putting a number on a unit, for EffectRunner (the damage rule, DamageRule;
## docs/plans/phases/rebuild-phase5c-combos.md, section 4): a hit through
## crits, DEF, and Shields with its log line, the heroes' crit and echo rules
## (Crown of Stars, Shared Pain, The Hungering Rift), lifesteal and Engorge,
## heals and overheal, Shields given and spent, max HP gained and given up,
## and stored damage let go (the clean-up, docs/plans/phases/cleanup-and-layout.md).


## Lands a hit of `amount` (its base) on `target`: the damage rule (its
## `power`, plus a tactic's payoff; the crit's; the target's Mark), then
## DEF, then Shield, then HP. Logs it and returns what got through DEF.
## (heal's `ceiling`, phase 8 part 6: HP it may lift to at most, the rest a
## Shield; -1: max HP.)
## `steals`: false for a hit that never lifesteals (Shadow Engine's strike,
## which comes from lifesteal). `note` says what made it, if not an ability.
## `ruled`: a hit a hero rule made (an echo, a carry), which starts no echo
## or carry of its own (phase 5c step 5c). `steal_bp`: the hit's own
## lifesteal share, added to the attacker's (phase 8 part 5, Rend).
## An execution (phase 8 part 2): a target the hit left standing below
## `below_bp` of its max HP loses the rest of its HP, past any Shield or
## DEF, logged as a DAMAGE line noted "executed" from the same source. The
## fall itself is the deaths step's, as for any other hit.
static func execute(sim: CombatSim, source: EffectSource, victim: UnitState, below_bp: int) -> void:
	if victim.hp <= 0 or victim.hp * FixedMath.BP_ONE >= below_bp * victim.max_hp:
		return
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.DAMAGE, source)
	entry.note = "executed"
	entry.target = victim.id
	entry.amount = victim.hp
	entry.set_rule(victim.hp, 0, 0, 0, 0)
	victim.hp = 0
	victim.executed = true
	victim.last_hit_chain = entry.chain
	victim.last_hit_source = source
	victim.last_hit_status = ""
	if source.relic_side < 0 and source.unit_id != victim.id:
		victim.last_attacker = source.unit_id
	sim.combat_log.add(entry)


static func deal_hit(sim: CombatSim, source: EffectSource, target: UnitState, amount: int, crit: bool, power: int = 0, steals: bool = true, note: String = "", ruled: bool = false, pierces: bool = false, steal_bp: int = 0) -> int:
	sim.last_dodged = false
	# Sidestep (phase 5c step 6b): a hit on it misses, then not again for a
	# while. Logged as DODGED; nothing else of the hit happens.
	if target.aura_bp[AuraDef.Stat.DODGE_EVERY_MS] > 0 and sim.tick >= target.dodge_ready_at:
		target.dodge_ready_at = sim.tick + maxi(FixedMath.ms_to_ticks(target.aura_bp[AuraDef.Stat.DODGE_EVERY_MS]), 1)
		var dodged: LogEntry = sim.new_entry(LogEntry.Kind.DODGED, source)
		dodged.target = target.id
		sim.combat_log.add(dodged)
		sim.last_dodged = true
		return 0
	# Dazzled (phase 8 part 3, the Dazzling Moth): its basic attack's hits
	# miss a share of the time, rolled on the fight's seeded RNG. Logged as
	# DODGED, noted "missed".
	if source.relic_side < 0 and not source.unit_id.is_empty():
		var striker: UnitState = sim.unit_by_id(source.unit_id)
		if striker != null and striker.aura_bp[AuraDef.Stat.MISS_BP] > 0 and source.ability_id == striker.def.basic_attack.id \
				and sim.rng.roll_bp(striker.aura_bp[AuraDef.Stat.MISS_BP]):
			var missed: LogEntry = sim.new_entry(LogEntry.Kind.DODGED, source)
			missed.target = target.id
			missed.note = "missed"
			sim.combat_log.add(missed)
			sim.last_dodged = true
			return 0
		# Evasive (phase 8 part 4, Tamsin's card): a basic attack's hits on it
		# miss a share of the time. Logged as DODGED, noted "evaded".
		if striker != null and target.aura_bp[AuraDef.Stat.EVADE_BP] > 0 and source.ability_id == striker.def.basic_attack.id \
				and sim.rng.roll_bp(target.aura_bp[AuraDef.Stat.EVADE_BP]):
			var evaded: LogEntry = sim.new_entry(LogEntry.Kind.DODGED, source)
			evaded.target = target.id
			evaded.note = "evaded"
			sim.combat_log.add(evaded)
			sim.last_dodged = true
			return 0
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.DAMAGE, source)
	entry.note = note
	if sim.damage_payoffs:
		var payoff: int = Tactics.damage_bonus_bp(sim, source, target)
		if payoff > 0:
			power += payoff
			entry.bonus = Tactics.bonus_note(payoff, sim.unit_by_id(source.unit_id).tactic)
	var attacker: UnitState = sim.unit_by_id(source.unit_id) if source.relic_side < 0 else null
	if attacker != null and source.ability_id == attacker.def.basic_attack.id:
		# A basic attack's hit from Stealth (phase 8 part 6, Veilweaver): the
		# hit and its striker carry it (UnitCondition's struck_from_stealth).
		entry.from_stealth = sim.shot_from_stealth or (not attacker.statuses.is_empty() and Statuses.is_stealthed(attacker))
		attacker.struck_from_stealth = entry.from_stealth
	var per_hit: bool = sim.vs_auras and attacker != null and not attacker.vs_conditions.is_empty()
	if per_hit:
		power += Passives.vs_bonus_bp(attacker, target, AuraDef.Stat.DAMAGE_BP, source.ability_id)
	# Dulled Shackles (the tuning phase, T-1): a Rooted or Stunned enemy's hits
	# are weaker, and stay so a while after the hold ends.
	if attacker != null and sim.hero_rules.held_weak_bp > 0 and attacker.side != EffectSource.Team.HEROES and target.side == EffectSource.Team.HEROES \
			and (SideRules.is_held(attacker) or attacker.hold_ended_at >= 0 and sim.tick - attacker.hold_ended_at <= sim.hero_rules.held_weak_ticks):
		power -= sim.hero_rules.held_weak_bp
		entry.note = ("%s, " % entry.note if not entry.note.is_empty() else "") + "dulled"
	var marked: int = Statuses.damage_taken_bp(target)
	# Crit damage bonuses (phase 5c step 5b) add to the crit's own +50%.
	var crit_bp: int = sim.tuning.crit_damage_bp - FixedMath.BP_ONE + (attacker.aura_bp[AuraDef.Stat.CRIT_DAMAGE_BP] if attacker != null else 0) if crit else 0
	if crit and attacker != null:
		crit_bp += _more_crit_damage(sim, attacker, target, source, per_hit)
	var heroes_hit: bool = attacker != null and attacker.side == EffectSource.Team.HEROES and target.side != EffectSource.Team.HEROES
	entry.crits = 1 if crit else 0
	if crit and heroes_hit and sim.hero_rules.crit_steps > 0:
		crit_bp = _crit_chain(sim, attacker, target, source, crit_bp, entry)
	var raw: int = DamageRule.apply(amount, power, crit_bp, marked, attacker.relic_bonus_bp if attacker != null else 0)
	entry.set_rule(amount, power, crit_bp, marked, attacker.relic_bonus_bp if attacker != null else 0)
	# Iron Skin (phase 5c step 6b): its first hits taken land at half.
	if target.hits_halved < target.aura_bp[AuraDef.Stat.HALVED_HITS]:
		target.hits_halved += 1
		raw = FixedMath.apply_bp(raw, 5000)
		entry.note = ("%s, " % entry.note if not entry.note.is_empty() else "") + "halved"
	# Guard (phase 4): an ally's guard takes its share of the hit, against its
	# own DEF.
	var guard: UnitState = Guards.covering(sim, source, target) if not sim.guards.is_empty() else null
	var guarded_raw: int = FixedMath.apply_bp(raw, guard.guard.share_bp) if guard != null else 0
	var ignore_bp: int = 0
	if attacker != null:
		ignore_bp = attacker.aura_bp[AuraDef.Stat.DEF_IGNORE_BP] + (Tactics.def_ignore_bp(attacker, target) if attacker.tactic != null else 0)
	if pierces:
		# A hit that ignores DEF (phase 8 part 4, Bitter Blood).
		ignore_bp = FixedMath.BP_ONE
	var dealt: int = sim.mitigate_hit(target, raw - guarded_raw, ignore_bp)
	var guarded: int = sim.mitigate_hit(guard, guarded_raw) if guard != null else 0
	entry.target = target.id
	entry.mitigated = maxi(raw - guarded_raw - dealt, 0)
	entry.amount = dealt
	if per_hit and not attacker.bonus_parts.is_empty() and dealt > 0:
		# What one passive's auras added (phase 8 part 6, Catalyst's deed):
		# its share of the hit's power bonus.
		var part_bp: int = Passives.vs_bonus_bp(attacker, target, AuraDef.Stat.DAMAGE_BP, source.ability_id, attacker.bonus_parts)
		if part_bp > 0:
			# Its share, with the fraction of a point carried to the next hit
			# (phase 8 part 6: Pack Call's 3% of a small bite).
			attacker.part_bonus_rest += FixedMath.mul_div(dealt * FixedMath.BP_ONE, part_bp, DamageRule.factor(power))
			@warning_ignore("integer_division")
			entry.part_bonus = attacker.part_bonus_rest / FixedMath.BP_ONE
			attacker.part_bonus_rest %= FixedMath.BP_ONE
	entry.crit = crit
	var had_shield: bool = target.shield > 0
	var hp_before: int = target.hp
	# Linked Shields (phase 8 part 2): its link spreads part of the hit over
	# its other linked allies first (SHARED lines, logged before this one's).
	if not sim.linkers.is_empty() and target.woven_by != null:
		var kept: int = Links.split(sim, target, dealt, source)
		if kept != dealt:
			entry.note = ("%s, " % entry.note if not entry.note.is_empty() else "") + "shared"
			dealt = kept
			entry.amount = dealt
	# Vengeance (phase 8 part 4): a share of the hit is stored instead of
	# taken, to be released later.
	if target.aura_bp[AuraDef.Stat.STORE_BP] > 0 and dealt > 0:
		var stored: int = FixedMath.apply_bp(dealt, mini(target.aura_bp[AuraDef.Stat.STORE_BP], FixedMath.BP_ONE))
		if stored > 0:
			target.stored += stored
			sim.any_stored = true
			dealt -= stored
			entry.amount = dealt
			entry.note = ("%s, " % entry.note if not entry.note.is_empty() else "") + "%d stored" % stored
	# Shieldbreaker and the Unbinder (phase 8 part 3): more off a Shield.
	var vs_shield_bp: int = FixedMath.BP_ONE + (attacker.aura_bp[AuraDef.Stat.SHIELD_DAMAGE_BP] if attacker != null else 0)
	entry.absorbed = sim.apply_damage_vs_shield(target, dealt, vs_shield_bp)
	entry.broke_shield = had_shield and target.shield == 0
	# What went past the target's last HP (phase 5c step 5b; Overkill Tithe).
	entry.overkill = maxi(dealt - entry.absorbed - hp_before, 0)
	sim.last_overkill = entry.overkill
	target.last_hit_chain = entry.chain
	target.last_hit_source = source
	target.last_hit_status = ""
	if source.relic_side < 0 and source.unit_id != target.id:
		target.last_attacker = source.unit_id
	sim.combat_log.add(entry)
	if guarded > 0:
		Guards.take(sim, guard, target, guarded, source)
	# A tactic's first hit on each enemy, and a crit stretching a Mark (phase
	# 5c step 6c).
	if sim.damage_payoffs and attacker != null and attacker.tactic != null and Tactics.own_hit(attacker, source):
		Tactics.on_hit(sim, attacker, target, crit)
	if steals and attacker != null and (sim.lifesteal or steal_bp > 0) and dealt > 0 and attacker.side != target.side:
		lifesteal(sim, attacker, target, dealt, source, steal_bp)
	if heroes_hit and not ruled:
		var overkill: int = entry.overkill
		if sim.hero_rules.echo_steps > 0 and dealt > 0:
			_echo(sim, attacker, target, dealt, source)
		if sim.hero_rules.carry_steps > 0 and overkill > 0:
			_carry(sim, attacker, target, overkill, source)
	return dealt


## Crown of Stars (the heroes' rule crit_chain; phase 5c step 5c): a crit
## rolls again, the k-th extra roll at the crit chance times (100% − fade·k)
## and adding the crit bonus times as much (under Chain of Echoes, times
## growth_bp(k) instead), until one misses or the steps run out. Returns the
## crit kind's bonus with the extra crits; the entry counts them.
static func _crit_chain(sim: CombatSim, attacker: UnitState, target: UnitState, source: EffectSource, crit_bp: int, entry: LogEntry) -> int:
	var rules: SideRules = sim.hero_rules
	var chance: int = attacker.stats.get_stat(UnitStats.Stat.CRIT) * sim.tuning.crit_bp_per_point + attacker.aura_bp[AuraDef.Stat.CRIT_CHANCE_BP]
	if not attacker.vs_conditions.is_empty():
		chance += Passives.vs_bonus_bp(attacker, target, AuraDef.Stat.CRIT_CHANCE_BP, source.ability_id)
	var total: int = crit_bp
	for k: int in range(1, rules.crit_steps + rules.deeper_steps + 1):
		var factor: int = rules.growth_bp(k) if rules.deeper_steps > 0 else FixedMath.BP_ONE - rules.crit_fade_bp * k
		if factor <= 0 or not sim.rng.roll_bp(FixedMath.apply_bp(chance, factor)):
			break
		total += FixedMath.apply_bp(crit_bp, factor)
		entry.crits += 1
	return total


## Shared Pain (echo_keywords): `dealt` on `target` echoes to every other
## standing enemy with the keyword the most of them share with it (ties to
## Keywords' order), at share_bp (compounded each step; under Chain of
## Echoes, growth_bp instead), and each echo echoes on, each enemy hit once a
## step, one chain step deeper each.
static func _echo(sim: CombatSim, attacker: UnitState, target: UnitState, dealt: int, source: EffectSource) -> void:
	var rules: SideRules = sim.hero_rules
	var foes: Array[UnitState] = []
	foes.assign(sim.standing_enemies_of(attacker).filter(func(unit: UnitState) -> bool: return unit.hp > 0))
	var keyword: String = ""
	var most: int = 0
	for name: String in Keywords.NAMES:
		if not Keywords.has(target, name):
			continue
		var sharing: int = foes.filter(func(unit: UnitState) -> bool: return unit != target and Keywords.has(unit, name)).size()
		if sharing > most:
			most = sharing
			keyword = name
	if keyword.is_empty():
		return
	var outer: int = sim.chain_depth
	var share: int = FixedMath.BP_ONE
	var last: Array[UnitState] = [target]
	for step: int in range(1, rules.echo_steps + rules.deeper_steps + 1):
		share = rules.growth_bp(step) if rules.deeper_steps > 0 else FixedMath.apply_bp(share, rules.echo_share_bp)
		var amount: int = FixedMath.apply_bp(dealt, share)
		if amount <= 0:
			break
		var hit: Array[UnitState] = []
		for foe: UnitState in sim.standing_enemies_of(attacker):
			if foe.hp > 0 and Keywords.has(foe, keyword) and last.any(func(echoer: UnitState) -> bool: return echoer != foe):
				hit.append(foe)
		if hit.is_empty():
			break
		sim.chain_depth = outer + step
		for foe: UnitState in hit:
			deal_hit(sim, source, foe, amount, false, 0, true, "Shared Pain", true)
		last = hit
	sim.chain_depth = outer


## The Hungering Rift (carry_overkill): `overkill` past `fallen`'s last HP
## hits the standing enemy nearest it, and that hit's overkill carries on,
## up to the steps (each carry ×growth_bp(1) under Chain of Echoes).
static func _carry(sim: CombatSim, attacker: UnitState, fallen: UnitState, overkill: int, source: EffectSource) -> void:
	var rules: SideRules = sim.hero_rules
	var outer: int = sim.chain_depth
	var from: UnitState = fallen
	var amount: int = overkill
	for step: int in range(1, rules.carry_steps + rules.deeper_steps + 1):
		var next: UnitState = null
		var best: int = -1
		for foe: UnitState in sim.standing_enemies_of(attacker):
			if foe == from or foe.hp <= 0:
				continue
			var distance_sq: int = ArenaPlane.length_sq(foe.pos - from.pos)
			if best < 0 or distance_sq < best:
				best = distance_sq
				next = foe
		if next == null or amount <= 0:
			break
		if rules.deeper_steps > 0:
			amount = FixedMath.apply_bp(amount, rules.growth_bp(1))
		sim.chain_depth = outer + step
		deal_hit(sim, source, next, amount, false, 0, true, "carried (The Hungering Rift)", true)
		amount = sim.last_overkill
		from = next
	sim.chain_depth = outer


## What a crit by `attacker` adds to crit damage beyond its auras (phase 5c
## step 5c): per-hit crit damage (Hunter's Engine, per Mark stack), and its
## crit chance past 100% times its crit_overflow_bp (Knife's Edge; the
## chance from CRIT and its crit-chance auras).
static func _more_crit_damage(sim: CombatSim, attacker: UnitState, target: UnitState, source: EffectSource, per_hit: bool) -> int:
	var more: int = Passives.vs_bonus_bp(attacker, target, AuraDef.Stat.CRIT_DAMAGE_BP, source.ability_id) if per_hit else 0
	var overflow: int = attacker.aura_bp[AuraDef.Stat.CRIT_OVERFLOW_BP]
	if overflow > 0:
		var chance: int = attacker.stats.get_stat(UnitStats.Stat.CRIT) * sim.tuning.crit_bp_per_point + attacker.aura_bp[AuraDef.Stat.CRIT_CHANCE_BP]
		if chance > FixedMath.BP_ONE:
			more += FixedMath.apply_bp(chance - FixedMath.BP_ONE, overflow)
	return more


## The attacker heals its lifesteal's share of a hit's `dealt` damage (phase
## 5c step 5b): its own line (LIFESTEAL), not a heal, so nothing that reacts
## to healing sees it (relics/README rule 5; Decision 21). Phase 5c step 5c:
## with lifesteal_heals (Blood Communion) it's a heal instead (a HEAL line
## marked lifesteal: heal power, healing taken, on_heal, and overheal to
## Shield all see it); and with overheal_strike_bp (Shadow Engine) what it
## would heal past full HP hits the attacker's target for that share.
## `extra_bp`: the hit's own share (a damage effect's lifesteal_pct). Phase 8
## part 5 (Hemophage): lifesteal_more_bp multiplies the whole share (+100%
## doubles it), its per-hit "vs" counting against `target`.
static func lifesteal(sim: CombatSim, attacker: UnitState, target: UnitState, dealt: int, source: EffectSource, extra_bp: int = 0) -> void:
	var share: int = attacker.aura_bp[AuraDef.Stat.LIFESTEAL_BP] + extra_bp
	var more: int = attacker.aura_bp[AuraDef.Stat.LIFESTEAL_MORE_BP]
	if not attacker.vs_conditions.is_empty():
		share += Passives.vs_bonus_bp(attacker, target, AuraDef.Stat.LIFESTEAL_BP, source.ability_id)
		more += Passives.vs_bonus_bp(attacker, target, AuraDef.Stat.LIFESTEAL_MORE_BP, source.ability_id)
	if more != 0:
		share = FixedMath.apply_bp(share, maxi(FixedMath.BP_ONE + more, 0))
	if share <= 0 or not attacker.alive:
		return
	steal(sim, attacker, FixedMath.apply_bp(dealt, share), source)


## `attacker` lifesteals `wanted` HP: a LIFESTEAL line (or a heal, with
## lifesteal_heals), what's past full HP to Engorge, and the overheal strike.
static func steal(sim: CombatSim, attacker: UnitState, wanted: int, source: EffectSource) -> void:
	if wanted <= 0 or not attacker.alive or attacker.hp <= 0:
		return
	var overheal: int
	if attacker.aura_bp[AuraDef.Stat.LIFESTEAL_HEALS] > 0:
		overheal = heal(sim, attacker, wanted, source, 0, attacker.aura_bp[AuraDef.Stat.HEAL_BP] - FixedMath.BP_ONE, true)
	else:
		var healed: int = clampi(wanted, 0, attacker.max_hp - attacker.hp)
		overheal = wanted - healed
		if healed > 0:
			attacker.hp += healed
			var entry: LogEntry = sim.new_entry(LogEntry.Kind.LIFESTEAL, source)
			entry.target = attacker.id
			entry.amount = healed
			sim.combat_log.add(entry)
	if overheal > 0 and attacker.aura_bp[AuraDef.Stat.LIFESTEAL_MAX_HP_BP] > 0:
		_engorge(sim, attacker, overheal)
	# The strike is one chain step deeper, and none comes at the chain limit:
	# a strike's hit can echo (Shared Pain), and the echo's lifesteal strike
	# again, so without the guard the two would call each other forever.
	var strike: int = attacker.aura_bp[AuraDef.Stat.OVERHEAL_STRIKE_BP]
	if strike > 0 and overheal > 0 and attacker.target != null and attacker.target.alive and attacker.target.side != attacker.side \
			and sim.chain_depth < sim.chain_limit_of(attacker.id, -1):
		var outer: int = sim.chain_depth
		sim.chain_depth = outer + 1
		deal_hit(sim, source, attacker.target, FixedMath.apply_bp(overheal, strike), false, 0, false, "overheal from lifesteal")
		sim.chain_depth = outer


## Heals `target` (capped at its max HP), logs it, and if any HP came back,
## weakens its damage over time. The first heal in a window strips
## heal_cleanse_bp of each damage-over-time status; each further heal within
## heal_cleanse_window strips that share times heal_cleanse_falloff_bp again
## (by default 10%, 5%, 2.5%, ...), so rapid small heals can't wipe it out.
## `overheal_shield_bp`: what the heal would have restored past full HP comes
## back as that share of Shield (phase 4, Ward Thread).
## `amount` is the heal's base: the damage rule applies its `power` and the
## target's healing taken (the target's side, like a Mark on damage).
## The healer's overheal_shield_bp aura (Overflow Chalice; phase 5c step 5c)
## adds to the heal's own share. `by_lifesteal` marks lifesteal that heals
## (Blood Communion). Returns what it would have restored past full HP.
## `relic_bp`: the relic kind's bonus (Chain of Echoes' growth).
static func heal(sim: CombatSim, target: UnitState, amount: int, source: EffectSource, overheal_shield_bp: int = 0, power: int = 0, by_lifesteal: bool = false, relic_bp: int = 0,
		ceiling: int = -1) -> int:
	var base: int = amount
	var taken_bp: int = target.aura_bp[AuraDef.Stat.HEALING_TAKEN_BP] - FixedMath.BP_ONE
	amount = DamageRule.apply(amount, power, 0, taken_bp, relic_bp)
	var healed: int = clampi(target.max_hp - target.hp, 0, amount)
	# A unit brought to 0 HP this tick falls in the deaths step: no heal in
	# the same tick lifts it back (rebuild-phase1-arena-sim.md, deaths; found
	# in phase 8 part 6 with Hell Hide).
	var downed: bool = target.hp <= 0
	if downed:
		healed = 0
	elif ceiling >= 0:
		# A capped heal (phase 8 part 6, Lantern Vigil): what it would lift past
		# the cap is a Shield, all of it.
		healed = clampi(ceiling - target.hp, 0, amount)
		if amount > healed:
			overheal_shield_bp = maxi(overheal_shield_bp, FixedMath.BP_ONE)
	target.hp += healed
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.HEAL, source)
	entry.set_rule(base, power, 0, taken_bp, relic_bp)
	entry.target = target.id
	entry.amount = healed
	entry.lifesteal = by_lifesteal
	sim.combat_log.add(entry)
	if sim.overheal_auras and source.relic_side < 0:
		var healer: UnitState = sim.unit_by_id(source.unit_id)
		if healer != null:
			overheal_shield_bp += healer.aura_bp[AuraDef.Stat.OVERHEAL_SHIELD_BP]
	if overheal_shield_bp > 0 and amount > healed and not downed:
		var shield: int = FixedMath.apply_bp(amount - healed, overheal_shield_bp)
		if shield > 0:
			give_shield(sim, target, shield, source)
	if healed <= 0:
		return amount - healed
	var window_start: int = sim.tick - sim.tuning.heal_cleanse_window_ticks
	while not target.recent_heal_ticks.is_empty() and target.recent_heal_ticks[0] <= window_start:
		target.recent_heal_ticks.remove_at(0)
	var share_bp: int = sim.tuning.heal_cleanse_bp
	for i: int in target.recent_heal_ticks.size():
		share_bp = FixedMath.apply_bp(share_bp, sim.tuning.heal_cleanse_falloff_bp)
	target.recent_heal_ticks.append(sim.tick)
	if not target.statuses.is_empty():
		Statuses.cleanse_over_time(sim, target, share_bp, source, true)
	return amount - healed


## Engorge (phase 8 part 5): lifesteal_max_hp_bp of what `unit`'s lifesteal
## would have healed past full becomes max HP and HP, for the fight, up to
## lifesteal_max_hp_cap_bp of its max HP before any of it (0: no cap). The
## MAX_HP_UP line is sourced to the passive that holds the aura.
static func _engorge(sim: CombatSim, unit: UnitState, overheal: int) -> void:
	var gain: int = FixedMath.apply_bp(overheal, unit.aura_bp[AuraDef.Stat.LIFESTEAL_MAX_HP_BP])
	var cap_bp: int = unit.aura_bp[AuraDef.Stat.LIFESTEAL_MAX_HP_CAP_BP]
	if cap_bp > 0:
		gain = mini(gain, FixedMath.apply_bp(unit.base_max_hp - unit.engorged, cap_bp) - unit.engorged)
	if gain <= 0 or not unit.alive or unit.hp <= 0:
		return
	unit.engorged += gain
	unit.base_max_hp += gain
	unit.max_hp += gain
	unit.hp += gain
	var part_id: String = ""
	var part_name: String = ""
	for part: PartDef in unit.def.passives:
		if part.kind == PartDef.Kind.AURA and part.aura.stat == AuraDef.Stat.LIFESTEAL_MAX_HP_BP:
			part_id = part.id
			part_name = part.name
			break
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.MAX_HP_UP, EffectSource.make(unit.id, part_id, part_name))
	entry.target = unit.id
	entry.amount = gain
	sim.combat_log.add(entry)


## `unit` banks `overheal` and gains +1 max HP (and HP) for every `per` of
## it, for the fight (phase 8 part 2, The Hearthkeeper; MAX_HP_UP).
static func grow_max_hp(sim: CombatSim, unit: UnitState, overheal: int, per: int, source: EffectSource) -> void:
	unit.overheal_bank += overheal
	@warning_ignore("integer_division")
	var gain: int = unit.overheal_bank / per
	if gain <= 0 or not unit.alive or unit.hp <= 0:
		return
	unit.overheal_bank -= gain * per
	unit.base_max_hp += gain
	unit.max_hp += gain
	unit.hp += gain
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.MAX_HP_UP, source)
	entry.target = unit.id
	entry.amount = gain
	sim.combat_log.add(entry)


## `unit`'s whole Shield is spent (phase 8 part 4, Bulwark Burst): logged
## as SHIELD_SPENT with what it was; nothing if it has none.
static func spend_shield(sim: CombatSim, unit: UnitState, source: EffectSource, keep_bp: int = 0) -> void:
	if unit.shield <= 0:
		return
	# Shatterburst keeps a share (phase 8 part 4).
	var kept: int = FixedMath.apply_bp(unit.shield, keep_bp) if keep_bp > 0 else 0
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.SHIELD_SPENT, source)
	entry.target = unit.id
	entry.amount = unit.shield - kept
	if kept > 0:
		entry.note = "keeps %d" % kept
	unit.shield = kept
	sim.combat_log.add(entry)


## `unit` gains `amount` max HP and HP for the fight (phase 8 part 5, The
## Iron Maw), logged as MAX_HP_UP.
static func gain_max_hp(sim: CombatSim, unit: UnitState, amount: int, source: EffectSource) -> void:
	if amount <= 0 or not unit.alive or unit.hp <= 0:
		return
	unit.base_max_hp += amount
	unit.max_hp += amount
	unit.hp += amount
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.MAX_HP_UP, source)
	entry.target = unit.id
	entry.amount = amount
	sim.combat_log.add(entry)


## `unit` gives up the max HP (and HP) Engorge added to it (phase 8 part 5,
## Sanguine Nova), logged as MAX_HP_DOWN with how much; nothing if it has
## none. Its HP comes down to its max HP if it's above it.
static func spend_engorged(sim: CombatSim, unit: UnitState, source: EffectSource) -> void:
	if unit.engorged <= 0:
		return
	var lost: int = unit.engorged
	unit.engorged = 0
	unit.base_max_hp = maxi(unit.base_max_hp - lost, 1)
	unit.max_hp = maxi(unit.max_hp - lost, 1)
	unit.hp = mini(unit.hp, unit.max_hp)
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.MAX_HP_DOWN, source)
	entry.target = unit.id
	entry.amount = lost
	sim.combat_log.add(entry)


## The damage `unit` stored is let go (phase 8 part 4, Vengeance), logged as
## RELEASED with what it had grown to; nothing if it stored none.
static func release_stored(sim: CombatSim, unit: UnitState, source: EffectSource) -> void:
	if unit.stored <= 0:
		return
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.RELEASED, source)
	entry.target = unit.id
	entry.amount = unit.stored
	unit.stored = 0
	sim.combat_log.add(entry)


static func give_shield(sim: CombatSim, target: UnitState, amount: int, source: EffectSource) -> LogEntry:
	target.shield += amount
	# A Shield from a unit with a link links its holder (phase 8 part 2).
	if not sim.linkers.is_empty() and amount > 0 and source.relic_side < 0:
		var giver: UnitState = sim.unit_by_id(source.unit_id)
		if giver != null and giver.link != null and giver.side == target.side:
			target.woven_by = giver
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.SHIELD, source)
	entry.target = target.id
	entry.amount = amount
	entry.shield_after = target.shield
	sim.combat_log.add(entry)
	return entry
