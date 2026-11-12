extends Node3D
## Fluxo do jogo: carregamento, menu, partida, porto, mapa, abordagens e naufrágio.

var world: World
var ctl: PlayerController
var hud: HUD
var menu: MenuUI
var port_ui: PortUI
var map_ui: MapUI
var playing := false
var _menu_cam: Camera3D
var _menu_t := 0.0
var _save_timer := 90.0
var _board_target: Ship
var _talk_target: Dictionary = {}

const MENU_POINT := Vector2(1150, 1300)


func _ready() -> void:
	MenuUI._apply_quality()
	menu = MenuUI.new()
	add_child(menu)
	menu.show_loading("Gerando o arquipélago...")
	menu.start_new.connect(_on_start_new)
	menu.continue_game.connect(_on_continue)
	menu.resume.connect(_on_resume)
	menu.quit_to_menu.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene())
	await get_tree().process_frame
	await get_tree().process_frame
	world = World.new()
	add_child(world)
	world.player_died.connect(_on_player_died)
	_menu_cam = Camera3D.new()
	_menu_cam.far = 12000.0
	add_child(_menu_cam)
	_menu_cam.current = true
	world.build_islands_near(MENU_POINT, 2600.0)
	# alguns navios para o cenário do menu
	for k in 3:
		var p := MENU_POINT + Vector2.from_angle(k * 2.1) * (180.0 + k * 90.0)
		var s := world.spawn_ship([3, 4, 1][k], [Game.ENG, Game.ESP, Game.PIR][k], Ship.Role.MERCHANT, p, k * 1.3)
		s.sail_level = 0.66
		s.sail_actual = 0.66
		s.speed = 4.0
	Sfx.start_ambience()
	menu.show_main()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest="):
			var path := "res://scripts/dev_autotest.gd"
			for b in OS.get_cmdline_user_args():
				if b.begins_with("--testscript="):
					path = b.split("=")[1]
			var t: Node = load(path).new()
			t.main = self
			add_child(t)


func _process(delta: float) -> void:
	if not playing:
		_menu_t += delta * 0.04
		if _menu_cam and _menu_cam.current:
			var c := Vector3(MENU_POINT.x, 0, MENU_POINT.y)
			_menu_cam.global_position = c + Vector3(cos(_menu_t) * 330.0, 26.0 + sin(_menu_t * 0.7) * 6.0, sin(_menu_t) * 330.0)
			_menu_cam.look_at(c + Vector3(0, 14, 0), Vector3.UP)
		return
	if get_tree().paused:
		return
	_save_timer -= delta
	if _save_timer <= 0.0:
		_save_timer = 90.0
		if world.player and not world.player.dead:
			Game.save_game()
	_update_action()


# ================================================================ início da partida
func _on_start_new(career: int, cname: String) -> void:
	Game.new_game(career, cname)
	_enter_game()


func _on_continue() -> void:
	if Game.load_game():
		_enter_game()
	else:
		Game.notify("Não foi possível carregar o jogo salvo.", Color(1, 0.4, 0.3))


func _enter_game() -> void:
	menu.show_loading("Içando as velas...")
	await get_tree().process_frame
	await get_tree().process_frame
	for s in world.ships.duplicate():
		world.remove_ship(s)
	world.proj.clear_all()
	for i in world.port_islands.size():
		world.port_islands[i].set_owner_flag(Game.port_owner[i])
		world.port_aggro[i] = false
	ctl = PlayerController.new()
	add_child(ctl)
	world.ctl = ctl
	world.spawn_player()
	world.build_islands_near(Game.player_pos, 3200.0)
	hud = HUD.new(ctl)
	add_child(hud)
	ctl.hud_ref = hud
	hud.open_map.connect(_open_map)
	hud.open_menu.connect(_open_pause)
	hud.action_pressed.connect(_on_action)
	port_ui = PortUI.new()
	add_child(port_ui)
	port_ui.closed.connect(_on_port_closed)
	port_ui.walk_town.connect(_walk_town)
	map_ui = MapUI.new()
	add_child(map_ui)
	map_ui.fast_travel.connect(_fast_travel)
	map_ui.closed.connect(func():
		get_tree().paused = false
		hud.modal = false)
	_menu_cam.current = false
	ctl.cam.current = true
	menu.hide_menu()
	playing = true
	var where := world.port_islands[world.nearest_port(Game.player_pos)].name
	Game.notify("%s, %s. Você está perto de %s." % [Game.captain_name, Game.career_title(), where], Color(1, 0.9, 0.6))
	Game.notify("Joystick: esquerda/direita vira o navio, para cima solta mais vela, para baixo recolhe.", Color(0.85, 0.95, 1))


