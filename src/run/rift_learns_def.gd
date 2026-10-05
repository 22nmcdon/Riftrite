class_name RiftLearnsDef
extends RefCounted
## The rift learns' data (data/rift_learns.json; phase 8 part 3,
## docs/plans/rebuild-phase8-act3.md section 5, enemy-growth.md section 5):
## how many fights it reads, and the habits it answers, each with what a
## fight counts toward it, how much a fight of it is a habit, and the
## upgrades and specializations that answer it. RiftLearns does the rest.
##
##   {"fights": 3, "second_at_pct": 100,
##    "habits": [{"id": "roots", "name": "Roots and control",
##      "against": "your Roots", "measure": "rooted", "per_fight": 4,
##      "upgrades": ["anchored"], "specializations": []}, ...]}
##
## A measure (MEASURES) is what one fight counts:
##   rooted, marked, burning, stealthed  the heroes' applications of a status
##                       with that keyword (Keywords), each one;
##   healing             HP the heroes healed, lifesteal too;
##   shields             Shield the heroes gave;
##   casts               the heroes' signature fires;
##   back, front         heroes placed on their back row, or on their front row
##                       or past it;
##   bunched             pairs of heroes placed side by side.
## A habit's score is its measure over the fights read against per_fight that
## many times (100% at exactly per_fight a fight). The top answerable habit is
## always answered; the second only at second_at_pct or more.

const MEASURES: Array[String] = ["rooted", "marked", "burning", "stealthed", "healing", "shields", "casts", "back", "front", "bunched"]
## The measures that count a status's applications, by its keyword.
const KEYWORD_MEASURES: Array[String] = ["rooted", "marked", "burning", "stealthed"]


class Habit:
	var id: String
	var name: String
	## How the fight card names it: "your Roots".
	var against: String
	var measure: String
	var per_fight: int
	## Enemy upgrade ids (data/enemy_upgrades.json) that answer it.
	var upgrades: Array[String] = []
	## Specialization ids (an enemy's "specializations") that answer it.
	var specializations: Array[String] = []


var fights: int = 3
var second_at_bp: int = 10000
var habits: Array[Habit] = []


static func read(reader: DataReader) -> RiftLearnsDef:
	var def := RiftLearnsDef.new()
	def.fights = reader.req_int("fights", 1)
	def.second_at_bp = reader.req_int("second_at_pct", 0) * 100
	var ids: Array[String] = []
	for entry: DataReader in reader.opt_object_array("habits"):
		var habit := Habit.new()
		habit.id = entry.req_string("id")
		habit.name = entry.req_string("name")
		habit.against = entry.req_string("against")
		habit.measure = entry.req_choice("measure", MEASURES)
		habit.per_fight = entry.req_int("per_fight", 1)
		if entry.has("upgrades"):
			habit.upgrades = entry.req_string_array("upgrades")
		if entry.has("specializations"):
			habit.specializations = entry.req_string_array("specializations")
		if habit.upgrades.is_empty() and habit.specializations.is_empty():
			entry.error("a habit needs an upgrade or a specialization that answers it")
		if ids.has(habit.id):
			entry.error("habit \"%s\" is listed twice" % habit.id)
		ids.append(habit.id)
		entry.finish()
		def.habits.append(habit)
	if def.habits.is_empty():
		reader.error("\"habits\" needs at least one habit")
	reader.finish()
	return def


func habit(habit_id: String) -> Habit:
	for each: Habit in habits:
		if each.id == habit_id:
			return each
	return null
