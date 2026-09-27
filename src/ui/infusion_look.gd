class_name InfusionLook
extends RefCounted
## How an item's infusion looks (docs/ui-asset-design.md, 8.3): its gem form
## and its spill arrows, from the game's infusion rules (CLAUDE.md). For now
## nothing spills: neighbor spill went with item rows, and keyword spill comes
## with the infusion rework (docs/plans/fun-redesign.md), which redraws the
## arrows. Read-only, like the rest of the UI.


## The gem form. A transformation shows as one only once it's discovered
## (transformations are hidden synergies).
static func form(content: ContentDb, item_id: String, essence_ids: Array[String], discovered: Array[String]) -> Glyph.Infusion:
	if essence_ids.is_empty():
		return Glyph.Infusion.EMPTY
	if known_transformation(content, item_id, essence_ids, discovered):
		return Glyph.Infusion.TRANSFORMATION
	if essence_ids.size() == 1:
		return Glyph.Infusion.SINGLE
	return Glyph.Infusion.PURE if essence_ids[0] == essence_ids[1] else Glyph.Infusion.ALLOY


static func known_transformation(content: ContentDb, item_id: String, essence_ids: Array[String], discovered: Array[String]) -> bool:
	for synergy_id: String in discovered:
		var synergy: SynergyDef = content.synergies.get(synergy_id)
		if synergy != null and synergy.layer == SynergyDef.Layer.TRANSFORMATION and synergy.items.has(item_id) and essence_ids.has(synergy.essence):
			return true
	return false


static func level(content: ContentDb, essence_ids: Array[String], xp: int) -> int:
	return Infusions.level_for(xp, content.tuning) if not essence_ids.is_empty() else Infusions.Level.BASE


## The spill arrows' colors, [left, right], or [] when it doesn't spill:
## always [] until keyword spill arrives.
static func spill_colors(_gem_form: Glyph.Infusion, _essence_ids: Array[String], _infusion_level: int) -> Array[Color]:
	return [] as Array[Color]


## Flat bars where arrows would be (a transformation never spills): off
## while nothing spills.
static func shows_no_spill(_gem_form: Glyph.Infusion, _infusion_level: int) -> bool:
	return false