# ================================================================ ações de contexto
func _update_action() -> void:
	var p := world.player
	if p == null:
		return
	if ctl.mode == PlayerController.Mode.HORSE:
		hud.set_action("dismount", "Desmontar")
		return
	if ctl.mode == PlayerController.Mode.FOOT:
		_talk_target = {}
		if ctl.digging > 0.0:
			hud.set_action("", "")
		elif ctl.near_treasure():
			hud.set_action("dig", "Cavar o tesouro!")
		elif ctl.town and ctl.town.hostile() and ctl.town.guards_alive() == 0 and Game.port_fort_hp[ctl.town.site.idx] <= 0.0 \
				and Game.port_owner[ctl.town.site.idx] != Game.career and ctl.foot_pos.distance_to(ctl.town.site.town_center) < 60.0:
			hud.set_action("conquer", "Tomar %s!" % ctl.town.site.name)
		elif ctl.town and ctl.town.hostile() and ctl.town.guards_alive() > 0:
			hud.set_action("back", "Recuar para o navio")
		elif ctl.near_horse():
			hud.set_action("mount", "Montar no cavalo")
		elif ctl.town and not ctl.town.nearest_person(ctl.foot_pos, 3.2).is_empty():
			_talk_target = ctl.town.nearest_person(ctl.foot_pos, 3.2)
			if _talk_target["kind"] == "especial":
				hud.set_action("romance", "Falar com %s" % _talk_target["name"])
			else:
				hud.set_action("talk", "Conversar")
		elif ctl.town and ctl.foot_pos.distance_to(ctl.town.site.tavern_pos) < 11.0:
			hud.set_action("tavern", "Entrar na taverna")
		else:
			hud.set_action("back", "Voltar ao navio")
		return
	if p.dead:
		hud.set_action("", "")
		return
	var b := world.boarding_candidate()
	if b:
		hud.set_action("board", "Abordar o %s" % b.def["name"])
		return
	var pi := world.nearest_port(p.pos2())
	var isl := world.port_islands[pi]
	if p.pos2().distance_to(isl.dock_point) < 190.0 and p.speed < 7.5:
		if Game.can_dock(pi):
			hud.set_action("dock", "Atracar em %s" % isl.name)
			return
		if Game.port_fort_hp[pi] <= 0.0:
			hud.set_action("invade", "Invadir %s" % isl.name)
			return
	var lp := world.landing_point()
	if lp != Vector2.INF and lp.distance_to(p.pos2()) < 160.0 and p.speed < 5.0:
		hud.set_action("land", "Desembarcar")
		return
	hud.set_action("", "")


func _on_action(id: String) -> void:
	var p := world.player
	match id:
		"dig":
			ctl.start_dig()
		"back":
			ctl.return_to_ship()
		"land":
			var lp := world.landing_point()
			if lp != Vector2.INF:
				ctl.go_ashore(lp)
		"dock":
			_dock(world.nearest_port(p.pos2()))
		"invade":
			_invade(world.nearest_port(p.pos2()))
		"board":
			_board(world.boarding_candidate())
		"mount":
			ctl.mount(ctl.near_horse())
		"dismount":
			ctl.dismount()
		"conquer":
			if ctl.town:
				var ci := ctl.town.site.idx
				var res := world.capture_port(ci, 0.25)
				if res["win"]:
					ctl.town.alarm = false
					Sfx.play("bell")
					hud.show_dialog("Cidade tomada!", "%s agora pertence a %s! Saque: %d moedas." % [ctl.town.site.name, Game.NATIONS[Game.career]["name"], res.get("gold", 0)], [["Viva!", Callable()]])
				else:
					hud.show_dialog("Resistência", "Os últimos defensores repeliram você. Perdeu %d homens." % res["lost"], [["Recuar", Callable()]])
		"talk":
			_talk()
		"romance":
			if ctl.town:
				_romance(ctl.town.site.idx)
		"tavern":
			if ctl.town:
				var ti := ctl.town.site.idx
				if Game.can_dock(ti):
					hud.release_all()
					hud.modal = true
					get_tree().paused = true
					port_ui.open(ti, "taverna")
				else:
					Game.notify("O taverneiro olha torto: \"Aqui não servimos inimigos!\"", Color(1, 0.5, 0.4))


