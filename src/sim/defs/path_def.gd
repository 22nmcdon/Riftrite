class_name PathDef
extends RefCounted
## One of a hero's three paths, in data/paths.json
## (docs/plans/rebuild-phase4-paths.md, section 1): what vowing to it does
## (the taste and its cost), what transforming into it does, and its deed.
##   {"id": "deadeye", "hero": "maren", "name": "Deadeye", "title": "the sniper",
##    "fantasy": "She plants her feet and makes one shot count.",
##    "placement": "A corner with a long sightline.",
##    "vowed": {"taste": "...", "cost": "...", "patch": {...a KitPatch...}},
##    "transformed": {"text": "...", "cost": "...", "patch": {...a KitPatch...}},
##    "deed": {...a DeedDef...}}
## Each patch changes the hero's base kit; the transformed one replaces the
## vowed one rather than adding to it (the transformation carries the full
## mechanic). The texts are the player's; the sim never reads them.
## ContentDb builds both kits (vowed_kit, transformed_kit) once the heroes
## are loaded. A path may carry up to two apexes (phase 8 part 2,
## `"apexes"`: ApexDef), each built on the transformed kit.

## A hero's stage in a fight: base (no path), vowed, transformed, vowed to
## one of the path's apexes, or the apex itself (phase 8 part 2).
enum Stage { BASE, VOWED, TRANSFORMED, APEX_VOWED, APEX }

const STAGE_NAMES: Array[String] = ["base", "vowed", "transformed", "apex vowed", "apex"]
const APEXES_PER_PATH: int = 2

var id: String
var hero: String
var name: String
## "the sniper".
var title: String
var fantasy: String
## Where the hero wants to stand on this path.
var placement: String
var taste: String
var vowed_cost: String
var vowed_patch: KitPatch
## What the transformation brings.
var transformed_text: String
var transformed_cost: String
var transformed_patch: KitPatch
var deed: DeedDef
## The hero's kit on this path, built by ContentDb (null until then).
var vowed_kit: UnitDef = null
var transformed_kit: UnitDef = null
## Its apexes, in the file's order (none until they're written).
var apexes: Array[ApexDef] = []


static func read(reader: DataReader) -> PathDef:
	var def := PathDef.new()
	def.id = reader.req_string("id")
	def.hero = reader.req_string("hero")
	def.name = reader.req_string("name")
	def.title = reader.req_string("title")
	def.fantasy = reader.req_string("fantasy")
	def.placement = reader.req_string("placement")
	var vowed: DataReader = reader.req_object("vowed")
	if vowed != null:
		def.taste = vowed.req_string("taste")
		def.vowed_cost = vowed.req_string("cost")
		var patch: DataReader = vowed.req_object("patch")
		def.vowed_patch = KitPatch.read(patch) if patch != null else KitPatch.make()
		vowed.finish()
	var transformed: DataReader = reader.req_object("transformed")
	if transformed != null:
		def.transformed_text = transformed.req_string("text")
		def.transformed_cost = transformed.req_string("cost")
		var patch: DataReader = transformed.req_object("patch")
		def.transformed_patch = KitPatch.read(patch) if patch != null else KitPatch.make()
		transformed.finish()
	# A missing block has been reported; an empty patch keeps loading going.
	if def.vowed_patch == null:
		def.vowed_patch = KitPatch.make()
	if def.transformed_patch == null:
		def.transformed_patch = KitPatch.make()
	var deed_reader: DataReader = reader.req_object("deed")
	def.deed = DeedDef.read(deed_reader) if deed_reader != null else DeedDef.new()
	for apex_reader: DataReader in reader.opt_object_array("apexes"):
		def.apexes.append(ApexDef.read(apex_reader, def.id))
	reader.finish()
	return def


## The hero's kit at `stage` on this path (the base kit: `base`). An apex
## stage needs `apex_id`, one of its apexes.
func kit(stage: Stage, base: UnitDef, apex_id: String = "") -> UnitDef:
	match stage:
		Stage.VOWED:
			return vowed_kit
		Stage.TRANSFORMED:
			return transformed_kit
		Stage.APEX_VOWED, Stage.APEX:
			var crowned: ApexDef = apex(apex_id)
			return crowned.kit(stage) if crowned != null else transformed_kit
	return base


## Its apex `apex_id`, or null.
func apex(apex_id: String) -> ApexDef:
	for found: ApexDef in apexes:
		if found.id == apex_id:
			return found
	return null


## Every kit its apexes give (each apex's taste and apex kits; built ones).
func apex_kits() -> Array[UnitDef]:
	var kits: Array[UnitDef] = []
	for crowned: ApexDef in apexes:
		for kit: UnitDef in [crowned.vowed_kit, crowned.apex_kit]:
			if kit != null:
				kits.append(kit)
	return kits


## True at an apex stage.
static func is_apex(stage: Stage) -> bool:
	return stage == Stage.APEX_VOWED or stage == Stage.APEX
