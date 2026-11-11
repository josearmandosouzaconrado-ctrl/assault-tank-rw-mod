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
	main.ctl.cycle_camera()
	await _wait(1.0)
	await _shot("04_timao")
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
	# desembarque
	var isl := w.port_islands[pi]
	var lp := isl.find_coast(Game.dock_offset(pi).rotated(1.2)) - Game.dock_offset(pi).rotated(1.2) * 20.0
	main.ctl.go_ashore(lp)
	Game.treasure = {"pos": lp + Vector2(3, 0), "island": isl.name}
	await _wait(1.0)
	await _shot("14_a_pe")
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
	print("Navios: ", w.ships.size(), " FPS: ", Engine.get_frames_per_second())
	print("AUTOTEST OK")
	get_tree().quit()