func _dock(i: int) -> void:
	var p := world.player
	var isl := world.port_islands[i]
	var dir := Game.dock_offset(i)
	var pos := isl.dock_point + dir * 25.0
	p.global_position = Vector3(pos.x, p.global_position.y, pos.y)
	p.yaw = atan2(-dir.x, -dir.y)
	p.speed = 0.0
	ctl.sail_target = 0.0
	p.sail_level = 0.0
	p.sail_actual = 0.0
	ctl.steer_input = 0.0
	# missão de entrega concluída neste porto?
	Game.player_pos = pos
	hud.release_all()
	hud.modal = true
	get_tree().paused = true
	port_ui.open(i)


func _talk() -> void:
	if _talk_target.is_empty() or ctl.town == null:
		return
	var nm: String = _talk_target["name"]
	var line := ctl.town.random_line()
	if _talk_target["kind"] == "guarda":
		var owner: int = Game.port_owner[ctl.town.site.idx]
		if Game.nation_hostile_to_player(owner):
			line = "Alto lá! Eu conheço essa cara... é melhor voltar para o seu navio antes que eu chame o capitão da guarda!"
		else:
			line = ["Circulando, cidadão. Ordens do governador.", "Tudo calmo hoje, capitão.", "O forte está bem guarnecido. Ninguém toma esta cidade."][randi() % 3]
	hud.show_dialog(nm, line, [["Até mais", Callable()]])


## Romance com a pessoa especial de cada cidade: conversar, presentear, jantar e casar.
func _romance(i: int) -> void:
	var nm := Game.romance_name(i)
	var a := Game.affection(i)
	var opts := []
	var mood := "%s olha para você com curiosidade." % nm
	var key := str(i)
	if Game.spouse == i:
		mood = "%s corre para abraçar você: \"Você voltou!\"" % nm
		# ciúme: rumores de outros romances chegam ao porto
		if int(Game.romance_day.get(key + "c", -1)) != Game.day:
			Game.romance_day[key + "c"] = Game.day
			for k in Game.romance:
				if k != key and int(Game.romance[k]) >= 60 and randf() < 0.4:
					Game.add_affection(i, -15)
					mood = "%s cruza os braços: \"Ouvi falar de %s, em %s... Quem é?\" (ciúme: afeto -15)" % [nm, Game.romance_name(int(k)), world.port_islands[int(k)].name]
					break
		opts.append(["Beijar", func(): _couple_scene(i, "kiss")])
		opts.append(["Dançar na praça", func(): _couple_scene(i, "dance")])
		opts.append(["Jantar na taverna (150 moedas)", func(): _date_dinner(i)])
		opts.append(["Passar a noite em casa (descansar até de manhã)", func(): _couple_scene(i, "night")])
		_quest_options(i, opts)
		opts.append(["Até logo", Callable()])
		hud.show_dialog(nm, mood + "  (afeto %d/100)" % Game.affection(i) + _quest_text(i), opts)
		return
	if a >= 80:
		mood = "%s não tira os olhos de você. O afeto é evidente." % nm
	elif a >= 50:
		mood = "%s fica feliz em ver você e sorri." % nm
	elif a >= 20:
		mood = "%s cumprimenta você com simpatia." % nm
	var talked: bool = int(Game.romance_day.get(key, -1)) == Game.day
	opts.append(["Conversar" + (" (já conversaram hoje)" if talked else ""), func():
		if talked:
			Game.notify("%s: \"Volte amanhã, capitão.\"" % nm, Color(1, 0.8, 0.85))
			return
		Game.romance_day[key] = Game.day
		Game.add_affection(i, 6)
		Game.notify("Vocês conversam sobre o mar e as estrelas. (afeto %d/100)" % Game.affection(i), Color(1, 0.8, 0.85))])
	opts.append(["Dar um presente (300 moedas)", func():
		if Game.gold < 300:
			Game.notify("Você não tem moedas suficientes.", Color(1, 0.6, 0.4))
			return
		Game.gold -= 300
		Game.add_affection(i, 12)
		Sfx.play("coin")
		Game.notify("%s adorou o presente! (afeto %d/100)" % [nm, Game.affection(i)], Color(1, 0.8, 0.85))])
	opts.append(["Jantar na taverna (150 moedas)", func(): _date_dinner(i)])
	if a >= 30:
		opts.append(["Dançar na praça", func(): _couple_scene(i, "dance")])
	if a >= 50:
		opts.append(["Beijar", func(): _couple_scene(i, "kiss")])
	if a >= 80:
		opts.append(["Passar a noite juntos", func(): _couple_scene(i, "night")])
	if a >= 20:
		_quest_options(i, opts)
	if a >= 100 and Game.spouse < 0:
		opts.append(["Pedir em casamento", func():
			Game.spouse = i
			Game.morale = minf(100.0, Game.morale + 30.0)
			Sfx.play("bell")
			Game.notify("%s disse SIM! A cidade inteira comemora o casamento." % nm, Color(1, 0.85, 0.3))
			Game.save_game()])
	opts.append(["Até logo", Callable()])
	hud.show_dialog(nm, mood + "  (afeto %d/100)" % a + _quest_text(i), opts)


