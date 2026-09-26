class_name InfusionLook
extends RefCounted
## How an item's infusion looks (docs/ui-asset-design.md, 8.3): its gem form
## and its spill arrows, from the game's infusion rules (CLAUDE.md). Only
## Resonant infusions spill; a single and a pure double spill their essence
## to both sides, an alloy its first essence left and its second right; a
## transformation never spills. Read-only, like the rest of the UI.


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


## The spill arrows' colors, [left, right], or [] when it doesn't spill.
static func spill_colors(gem_form: Glyph.Infusion, essence_ids: Array[String], infusion_level: int) -> Array[Color]:
	if infusion_level != Infusions.Level.RESONANT:
		return [] as Array[Color]
	match gem_form:
		Glyph.Infusion.SINGLE, Glyph.Infusion.PURE:
			var hue: Color = UiStyle.ESSENCE.get(essence_ids[0], UiStyle.TEXT)
			return [hue, hue] as Array[Color]
		Glyph.Infusion.ALLOY:
			return [UiStyle.ESSENCE.get(essence_ids[0], UiStyle.TEXT), UiStyle.ESSENCE.get(essence_ids[1], UiStyle.TEXT)] as Array[Color]
	return [] as Array[Color]


## A transformation at Resonant shows flat bars where arrows would be.
static func shows_no_spill(gem_form: Glyph.Infusion, infusion_level: int) -> bool:
	return gem_form == Glyph.Infusion.TRANSFORMATION and infusion_level == Infusions.Level.RESONANT
