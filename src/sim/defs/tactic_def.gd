class_name TacticDef
extends RefCounted
## A tactic in data/tactics.json (docs/plans/rebuild-phase3b-tactics.md,
## sections 1 and 2): a change to how a hero behaves in a fight, never to
## what they can do. A hero takes at most one (UnitSetup.tactic). Each has a
## kind, which is code (the plan's three: no effect, trigger, or part could
## change how a unit picks, walks, or holds its signature), and that kind's
## numbers:
##   {"id": "casters_first", "name": "Casters first", "text": "...",
##    "kind": "prefer_target", "archetypes": ["caster", "support"],
##    "heroes": ["brannoc", "maren", "vell"]}
##   prefer_target        goes for the nearest enemy of these archetypes
##                        first ("archetypes": EnemyDef's names)
##   hold_ground          doesn't walk until an enemy comes within
##                        "release_hexes" (whole hexes), then lets go for good
##   signature_threshold  its mana signature (one that heals the lowest ally)
##                        waits, full, until an ally in its reach is below
##                        "below_pct" of max HP
## "heroes" lists who can take it (ContentDb checks they exist, and that a
## signature_threshold hero's signature heals the lowest ally). "text" is the
## player's sentence, like every ability's.
## An optional "payoff" (round 2, section 9) pays for the behavior, only
## while it applies; each kind reads only its own key, in basis points:
##   prefer_target        {"damage_vs_bp": 2000}  more damage from its own
##                        hits on the archetypes it goes for
##   hold_ground          {"atsp_bp": 2000}  a faster attack while it holds
##   signature_threshold  {"heal_bp": 3000}  more healing from the fire
##                        that waited

enum Kind { PREFER_TARGET, HOLD_GROUND, SIGNATURE_THRESHOLD }

const KIND_NAMES: Array[String] = ["prefer_target", "hold_ground", "signature_threshold"]

var id: String
var name: String
var text: String
var kind: Kind
## prefer_target: the archetypes it goes for first (EnemyDef.ARCHETYPE_NAMES).
var archetypes: Array[String] = []
## hold_ground: how near an enemy lets it go, on the plane (center to center).
var release_range: int = 0
## signature_threshold: the HP share (basis points) an ally must be below.
var below_bp: int = 0
## Who can take it, by hero id.
var heroes: Array[String] = []
## The payoff, in basis points (0: none); only its kind's is ever set.
var damage_vs_bp: int = 0
var atsp_bp: int = 0
var heal_bp: int = 0


static func read(reader: DataReader) -> TacticDef:
	var def := TacticDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.text = reader.req_string("text")
	def.kind = maxi(KIND_NAMES.find(reader.req_choice("kind", KIND_NAMES)), 0) as Kind
	match def.kind:
		Kind.PREFER_TARGET:
			def.archetypes = reader.opt_choice_array("archetypes", EnemyDef.ARCHETYPE_NAMES)
			if def.archetypes.is_empty():
				reader.error("a prefer_target tactic needs \"archetypes\" (at least one)")
		Kind.HOLD_GROUND:
			def.release_range = reader.req_int("release_hexes", 1, 10) * HexGrid.HEX
		Kind.SIGNATURE_THRESHOLD:
			def.below_bp = reader.req_int("below_pct", 1, 99) * 100
	if reader.has("payoff"):
		var payoff: DataReader = reader.req_object("payoff")
		if payoff != null:
			match def.kind:
				Kind.PREFER_TARGET:
					def.damage_vs_bp = payoff.req_int("damage_vs_bp", 1, 20000)
				Kind.HOLD_GROUND:
					def.atsp_bp = payoff.req_int("atsp_bp", 1, 20000)
				Kind.SIGNATURE_THRESHOLD:
					def.heal_bp = payoff.req_int("heal_bp", 1, 20000)
			payoff.finish()
	def.heroes = reader.req_string_array("heroes")
	if def.heroes.is_empty() and reader.has("heroes"):
		reader.error("a tactic needs at least one hero who can take it")
	reader.finish()
	return def


## Whether the hero with this kit id can take it.
func allows(kit_id: String) -> bool:
	return heroes.has(kit_id)
