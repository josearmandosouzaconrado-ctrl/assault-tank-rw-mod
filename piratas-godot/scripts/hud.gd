class_name HUD
extends CanvasLayer
## Interface de jogo para celular (multitoque) e computador.

signal open_map
signal open_menu
signal action_pressed(id: String)

const GOLD := Color(0.95, 0.78, 0.38)
const INK := Color(0.08, 0.06, 0.04, 0.72)

var ctl: PlayerController
var root: Control
var widgets: Array = []
var _touch_owner := {}   # índice do dedo -> widget (ou "cam")
var modal := false

var wheel: WheelCtl
var joy: JoyCtl
var sail: SailCtl
var fire_l: RoundBtn
var fire_r: RoundBtn
var action_btn: RoundBtn
var small_btns: Array = []
var status: StatusPanel
var compass: CompassCtl
var minimap: MiniMap
var msg_box: VBoxContainer
var target_lbl: Label
var dialog_layer: Control
var damage_flash: ColorRect
var action_id := ""
var _flash := 0.0


# ======================================================================== widgets
class Widget extends Control:
	var hud: HUD
	var held := false

	func _init(h: HUD) -> void:
		hud = h
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func hit(p: Vector2) -> bool:
		return is_visible_in_tree() and get_global_rect().grow(8).has_point(p)

	func t_down(_p: Vector2) -> void:
		held = true
		queue_redraw()

	func t_drag(_p: Vector2, _rel: Vector2) -> void:
		pass

	func t_up() -> void:
		held = false
		queue_redraw()


## Joystick de navegação: X = leme (volta ao centro ao soltar),
## empurrar para cima/baixo sobe ou recolhe um nível de vela.
class WheelCtl extends Widget:
	var knob := Vector2.ZERO
	var _sail_latch := 0

	func t_down(p: Vector2) -> void:
		super.t_down(p)
		hud.ctl.steer_touch = true
		t_drag(p, Vector2.ZERO)

	func t_drag(p: Vector2, _rel: Vector2) -> void:
		var c := global_position + size * 0.5
		var r := size.x * 0.38
		knob = ((p - c) / r).limit_length(1.0)
		# zona morta pequena e resposta suave
		var x := knob.x
		x = signf(x) * clampf((absf(x) - 0.08) / 0.92, 0.0, 1.0)
		hud.ctl.steer_input = signf(x) * pow(absf(x), 1.3)
		if knob.y < -0.7 and _sail_latch != -1:
			_sail_latch = -1
			hud.ctl.sail_step(1)
		elif knob.y > 0.7 and _sail_latch != 1:
			_sail_latch = 1
			hud.ctl.sail_step(-1)
		elif absf(knob.y) < 0.4:
			_sail_latch = 0

	func t_up() -> void:
		super.t_up()
		knob = Vector2.ZERO
		_sail_latch = 0
		hud.ctl.steer_touch = false
		hud.ctl.steer_input = 0.0

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.38
		var f := ThemeDB.fallback_font
		draw_circle(c, r + 10, Color(0, 0, 0, 0.28))
		draw_arc(c, r + 10, 0, TAU, 48, Color(GOLD, 0.45), 2.5)
		# setas
		var col := Color(1, 1, 1, 0.55)
		draw_string(f, c + Vector2(-r - 4, 7), "◄", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
		draw_string(f, c + Vector2(r - 14, 7), "►", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
		draw_string(f, c + Vector2(-40, -r + 14), "+ vela", HORIZONTAL_ALIGNMENT_CENTER, 80, 13, GOLD)
		draw_string(f, c + Vector2(-40, r - 2), "- vela", HORIZONTAL_ALIGNMENT_CENTER, 80, 13, GOLD)
		# manete com o timão desenhado
		var kc := c + knob * r
		var a := hud.ctl.steer_input * 1.6 if hud.ctl else 0.0
		var kr := r * 0.42
		var wood := Color(0.45, 0.28, 0.15, 0.95)
		for k in 8:
			var ang := a + k * PI / 4.0
			var d := Vector2(cos(ang), sin(ang))
			draw_line(kc, kc + d * (kr + 9), wood, 5.0)
			draw_circle(kc + d * (kr + 10), 5, wood)
		draw_arc(kc, kr, 0, TAU, 32, wood, 7.0)
		draw_circle(kc, kr * 0.3, GOLD)


class JoyCtl extends Widget:
	var knob := Vector2.ZERO

	func t_down(p: Vector2) -> void:
		super.t_down(p)
		t_drag(p, Vector2.ZERO)

	func t_drag(p: Vector2, _rel: Vector2) -> void:
		var c := global_position + size * 0.5
		var r := size.x * 0.4
		knob = ((p - c) / r).limit_length(1.0)
		hud.ctl.move_vec = Vector2(knob.x, -knob.y)
		queue_redraw()

	func t_up() -> void:
		super.t_up()
		knob = Vector2.ZERO
		hud.ctl.move_vec = Vector2.ZERO
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.4
		draw_circle(c, r, Color(0, 0, 0, 0.3))
		draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.4), 3.0)
		draw_circle(c + knob * r, r * 0.38, Color(0.95, 0.85, 0.6, 0.75))


