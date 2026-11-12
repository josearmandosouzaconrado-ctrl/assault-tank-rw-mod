class_name MenuUI
extends CanvasLayer
## Menu principal, escolha de carreira, opções e pausa.

signal start_new(career: int, cname: String)
signal continue_game
signal resume
signal quit_to_menu

const CAREERS := [
	[5, "Pirata", "Liberdade total. Saqueie qualquer bandeira, cace tesouros, use bandeiras falsas e torne-se o Rei dos Piratas. Todas as nações vão caçá-lo.", "Saveiro em Nassau"],
	[0, "Marinha Real Britânica", "Sirva o Rei Jorge. Proteja as colônias, caçe piratas, enfrente Espanha e França e suba até Almirante.", "Brigue em Port Royal"],
	[1, "Armada Espanhola", "Defenda os galeões do tesouro e as cidades do Império contra ingleses, holandeses e piratas.", "Escuna em Havana"],
	[2, "Marine Royale (França)", "Pela glória do Rei Sol: escolte mercadores, ataque ingleses e holandeses, aliado da Espanha.", "Escuna em Petit-Goâve"],
	[3, "Marinha Holandesa", "Mercadores e guerreiros: domine o comércio a partir de Willemstad e Sint Eustatius.", "Escuna em Sint Eustatius"],
	[4, "Armada Portuguesa", "Proteja o açúcar do Brasil em Salvador e Olinda, aliado dos ingleses contra Espanha e França.", "Escuna em Olinda"],
]

var box: Control
var _name_edit: LineEdit
var _chosen := 5
var in_game := false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS


func _clear() -> void:
	for c in get_children():
		c.queue_free()
	visible = true


func _center_panel(w: float, shade := 0.35) -> VBoxContainer:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, shade)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.panel(0.88))
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(w, 0)
	p.offset_left = -w * 0.5
	p.offset_right = w * 0.5
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	p.add_child(vb)
	return vb


func show_loading(text := "Içando as velas...") -> void:
	_clear()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var t := UiStyle.title("MARES DE FORTUNA", 54)
	t.set_anchors_preset(Control.PRESET_CENTER)
	t.offset_left = -400
	t.offset_right = 400
	t.offset_top = -80
	add_child(t)
	var l := UiStyle.label(text, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.offset_left = -400
	l.offset_right = 400
	l.offset_top = 10
	add_child(l)


func show_main() -> void:
	_clear()
	in_game = false
	var title := UiStyle.title("MARES DE FORTUNA", 64)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -500
	title.offset_right = 500
	title.offset_top = 40
	add_child(title)
	var sub := UiStyle.title("Mar do Caribe, 1705 — pirata ou oficial da marinha: o mar é seu", 20)
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.offset_left = -500
	sub.offset_right = 500
	sub.offset_top = 124
	add_child(sub)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.custom_minimum_size = Vector2(380, 0)
	vb.offset_left = -190
	vb.offset_right = 190
	vb.offset_top = -40
	add_child(vb)
	if Game.has_save:
		var c := UiStyle.button("Continuar viagem", 62, 24)
		c.pressed.connect(func(): continue_game.emit())
		vb.add_child(c)
	var n := UiStyle.button("Novo jogo", 62, 24)
	n.pressed.connect(show_career)
	vb.add_child(n)
	var o := UiStyle.button("Opções", 56, 20)
	o.pressed.connect(show_options)
	vb.add_child(o)
	var cred := UiStyle.label("Feito em Godot 4 • mapa real do Caribe (Natural Earth) • modelos e texturas CC0 de Kenney, Quaternius e ambientCG", 13, Color(1, 1, 1, 0.55))
	cred.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cred.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cred.offset_left = -400
	cred.offset_right = 400
	cred.offset_top = -34
	add_child(cred)


func show_career() -> void:
	_clear()
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.panel(0.92))
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 30
	p.offset_right = -30
	p.offset_top = 20
	p.offset_bottom = -20
	add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(vb)
	vb.add_child(UiStyle.title("Escolha seu caminho", 32))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	var cards: Array = []
	for c in CAREERS:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := UiStyle.panel(0.6)
		sb.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", sb)
		var cv := VBoxContainer.new()
		card.add_child(cv)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		cv.add_child(h)
		h.add_child(UiStyle.flag_rect(Game.NATIONS[c[0]]["flag"], Vector2(60, 40)))
		var nl := UiStyle.label(c[1], 19, UiStyle.GOLD)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nl)
		var d := UiStyle.label(c[2], 14)
		d.custom_minimum_size = Vector2(0, 74)
		cv.add_child(d)
		cv.add_child(UiStyle.label("Início: " + c[3], 13, Color(0.8, 0.75, 0.6)))
		var b := UiStyle.button("Escolher", 44, 17)
		var nat: int = c[0]
		b.pressed.connect(func():
			_chosen = nat
			for k in cards.size():
				var s2: StyleBoxFlat = cards[k].get_theme_stylebox("panel")
				s2.border_color = UiStyle.GOLD if CAREERS[k][0] == nat else Color(0.78, 0.6, 0.3)
				s2.set_border_width_all(5 if CAREERS[k][0] == nat else 3)
			)
		cv.add_child(b)
		grid.add_child(card)
		cards.append(card)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	vb.add_child(bottom)
	var nl2 := UiStyle.label("Nome do capitão:", 18)
	nl2.autowrap_mode = TextServer.AUTOWRAP_OFF
	bottom.add_child(nl2)
	_name_edit = LineEdit.new()
	_name_edit.text = "Jack"
	_name_edit.custom_minimum_size = Vector2(260, 48)
	_name_edit.add_theme_font_size_override("font_size", 20)
	_name_edit.max_length = 20
	bottom.add_child(_name_edit)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	var back := UiStyle.button("Voltar", 50, 18)
	back.pressed.connect(show_main)
	bottom.add_child(back)
	var go := UiStyle.button("Zarpar!", 50, 22)
	go.custom_minimum_size.x = 200
	go.pressed.connect(func(): start_new.emit(_chosen, _name_edit.text))
	bottom.add_child(go)
	_chosen = 5
	var s0: StyleBoxFlat = cards[0].get_theme_stylebox("panel")
	s0.border_color = UiStyle.GOLD
	s0.set_border_width_all(5)