## Pedido especial da pessoa amada: trazer mercadorias de outro porto (sobe muito o afeto).
func _quest_text(i: int) -> String:
	var q: Dictionary = Game.romance_quest.get(str(i), {})
	if q.is_empty():
		return ""
	return "\nPedido: %d %s (no porão: %d)" % [q["qty"], Game.good_name(q["good"]), int(Game.cargo.get(q["good"], 0))]


func _quest_options(i: int, opts: Array) -> void:
	var nm := Game.romance_name(i)
	var q: Dictionary = Game.romance_quest.get(str(i), {})
	if q.is_empty():
		opts.append(["Perguntar o que deseja", func():
			var g: Dictionary = Game.GOODS[randi() % Game.GOODS.size()]
			var n := randi_range(4, 9)
			Game.romance_quest[str(i)] = {"good": g["id"], "qty": n}
			Game.notify("%s sonha com %d %s. Traga no porão do navio e entregue em mãos." % [nm, n, g["name"]], Color(1, 0.8, 0.85))])
	elif int(Game.cargo.get(q["good"], 0)) >= int(q["qty"]):
		opts.append(["Entregar %d %s" % [q["qty"], Game.good_name(q["good"])], func():
			Game.cargo[q["good"]] = int(Game.cargo[q["good"]]) - int(q["qty"])
			if int(Game.cargo[q["good"]]) <= 0:
				Game.cargo.erase(q["good"])
			Game.romance_quest.erase(str(i))
			Game.add_affection(i, 25)
			Sfx.play("bell", -6.0)
			Game.notify("%s se emociona com o presente! (afeto %d/100)" % [nm, Game.affection(i)], Color(1, 0.85, 0.5))])


func _date_dinner(i: int) -> void:
	if ctl.cutscene:
		return
	if Game.gold < 150:
		hud.close_dialog()
		Game.notify("Você não tem moedas suficientes.", Color(1, 0.6, 0.4))
		return
	Game.gold -= 150
	Game.morale = minf(100.0, Game.morale + 4.0)
	_couple_scene(i, "dinner")