class SailCtl extends Widget:
	func t_down(p: Vector2) -> void:
		super.t_down(p)
		t_drag(p, Vector2.ZERO)

	func t_drag(p: Vector2, _rel: Vector2) -> void:
		var lp := p - global_position
		var v := 1.0 - clampf((lp.y - 30.0) / (size.y - 60.0), 0.0, 1.0)
		hud.ctl.sail_target = snappedf(v * 3.0, 1.0) / 3.0

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(w * 0.3, 30, w * 0.4, h - 60), Color(0, 0, 0, 0.35))
		var f := ThemeDB.fallback_font
		var labels := ["RECOLHIDAS", "1/3", "2/3", "TODAS"]
		for i in 4:
			var y := 30.0 + (h - 60.0) * (1.0 - i / 3.0)
			draw_line(Vector2(w * 0.2, y), Vector2(w * 0.8, y), Color(1, 1, 1, 0.4), 2.0)
		var cur := hud.ctl.sail_target if hud.ctl else 0.0
		var y := 30.0 + (h - 60.0) * (1.0 - cur)
		var sh := (h - 60.0) * cur
		draw_rect(Rect2(w * 0.3, y, w * 0.4, sh), Color(0.93, 0.89, 0.78, 0.55))
		draw_rect(Rect2(w * 0.08, y - 13, w * 0.84, 26), GOLD)
		var idx := int(round(cur * 3.0))
		draw_string(f, Vector2(0, 18), "VELAS", HORIZONTAL_ALIGNMENT_CENTER, w, 16, Color(1, 1, 1, 0.85))
		draw_string(f, Vector2(0, h - 6), labels[idx], HORIZONTAL_ALIGNMENT_CENTER, w, 13, GOLD)


class RoundBtn extends Widget:
	var text := ""
	var sub := ""
	var color := Color(0.15, 0.1, 0.06, 0.75)
	var progress := 1.0
	var on_press: Callable
	var pill := false
	var font_size := 18

	func t_down(p: Vector2) -> void:
		super.t_down(p)
		Sfx.play("click", -12.0)
		if on_press.is_valid():
			on_press.call()

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		var c := size * 0.5
		var col := color.lightened(0.25) if held else color
		if pill:
			var sb := StyleBoxFlat.new()
			sb.bg_color = col
			sb.border_color = GOLD
			sb.set_border_width_all(3)
			sb.set_corner_radius_all(int(size.y * 0.5))
			draw_style_box(sb, Rect2(Vector2.ZERO, size))
		else:
			var r := minf(size.x, size.y) * 0.5 - 3
			draw_circle(c, r, col)
			draw_arc(c, r, 0, TAU, 40, Color(GOLD, 0.5), 2.0)
			if progress < 1.0:
				draw_arc(c, r - 4, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, Color(1, 0.4, 0.2, 0.9), 6.0)
			else:
				draw_arc(c, r - 4, 0, TAU, 40, Color(GOLD, 0.95), 4.0)
		var ty := c.y + font_size * 0.35 - (8 if sub != "" else 0)
		draw_string(f, Vector2(0, ty), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color(1, 1, 1, 0.95))
		if sub != "":
			draw_string(f, Vector2(0, ty + 18), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, GOLD)


