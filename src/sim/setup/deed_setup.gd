class_name DeedSetup
extends RefCounted
## A hero's progress on one deed track as it enters a fight (the run keeps
## it between fights; docs/plans/deeds.md).

const CALLING: String = "calling"
const SPECIALIZATION: String = "specialization"

## CALLING or SPECIALIZATION.
var track_id: String
var def: DeedTrackDef
var progress: int = 0
## Level 2's chosen option (0 or 1), or -1 if not chosen yet.
var choice: int = -1


static func make(id: String, track: DeedTrackDef, track_progress: int = 0, track_choice: int = -1) -> DeedSetup:
	var setup := DeedSetup.new()
	setup.track_id = id
	setup.def = track
	setup.progress = track_progress
	setup.choice = track_choice
	return setup


func level() -> int:
	return def.level_for(progress)