## Cenas do casal (sem nada explícito): "kiss" beijo com a câmera girando e corações; "dance" dança na praça;
## "dinner" jantar à luz de vela na porta da taverna; "night" beijo e a tela escurece até a manhã seguinte.
func _couple_scene(i: int, kind: String) -> void:
	hud.close_dialog()
	if ctl.cutscene or ctl.town == null or ctl.town.special.is_empty() or ctl.avatar.is_empty():
		return
	var nm := Game.romance_name(i)
	var sp: Dictionary = ctl.town.special["p"]
	var sroot: Node3D = sp["root"]
	var home := sroot.global_position
	var home_yaw := sroot.rotation.y
	var spos := home
	var ps: PortSite = ctl.town.site
	var u3 := Vector3(ps.dir.x, 0, ps.dir.y)
	if kind == "dance":
		spos = ps.town_center + u3 * 7.0
		spos.y = world.walk_height(spos.x, spos.z)
	var to_cam := (ctl.foot_pos - home)
	to_cam.y = 0.0
	if kind != "kiss" and kind != "night" or to_cam.length() < 0.1:
		to_cam = Vector3(-u3.z, 0, u3.x)
	var fwd := to_cam.normalized()
	var gap := 0.5 if kind == "kiss" or kind == "night" else (1.0 if kind == "dance" else 1.5)
	var table: Node3D = null
	if kind == "dinner":
		table = _dinner_table(spos + fwd * gap * 0.5, fwd)
		world.add_child(table)
	sroot.global_position = spos
	sroot.rotation.y = atan2(-fwd.x, -fwd.z)
	ctl.foot_pos = spos + fwd * gap
	ctl.avatar_yaw = atan2(fwd.x, fwd.z)
	if kind == "dinner":
		# sentados frente a frente, cada um num banco
		sroot.global_position = spos + Vector3(0, -0.09, 0) + fwd * 0.33
		ctl.foot_pos = spos + fwd * gap + Vector3(0, -0.09, 0) - fwd * 0.33
	var anim := "Idle"
	match kind:
		"dance":
			anim = "Dance"
		"dinner":
			anim = "Sitting"
	sp["cur"] = ""
	Assets.play(sp, anim, 0.8 if kind == "dance" else 1.0)
	ctl.cutscene = true
	ctl.cutscene_anim = anim
	ctl.move_vec = Vector2.ZERO
	hud.modal = true
	hud.root.visible = false
	if ctl.avatar.has("sword") and is_instance_valid(ctl.avatar["sword"]):
		ctl.avatar["sword"].visible = false
	var m1: Node3D = ctl.avatar["model"]
	var m2: Node3D = sp["model"]
	if kind == "kiss" or kind == "night":
		var tw := create_tween().set_parallel(true)
		tw.tween_property(m1, "rotation:x", 0.12, 1.2)
		tw.tween_property(m2, "rotation:x", 0.1, 1.2)
	# câmera de cinema girando devagar em volta do casal
	var cam := Camera3D.new()
	cam.fov = 40.0 if kind == "kiss" or kind == "night" else 50.0
	world.add_child(cam)
	var mid := spos + fwd * gap * 0.5 + Vector3(0, 1.45 if kind != "dinner" else 1.0, 0)
	var dist := 2.4 if kind == "kiss" or kind == "night" else 4.2
	var base_ang := atan2(fwd.z, fwd.x) + PI * 0.5
	var orbit := func(t: float) -> void:
		var a := base_ang + t
		cam.global_position = mid + Vector3(cos(a), 0, sin(a)) * dist + Vector3(0, 0.25, 0)
		cam.look_at(mid, Vector3.UP)
	orbit.call(0.0)
	cam.current = true
	var dur := 5.0 if kind != "night" else 3.4
	create_tween().tween_method(orbit, 0.0, 0.9, dur)
	Sfx.play("bell", -14.0)
	for k in 6:
		var h := Label3D.new()
		h.text = "♥"
		h.font_size = 96
		h.pixel_size = 0.002
		h.modulate = Color(1, 0.25, 0.4)
		h.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		h.no_depth_test = true
		world.add_child(h)
		h.global_position = mid + Vector3(randf_range(-0.35, 0.35), 0.25, randf_range(-0.35, 0.35))
		var ht := create_tween()
		ht.tween_interval(0.6 + k * 0.5)
		ht.tween_property(h, "global_position", h.global_position + Vector3(0, 0.9, 0), 1.6)
		ht.parallel().tween_property(h, "modulate:a", 0.0, 1.6)
		ht.tween_callback(h.queue_free)
	await get_tree().create_timer(dur).timeout
	var once := int(Game.romance_day.get(str(i) + kind, -1)) != Game.day
	Game.romance_day[str(i) + kind] = Game.day
	match kind:
		"night":
			var layer := CanvasLayer.new()
			layer.layer = 50
			add_child(layer)
			var black := ColorRect.new()
			black.color = Color(0, 0, 0, 0)
			black.set_anchors_preset(Control.PRESET_FULL_RECT)
			layer.add_child(black)
			var lbl := Label.new()
			lbl.text = "Mais tarde, naquela noite..."
			lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 30)
			lbl.modulate = Color(1, 0.9, 0.8, 0)
			layer.add_child(lbl)
			var ft := create_tween()
			ft.tween_property(black, "color:a", 1.0, 1.2)
			ft.tween_property(lbl, "modulate:a", 1.0, 0.8)
			await ft.finished
			await get_tree().create_timer(1.8).timeout
			Game.time_of_day = 0.27
			Game.day += 1
			Game.morale = minf(100.0, Game.morale + 25.0)
			Game.add_affection(i, 8)
			ctl.hp = 100.0
			world._update_environment(true)
			lbl.text = "Ao amanhecer, ao lado de %s." % nm
			await get_tree().create_timer(1.6).timeout
			var bt := create_tween()
			bt.tween_property(lbl, "modulate:a", 0.0, 0.6)
			bt.tween_property(black, "color:a", 0.0, 1.2)
			await bt.finished
			layer.queue_free()
			Game.notify("Uma noite inesquecível com %s. Você e a tripulação descansaram (+moral)." % nm, Color(1, 0.8, 0.85))
		"kiss":
			if once:
				Game.add_affection(i, 5)
			Game.notify("%s retribui o beijo e sorri. (afeto %d/100)" % [nm, Game.affection(i)], Color(1, 0.8, 0.85))
		"dance":
			if once:
				Game.add_affection(i, 8)
				Game.morale = minf(100.0, Game.morale + 5.0)
			Game.notify("Vocês dançaram na praça ao som da rabeca. (afeto %d/100)" % Game.affection(i), Color(1, 0.8, 0.85))
		"dinner":
			if once:
				Game.add_affection(i, 10)
			Game.notify("Um jantar à luz de velas com %s. (afeto %d/100)" % [nm, Game.affection(i)], Color(1, 0.8, 0.85))
	# rumores: namorar outra pessoa sendo casado deixa o cônjuge com ciúme
	if Game.spouse >= 0 and Game.spouse != i and once:
		Game.add_affection(Game.spouse, -8)
		Game.notify("Rumores devem chegar a %s..." % Game.romance_name(Game.spouse), Color(1, 0.6, 0.5))
	var back := create_tween().set_parallel(true)
	back.tween_property(m1, "rotation:x", 0.0, 0.6)
	back.tween_property(m2, "rotation:x", 0.0, 0.6)
	cam.queue_free()
	if table:
		table.queue_free()
	if is_instance_valid(sroot):
		sroot.global_position = home
		sroot.rotation.y = home_yaw
		sp["cur"] = ""
		Assets.play(sp, "Idle")
	if kind == "dinner":
		ctl.foot_pos = home + fwd * 1.6
	ctl.foot_pos.y = world.walk_height(ctl.foot_pos.x, ctl.foot_pos.z)
	ctl.cam.current = true
	ctl.cutscene = false
	ctl.cutscene_anim = ""
	if ctl.avatar.has("sword") and is_instance_valid(ctl.avatar["sword"]):
		ctl.avatar["sword"].visible = true
	hud.root.visible = true
	hud.modal = false


