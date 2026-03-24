extends Control

var band_color: Color = Color(0.10, 0.60, 0.15, 0.88)
var band_width: float = 52.0
var stamp_text: String = "ENACTED"
var text_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var font_size: int = 20

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var w = size.x
	var h = size.y
	if w < 4.0 or h < 4.0:
		return
	var center = Vector2(w * 0.5, h * 0.5)
	var diag_norm = Vector2(w, h).normalized()
	var perp = Vector2(-diag_norm.y, diag_norm.x)
	var reach = Vector2(w, h).length()
	var half_band = band_width * 0.5
	var p1 = center - diag_norm * reach - perp * half_band
	var p2 = center + diag_norm * reach - perp * half_band
	var p3 = center + diag_norm * reach + perp * half_band
	var p4 = center - diag_norm * reach + perp * half_band
	draw_colored_polygon(PackedVector2Array([p1, p2, p3, p4]), band_color)
	var angle = atan2(h, w)
	var font = get_theme_font("font", "Label")
	var text_w = font.get_string_size(stamp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var ascent = font.get_ascent(font_size)
	draw_set_transform(center, angle, Vector2.ONE)
	draw_string(font, Vector2(-text_w * 0.5, ascent * 0.5), stamp_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	draw_set_transform_matrix(Transform2D.IDENTITY)
