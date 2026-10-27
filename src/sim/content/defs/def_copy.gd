class_name DefCopy
extends RefCounted
## Copies of content definitions, for changing one without touching the
## shared one the content loaded (docs/plans/rebuild-phase5-run.md, section
## 7: kit modifiers). A shallow copy: every script variable is copied, and
## arrays are duplicated (their items shared), so a caller copies deeper
## only what it changes.


## A shallow copy of `def` (an AbilityDef, EffectDef, PartDef, AuraDef,
## ManaDef, ShapeDef, or TriggerDef).
static func shallow(def: RefCounted) -> RefCounted:
	var other: RefCounted = (def.get_script() as GDScript).new()
	for property: Dictionary in def.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var value: Variant = def.get(property["name"])
		other.set(property["name"], (value as Array).duplicate() if value is Array else value)
	return other
