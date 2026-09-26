class_name PlaytestJournal
extends RefCounted
## A record of one run for reading after a playtest (docs/plans/
## slice-content.md): the seed, every action the player took (with the day,
## step, and gold), each fight (the guild that fought it, the result, and how
## long it took), and how the run ended. Saved as JSON after every change to
## <dir>/run_<seed>.json, so a crash loses nothing. UI-side only: it reads
## the run and never changes it.

const DEFAULT_DIR: String = "user://playtests"

var dir: String
var seed_value: int = 0
var data: Dictionary = {}


static func make(journal_dir: String = DEFAULT_DIR) -> PlaytestJournal:
	var journal := PlaytestJournal.new()
	journal.dir = journal_dir
	return journal


func path() -> String:
	return dir.path_join("run_%d.json" % seed_value)


## Starts a journal for a new run, or picks up the saved one for this seed.
func open(state: RunState) -> void:
	seed_value = state.seed_value
	data = {}
	if FileAccess.file_exists(path()):
		var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(path()))
		if typeof(loaded) == TYPE_DICTIONARY:
			data = loaded
	if data.is_empty():
		data = {"seed": seed_value, "started": Time.get_datetime_string_from_system(), "sessions": 0, "actions": [], "fights": [], "ending": {}}
	data["sessions"] = int(data.get("sessions", 0)) + 1
	save()


## Notes an action that went through (its Result's note).
func action(state: RunState, note: String) -> void:
	if data.is_empty() or note.is_empty():
		return
	(data["actions"] as Array).append({"day": state.day, "phase": state.phase, "gold": state.gold, "did": note})
	if state.phase == "act_end" or state.phase == "run_over":
		data["ending"] = {"phase": state.phase, "day": state.day, "wins": state.wins, "losses": state.losses,
			"relics": state.relics.duplicate(), "synergies": state.discovered.duplicate()}
	save()


## Notes a fight: the guild that fought it and how it went.
func fight(state: RunState, encounter_id: String, day: int, result: FightResult) -> void:
	if data.is_empty():
		return
	var guild: Array = []
	for hero: RunHero in state.heroes:
		var items: Array = []
		for item: RunItem in hero.items:
			items.append({"item": item.item_id, "tier": TuningDef.TIER_LABELS[item.tier], "essences": item.essence_ids.duplicate(), "xp": item.xp})
		guild.append({"hero": hero.hero_id, "rank": TuningDef.TIER_LABELS[hero.rank], "specialization": hero.specialization_id,
			"row": EncounterDef.ROW_NAMES[hero.row], "backup": hero.benched, "items": items})
	var outcome: String = ["victory", "defeat", "tie"][result.outcome]
	(data["fights"] as Array).append({"day": day, "encounter": encounter_id, "outcome": outcome,
		"seconds": snappedf(result.end_tick / float(FixedMath.TICKS_PER_SECOND), 0.1), "guild": guild, "relics": state.relics.duplicate()})
	save()


func save() -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var file: FileAccess = FileAccess.open(path(), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "  "))