class StatusPanel extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _bar(y: float, label: String, v: float, col: Color) -> void:
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(12, y + 13), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.85))
		draw_rect(Rect2(86, y + 2, 200, 13), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(86, y + 2, 200 * clampf(v, 0, 1), 13), col)

	func _draw() -> void:
		var w := World.I
		if w == null or w.player == null:
			return
		var s := w.player
		var sb := StyleBoxFlat.new()
		sb.bg_color = INK
		sb.border_color = Color(GOLD, 0.6)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(12, 24), "%s" % Game.career_title(), HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 15, GOLD)
		draw_string(f, Vector2(12, 46), "Ouro: %d   Tripulação: %d/%d   Tropas: %d   Moral: %d%%" % [Game.gold, s.crew, s.max_crew, Game.soldiers, int(Game.morale)], HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 14, Color.WHITE)
		_bar(54, "Casco", s.hp / s.max_hp, Color(0.85, 0.25, 0.2).lerp(Color(0.3, 0.8, 0.3), s.hp / s.max_hp))
		_bar(72, "Velas", s.sail_hp / 100.0, Color(0.9, 0.88, 0.75))
		var spd := s.speed * 1.94 * 0.6
		draw_string(f, Vector2(12, 106), "%s  •  %.1f nós  •  Carga %d/%d  •  %s" % [s.def["name"], spd, Game.cargo_used(), Game.cargo_capacity(), Game.AMMO[s.ammo]], HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 13, Color(1, 1, 1, 0.75))


class CompassCtl extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var w := World.I
		if w == null or w.player == null:
			return
		var cam := get_viewport().get_camera_3d()
		var heading := w.player.yaw
		if cam:
			var fz := -cam.global_basis.z
			heading = atan2(-fz.x, -fz.z)
		var sb := StyleBoxFlat.new()
		sb.bg_color = INK
		sb.set_corner_radius_all(8)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var f := ThemeDB.fallback_font
		var cx := size.x * 0.5
		var ppr := size.x / 2.2
		var names := {0: "N", 45: "NO", 90: "O", 135: "SO", 180: "S", 225: "SE", 270: "L", 315: "NE"}
		for deg in range(0, 360, 15):
			var a := deg_to_rad(deg)
			var diff := angle_difference(heading, a)
			var x := cx - diff * ppr
			if x < 8 or x > size.x - 8:
				continue
			if names.has(deg):
				draw_string(f, Vector2(x - 20, 24), names[deg], HORIZONTAL_ALIGNMENT_CENTER, 40, 18 if deg % 90 == 0 else 14, GOLD if deg == 0 else Color.WHITE)
			else:
				draw_line(Vector2(x, 8), Vector2(x, 16), Color(1, 1, 1, 0.5), 2.0)
		draw_line(Vector2(cx, 28), Vector2(cx, size.y - 2), Color(1, 0.3, 0.2), 2.0)
		# seta do vento
		var wv := w.wind_vec()
		var wind_yaw := atan2(-wv.x, -wv.y)
		var rel := angle_difference(heading, wind_yaw)
		var ac := Vector2(size.x - 34, size.y * 0.5)
		var d := Vector2(-sin(rel), -cos(rel))
		draw_circle(ac, 15, Color(0, 0, 0, 0.35))
		draw_line(ac - d * 11, ac + d * 11, Color(0.6, 0.85, 1.0), 3.0)
		draw_line(ac + d * 11, ac + d * 11 - d.rotated(0.5) * 7, Color(0.6, 0.85, 1.0), 3.0)
		draw_line(ac + d * 11, ac + d * 11 - d.rotated(-0.5) * 7, Color(0.6, 0.85, 1.0), 3.0)
		draw_string(f, Vector2(8, 36), "Dia %d  %02d:%02d" % [Game.day, int(Game.time_of_day * 24.0), int(fmod(Game.time_of_day * 1440.0, 60.0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.6))


class MiniMap extends Control:
	var range_m := 2200.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var w := World.I
		if w == null or w.player == null:
			return
		var c := size * 0.5
		var r := size.x * 0.5
		draw_circle(c, r, Color(0.05, 0.18, 0.28, 0.82))
		var pp := w.player.pos2()
		var k := r / range_m
		if material == null:
			var m := ShaderMaterial.new()
			m.shader = load("res://shaders/circle_mask.gdshader")
			material = m
		(material as ShaderMaterial).set_shader_parameter("center", c)
		(material as ShaderMaterial).set_shader_parameter("radius", r - 1.0)
		if w.map_texture:
			var half := Game.WORLD_HALF
			var ts := w.map_texture.get_size()
			var px := ts.x / (half * 2.0)
			var src := Rect2((pp - Vector2(range_m, range_m) + Vector2(half, half)) * px, Vector2(range_m, range_m) * 2.0 * px)
			draw_texture_rect_region(w.map_texture, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), src)
		for ps in w.port_islands:
			var dp := c + (ps.dock_point - pp) * k
			if dp.distance_to(c) < r - 4:
				var nat: int = Game.port_owner[ps.idx]
				draw_circle(dp, 5, Game.NATIONS[nat]["color"])
				draw_arc(dp, 5, 0, TAU, 12, Color.WHITE, 1.5)
		for s in w.ships:
			if s.is_player or s.dead:
				continue
			var q := c + (s.pos2() - pp) * k
			if q.distance_to(c) > r - 4:
				continue
			var col := Color(1, 0.25, 0.2) if w.hostile(w.player, s) else Color(0.9, 0.9, 0.9)
			if s.mission_target:
				col = Color(1, 0.6, 0.0)
			draw_circle(q, 4.5, col)
		for l in w.loot:
			var lp: Vector3 = l["node"].global_position
			var q := c + (Vector2(lp.x, lp.z) - pp) * k
			if q.distance_to(c) < r:
				draw_circle(q, 2.5, Color(1, 0.85, 0.3))
		var mp := w.mission_point()
		if mp != Vector2.INF:
			var q := c + (mp - pp) * k
			if q.distance_to(c) > r - 6:
				q = c + (q - c).normalized() * (r - 6)
			draw_circle(q, 6, Color(1, 0.3, 0.2))
		if Game.treasure.has("pos"):
			var q: Vector2 = c + (Game.treasure["pos"] - pp) * k
			if q.distance_to(c) > r - 6:
				q = c + (q - c).normalized() * (r - 6)
			draw_string(ThemeDB.fallback_font, q + Vector2(-6, 6), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.85, 0.2))
		# jogador
		var f := w.player.forward()
		var tip := c + f * 10
		var left := c - f * 6 + Vector2(f.y, -f.x) * 6
		var right := c - f * 6 - Vector2(f.y, -f.x) * 6
		draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(0.3, 1.0, 0.4))
		draw_arc(c, r, 0, TAU, 64, GOLD, 3.0)
		draw_string(ThemeDB.fallback_font, c + Vector2(-6, -r + 16), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GOLD)


