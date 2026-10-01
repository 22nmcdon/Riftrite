class_name SideRules
extends RefCounted
## Rules of the fight one side plays by (phase 5c step 5c,
## docs/plans/rebuild-phase5c-combos.md, section 12.2): the heroes' relics
## rewrite them ("rules" in data/relics.json; RunContent merges the run's
## into FightSetup.hero_rules). Each rule is code (CLAUDE.md rule 3: said in
## the plan), with its numbers in the data. A fight with none never reaches
## a rule's code, so it's the fight it was.
##   "marks_stack": true        a Mark a hero applies stacks as it refreshes
##                              (Hunter's Engine; StatusState.stacks)
##   "crit_chain": {"steps": 10, "fade_bp": 500}   a hero's crit rolls again,
##                              each step's chance and bonus 5% less (Crown of
##                              Stars)
##   "echo_keywords": {"share_bp": 9000, "steps": 3}   a hero's hit echoes to
##                              the other enemies sharing a keyword (Shared Pain)
##   "carry_overkill": {"steps": 8}   a hero's overkill carries to the nearest
##                              enemy (The Hungering Rift)
##   "overcharge": {"power_bp": 2500, "steps": 8}   mana past a full bar
##                              fires the signature again (Overcharge)
##   "second_dawn": {"after_ms": 5000, "hp_bp": 5000}   a hero's first fall
##                              rises again (Second Dawn)
##   "deeper_chains": {"steps": 4, "grow_bp": 1500}   the heroes' chains go
##                              deeper and grow each step (Chain of Echoes)
##   "keywords_twice": true     keywords heroes apply go on twice (Crown of the
##                              Hollow King)
##   "keywords_last": true      keywords heroes put on enemies never end
##                              (Everflame)
##   "unbending": {"def_bp": 100, "max_hp_bp": 100}   statuses enemies apply
##                              to heroes are blocked, each a stack of
##                              `unbending` (The Unbending; the numbers are
##                              the status's, shown on the card)
##   "collapse": {"immune": true, "enemy_max_hp_bp": 500}   crumbled ground
##                              spares heroes and hurts enemies more
##                              (Riftwalker's Soles)
##   "long_watch": {"from_ms": 60000, "every_ms": 10000, "tie_ms": 300000}
##                              no 180s tie; heroes grow every 10s from 60s
##                              (The Long Watch)

var marks_stack: bool = false
## crit_chain: extra rolls (0: off) and how much each step fades.
var crit_steps: int = 0
var crit_fade_bp: int = 0
## echo_keywords: each step's share of the hit before (0: off) and steps.
var echo_share_bp: int = 0
var echo_steps: int = 0
## carry_overkill: how many carries (0: off).
var carry_steps: int = 0
## overcharge: each extra fire's power more than the last (0: off), and
## how many extra fires.
var overcharge_power_bp: int = 0
var overcharge_steps: int = 0
## second_dawn: ticks until the rise (0: off), and the HP it rises with.
var rise_ticks: int = 0
var rise_hp_bp: int = 0
## deeper_chains: steps deeper (0: off), and how much each step grows.
var deeper_steps: int = 0
var deeper_grow_bp: int = 0
var keywords_twice: bool = false
var keywords_last: bool = false
var unbending: bool = false
var unbending_def_bp: int = 0
var unbending_max_hp_bp: int = 0
var collapse_immune: bool = false
var collapse_enemy_bp: int = 0
## long_watch: from when and how often heroes grow (0: off), and the tie.
var watch_from_ticks: int = 0
var watch_every_ticks: int = 0
var watch_tie_ticks: int = 0


