class_name InfusionLook
extends RefCounted
## How an item's infusion looks (docs/ui-asset-design.md, 8.3): its gem form
## and its mark (docs/plans/infusion-rework.md): rays while a Resonant single
## spills to its holder's items that share a keyword, a star once an alloy or
## pure double awakens. The rules come from the sim's ItemState, so the UI
## never re-implements them. Read-only, like the rest of the UI.


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


## The item's mark: SPILLS for a Resonant single, AWAKENED for a Resonant
## named alloy or pure double, else NONE. A known transformation never spills
## or awakens.
static func mark(content: ContentDb, item_id: String, essence_ids: Array[String], xp: int, gem_form: Glyph.Infusion) -> FrameDecor.Mark:
	if essence_ids.is_empty() or gem_form == Glyph.Infusion.TRANSFORMATION:
		return FrameDecor.Mark.NONE
	var state: ItemState = _state(content, item_id, essence_ids, xp)
	if state.spills():
		return FrameDecor.Mark.SPILLS
	if state.awakened():
		return FrameDecor.Mark.AWAKENED
	return FrameDecor.Mark.NONE


## The mark's color: the (first) essence's.
static func mark_color(essence_ids: Array[String]) -> Color:
	return UiStyle.ESSENCE.get(essence_ids[0], UiStyle.TEXT) if not essence_ids.is_empty() else UiStyle.TEXT


static func _state(content: ContentDb, item_id: String, essence_ids: Array[String], xp: int) -> ItemState:
	var essences: Array[EssenceDef] = []
	for essence_id: String in essence_ids:
		essences.append(content.essences[essence_id])
	return ItemState.make(content.items[item_id], 0, UnitStats.make(1), content, essences, 0, xp)
