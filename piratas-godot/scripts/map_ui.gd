class_name MapUI
extends CanvasLayer
## Mapa do arquipélago: ilhas, portos (com a cor do dono), jogador, missão e tesouro.

signal closed
signal fast_travel(port_idx: int)

var canvas: Control
var info: Label
var _outlines := {}
var _sel := -1
var travel_btn: Button


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open() -> void:
	visible = true
	_sel = -1
	for c in get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(_draw_map)
	canvas.gui_input.connect(_on_input)
	add_child(canvas)
	var close := UiStyle.button("Fechar mapa", 52, 18)
	close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left = -200
	close.offset_right = -16
	close.offset_top = 14
	close.offset_bottom = 66
	close.pressed.connect(func():
		visible = false
		closed.emit())
	add_child(close)
	travel_btn = UiStyle.button("Viagem rápida", 52, 18)
	travel_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	travel_btn.offset_left = 16
	travel_btn.offset_right = 300
	travel_btn.offset_top = 14
	travel_btn.offset_bottom = 66
	travel_btn.visible = false
	travel_btn.pressed.connect(func():
		if _sel >= 0:
			visible = false
			fast_travel.emit(_sel))
	add_child(travel_btn)
	info = UiStyle.label("Toque num porto para ver detalhes.", 16)
	info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	info.offset_top = -64
	info.offset_left = 20
	info.offset_right = -20
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(info)


func _map_rect() -> Rect2:
	var s := canvas.size
	var side := minf(s.x - 40.0, s.y - 90.0)
	return Rect2(Vector2((s.x - side) * 0.5, 14.0), Vector2(side, side))


func _to_screen(p: Vector2) -> Vector2:
	var r := _map_rect()
	var h := Game.WORLD_HALF
	return r.position + (p + Vector2(h, h)) / (2.0 * h) * r.size


func _draw_map() -> void:
	var w := World.I
	var r := _map_rect()
	canvas.draw_rect(r, Color(0.08, 0.27, 0.38))
	var f := ThemeDB.fallback_font
	# grade de navegação
	for i in range(1, 8):
		var x := r.position.x + r.size.x * i / 8.0
		var y := r.position.y + r.size.y * i / 8.0
		canvas.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(1, 1, 1, 0.06), 1.0)
		canvas.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.06), 1.0)
	if w.map_texture:
		canvas.draw_texture_rect(w.map_texture, r, false)
	# estradas
	for road in w.roads:
		var sp := PackedVector2Array()
		for q in road:
			sp.append(_to_screen(q))
		canvas.draw_polyline(sp, Color(0.45, 0.32, 0.18, 0.9), 1.5)
	for i in w.port_islands.size():
		var isl := w.port_islands[i]
		var p := _to_screen(isl.dock_point)
		var nat: int = Game.port_owner[i]
		canvas.draw_circle(p, 8, Game.NATIONS[nat]["color"])
		canvas.draw_arc(p, 8, 0, TAU, 16, Color.WHITE if i != _sel else Color(1, 0.9, 0.2), 2.0)
		canvas.draw_string(f, p + Vector2(-70, -12), isl.name, HORIZONTAL_ALIGNMENT_CENTER, 140, 14, Color.WHITE)
		if Game.port_fort_hp[i] <= 0.0:
			canvas.draw_string(f, p + Vector2(-70, 24), "forte destruído", HORIZONTAL_ALIGNMENT_CENTER, 140, 11, Color(1, 0.5, 0.3))
	if not w.war.is_empty():
		var wq := _to_screen(w.port_islands[w.war["port"]].dock_point)
		canvas.draw_arc(wq, 18, 0, TAU, 24, Color(1, 0.5, 0.1), 4.0)
		canvas.draw_string(f, wq + Vector2(-70, 40), "GUERRA", HORIZONTAL_ALIGNMENT_CENTER, 140, 14, Color(1, 0.55, 0.2))
	var mp := w.mission_point()
	if mp != Vector2.INF:
		var q := _to_screen(mp)
		canvas.draw_circle(q, 10, Color(1, 0.25, 0.2, 0.5))
		canvas.draw_arc(q, 14, 0, TAU, 20, Color(1, 0.25, 0.2), 3.0)
		canvas.draw_string(f, q + Vector2(-60, 30), "MISSÃO", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(1, 0.4, 0.3))
	if Game.treasure.has("pos"):
		var q := _to_screen(Game.treasure["pos"])
		canvas.draw_string(f, q + Vector2(-9, 9), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.85, 0.1, 0.05))
	if w.player:
		var pp := _to_screen(w.player.pos2())
		var fw := w.player.forward()
		var tip := pp + fw * 13
		var l := pp - fw * 8 + Vector2(fw.y, -fw.x) * 8
		var rr := pp - fw * 8 - Vector2(fw.y, -fw.x) * 8
		canvas.draw_colored_polygon(PackedVector2Array([tip, l, rr]), Color(0.2, 1.0, 0.35))
		canvas.draw_arc(pp, 18, 0, TAU, 24, Color(0.2, 1.0, 0.35, 0.6), 2.0)
	# rosa dos ventos e legenda
	var c := r.position + Vector2(56, r.size.y - 56)
	canvas.draw_circle(c, 40, Color(0, 0, 0, 0.3))
	canvas.draw_string(f, c + Vector2(-8, -24), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiStyle.GOLD)
	var wv := w.wind_vec()
	canvas.draw_line(c - wv * 26, c + wv * 26, Color(0.6, 0.85, 1.0), 3.0)
	canvas.draw_circle(c + wv * 26, 5, Color(0.6, 0.85, 1.0))
	canvas.draw_string(f, c + Vector2(-40, 58), "vento", HORIZONTAL_ALIGNMENT_CENTER, 80, 13, Color(0.6, 0.85, 1.0))
	var ly := r.position.y + 10
	for n in Game.nation_count():
		canvas.draw_circle(Vector2(r.end.x - 150, ly + n * 22 + 6), 6, Game.NATIONS[n]["color"])
		canvas.draw_string(f, Vector2(r.end.x - 138, ly + n * 22 + 11), Game.NATIONS[n]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


func _on_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var w := World.I
		var best := -1
		var bd := 40.0
		for i in w.port_islands.size():
			var d := _to_screen(w.port_islands[i].dock_point).distance_to(e.position)
			if d < bd:
				bd = d
				best = i
		_sel = best
		if best >= 0:
			var nat: int = Game.port_owner[best]
			var p: Dictionary = Game.PORTS_DEF[best]
			var dist := w.player.pos2().distance_to(w.port_islands[best].dock_point) if w.player else 0.0
			info.text = "%s (%s) — produz %s; procura %s. Distância: %.1f km. %s" % [p["name"], Game.NATIONS[nat]["name"],
				", ".join(p["prod"].map(func(x): return Game.good_name(x))), ", ".join(p["need"].map(func(x): return Game.good_name(x))),
				dist / 1000.0, "Hostil a você!" if not Game.can_dock(best) else "Você pode atracar."]
			travel_btn.visible = Game.can_dock(best)
			travel_btn.text = "Viagem rápida até %s" % p["name"]
		else:
			travel_btn.visible = false
		canvas.queue_redraw()