## Mesa com toalha, dois bancos, pratos, garrafa e uma vela acesa.
func _dinner_table(c: Vector3, fwd: Vector3) -> Node3D:
	var root := Node3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var b := Basis(Vector3.UP, atan2(fwd.x, fwd.z))
	var wood := Color(0.42, 0.28, 0.17)
	c.y = world.walk_height(c.x, c.z)
	Structures.box(st, Transform3D(b, c + Vector3(0, 0.74, 0)), Vector3(0.9, 0.05, 0.75), Color(0.93, 0.91, 0.86), Structures.PLAIN)
	for sx in [-0.38, 0.38]:
		for sz in [-0.3, 0.3]:
			Structures.box(st, Transform3D(b, c + b * Vector3(sx, 0.36, sz)), Vector3(0.06, 0.72, 0.06), wood, Structures.WOOD)
	for s in [-1.0, 1.0]:
		var sc: Vector3 = c + b * Vector3(0, 0, s * 0.75)
		Structures.box(st, Transform3D(b, sc + Vector3(0, 0.43, 0)), Vector3(0.45, 0.06, 0.4), wood, Structures.WOOD)
		Structures.box(st, Transform3D(b, sc + Vector3(0, 0.2, 0)), Vector3(0.36, 0.4, 0.3), wood.darkened(0.2), Structures.WOOD)
		Structures.cyl(st, c + b * Vector3(0, 0.765, s * 0.22), c + b * Vector3(0, 0.78, s * 0.22), 0.13, 0.13, Color(0.9, 0.88, 0.82), Structures.PLAIN, 12)
	Structures.cyl(st, c + b * Vector3(0.25, 0.765, 0), c + b * Vector3(0.25, 1.0, 0), 0.045, 0.03, Color(0.15, 0.3, 0.12), Structures.DARK, 8)
	Structures.cyl(st, c + b * Vector3(-0.2, 0.765, 0), c + b * Vector3(-0.2, 0.92, 0), 0.025, 0.025, Color(0.95, 0.93, 0.85), Structures.PLAIN, 6)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Structures.material()
	root.add_child(mi)
	var flame := OmniLight3D.new()
	flame.light_color = Color(1.0, 0.7, 0.35)
	flame.light_energy = 1.6
	flame.omni_range = 4.0
	flame.position = c + b * Vector3(-0.2, 0.98, 0)
	root.add_child(flame)
	var fl := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.02
	sm.height = 0.05
	fl.mesh = sm
	fl.material_override = ShipBuilder.glow_material()
	fl.position = c + b * Vector3(-0.2, 0.95, 0)
	root.add_child(fl)
	return root


