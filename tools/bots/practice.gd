extends RefCounted
## Practice fights (docs/plans/rebuild-phase6-bot-tuning.md, section 2.3):
## how much a fight is worth to the heroes, for the good bot's judgments
## and the expert's tries. A fight's worth is a win (1) plus the share of
## the heroes' HP left (so 1 to 2), or that share minus 1 for a loss (-1 to
## 0): any win beats any loss, and a closer loss beats a rout.


## Fights `setup` to its end and returns its worth.
static func worth(setup: FightSetup, content: ContentDb) -> float:
	if not setup.validate(content).is_empty():
		return -2.0
	var sim := CombatSim.new(setup, content)
	while not sim.finished:
		sim.step()
	var hp: int = 0
	var max_hp: int = 0
	for unit: UnitState in sim.heroes:
		hp += maxi(unit.hp, 0) if unit.alive else 0
		max_hp += unit.max_hp
	var left: float = float(hp) / maxf(max_hp, 1)
	return 1.0 + left if sim.outcome != FightResult.Outcome.DEFEAT else left - 1.0
