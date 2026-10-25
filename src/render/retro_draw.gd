class_name RetroDraw
extends RefCounted
## Shared 16-bit look: the palette plus the tile and panel renderers used by
## the board, the previews and the HUD, so every block and panel is drawn by
## one piece of code. Square corners, whole-pixel rectangles, no gradients,
## blur, antialiasing or glow.

const BACKGROUND := Color("0b0e1f")
const GRID := Color(0.55, 0.62, 0.95, 0.09)
const PANEL_FILL := Color("10142b")
const PANEL_BORDER := Color("3b4688")
const PANEL_LIGHT := Color("5866b4")
const PANEL_DARK := Color("070914")
const TEXT := Color("eef0ff")
const CAPTION := Color("8f9ad8")
const ACCENT := Color("ffd95a")
const FRAME: float = 4.0

const GHOST_FILL_ALPHA: float = 0.14
const GHOST_OUTLINE_ALPHA: float = 0.65


## One raised tile filling `rect` (a whole-pixel square): dark outline, light
## top/left bevel, dark bottom/right bevel and a flat inset face.
static func draw_tile(ci: CanvasItem, rect: Rect2, color: Color, alpha: float = 1.0) -> void:
	var border: float = 2.0 if rect.size.x >= 28.0 else 1.0
	var bevel: float = maxf(2.0, floorf(rect.size.x / 8.0))
	var inner: Rect2 = rect.grow(-border)
	ci.draw_rect(rect, _a(color.darkened(0.75), alpha))
	ci.draw_rect(inner, _a(color.darkened(0.4), alpha))
	var light: Color = _a(color.lightened(0.55), alpha)
	ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x - bevel, bevel)), light)
	ci.draw_rect(Rect2(inner.position + Vector2(0, bevel), Vector2(bevel, inner.size.y - 2.0 * bevel)), light)
	ci.draw_rect(inner.grow(-bevel), _a(color, alpha))


## Translucent outline-and-wash marker for where the piece will land. Clearly
## not a solid tile, but still tinted with the piece's colour.
static func draw_ghost(ci: CanvasItem, rect: Rect2, color: Color) -> void:
	var inner: Rect2 = rect.grow(-1.0)
	ci.draw_rect(inner, Color(color, GHOST_FILL_ALPHA))
	ci.draw_rect(inner, Color(color, GHOST_OUTLINE_ALPHA), false, 2.0)


## Pixel-style panel: dark outline, mid border with a lit top/left edge, fill.
static func draw_panel(ci: CanvasItem, rect: Rect2) -> void:
	ci.draw_rect(rect, PANEL_DARK)
	ci.draw_rect(rect.grow(-1.0), PANEL_BORDER)
	ci.draw_rect(Rect2(rect.position + Vector2.ONE, Vector2(rect.size.x - 3.0, 1.0)), PANEL_LIGHT)
	ci.draw_rect(Rect2(rect.position + Vector2.ONE, Vector2(1.0, rect.size.y - 3.0)), PANEL_LIGHT)
	ci.draw_rect(rect.grow(-3.0), PANEL_FILL)


static func _a(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)