## Viagem rápida até um porto amigo (como no Black Flag): o tempo passa conforme a distância.
func _fast_travel(i: int) -> void:
	get_tree().paused = false
	hud.modal = false
	var p := world.player
	if p == null or p.dead or ctl.on_land():
		Game.notify("Volte ao navio para viajar.", Color(1, 0.6, 0.4))
		return
	for s in world.ships:
		if not s.is_player and not s.dead and world.hostile(p, s) and s.pos2().distance_to(p.pos2()) < 900.0:
			Game.notify("Há inimigos por perto! Não dá para viajar agora.", Color(1, 0.4, 0.3))
			return
	var ps := world.port_islands[i]
	var dist := p.pos2().distance_to(ps.dock_point)
	var secs := dist / 9.0
	var days_before := Game.day
	Game.advance_time(secs)
	menu.show_loading("Navegando até %s..." % ps.name)
	await get_tree().process_frame
	await get_tree().process_frame
	for s in world.ships.duplicate():
		if not s.is_player:
			world.remove_ship(s)
	world.proj.clear_all()
	var dp := world.dock_spawn(i)
	p.global_position = Vector3(dp.x, 0.0, dp.y)
	p.yaw = atan2(ps.dir.y, -ps.dir.x)
	p.speed = 0.0
	ctl.sail_target = 0.0
	Game.player_pos = dp
	world.build_islands_near(dp, 3200.0)
	world._update_environment(true)
	menu.hide_menu()
	Game.notify("Chegou a %s após %d dia(s) de viagem." % [ps.name, Game.day - days_before], Color(0.85, 0.95, 1))
	Game.save_game()


func _walk_town(i: int) -> void:
	port_ui.visible = false
	get_tree().paused = false
	hud.modal = false
	var ps := world.port_islands[i]
	ctl.go_ashore(Vector2(ps.pier_end.x, ps.pier_end.z))
	ctl.foot_yaw = atan2(ps.dir.x, ps.dir.y)
	Game.notify("Bem-vindo a %s! Converse com os moradores, visite a taverna ou pegue um cavalo no estábulo." % ps.name, Color(0.9, 0.95, 1))


func _on_port_closed() -> void:
	get_tree().paused = false
	hud.modal = false
	world.player.apply_player_stats()


