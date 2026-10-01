class_name ItemIcon
extends Control
## The item language (docs/plans/rebuild-phase5b-art.md, section 5): a kind's
## frame (art/ui/items/frames/) with a glyph (art/ui/items/glyphs/, split
## from the uploaded icons by tools/art/item_glyphs.py) drawn on it in the
## kind's color. The frame always says the kind; the glyph is the thing's
## own ("icon" in items.json and relics.json), shared until more are drawn.
## Upgrades take the upgrade frame (a vow pick the vow frame) with a plus.
## An empty glyph draws the bare frame (an empty slot's kind).

const FRAMES: String = "res://art/ui/items/frames/%s.svg"
const KINDS: Array[String] = ["charm", "tactic", "sigil", "gambit", "relic", "upgrade", "vow", "path", "bond"]
## A kind drawn in another kind's frame: gambits (phase 5c step 6) take the
## rose frame grafts had, until theirs is drawn.
const FRAME_OF: Dictionary[String, String] = {"gambit": "graft"}
## Each kind's glyph color, from the uploaded icons (gambit: the rose frame's).
const TINTS: Dictionary[String, Color] = {
	"charm": Color("ffd66e"), "tactic": Color("f1e6c8"), "sigil": Color("8ff5e8"), "gambit": Color("ffb3c1"),
	"relic": Color("ffd66e"), "upgrade": Color("ffd66e"), "vow": Color("ffd66e"), "path": Color("8ff5e8"), "bond": Color("ffd66e"),
}
## An upgrade's glyph.
const UPGRADE_GLYPH: String = "deep_mend"
## How much of the frame the glyph covers (the uploaded icons draw it at
## full size over the frame).
const GLYPH_SHARE: float = 1.0

var kind: String
var glyph: String
var frame_texture: Texture2D
var glyph_texture: Texture2D = null


static func make(icon_kind: String, glyph_name: String, side: float = 48.0) -> ItemIcon:
	var icon := ItemIcon.new()
	icon.kind = icon_kind
	icon.glyph = glyph_name
	icon.frame_texture = ArenaView.art(FRAMES % FRAME_OF.get(icon_kind, icon_kind))
	if not glyph_name.is_empty():
		icon.glyph_texture = ArenaView.art(RunContent.GLYPHS % glyph_name)
	icon.custom_minimum_size = Vector2(side, side)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


static func for_item(item: ItemDef, side: float = 48.0) -> ItemIcon:
	return make(ItemDef.KIND_NAMES[item.kind], item.icon, side)


static func for_relic(relic: RelicDef, side: float = 48.0) -> ItemIcon:
	return make("relic", relic.icon, side)


static func for_upgrade(upgrade: UpgradeDef, side: float = 48.0) -> ItemIcon:
	return make("vow" if upgrade.layer == UpgradeDef.Layer.TASTE else "upgrade", UPGRADE_GLYPH, side)


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	var box := Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side))
	draw_texture_rect(frame_texture, box, false)
	if glyph_texture != null:
		var inset: float = side * (1.0 - GLYPH_SHARE) / 2.0
		draw_texture_rect(glyph_texture, box.grow(-inset), false, TINTS[kind])
