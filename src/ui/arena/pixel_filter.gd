class_name PixelFilter
extends ColorRect
## The arena as pixel art, for testing (the playtester's idea, 2026-10-29;
## docs/plans/art/art-style-guide.md, Question SF): laid over the board, it
## redraws what's under it in square blocks, each the average of the screen
## pixels it covers, so the arena reads as about 360 pixels tall (the look
## tests' medium size: 640 x 360 on a 16:9 screen) and is scaled up crisp.
## It only draws: it takes no input, and the fight and the board under it
## are unchanged (rule 2). What's drawn above it (popups, banners, the log,
## the hero panel) stays sharp, by z_index.

## The arena's height in pixel-art pixels: each block is the screen's height
## over this, rounded (3 at 1080p), never under 2 and never over 8 (the
## shader averages at most 8 x 8).
const PIXEL_ROWS: int = 360
## Above the board's units and effects (FightFx is 1), under the banners,
## popups, and panels.
const Z: int = 2

const SHADER: String = """
shader_type canvas_item;
// Nearest, not mipmaps: the screen texture's mipmaps are blurred, which
// smears instead of making blocks.
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float block = 3.0;

void fragment() {
	// The average of the screen pixels in this fragment's block, exactly.
	vec2 origin = floor(FRAGCOORD.xy / block) * block;
	int n = int(block);
	vec3 sum = vec3(0.0);
	for (int y = 0; y < 8; y++) {
		if (y >= n) {
			break;
		}
		for (int x = 0; x < 8; x++) {
			if (x >= n) {
				break;
			}
			sum += texture(screen_texture, (origin + vec2(float(x), float(y)) + 0.5) * SCREEN_PIXEL_SIZE).rgb;
		}
	}
	COLOR = vec4(sum / float(n * n), 1.0);
}
"""


static func make() -> PixelFilter:
	var filter := PixelFilter.new()
	var shader := Shader.new()
	shader.code = SHADER
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	filter.material = shader_material
	filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filter.z_index = Z
	filter.visible = false
	return filter


## How many screen pixels wide a block is on a screen `screen_height` tall.
static func block_for(screen_height: float) -> int:
	return clampi(roundi(screen_height / PIXEL_ROWS), 2, 8)


## Covers `rect` (global) and sizes the blocks to the screen.
func cover(rect: Rect2) -> void:
	var parent: Control = get_parent() as Control
	position = rect.position - (parent.global_position if parent != null else Vector2.ZERO)
	size = rect.size
	(material as ShaderMaterial).set_shader_parameter("block", float(block_for(get_viewport_rect().size.y)))