func _invade(i: int) -> void:
	var isl := world.port_islands[i]
	var garrison := 120 + Game.rank_index() * 30
	hud.show_dialog("Invadir %s?" % isl.name,
		"O forte foi silenciado. Sua tripulação (%d homens) vai desembarcar contra a guarnição (cerca de %d soldados). Se vencer, a cidade passa para %s." % [
			world.player.crew, garrison, Game.NATIONS[Game.career]["name"]],
		[["Ao ataque!", func():
			var res := world.capture_port(i)
			if res["win"]:
				hud.show_dialog("Vitória!", "%s agora pertence a %s! Saque: %d moedas. Você perdeu %d homens." % [isl.name, Game.NATIONS[Game.career]["name"], res.get("gold", 0), res["lost"]],
					[["Entrar na cidade", func(): _dock(i)]])
				Sfx.play("bell")
			else:
				hud.show_dialog("Derrota", "A guarnição repeliu o ataque. Você perdeu %d homens." % res["lost"], [["Recuar", Callable()]])],
		["Cancelar", Callable()]])


func _board(t: Ship) -> void:
	if t == null:
		return
	_board_target = t
	var p := world.player
	hud.show_dialog("Abordagem!", "Lançar os ganchos sobre o %s?\nSua tripulação: %d  •  Tripulação inimiga: %d" % [t.display_name(), p.crew, t.crew],
		[["Abordar!", _do_board], ["Cancelar", Callable()]])


func _do_board() -> void:
	var t := _board_target
	if t == null or not is_instance_valid(t) or t.dead:
		return
	var p := world.player
	var enemy := t.crew if not t.surrendered else int(t.crew * 0.2)
	world.on_ship_attacked(t, p, true)
	hud.close_dialog()
	# luta no convés em tempo real (o capitão e a tripulação contra os marujos inimigos)
	ctl.start_boarding(t, enemy, func(win: bool): _board_done(t, enemy, win))


func _board_done(t: Ship, enemy: int, win: bool) -> void:
	ctl.end_boarding()
	if t == null or not is_instance_valid(t) or t.dead:
		return
	var p := world.player
	# as baixas do resto da tripulação seguem a luta do capitão
	var res := world.resolve_boarding(enemy, 99.0 if win else 0.01)
	if not win:
		p.take_raw_damage(p.max_hp * 0.08)
		t.crew = maxi(1, t.crew - int(res["killed"] * 0.3))
		hud.show_dialog("Repelidos!", "A tripulação inimiga resistiu. Você perdeu %d homens." % res["lost"], [["Recuar", Callable()]])
		return
	t.crew = 0
	t.surrendered = true
	var body := "O %s se rendeu! Você perdeu %d homens.\nNo porão: %d moedas%s." % [t.display_name(), res["lost"], t.gold,
		("" if t.cargo.is_empty() else " e " + ", ".join(t.cargo.keys().map(func(k): return "%d %s" % [t.cargo[k], Game.good_name(k)])))]
	var opts := [
		["Saquear e deixar partir", func():
			_show_loot(world.board_loot(t))],
		["Saquear e afundar", func():
			_show_loot(world.board_loot(t))
			t.die(false)],
	]
	if p.crew >= 10:
		opts.append(["Tomar o navio (%s)" % t.def["name"], func():
			_show_loot(world.board_loot(t))
			world.take_over_ship(t)])
	hud.show_dialog("Vitória na abordagem!", body, opts)
	Sfx.play("bell", -4.0)


func _show_loot(got: Dictionary) -> void:
	var txt := "Saque: +%d moedas" % got["gold"]
	for k in got["cargo"]:
		txt += ", %d %s" % [got["cargo"][k], Game.good_name(k)]
	Game.notify(txt, Color(1, 0.9, 0.4))
	Sfx.play("coin")


# ================================================================ menus
func _open_map() -> void:
	hud.release_all()
	hud.modal = true
	get_tree().paused = true
	map_ui.open()


func _open_pause() -> void:
	hud.release_all()
	hud.modal = true
	get_tree().paused = true
	menu.show_pause()


func _on_resume() -> void:
	get_tree().paused = false
	hud.modal = false


func _on_player_died() -> void:
	hud.show_dialog("Naufrágio!", "Seu navio foi para o fundo do mar. Você e alguns marujos foram resgatados por pescadores.\nVocê perde a carga, as melhorias e metade do ouro.",
		[["Recomeçar no porto mais próximo", func(): world.respawn_after_sinking()]])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and playing and not get_tree().paused:
		_open_pause()
	elif what == NOTIFICATION_APPLICATION_PAUSED and playing:
		Game.save_game()
