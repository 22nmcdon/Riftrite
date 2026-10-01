class_name SideRules
extends RefCounted
## Rules of the fight one side plays by (phase 5c step 5c,
## docs/plans/rebuild-phase5c-combos.md, section 12.2): the heroes' relics
## rewrite them ("rules" in data/relics.json; RunContent merges the run's
## into FightSetup.hero_rules). Each rule is code (CLAUDE.md rule 3: said in
## the plan), with its numbers in the data. A fight with none never reaches
## a rule's code, so it's the fight it was.
##   "marks_stack": true   a Mark a hero applies stacks as it refreshes
##                         (Hunter's Engine; StatusState.stacks)

var marks_stack: bool = false


static func read(reader: DataReader) -> SideRules:
	var rules := SideRules.new()
	rules.marks_stack = reader.opt_bool("marks_stack", false)
	reader.finish()
	return rules


## True if any rule is on.
func any() -> bool:
	return marks_stack


## These rules and `other`'s together (a flag on in either is on).
func merged(other: SideRules) -> SideRules:
	var rules := SideRules.new()
	rules.marks_stack = marks_stack or other.marks_stack
	return rules