# ======================================================================== montagem
func _init(controller: PlayerController) -> void:
	ctl = controller
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	damage_flash = ColorRect.new()
	damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_flash.color = Color(0.8, 0.05, 0.0, 0.0)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(damage_flash)

	status = StatusPanel.new()
	status.position = Vector2(12, 10)
	status.size = Vector2(420, 116)
	root.add_child(status)

	compass = CompassCtl.new()
	compass.set_anchors_preset(Control.PRESET_CENTER_TOP)
	compass.offset_left = -190
	compass.offset_right = 190
	compass.offset_top = 8
	compass.offset_bottom = 50
	root.add_child(compass)

	minimap = MiniMap.new()
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -200
	minimap.offset_right = -12
	minimap.offset_top = 10
	minimap.offset_bottom = 198
	root.add_child(minimap)

	target_lbl = Label.new()
	target_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	target_lbl.offset_left = -260
	target_lbl.offset_right = 260
	target_lbl.offset_top = 56
	target_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_lbl.add_theme_font_size_override("font_size", 16)
	target_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	target_lbl.add_theme_constant_override("outline_size", 5)
	target_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(target_lbl)

	msg_box = VBoxContainer.new()
	msg_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msg_box.offset_left = -330
	msg_box.offset_right = 330
	msg_box.offset_top = 92
	msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(msg_box)

	wheel = WheelCtl.new(self)
	_anchor(wheel, Control.PRESET_BOTTOM_LEFT, Vector2(24, -24), Vector2(230, 230))
	joy = JoyCtl.new(self)
	_anchor(joy, Control.PRESET_BOTTOM_LEFT, Vector2(30, -30), Vector2(220, 220))
	joy.visible = false

	sail = SailCtl.new(self)
	_anchor(sail, Control.PRESET_RIGHT_WIDE, Vector2(-86, 0), Vector2(78, 0))
	sail.offset_top = 210
	sail.offset_bottom = -232

	fire_r = _round("ESTIBORDO", "►", Control.PRESET_BOTTOM_RIGHT, Vector2(-160, -168), Vector2(146, 146), func(): _fire(1.0))
	fire_l = _round("BOMBORDO", "◄", Control.PRESET_BOTTOM_RIGHT, Vector2(-318, -140), Vector2(128, 128), func(): _fire(-1.0))
	fire_r.color = Color(0.45, 0.08, 0.05, 0.75)
	fire_l.color = Color(0.45, 0.08, 0.05, 0.75)

	var defs := [
		["MENU", func(): open_menu.emit()],
		["MAPA", func(): open_map.emit()],
		["CÂMERA", func(): ctl.cycle_camera()],
		["LUNETA", func(): ctl.toggle_spyglass()],
		["MUNIÇÃO", func(): _cycle_ammo()],
		["BANDEIRA", func(): _cycle_flag()],
	]
	for i in defs.size():
		var col := i % 2
		var row := i / 2
		var b := _round(defs[i][0], "", Control.PRESET_TOP_LEFT, Vector2(16 + col * 84, 140 + row * 80), Vector2(76, 76), defs[i][1])
		b.font_size = 12
		small_btns.append(b)

	action_btn = RoundBtn.new(self)
	action_btn.pill = true
	action_btn.font_size = 20
	action_btn.color = Color(0.12, 0.3, 0.12, 0.85)
	_anchor(action_btn, Control.PRESET_CENTER_BOTTOM, Vector2(-170, -96), Vector2(340, 66))
	action_btn.on_press = func(): action_pressed.emit(action_id)
	action_btn.visible = false
	widgets.append(action_btn)

	dialog_layer = Control.new()
	dialog_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dialog_layer)

	Game.message.connect(_on_message)


