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
			var t: Node = load("res://scripts/dev_autotest.gd").new()
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
	if Game.spouse == i:
		mood = "%s corre para abraçar você: \"Você voltou!\"" % nm
		opts.append(["Passar a noite em casa (descansar até de manhã)", func():
			Game.time_of_day = 0.27
			Game.day += 1
			Game.morale = minf(100.0, Game.morale + 25.0)
			Game.notify("Uma noite tranquila em casa. A tripulação também descansou (+moral).", Color(1, 0.8, 0.85))
			world._update_environment(true)])
		opts.append(["Até logo", Callable()])
		hud.show_dialog(nm, mood, opts)
		return
	if a >= 80:
		mood = "%s não tira os olhos de você. O afeto é evidente." % nm
	elif a >= 50:
		mood = "%s fica feliz em ver você e sorri." % nm
	elif a >= 20:
		mood = "%s cumprimenta você com simpatia." % nm
	var talked: bool = int(Game.romance_day.get(str(i), -1)) == Game.day
	opts.append(["Conversar" + (" (já conversaram hoje)" if talked else ""), func():
		if talked:
			Game.notify("%s: \"Volte amanhã, capitão.\"" % nm, Color(1, 0.8, 0.85))
			return
		Game.romance_day[str(i)] = Game.day
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
	opts.append(["Convidar para jantar na taverna (150 moedas)", func():
		if Game.gold < 150:
			Game.notify("Você não tem moedas suficientes.", Color(1, 0.6, 0.4))
			return
		Game.gold -= 150
		Game.add_affection(i, 9)
		Game.morale = minf(100.0, Game.morale + 4.0)
		Game.notify("Um jantar à luz de velas, com música de rabeca. (afeto %d/100)" % Game.affection(i), Color(1, 0.8, 0.85))])
	if a >= 100 and Game.spouse < 0:
		opts.append(["Pedir em casamento", func():
			Game.spouse = i
			Game.morale = minf(100.0, Game.morale + 30.0)
			Sfx.play("bell")
			Game.notify("%s disse SIM! A cidade inteira comemora o casamento." % nm, Color(1, 0.85, 0.3))
			Game.save_game()])
	opts.append(["Até logo", Callable()])
	hud.show_dialog(nm, mood + "  (afeto %d/100)" % a, opts)


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
	var res := world.resolve_boarding(enemy)
	world.on_ship_attacked(t, p, true)
	if not res["win"]:
		p.take_raw_damage(p.max_hp * 0.08)
		t.crew = maxi(1, t.crew - int(res["killed"] * 0.5))
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
