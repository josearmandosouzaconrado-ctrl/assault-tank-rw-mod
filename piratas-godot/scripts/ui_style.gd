class_name UiStyle
extends RefCounted
## Estilo visual comum dos menus (madeira escura + dourado).

const GOLD := Color(0.95, 0.78, 0.38)


static func panel(alpha := 0.94) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.07, 0.045, alpha)
	sb.border_color = Color(0.78, 0.6, 0.3)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(20)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	return sb


static func _btn_box(c: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func button(text: String, min_h := 54, font := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.add_theme_font_size_override("font_size", font)
	b.add_theme_stylebox_override("normal", _btn_box(Color(0.28, 0.18, 0.1), Color(0.6, 0.45, 0.22)))
	b.add_theme_stylebox_override("hover", _btn_box(Color(0.36, 0.24, 0.13), GOLD))
	b.add_theme_stylebox_override("pressed", _btn_box(Color(0.5, 0.33, 0.15), GOLD))
	b.add_theme_stylebox_override("disabled", _btn_box(Color(0.18, 0.15, 0.12), Color(0.3, 0.27, 0.22)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color(0.98, 0.93, 0.82))
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.47, 0.42))
	b.pressed.connect(func(): Sfx.play("click", -10.0))
	return b


static func label(text: String, size := 18, color := Color(0.95, 0.92, 0.85)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func title(text: String, size := 30) -> Label:
	var l := label(text, size, GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 8)
	return l


static func flag_rect(flag_type: int, sz := Vector2(72, 48)) -> ColorRect:
	var r := ColorRect.new()
	r.custom_minimum_size = sz
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/flag_ui.gdshader")
	m.set_shader_parameter("flag_type", flag_type)
	r.material = m
	return r
