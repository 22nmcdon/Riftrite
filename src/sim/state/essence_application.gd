class_name EssenceApplication
extends RefCounted
## One essence acting on one item at some strength: the item's own infusion
## (strength from its level: Base, Attuned, Resonant) or a spill from a
## Resonant neighbor (a share of the neighbor's strength). Everything the
## essence does scales by `strength_bp`: its conversion rate, its same-kind
## bonus, its modifiers, and its effects' numbers.

var essence: EssenceDef
var strength_bp: int
## Shown in the log in place of the essence name, e.g. "Ember, Attuned" or
## "Ember spill from Rust Cleaver".
var label: String


static func make(essence_def: EssenceDef, strength: int, text: String) -> EssenceApplication:
	var app := EssenceApplication.new()
	app.essence = essence_def
	app.strength_bp = strength
	app.label = text
	return app