func show_options() -> void:
	_clear()
	var vb := _center_panel(520, 0.5)
	vb.add_child(UiStyle.title("Opções", 30))
	vb.add_child(UiStyle.label("Qualidade gráfica (vale ao reiniciar o jogo):", 17))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	vb.add_child(h)
	for q in 3:
		var b := UiStyle.button(["Baixa", "Média", "Alta"][q] + (" ✔" if Game.quality == q else ""), 50, 18)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			Game.quality = q
			Game.save_settings()
			_apply_quality()
			show_options())
		h.add_child(b)
	var m := UiStyle.button("Música: " + ("ligada" if Sfx.music_on else "desligada"), 50, 18)
	m.pressed.connect(func():
		Sfx.music_on = not Sfx.music_on
		Game.save_settings()
		show_options())
	vb.add_child(m)
	vb.add_child(UiStyle.label("Controles no computador: A/D leme, W/S velas, Q/E canhões, R munição, C câmera, Z luneta, F ação, M mapa, Esc pausa. Arraste com o mouse para olhar; roda do mouse para zoom.", 14, Color(0.8, 0.75, 0.6)))
	var back := UiStyle.button("Voltar", 50, 18)
	back.pressed.connect(func():
		if in_game:
			show_pause()
		else:
			show_main())
	vb.add_child(back)


static func _apply_quality() -> void:
	var vp := Engine.get_main_loop().root as Window
	if vp:
		vp.scaling_3d_scale = [0.6, 0.8, 1.0][Game.quality]
		vp.msaa_3d = Viewport.MSAA_DISABLED if Game.quality < 2 else Viewport.MSAA_2X


func show_pause() -> void:
	_clear()
	in_game = true
	var vb := _center_panel(440, 0.5)
	vb.add_child(UiStyle.title("Pausa", 32))
	vb.add_child(UiStyle.label("%s — %s\nNavios afundados: %d • Capturados: %d • Portos tomados: %d • Tesouros: %d" % [Game.captain_name, Game.career_title(),
		Game.stats["sunk"], Game.stats["captured"], Game.stats["ports"], Game.stats["treasures"]], 16))
	var r := UiStyle.button("Continuar", 56, 22)
	r.pressed.connect(func():
		visible = false
		resume.emit())
	vb.add_child(r)
	var s := UiStyle.button("Salvar jogo", 52, 18)
	s.pressed.connect(func():
		Game.save_game()
		Game.notify("Jogo salvo.", Color(0.7, 1, 0.7))
		s.text = "Salvo!")
	vb.add_child(s)
	var o := UiStyle.button("Opções", 52, 18)
	o.pressed.connect(show_options)
	vb.add_child(o)
	var q := UiStyle.button("Salvar e voltar ao menu", 52, 18)
	q.pressed.connect(func():
		Game.save_game()
		quit_to_menu.emit())
	vb.add_child(q)


func hide_menu() -> void:
	visible = false
	for c in get_children():
		c.queue_free()