func _anchor(w: Control, preset: int, off: Vector2, sz: Vector2) -> void:
	w.set_anchors_preset(preset)
	match preset:
		Control.PRESET_BOTTOM_LEFT:
			w.offset_left = off.x
			w.offset_right = off.x + sz.x
			w.offset_bottom = off.y
			w.offset_top = off.y - sz.y
		Control.PRESET_BOTTOM_RIGHT:
			w.offset_left = off.x
			w.offset_right = off.x + sz.x
			w.offset_top = off.y
			w.offset_bottom = off.y + sz.y
		Control.PRESET_TOP_LEFT:
			w.offset_left = off.x
			w.offset_right = off.x + sz.x
			w.offset_top = off.y
			w.offset_bottom = off.y + sz.y
		Control.PRESET_CENTER_BOTTOM:
			w.offset_left = off.x
			w.offset_right = off.x + sz.x
			w.offset_top = off.y
			w.offset_bottom = off.y + sz.y
		Control.PRESET_RIGHT_WIDE:
			w.offset_left = off.x
			w.offset_right = off.x + sz.x
	root.add_child(w)
	if w is Widget:
		widgets.append(w)


func _round(t: String, sub: String, preset: int, off: Vector2, sz: Vector2, cb: Callable) -> RoundBtn:
	var b := RoundBtn.new(self)
	b.text = t
	b.sub = sub
	b.on_press = cb
	_anchor(b, preset, off, sz)
	return b


# ======================================================================== ações
func _fire(side: float) -> void:
	var p := World.I.player
	if p and not p.dead and not ctl.on_land():
		p.fire(side)


func _cycle_ammo() -> void:
	var p := World.I.player
	p.ammo = (p.ammo + 1) % 3
	Game.ammo = p.ammo
	Game.notify("Munição: %s" % Game.AMMO[p.ammo] + ["  (danifica o casco)", "  (rasga as velas)", "  (atinge a tripulação)"][p.ammo], Color(0.9, 0.9, 1))


func _cycle_flag() -> void:
	var opts := [Game.career]
	if Game.career == Game.PIR:
		opts = [Game.PIR, Game.ENG, Game.ESP, Game.FRA, Game.HOL, Game.POR]
	else:
		opts = [Game.career, Game.PIR]
	var cur := Game.player_flag()
	var i := (opts.find(cur) + 1) % opts.size()
	var f: int = opts[i]
	Game.false_flag = -1 if f == Game.career else f
	var p := World.I.player
	p.flag_nation = f
	p.set_flag(Game.NATIONS[f]["flag"])
	if f == Game.PIR and Game.career != Game.PIR:
		Game.notify("Bandeira pirata hasteada: todos os navios o verão como pirata!", Color(1, 0.4, 0.3))
	elif Game.false_flag >= 0:
		Game.notify("Bandeira falsa: %s. Navios dessa nação não o reconhecerão até você atirar." % Game.NATIONS[f]["name"], Color(1, 0.85, 0.5))
	else:
		Game.notify("Bandeira verdadeira hasteada: %s." % Game.NATIONS[f]["name"], Color(1, 1, 1))


