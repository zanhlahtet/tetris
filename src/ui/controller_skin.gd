class_name ControllerSkin
extends RefCounted
## Procedural retro-console look for the touch controls: a warm gray body,
## charcoal D-pad, round purple face buttons and a pill button. Pure drawing
## helpers with no input or game knowledge; every draw call takes the
## CanvasItem to paint on, and a `pressed` flag for the physical "pushed in"
## state. Not affiliated with any console maker; the shapes are generic.

const BODY := Color("c9c3b8")
const BODY_EDGE := Color("e4dfd5")
const BODY_SHADE := Color("8f897e")
const DPAD := Color("34343a")
const DPAD_PRESSED := Color("1d1d21")
const DPAD_LIGHT := Color("57575f")
const DPAD_MARK := Color("6d6d77")
const FACE_CCW := Color("b9a4ec")
const FACE_CW := Color("7a58c2")
const PILL_PAUSE := Color("b4aea3")
const LABEL_DARK := Color("2b2833")
const LABEL_LIGHT := Color("f4f0ff")
const SHADOW := Color(0, 0, 0, 0.35)
## How far a pressed control sinks, and how far its shadow falls, in pixels.
const DEPTH: float = 4.0
const DISABLED_ALPHA: float = 0.5


static func draw_body(ci: CanvasItem, rect: Rect2, alpha: float = 1.0) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = _fade(BODY, alpha)
	box.set_corner_radius_all(int(minf(rect.size.x, rect.size.y) * 0.16))
	box.set_border_width_all(3)
	box.border_color = _fade(BODY_SHADE, alpha)
	box.border_width_top = 3
	ci.draw_style_box(box, rect)
	# Top highlight along the inside of the upper edge.
	var r: float = box.corner_radius_top_left
	ci.draw_line(rect.position + Vector2(r, 5), Vector2(rect.end.x - r, rect.position.y + 5), _fade(BODY_EDGE, alpha), 2.0)


## Cross-shaped D-pad inside `box` (a square). `down`, `left` and `right`
## say which arms are pushed in; the up arm is decorative.
static func draw_dpad(ci: CanvasItem, box: Rect2, left: bool, right: bool, down: bool, alpha: float = 1.0) -> void:
	var t: float = box.size.x / 3.0
	var o: Vector2 = box.position
	var cross := PackedVector2Array([
		Vector2(t, 0), Vector2(2 * t, 0), Vector2(2 * t, t), Vector2(3 * t, t),
		Vector2(3 * t, 2 * t), Vector2(2 * t, 2 * t), Vector2(2 * t, 3 * t),
		Vector2(t, 3 * t), Vector2(t, 2 * t), Vector2(0, 2 * t), Vector2(0, t), Vector2(t, t)])
	for i in range(cross.size()):
		cross[i] += o
	var shadow := PackedVector2Array()
	for p in cross:
		shadow.append(p + Vector2(0, DEPTH))
	ci.draw_colored_polygon(shadow, _fade(SHADOW, alpha))
	ci.draw_colored_polygon(cross, _fade(DPAD, alpha))
	# Bevel: edges facing up/left catch light, the rest stay dark.
	for i in range(cross.size()):
		var a: Vector2 = cross[i]
		var b: Vector2 = cross[(i + 1) % cross.size()]
		var lit: bool = (a.y == b.y and b.x > a.x and a.y <= o.y + t) or (a.x == b.x and b.y < a.y and a.x <= o.x + t)
		ci.draw_line(a, b, _fade(DPAD_LIGHT if lit else DPAD_PRESSED, alpha), 3.0)
	var arms: Array = [
		[Rect2(o + Vector2(t, 0), Vector2(t, t)), false, Vector2(0, -1)],
		[Rect2(o + Vector2(0, t), Vector2(t, t)), left, Vector2(-1, 0)],
		[Rect2(o + Vector2(2 * t, t), Vector2(t, t)), right, Vector2(1, 0)],
		[Rect2(o + Vector2(t, 2 * t), Vector2(t, t)), down, Vector2(0, 1)],
	]
	for arm: Array in arms:
		var rect: Rect2 = arm[0]
		var sink := Vector2.ZERO
		if arm[1]:
			sink = Vector2(0, 2)
			ci.draw_rect(rect.grow(-3), _fade(DPAD_PRESSED, alpha))
			ci.draw_line(rect.position + Vector2(3, 3), Vector2(rect.end.x - 3, rect.position.y + 3), _fade(Color.BLACK, alpha), 3.0)
		_draw_arrow(ci, rect.get_center() + sink, arm[2], t * 0.2, _fade(DPAD_MARK if not arm[1] else DPAD_LIGHT, alpha))
	ci.draw_circle(box.get_center(), t * 0.16, _fade(DPAD_PRESSED, alpha))


static func draw_round_button(ci: CanvasItem, rect: Rect2, color: Color, label: String, pressed: bool, alpha: float = 1.0) -> void:
	var radius: float = minf(rect.size.x, rect.size.y) / 2.0
	var center: Vector2 = rect.get_center()
	if pressed:
		center.y += DEPTH
	else:
		ci.draw_circle(center + Vector2(0, DEPTH), radius, _fade(SHADOW, alpha))
	var face: Color = color.darkened(0.25) if pressed else color
	ci.draw_circle(center, radius, _fade(face.darkened(0.35), alpha))
	ci.draw_circle(center, radius - 3.0, _fade(face, alpha))
	if not pressed:
		ci.draw_arc(center, radius - 5.0, deg_to_rad(200), deg_to_rad(290), 16, _fade(face.lightened(0.45), alpha), 3.0)
	_draw_label(ci, center, label, int(radius * 0.95), LABEL_DARK if color.get_luminance() > 0.5 else LABEL_LIGHT, alpha)


static func draw_pill(ci: CanvasItem, rect: Rect2, color: Color, label: String, pressed: bool, alpha: float = 1.0) -> void:
	var r := rect
	if pressed:
		r.position.y += DEPTH
	else:
		ci.draw_style_box(_pill_box(SHADOW, alpha, rect.size.y), Rect2(rect.position + Vector2(0, DEPTH), rect.size))
	var face: Color = color.darkened(0.2) if pressed else color
	var box := _pill_box(face, alpha, rect.size.y)
	box.set_border_width_all(3)
	box.border_color = _fade(face.darkened(0.35), alpha)
	ci.draw_style_box(box, r)
	if not pressed:
		ci.draw_line(r.position + Vector2(r.size.y / 2.0, 6), Vector2(r.end.x - r.size.y / 2.0, r.position.y + 6), _fade(face.lightened(0.45), alpha), 2.0)
	_draw_label(ci, r.get_center(), label, clampi(int(rect.size.y * 0.5), 14, 36), LABEL_DARK if color.get_luminance() > 0.5 else LABEL_LIGHT, alpha)


static func _pill_box(color: Color, alpha: float, height: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _fade(color, alpha)
	box.set_corner_radius_all(int(height / 2.0))
	return box


static func _draw_label(ci: CanvasItem, center: Vector2, text: String, font_size: int, color: Color, alpha: float) -> void:
	var font: Font = RetroFont.bold()
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := Vector2(center.x - size.x / 2.0, center.y + font.get_ascent(font_size) / 2.0 - font.get_descent(font_size) / 2.0)
	ci.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _fade(color, alpha))


static func _draw_arrow(ci: CanvasItem, center: Vector2, dir: Vector2, size: float, color: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	ci.draw_colored_polygon(PackedVector2Array([
		center + dir * size, center - dir * size * 0.7 + side * size, center - dir * size * 0.7 - side * size]), color)


static func _fade(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)