static func read(reader: DataReader) -> SideRules:
	var rules := SideRules.new()
	rules.marks_stack = reader.opt_bool("marks_stack", false)
	var part: DataReader = _part(reader, "crit_chain")
	if part != null:
		rules.crit_steps = part.req_int("steps", 1, 50)
		rules.crit_fade_bp = part.req_int("fade_bp", 0, 1000)
		part.finish()
	part = _part(reader, "echo_keywords")
	if part != null:
		rules.echo_share_bp = part.req_int("share_bp", 1, FixedMath.BP_ONE)
		rules.echo_steps = part.req_int("steps", 1, 20)
		part.finish()
	part = _part(reader, "carry_overkill")
	if part != null:
		rules.carry_steps = part.req_int("steps", 1, 50)
		part.finish()
	part = _part(reader, "overcharge")
	if part != null:
		rules.overcharge_power_bp = part.req_int("power_bp", 1, FixedMath.BP_ONE)
		rules.overcharge_steps = part.req_int("steps", 1, 20)
		part.finish()
	part = _part(reader, "second_dawn")
	if part != null:
		rules.rise_ticks = part.req_ticks("after_ms", FixedMath.MS_PER_TICK)
		rules.rise_hp_bp = part.req_int("hp_bp", 1, FixedMath.BP_ONE)
		part.finish()
	part = _part(reader, "deeper_chains")
	if part != null:
		rules.deeper_steps = part.req_int("steps", 1, 20)
		rules.deeper_grow_bp = part.req_int("grow_bp", 0, FixedMath.BP_ONE)
		part.finish()
	rules.keywords_twice = reader.opt_bool("keywords_twice", false)
	rules.keywords_last = reader.opt_bool("keywords_last", false)
	part = _part(reader, "unbending")
	if part != null:
		rules.unbending = true
		rules.unbending_def_bp = part.req_int("def_bp", 0, FixedMath.BP_ONE)
		rules.unbending_max_hp_bp = part.req_int("max_hp_bp", 0, FixedMath.BP_ONE)
		part.finish()
	part = _part(reader, "collapse")
	if part != null:
		rules.collapse_immune = part.opt_bool("immune", false)
		rules.collapse_enemy_bp = part.opt_int("enemy_max_hp_bp", 0, 0, FixedMath.BP_ONE)
		part.finish()
	part = _part(reader, "long_watch")
	if part != null:
		rules.watch_from_ticks = part.req_ticks("from_ms", FixedMath.MS_PER_TICK)
		rules.watch_every_ticks = part.req_ticks("every_ms", FixedMath.MS_PER_TICK)
		rules.watch_tie_ticks = part.req_ticks("tie_ms", FixedMath.MS_PER_TICK)
		part.finish()
	reader.finish()
	return rules


static func _part(reader: DataReader, key: String) -> DataReader:
	return reader.req_object(key) if reader.has(key) else null


## True if any rule is on.
func any() -> bool:
	return marks_stack or crit_steps > 0 or echo_steps > 0 or carry_steps > 0 or overcharge_steps > 0 or rise_ticks > 0 or deeper_steps > 0 \
		or keywords_twice or keywords_last or unbending or collapse_immune or collapse_enemy_bp > 0 or watch_every_ticks > 0


## These rules and `other`'s together: a flag on in either is on, and a
## rule's numbers come from whichever has it (a run holds each relic once).
func merged(other: SideRules) -> SideRules:
	var rules: SideRules = DefCopy.shallow(self) as SideRules
	rules.marks_stack = marks_stack or other.marks_stack
	if other.crit_steps > 0:
		rules.crit_steps = other.crit_steps
		rules.crit_fade_bp = other.crit_fade_bp
	if other.echo_steps > 0:
		rules.echo_share_bp = other.echo_share_bp
		rules.echo_steps = other.echo_steps
	if other.carry_steps > 0:
		rules.carry_steps = other.carry_steps
	if other.overcharge_steps > 0:
		rules.overcharge_power_bp = other.overcharge_power_bp
		rules.overcharge_steps = other.overcharge_steps
	if other.rise_ticks > 0:
		rules.rise_ticks = other.rise_ticks
		rules.rise_hp_bp = other.rise_hp_bp
	if other.deeper_steps > 0:
		rules.deeper_steps = other.deeper_steps
		rules.deeper_grow_bp = other.deeper_grow_bp
	rules.keywords_twice = keywords_twice or other.keywords_twice
	rules.keywords_last = keywords_last or other.keywords_last
	if other.unbending:
		rules.unbending = true
		rules.unbending_def_bp = other.unbending_def_bp
		rules.unbending_max_hp_bp = other.unbending_max_hp_bp
	rules.collapse_immune = collapse_immune or other.collapse_immune
	rules.collapse_enemy_bp = maxi(collapse_enemy_bp, other.collapse_enemy_bp)
	if other.watch_every_ticks > 0:
		rules.watch_from_ticks = other.watch_from_ticks
		rules.watch_every_ticks = other.watch_every_ticks
		rules.watch_tie_ticks = other.watch_tie_ticks
	return rules


## A chain step's factor (bp) under Chain of Echoes: grow_bp more for each
## of `step` steps, compounded (1.15, 1.32, ...); 10000 without it.
func growth_bp(step: int) -> int:
	var factor: int = FixedMath.BP_ONE
	if deeper_steps > 0:
		for i: int in step:
			factor = FixedMath.apply_bp(factor, FixedMath.BP_ONE + deeper_grow_bp)
	return factor