func flash_damage() -> void:
	_flash = 0.35


func _on_message(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_font_size_override("font_size", 19)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_box.add_child(l)
	while msg_box.get_child_count() > 4:
		msg_box.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(l, "modulate:a", 0.0, 1.2)
	tw.tween_callback(l.queue_free)


func set_action(id: String, text: String) -> void:
	action_id = id
	action_btn.visible = id != ""
	if action_btn.text != text:
		action_btn.text = text
		action_btn.queue_redraw()


func _process(delta: float) -> void:
	var w := World.I
	if w == null or w.player == null:
		return
	var foot := ctl.on_land()
	wheel.visible = not foot
	joy.visible = foot
	sail.visible = not foot
	fire_l.visible = not foot
	fire_r.visible = not foot
	fire_l.progress = w.player.reload_frac(-1.0)
	fire_r.progress = w.player.reload_frac(1.0)
	fire_l.queue_redraw()
	fire_r.queue_redraw()
	for b in small_btns:
		b.visible = not foot or b.text in ["MENU", "MAPA"]
	_flash = maxf(0.0, _flash - delta)
	damage_flash.color.a = _flash * 0.6
	# alvo na mira
	var txt := ""
	if not foot and not w.player.dead:
		for side in [1.0, -1.0]:
			var t := w.player.find_target(side, false)
			if t:
				var hs := "INIMIGO" if w.hostile(w.player, t) else "neutro"
				txt = "%s %s — casco %d%%  velas %d%%  tripulação %d  [%s]" % ["►" if side > 0 else "◄", t.display_name(), int(100 * t.hp / t.max_hp), int(t.sail_hp), t.crew, hs]
				break
	target_lbl.text = txt


# ======================================================================== roteamento de toque
func _input(e: InputEvent) -> void:
	if modal or not root.visible:
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			var w: Variant = null
			for wi in widgets:
				if wi.hit(e.position):
					w = wi
					break
			if w:
				_touch_owner[e.index] = w
				w.t_down(e.position)
			else:
				_touch_owner[e.index] = "cam"
		else:
			var o = _touch_owner.get(e.index)
			if o is Widget:
				o.t_up()
			_touch_owner.erase(e.index)
	elif e is InputEventScreenDrag:
		var o = _touch_owner.get(e.index)
		if o is Widget:
			o.t_drag(e.position, e.relative)
		elif o == "cam":
			ctl.look(e.relative)
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			ctl.zoom = clampf(ctl.zoom * 0.9, 0.45, 2.2)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			ctl.zoom = clampf(ctl.zoom * 1.1, 0.45, 2.2)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_Q:
				_fire(-1.0)
			KEY_E:
				_fire(1.0)
			KEY_M:
				open_map.emit()
			KEY_ESCAPE:
				open_menu.emit()
			KEY_F, KEY_SPACE:
				if action_id != "":
					action_pressed.emit(action_id)
			KEY_R:
				_cycle_ammo()


func release_all() -> void:
	for k in _touch_owner:
		var o = _touch_owner[k]
		if o is Widget:
			o.t_up()
	_touch_owner.clear()
	ctl.move_vec = Vector2.ZERO
	ctl.steer_touch = false


# ======================================================================== diálogo modal
func show_dialog(title: String, body: String, options: Array) -> void:
	modal = true
	release_all()
	get_tree().paused = true
	for c in dialog_layer.get_children():
		c.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog_layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 0)
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -170
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	dialog_layer.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", GOLD)
	vb.add_child(t)
	var b := Label.new()
	b.text = body
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(520, 0)
	b.add_theme_font_size_override("font_size", 18)
	vb.add_child(b)
	for o in options:
		var btn := UiStyle.button(o[0])
		var cb: Callable = o[1]
		btn.pressed.connect(func():
			close_dialog()
			if cb.is_valid():
				cb.call())
		vb.add_child(btn)


func close_dialog() -> void:
	for c in dialog_layer.get_children():
		c.queue_free()
	modal = false
	get_tree().paused = false
