class_name DeedTrackDef
extends RefCounted
## One of a hero's two deed tracks (docs/plans/deeds.md): their calling
## (data/heroes.json, from the start of the run) or a specialization's
## (data/specializations.json, from the pick at rank B). A deed, and three
## levels of unlocks made of specialization-style parts (SpecializationDef):
##   {"deed": {...}, "levels": [
##     {"text": "...", "parts": [...]},
##     {"options": [{"name": "...", "text": "...", "parts": [...]}, {...}]},
##     {"text": "...", "parts": [...]}]}
## Level 2 is a choice of two options, made between fights; until then that
## level waits, unspent. A later part with the same key replaces an earlier
## one, in its place.


class Level:
	## What the player reads. For a choice level, see the options.
	var text: String = ""
	var parts: Array[SpecializationDef.Part] = []
	## Level 2: the two options (each a Level with a name).
	var options: Array[Level] = []
	var name: String = ""

	func is_choice() -> bool:
		return not options.is_empty()


## The level that offers a choice (0-based index into levels).
const CHOICE_LEVEL: int = 1

## Credits the parts in the log ("Hearthwall 2").
var name: String
var deed: DeedDef
var levels: Array[Level] = []


## `label`: the name the log credits (a calling's or specialization's);
## `id_prefix` makes ability item ids unique.
static func read(reader: DataReader, label: String, id_prefix: String, allow_basic_attack: bool = true) -> DeedTrackDef:
	var def := DeedTrackDef.new()
	def.name = label
	var deed_reader: DataReader = reader.req_object("deed")
	if deed_reader != null:
		def.deed = DeedDef.read(deed_reader)
	var level_readers: Array[DataReader] = reader.opt_object_array("levels")
	if level_readers.size() != DeedDef.LEVELS:
		reader.error("a deed track needs %d levels" % DeedDef.LEVELS)
	for i: int in level_readers.size():
		var level_reader: DataReader = level_readers[i]
		var rank_label: String = str(i + 1)
		var level := Level.new()
		if i == CHOICE_LEVEL:
			var option_readers: Array[DataReader] = level_reader.opt_object_array("options")
			if option_readers.size() != 2:
				level_reader.error("level %d offers a choice of exactly 2 options" % (i + 1))
			for option_reader: DataReader in option_readers:
				var option := Level.new()
				option.name = option_reader.req_string("name")
				option.text = option_reader.req_string("text")
				option.parts = _read_parts(option_reader, "%s %s" % [label, rank_label], "%s_%d_%s" % [id_prefix, i + 1, option.name.to_snake_case()], rank_label, allow_basic_attack)
				option_reader.finish()
				level.options.append(option)
		else:
			level.text = level_reader.req_string("text")
			level.parts = _read_parts(level_reader, "%s %s" % [label, rank_label], "%s_%d" % [id_prefix, i + 1], rank_label, allow_basic_attack)
		level_reader.finish()
		def.levels.append(level)
	def._check_auto_attack(reader)
	reader.finish()
	return def


static func _read_parts(reader: DataReader, label: String, id_prefix: String, rank_label: String, allow_basic_attack: bool) -> Array[SpecializationDef.Part]:
	var parts: Array[SpecializationDef.Part] = []
	var keys: Array[String] = []
	for part_reader: DataReader in reader.opt_object_array("parts"):
		var part: SpecializationDef.Part = SpecializationDef.read_part(part_reader, label, id_prefix, rank_label)
		if part.kind == SpecializationDef.Kind.BASIC_ATTACK and not allow_basic_attack:
			part_reader.error("this track can't replace the basic attack")
		if keys.has(part.key):
			part_reader.error("key \"%s\" is used twice in one level" % part.key)
		keys.append(part.key)
		parts.append(part)
	if parts.is_empty():
		reader.error("a level needs parts")
	return parts


## The level `progress` reaches.
func level_for(progress: int) -> int:
	return deed.level_for(progress) if deed != null else 0


## The parts in effect at `level` with level 2's option `choice` (-1: not
## chosen yet, so level 2 gives nothing). Same key replaces, in place.
func parts_at(level: int, choice: int) -> Array[SpecializationDef.Part]:
	var result: Array[SpecializationDef.Part] = []
	for i: int in mini(level, levels.size()):
		merge(result, level_parts(i, choice))
	return result


## One level's own parts (0-based), given the choice for the choice level.
func level_parts(index: int, choice: int) -> Array[SpecializationDef.Part]:
	var level: Level = levels[index]
	if not level.is_choice():
		return level.parts
	if choice < 0 or choice >= level.options.size():
		var none: Array[SpecializationDef.Part] = []
		return none
	return level.options[choice].parts


## Adds `parts` to `into`; a part with a key already there replaces it.
static func merge(into: Array[SpecializationDef.Part], parts: Array[SpecializationDef.Part]) -> void:
	for part: SpecializationDef.Part in parts:
		var replaced: bool = false
		for i: int in into.size():
			if into[i].key == part.key:
				into[i] = part
				replaced = true
		if not replaced:
			into.append(part)


## Every part on every level and option, for content checks.
func all_parts() -> Array[SpecializationDef.Part]:
	var result: Array[SpecializationDef.Part] = []
	for level: Level in levels:
		result.append_array(level.parts)
		for option: Level in level.options:
			result.append_array(option.parts)
	return result


## A basic_attack part needs an auto_attack part at its level or before,
## whichever level-2 option is taken.
func _check_auto_attack(reader: DataReader) -> void:
	for choice: int in [0, 1]:
		var covered: bool = false
		for i: int in levels.size():
			var parts: Array[SpecializationDef.Part] = level_parts(i, choice)
			for part: SpecializationDef.Part in parts:
				covered = covered or part.covers_auto_attack()
			for part: SpecializationDef.Part in parts:
				if part.kind == SpecializationDef.Kind.BASIC_ATTACK and not covered:
					reader.error("level %d replaces the basic attack, so it needs a part for basic-attack items too (an aura or grant with {\"auto_attack\": true})" % (i + 1))
					return
