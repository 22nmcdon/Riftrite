class_name ShopStage
extends MarginContainer
## A shop's stage at camp (docs/plans/rebuild-phase5b-art.md, section 6): the
## Pedlar's or the Magpie's scene (art/ui/shops/) behind the wares, with the
## keeper (his own figure: the scenes are empty) standing in it as in the
## shops look test, and the wares over the scene's right side. The scene
## fills the stage's width, lined up so its ground (FOCUS_Y) sits at the
## stage's bottom, and whatever the stage is too short for is cut from the
## top. The wares go in `wares`, a flow of cards.

const SCENES: String = "res://art/ui/shops/%s_scene.svg"
const KEEPERS: String = "res://art/ui/shops/%s.svg"
## A keeper's canvas, and his feet on it.
const KEEPER_CANVAS := Vector2(300, 520)
const KEEPER_FEET := Vector2(150, 500)
## Where each keeper's feet stand in his scene, and how tall his canvas is
## drawn there (scene units).
const STANDS: Dictionary[String, Array] = {
	"pedlar": [Vector2(390, 985), 640.0],
	"magpie": [Vector2(250, 900), 600.0],
}
const SCENE_SIZE := Vector2(1920, 1080)
## The scene's row that sits at the stage's bottom: just under the keeper's
## feet.
const FOCUS_Y: float = 1010.0
## How much of the stage's width the keeper keeps clear on the left.
const KEEPER_SHARE: float = 0.48
const MIN_HEIGHT: float = 580.0

var keeper: String
var scene: Texture2D
var figure: Texture2D
var wares: HFlowContainer


static func make(shop: String) -> ShopStage:
	var stage := ShopStage.new()
	stage.keeper = shop
	stage.scene = ArenaView.art(SCENES % shop)
	stage.figure = ArenaView.art(KEEPERS % shop)
	stage.clip_contents = true
	stage.custom_minimum_size = Vector2(0, MIN_HEIGHT)
	for side: String in ["top", "right", "bottom"]:
		stage.add_theme_constant_override("margin_" + side, 24)
	stage.wares = HFlowContainer.new()
	stage.wares.add_theme_constant_override("h_separation", 18)
	stage.wares.add_theme_constant_override("v_separation", 18)
	stage.wares.alignment = FlowContainer.ALIGNMENT_END
	stage.add_child(stage.wares)
	return stage


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		add_theme_constant_override("margin_left", int(size.x * KEEPER_SHARE))


func _draw() -> void:
	var scale_by: float = size.x / SCENE_SIZE.x
	var top: float = size.y - FOCUS_Y * scale_by
	top = minf(top, 0.0)
	draw_texture_rect(scene, Rect2(0.0, top, size.x, SCENE_SIZE.y * scale_by), false)
	var stand: Array = STANDS[keeper]
	var keeper_scale: float = float(stand[1]) / KEEPER_CANVAS.y * scale_by
	var feet: Vector2 = Vector2(0.0, top) + (stand[0] as Vector2) * scale_by
	draw_texture_rect(figure, Rect2(feet - KEEPER_FEET * keeper_scale, KEEPER_CANVAS * keeper_scale), false)
