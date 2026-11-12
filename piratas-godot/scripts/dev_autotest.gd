extends Node
## Roteiro de teste automático (só roda com: godot -- --autotest=DIR [--career=N]).
## Inicia uma partida, executa ações e salva capturas de tela em DIR.

var main: Node
var out_dir := ""
var career := 5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest="):
			out_dir = a.split("=")[1]
		elif a.begins_with("--career="):
			career = int(a.split("=")[1])
	_run()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(out_dir.path_join(name + ".png"))
		print("SHOT ", name)


func _run() -> void:
	while main.world == null:
		await _wait(0.2)
	await _wait(1.5)
	await _shot("00_menu")
	main.menu.show_career()
	await _wait(0.5)
	await _shot("01_carreira")
	main._on_start_new(career, "Teste")
	while not main.playing:
		await _wait(0.2)
	var w: World = main.world
	Game.time_of_day = 0.66
	w._update_environment()
	await _wait(2.0)
	await _shot("02_inicio")
	main.ctl.sail_target = 1.0
	await _wait(6.0)
	await _shot("03_velejando")
	var y0: float = main.world.player.yaw
	main.ctl.steer_touch = true
	main.ctl.steer_input = 1.0
	main.ctl.orbit_pitch = -0.55
	await _wait(9.0)
	await _shot("03b_curva")
	main.ctl.orbit_pitch = -0.2
	print("Curva: yaw ", y0, " -> ", main.world.player.yaw, " vel ", main.world.player.speed)
	main.ctl.steer_input = 0.0
	main.ctl.steer_touch = false
	main.ctl.cycle_camera()
	Game.time_of_day = 0.45
	w._update_environment()
	await _wait(1.0)
	await _shot("04_timao")
	Game.time_of_day = 0.66
	w._update_environment()
	main.ctl.cycle_camera()
	# inimigo ao lado para testar combate
	var p := w.player
	var side := Vector2(-p.forward().y, p.forward().x)
	var ep := p.pos2() + side * 160.0 + p.forward() * 20.0
	var e := w.spawn_ship(3, Game.ESP if Game.career != Game.ESP else Game.ENG, Ship.Role.PATROL, ep, p.yaw)
	e.aggro_player = true
	main.ctl.orbit_yaw = -1.2
	await _wait(1.0)
	p.reload[1.0] = 0.0
	p.fire(1.0)
	await _wait(0.6)
	await _shot("05_disparo")
	await _wait(2.5)
	await _shot("06_impacto")
	print("Inimigo HP: ", e.hp, "/", e.max_hp, " velas ", e.sail_hp)
	for k in 6:
		p.reload[1.0] = 0.0
		p.reload[-1.0] = 0.0
		p.fire(1.0)
		await _wait(1.5)
	print("Inimigo HP depois: ", e.hp, " morto=", e.dead)
	# armas extras: morteiro num navio distante, corrente pela proa e segurar-se
	Game.upgrades["morteiro"] = 2
	var far := w.spawn_ship(3, Game.ESP if Game.career != Game.ESP else Game.ENG, Ship.Role.MERCHANT, w._find_water_near(p.pos2() + p.forward() * 300.0), p.yaw)
	far.aggro_player = true
	far.surrendered = true
	far.speed = 0.0
	var save_speed := p.speed
	p.speed = 0.0
	main.ctl.sail_target = 0.0
	var mt := p.mortar_target()
	print("Morteiro mira em ", mt, " | longe ", far.global_position, " | perto ", e.global_position, " hp perto ", e.hp)
	var hp_e0 := e.hp
	main.hud._mortar()
	main.ctl.orbit_pitch = -0.5
	await _wait(1.5)
	await _shot("06b_morteiro")
	await _wait(6.0)
	print("Morteiro: longe HP ", far.hp, "/", far.max_hp, "  perto HP ", hp_e0, " -> ", e.hp)
	p.bow_cd = 0.0
	main.hud._bow()
	main.hud._brace()
	await _wait(1.5)
	print("Proa+segurar: brace_t ", p.brace_t, " bow_cd ", p.bow_cd)
	main.ctl.orbit_pitch = -0.2
	e.hp = 1.0
	e.take_hit(30.0, 0, p, e.global_position, true, Game.career)
	await _wait(3.0)
	await _shot("07_naufragio")
	# noite
	Game.time_of_day = 0.93
	w._update_environment()
	await _wait(1.5)
	await _shot("08_noite")
	Game.time_of_day = 0.5
	w.storm = 1.0
	w._update_environment()
	await _wait(1.5)
	await _shot("09_tempestade")
	w.storm = 0.0
	w._storm_target = 0.0
	w._update_environment()
	# porto
	var pi := w.nearest_port(p.pos2())
	main._dock(pi)
	await _wait(0.8)
	await _shot("10_porto")
	main.port_ui._show_tab("estaleiro")
	await _wait(0.4)
	await _shot("11_estaleiro")
	main.port_ui._show_tab("missoes")
	await _wait(0.4)
	await _shot("12_missoes")
	main.port_ui._show_tab("governo")
	await _wait(0.4)
	main.port_ui._close()
	await _wait(0.5)
	main._open_map()
	await _wait(0.6)
	await _shot("13_mapa")
	main.map_ui.visible = false
	get_tree().paused = false
	main.hud.modal = false
	# passear pela cidade
	var isl := w.port_islands[pi]
	main._walk_town(pi)
	Game.soldiers = 6
	main.ctl._spawn_followers()
	await _wait(2.0)
	main.ctl.foot_yaw = atan2(isl.dir.x, isl.dir.y)
	await _wait(1.0)
	await _shot("14_cidade_a_pe")
	# conversar com a pessoa especial
	var sp: Dictionary = main.ctl.town.special
	var spos: Vector3 = sp["p"]["root"].global_position
	main.ctl.foot_pos = spos + Vector3(isl.dir.x, 0, isl.dir.y) * 2.5
	var to: Vector3 = spos - main.ctl.foot_pos
	main.ctl.foot_yaw = atan2(-to.x, -to.z)
	main.ctl.foot_pitch = -0.15
	await _wait(1.0)
	await _shot("14b_pessoa")
	main._romance(isl.idx)
	await _wait(0.6)
	await _shot("14c_romance")
	main.hud.close_dialog()
	# taverna
	main.port_ui.open(isl.idx, "taverna")
	get_tree().paused = true
	await _wait(0.5)
	await _shot("14d_taverna")
	main.port_ui.visible = false
	get_tree().paused = false
	# cavalo
	var h: Horse = main.ctl.town.horses[0]
	main.ctl.foot_pos = h.global_position + Vector3(2, 0, 0)
	main.ctl.mount(h)
	main.ctl.move_vec = Vector2(0, 1)
	await _wait(4.0)
	await _shot("14e_cavalo")
	print("Cavalo andou até ", h.global_position, " vel ", h.speed)
	main.ctl.move_vec = Vector2.ZERO
	main.ctl.dismount()
	# roupa nova, mosquete e tiroteio numa cidade que fica hostil
	main.ctl.foot_yaw = atan2(isl.dir.x, isl.dir.y)
	Game.outfit = 2
	Game.coat_color = 1
	Game.hat = 1
	main.ctl._make_avatar()
	await _wait(0.5)
	main.ctl.town.provoke()
	await _wait(3.0)
	await _shot("16a_tiroteio")
	for k in 6:
		main.ctl.musket_cd = 0.0
		var g: Dictionary = main.ctl.town.nearest_enemy(main.ctl.foot_pos, 200.0)
		if g.is_empty():
			break
		var gp: Vector3 = g["p"]["root"].global_position
		var tv: Vector3 = gp - main.ctl.foot_pos
		main.ctl.foot_yaw = atan2(-tv.x, -tv.z)
		main.ctl.foot_pos = gp - tv.normalized() * 20.0
		main.ctl.shoot_musket()
		await _wait(0.7)
	await _shot("16b_mosquete")
	print("Guardas vivos: ", main.ctl.town.guards_alive(), " vida do capitão: ", main.ctl.hp)
	main.ctl.hp = 100.0
	main.ctl.town.alarm = false
	# vista do forte e das casas
	var fpos: Vector3 = isl.fort_pos
	var tcv: Vector3 = isl.town_center
	var view := tcv.lerp(fpos, 0.25)
	main.ctl.foot_pos = Vector3(view.x, w.walk_height(view.x, view.z), view.z)
	var tf: Vector3 = fpos - main.ctl.foot_pos
	main.ctl.foot_yaw = atan2(-tf.x, -tf.z)
	main.ctl.foot_pitch = 0.12
	await _wait(1.5)
	await _shot("16_forte")
	main.ctl.foot_pos = Vector3(tcv.x, w.walk_height(tcv.x, tcv.z), tcv.z) + Vector3(isl.dir.x, 0, isl.dir.y) * 6.0
	main.ctl.foot_yaw = atan2(isl.dir.x, isl.dir.y)
	main.ctl.foot_pitch = 0.05
	await _wait(1.0)
	await _shot("17_praca")
	Game.treasure = {"pos": Vector2(main.ctl.foot_pos.x, main.ctl.foot_pos.z) + Vector2(2, 0), "island": isl.name}
	main.ctl.start_dig()
	await _wait(3.2)
	print("Ouro após cavar: ", Game.gold)
	main.ctl.return_to_ship()
	main.ctl.foot_yaw = 0
	# vista da cidade a partir do mar
	main.ctl.mode = PlayerController.Mode.THIRD
	main.ctl.orbit_yaw = PI
	main.ctl.orbit_pitch = -0.08
	await _wait(1.5)
	await _shot("15_cidade")
	# reino e guerra
	Game.conquered = [pi, (pi + 1) % 19]
	Game.port_owner[pi] = Game.career
	Game.port_owner[(pi + 1) % 19] = Game.career
	Game.gold += 20000
	main.port_ui.open(pi, "governo")
	get_tree().paused = true
	await _wait(0.5)
	await _shot("18_governo")
	main.port_ui._found("Reino das Antilhas")
	await _wait(0.5)
	await _shot("19_reino")
	main.port_ui.visible = false
	get_tree().paused = false
	print("Carreira: ", Game.career_title(), " portos do reino: ", Game.kingdom_ports())
	w._start_war()
	w.war["port"] = w.nearest_port(p.pos2())
	await _wait(1.0)
	await _shot("20_guerra")
	print("Guerra: ", w.war.get("att", -1), " em ", w.war.get("port", -1), " frotas ", w.war.get("spawned", false))
	print("Navios: ", w.ships.size(), " FPS: ", Engine.get_frames_per_second())
	print("AUTOTEST OK")
	get_tree().quit()
