class_name PlayerController
extends Node3D
## Câmeras (terceira pessoa, timão em primeira pessoa, luneta) e o modo a pé nas ilhas.

enum Mode { THIRD, HELM, FOOT, HORSE, BOARD }

var cam: Camera3D
var mode := Mode.THIRD
var spyglass := false
var steer_input := 0.0
var steer_touch := false
var sail_target := 0.0
var move_vec := Vector2.ZERO
var orbit_yaw := 0.0
var orbit_pitch := -0.18
var helm_yaw := 0.0
var helm_pitch := -0.05
var zoom := 1.0
var _shake := 0.0
var _cam_pos := Vector3.ZERO
var _cam_yaw := 0.0
var _cam_y := 0.0
var _cam_init := false
var _look_idle := 10.0
var _helm_pitch_s := 0.0
var _rng := RandomNumberGenerator.new()

var foot_pos := Vector3.ZERO
var foot_yaw := 0.0
var foot_pitch := 0.0
var _bob := 0.0
var digging := 0.0
var _prev_mode := Mode.THIRD
var horse: Horse
var _rider: Dictionary = {}
var town: TownLife
var followers: Array = []
var _horse_cam_yaw := 0.0
var avatar: Dictionary = {}
var avatar_yaw := 0.0
var hp := 100.0
var _hurt_t := 0.0
var musket_cd := 0.0
var _shoot_anim := 0.0
var _slash_t := 0.0
var cutscene := false
var hud_ref: Node
var board: Boarding          # luta de abordagem em andamento
var _board_prev := Mode.THIRD


func _ready() -> void:
	cam = Camera3D.new()
	cam.far = 12000.0
	cam.near = 0.15
	cam.fov = 62.0
	add_child(cam)
	cam.current = true
	_rng.randomize()


func shake(v: float) -> void:
	_shake = maxf(_shake, v)


func on_land() -> bool:
	return mode == Mode.FOOT or mode == Mode.HORSE


func look(d: Vector2) -> void:
	var k := 0.0045 * (0.25 if spyglass else 1.0)
	_look_idle = 0.0
	match mode:
		Mode.HORSE:
			orbit_yaw -= d.x * k
			orbit_pitch = clampf(orbit_pitch - d.y * k, -1.0, 0.3)
		Mode.THIRD:
			orbit_yaw -= d.x * k
			orbit_pitch = clampf(orbit_pitch - d.y * k, -1.2, 0.25)
		Mode.HELM:
			helm_yaw = clampf(helm_yaw - d.x * k, -2.6, 2.6)
			helm_pitch = clampf(helm_pitch - d.y * k, -0.8, 0.6)
		Mode.FOOT, Mode.BOARD:
			foot_yaw -= d.x * k
			foot_pitch = clampf(foot_pitch - d.y * k, -1.1, 0.45)


func cycle_camera() -> void:
	if on_land() or mode == Mode.BOARD:
		return
	mode = Mode.HELM if mode == Mode.THIRD else Mode.THIRD
	spyglass = false
	helm_yaw = 0.0
	helm_pitch = -0.05


func toggle_spyglass() -> void:
	if on_land():
		return
	spyglass = not spyglass
	if spyglass:
		helm_yaw = wrapf(orbit_yaw, -PI, PI) if mode == Mode.THIRD else helm_yaw
		helm_pitch = 0.0


func sail_step(dir: int) -> void:
	var lvl := clampi(int(round(sail_target * 3.0)) + dir, 0, 3)
	sail_target = lvl / 3.0
	var names := ["Velas recolhidas", "1/3 de vela", "2/3 de vela", "Todas as velas!"]
	Game.notify(names[lvl], Color(0.9, 0.95, 1.0))
	Sfx.play("click", -8.0)


func go_ashore(p: Vector2) -> void:
	_prev_mode = mode
	mode = Mode.FOOT
	spyglass = false
	var w := World.I
	foot_pos = Vector3(p.x, w.walk_height(p.x, p.y), p.y)
	var sp := w.player.pos2()
	var away := (p - sp).normalized()
	foot_yaw = atan2(-away.x, -away.y)
	avatar_yaw = foot_yaw
	foot_pitch = -0.2
	_make_avatar()
	w.player.sail_level = 0.0
	w.player.rudder = 0.0
	sail_target = 0.0
	_spawn_followers()
	Game.notify("Você desembarcou. Explore a ilha!", Color(0.8, 1, 0.7))


func return_to_ship() -> void:
	if mode == Mode.HORSE:
		dismount()
	mode = _prev_mode if not (_prev_mode == Mode.FOOT or _prev_mode == Mode.HORSE) else Mode.THIRD
	digging = 0.0
	_free_avatar()
	hp = 100.0
	for f in followers:
		f["root"].queue_free()
	followers.clear()
	if town:
		town.queue_free()
		town = null
	Game.notify("De volta ao navio.", Color(0.8, 0.9, 1))


# ---------------------------------------------------------------- cavalo
func mount(h: Horse) -> void:
	if h == null:
		return
	horse = h
	h.ridden = true
	# o cavalo passa a pertencer ao mundo (pode sair da cidade)
	var gp := h.global_position
	h.get_parent().remove_child(h)
	World.I.add_child(h)
	h.global_position = gp
	var rr := RandomNumberGenerator.new()
	_rider = Assets.captain(rr, false)
	_free_avatar()
	h.add_child(_rider["root"])
	# costas do cavalo a ~1,4 m; sentado, o quadril fica 0,54 m acima e 0,33 m atrás da origem do modelo
	_rider["root"].position = Vector3(0, 0.86, -0.12)
	Assets.play(_rider, "Sitting")
	mode = Mode.HORSE
	_horse_cam_yaw = h.yaw
	orbit_yaw = 0.0
	orbit_pitch = -0.25
	Game.notify("Você montou no cavalo. Joystick para cavalgar.", Color(0.9, 0.85, 0.6))
	Sfx.play("click")


func dismount() -> void:
	if horse == null:
		return
	horse.ridden = false
	if not _rider.is_empty():
		_rider["root"].queue_free()
		_rider = {}
	var side := Vector2(-horse.forward().y, horse.forward().x)
	var p := Vector2(horse.global_position.x, horse.global_position.z) - side * 1.6
	foot_pos = Vector3(p.x, World.I.walk_height(p.x, p.y), p.y)
	foot_yaw = horse.yaw
	avatar_yaw = horse.yaw
	horse = null
	mode = Mode.FOOT
	_make_avatar()


# ---------------------------------------------------------------- abordagem em tempo real
func start_boarding(target: Ship, enemy_crew: int, done: Callable) -> void:
	_board_prev = mode if mode != Mode.BOARD else Mode.THIRD
	spyglass = false
	sail_target = 0.0
	mode = Mode.BOARD
	board = Boarding.new(self, target, World.I.player, enemy_crew, done)


func end_boarding() -> void:
	if board:
		board.cleanup()
	board = null
	mode = _board_prev
	_cam_init = false


func near_horse() -> Horse:
	if mode != Mode.FOOT or town == null:
		return null
	return town.nearest_horse(foot_pos, 3.5)


# ---------------------------------------------------------------- tropas que seguem o capitão
func _spawn_followers() -> void:
	for f in followers:
		f["root"].queue_free()
	followers.clear()
	var n := mini(Game.soldiers, 6)
	var rr := RandomNumberGenerator.new()
	rr.seed = 7
	for i in n:
		var p := Assets.soldier(Game.career, rr)
		World.I.add_child(p["root"])
		p["root"].global_position = foot_pos + Vector3(i - n * 0.5, 0, 3)
		p["phase"] = 0.0
		p["cd"] = rr.randf_range(1.0, 3.0)
		followers.append(p)


func _update_followers(delta: float, leader: Vector3, lyaw: float) -> void:
	var w := World.I
	var f := Vector2(-sin(lyaw), -cos(lyaw))
	var side := Vector2(-f.y, f.x)
	for i in followers.size():
		var p: Dictionary = followers[i]
		var root: Node3D = p["root"]
		var row := i / 2
		var col := (i % 2) * 2 - 1
		var slot := Vector2(leader.x, leader.z) - f * (3.5 + row * 2.2) + side * col * 1.4
		var pos := Vector2(root.global_position.x, root.global_position.z)
		var d := slot - pos
		var moving := d.length() > 0.6
		if moving:
			pos += d.normalized() * minf(d.length(), delta * (4.0 + d.length() * 1.2))
			root.rotation.y = lerp_angle(root.rotation.y, atan2(-d.x, -d.y), delta * 6.0)
			p["phase"] += delta * 7.0
		root.global_position = Vector3(pos.x, w.walk_height(pos.x, pos.y), pos.y)
		# as tropas atiram nos guardas inimigos
		p["cd"] = float(p.get("cd", 2.0)) - delta
		var aimed := false
		if town and p["cd"] <= 0.0:
			var g := town.nearest_enemy(root.global_position, 40.0)
			if not g.is_empty():
				p["cd"] = _rng.randf_range(2.5, 4.0)
				var gp: Vector3 = g["p"]["root"].global_position
				var to := gp - root.global_position
				root.rotation.y = atan2(-to.x, -to.z)
				p["aim_t"] = 1.0
				if p.has("rig"):
					p["rig"].fire_kick()
				_musket_fx(root.global_position + Vector3(0, 1.45, 0), to.normalized())
				if _rng.randf() < 0.4:
					town.kill(g)
				aimed = true
		p["aim_t"] = maxf(0.0, float(p.get("aim_t", 0.0)) - delta)
		if p["aim_t"] > 0.0:
			Assets.musket_pose(p, MusketRig.AIM)
			Assets.play(p, "Idle")
		elif moving:
			Assets.musket_pose(p, MusketRig.CARRY)
			Assets.play(p, "Run" if d.length() > 4.0 else "Walk")
		else:
			Assets.musket_pose(p, MusketRig.ORDER)
			Assets.play(p, "Idle")


## Mantém a vida da cidade (moradores, cavalos) quando o jogador está a pé perto de uma cidade.
func _update_town() -> void:
	var w := World.I
	var here := foot_pos if mode == Mode.FOOT else (horse.global_position if horse else foot_pos)
	var best: PortSite = null
	var bd := 650.0
	for ps in w.port_islands:
		var d := Vector2(ps.town_center.x, ps.town_center.z).distance_to(Vector2(here.x, here.z))
		if d < bd:
			bd = d
			best = ps
	if town and (best == null or town.site != best):
		town.queue_free()
		town = null
	if best and town == null:
		town = TownLife.new()
		w.add_child(town)
		town.setup(best)


func near_treasure() -> bool:
	if mode != Mode.FOOT or not Game.treasure.has("pos"):
		return false
	var tp: Vector2 = Game.treasure["pos"]
	return Vector2(foot_pos.x, foot_pos.z).distance_to(tp) < 6.0


func start_dig() -> void:
	if digging <= 0.0:
		digging = 2.6


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_C:
				cycle_camera()
			KEY_Z:
				toggle_spyglass()
			KEY_W, KEY_UP:
				if mode != Mode.FOOT:
					sail_target = minf(1.0, snappedf(sail_target + 0.34, 0.33))
			KEY_S, KEY_DOWN:
				if mode != Mode.FOOT:
					sail_target = maxf(0.0, snappedf(sail_target - 0.34, 0.33))


func _process(delta: float) -> void:
	var w := World.I
	if w == null or w.player == null:
		return
	var ship := w.player
	_shake = maxf(0.0, _shake - delta * 1.6)
	Game.drunk = maxf(0.0, Game.drunk - delta)
	if on_land():
		_update_town()
	musket_cd = maxf(0.0, musket_cd - delta)
	_hurt_t += delta
	if _hurt_t > 6.0 and hp < 100.0:
		hp = minf(100.0, hp + delta * 4.0)
	if mode == Mode.BOARD:
		if board:
			board.update(delta)
		ship.rudder = 0.0
		ship.sail_level = 0.0
	elif mode == Mode.FOOT:
		_foot(delta)
		_update_followers(delta, foot_pos, avatar_yaw)
	elif mode == Mode.HORSE:
		_ride(delta)
		_update_followers(delta, horse.global_position, horse.yaw)
	else:
		var kb := 0.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			kb -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			kb += 1.0
		if not steer_touch:
			steer_input = move_toward(steer_input, kb, delta * 3.0)
		if not ship.dead:
			ship.rudder = steer_input
			ship.sail_level = sail_target * 1.0
		if mode == Mode.THIRD and not spyglass:
			_third(ship, delta)
		else:
			_helm(ship, delta)
	if _shake > 0.0:
		cam.global_position += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _shake * 0.35
	if Game.drunk > 0.0:
		# tontura de quem bebeu rum demais
		var t := Time.get_ticks_msec() * 0.001
		var k := minf(Game.drunk / 20.0, 1.0)
		cam.rotate_object_local(Vector3.FORWARD, sin(t * 0.9) * 0.08 * k)
		cam.rotate_object_local(Vector3.RIGHT, sin(t * 1.3) * 0.03 * k)
	var target_fov := 60.0
	if spyglass:
		target_fov = 13.0
	elif mode == Mode.HELM:
		target_fov = 72.0
	elif mode == Mode.FOOT or mode == Mode.BOARD:
		target_fov = 74.0
	elif mode == Mode.HORSE:
		target_fov = 66.0
	cam.fov = lerpf(cam.fov, target_fov, 1.0 - exp(-delta * 8.0))


## Câmera de perseguição: fica atrás do navio, segue o rumo com atraso suave
## e ignora o balanço das ondas (sem sensação de estar girando).
func _third(ship: Ship, delta: float) -> void:
	if not _cam_init:
		_cam_init = true
		_cam_yaw = ship.yaw + orbit_yaw
		_cam_y = ship._y
	# depois de um tempo sem mexer, a câmera volta para trás do navio
	_look_idle += delta
	if _look_idle > 2.5:
		var k_back := 1.0 - exp(-delta * 0.9)
		orbit_yaw = lerp_angle(orbit_yaw, 0.0, k_back)
		orbit_pitch = lerpf(orbit_pitch, -0.2, k_back)
	_cam_yaw = lerp_angle(_cam_yaw, ship.yaw + orbit_yaw, 1.0 - exp(-delta * 2.2))
	_cam_y = lerpf(_cam_y, ship._y, 1.0 - exp(-delta * 0.8))
	var f := ship.forward()
	var base := Vector3(ship.global_position.x, _cam_y, ship.global_position.z)
	var target := base + Vector3(f.x, 0.0, f.y) * ship.length * 0.2 + Vector3(0, 4.0 + ship.length * 0.16, 0)
	var dist := (ship.length * 1.35 + 18.0) * zoom
	var dir := Vector3(sin(_cam_yaw) * cos(orbit_pitch), -sin(orbit_pitch), cos(_cam_yaw) * cos(orbit_pitch))
	var want := target + dir * dist
	var floor_y := maxf(Ocean.height_at(want.x, want.z) + 2.5, World.I.terrain_height(want.x, want.z) + 3.0)
	want.y = maxf(want.y, floor_y)
	if _cam_pos == Vector3.ZERO or _cam_pos.distance_to(want) > 200.0:
		_cam_pos = want
	# posição já vem suavizada pelo ângulo; só amortece a altura
	_cam_pos = Vector3(want.x, lerpf(_cam_pos.y, want.y, 1.0 - exp(-delta * 4.0)), want.z)
	cam.global_position = _cam_pos
	cam.look_at(target, Vector3.UP)


func _helm(ship: Ship, delta: float) -> void:
	_cam_init = false
	var helm: Vector3 = ship.model["helm"]
	var p := ship.global_transform * helm
	if spyglass and mode == Mode.THIRD:
		p = ship.global_position + Vector3(0, ship.model["deck_mid"] + 3.0, 0)
	# sem rolagem e com pouco arfagem: o horizonte fica firme
	_helm_pitch_s = lerpf(_helm_pitch_s, ship._pitch * 0.25, 1.0 - exp(-delta * 2.0))
	var b := Basis.from_euler(Vector3(_helm_pitch_s, ship.yaw, 0.0))
	cam.global_position = p
	cam.global_basis = b * Basis.from_euler(Vector3(helm_pitch, helm_yaw, 0.0))
	_cam_pos = Vector3.ZERO


func _ride(delta: float) -> void:
	var mv := move_vec
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		mv.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		mv.y -= 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		mv.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		mv.x += 1.0
	horse.drive(delta, clampf(mv.y, -1.0, 1.0), clampf(mv.x, -1.0, 1.0))
	foot_pos = horse.global_position
	foot_yaw = horse.yaw
	# câmera atrás do cavalo
	_look_idle += delta
	if _look_idle > 2.5:
		orbit_yaw = lerp_angle(orbit_yaw, 0.0, 1.0 - exp(-delta * 1.2))
		orbit_pitch = lerpf(orbit_pitch, -0.25, 1.0 - exp(-delta * 1.2))
	_horse_cam_yaw = lerp_angle(_horse_cam_yaw, horse.yaw + orbit_yaw, 1.0 - exp(-delta * 3.0))
	var target := horse.global_position + Vector3(0, 2.4, 0)
	var dir := Vector3(sin(_horse_cam_yaw) * cos(orbit_pitch), -sin(orbit_pitch), cos(_horse_cam_yaw) * cos(orbit_pitch))
	var want := target + dir * 8.5 * zoom
	want.y = maxf(want.y, World.I.terrain_height(want.x, want.z) + 1.2)
	cam.global_position = want
	cam.look_at(target, Vector3.UP)


func _make_avatar() -> void:
	_free_avatar()
	var rr := RandomNumberGenerator.new()
	avatar = Assets.captain(rr, true)
	avatar["sword"] = Attire.wear(avatar, "hand_r", Attire.cutlass(avatar.get("female", false)), Attire.metal_material())
	World.I.add_child(avatar["root"])
	avatar["root"].global_position = foot_pos
	avatar["root"].rotation.y = avatar_yaw


func _free_avatar() -> void:
	if not avatar.is_empty() and is_instance_valid(avatar["root"]):
		avatar["root"].queue_free()
	avatar = {}


func musket_frac() -> float:
	var r: float = Assets.MUSKETS[clampi(Game.musket, 0, 2)]["reload"]
	return clampf(1.0 - musket_cd / r, 0.0, 1.0)


func _musket_fx(from: Vector3, dir: Vector3) -> void:
	Effects.I.emit("flash", from + dir * 0.9, dir)
	Effects.I.emit("smoke", from + dir * 0.9, dir)
	Sfx.play_at("cannon", from, -10.0, 2.6)


## Dispara o mosquete no guarda inimigo mais próximo na direção da câmera.
func shoot_musket() -> void:
	if mode != Mode.FOOT or musket_cd > 0.0 or avatar.is_empty() or digging > 0.0:
		return
	var m: Dictionary = Assets.MUSKETS[clampi(Game.musket, 0, 2)]
	musket_cd = m["reload"]
	var fwd := Vector3(-sin(foot_yaw), 0, -cos(foot_yaw))
	var target := {}
	var bd: float = m["range"]
	if town:
		for e in town.people:
			if not e.get("alive", true) or e["kind"] != "guarda":
				continue
			var gp: Vector3 = e["p"]["root"].global_position
			var to := gp - foot_pos
			var d := to.length()
			if d < bd and fwd.angle_to(Vector3(to.x, 0, to.z)) < deg_to_rad(40.0):
				bd = d
				target = e
	var dir := fwd
	if not target.is_empty():
		var tp: Vector3 = target["p"]["root"].global_position
		dir = (tp - foot_pos).normalized()
	avatar_yaw = atan2(-dir.x, -dir.z)
	avatar["root"].rotation.y = avatar_yaw
	Assets.play(avatar, "Idle")
	Assets.musket_pose(avatar, MusketRig.AIM)
	if avatar.has("rig"):
		avatar["rig"].fire_kick()
	_shoot_anim = 0.9
	_musket_fx(foot_pos + Vector3(0, 1.45, 0), dir)
	if target.is_empty():
		return
	town.provoke()
	var hit_chance: float = m["acc"] * (1.0 - 0.45 * bd / m["range"])
	if _rng.randf() < hit_chance:
		town.kill(target)
	else:
		Game.notify("Errou!", Color(1, 1, 1, 0.8))


## Golpe de sabre a pé: o mosquete fica no ombro esquerdo e a mão direita usa o sabre.
func sword_attack() -> void:
	if mode != Mode.FOOT or avatar.is_empty() or _slash_t > 0.0 or digging > 0.0:
		return
	_slash_t = 0.5
	avatar["cur"] = ""
	_shoot_anim = 0.0
	Assets.musket_pose(avatar, MusketRig.CARRY)
	Assets.play(avatar, "Sword" if _rng.randf() < 0.5 else "Sword2", 1.35)
	Sfx.play("click", -12.0)
	if town == null:
		return
	var best := {}
	var bd := 2.8
	for e in town.people:
		if e["kind"] != "guarda" or not e.get("alive", true):
			continue
		var d: float = e["p"]["root"].global_position.distance_to(foot_pos)
		if d < bd:
			bd = d
			best = e
	if best.is_empty():
		return
	var to: Vector3 = best["p"]["root"].global_position - foot_pos
	avatar_yaw = atan2(-to.x, -to.z)
	avatar["root"].rotation.y = avatar_yaw
	town.provoke()
	if _rng.randf() < 0.7:
		town.kill(best)
	else:
		Game.notify("O guarda aparou o golpe!", Color(1, 1, 1, 0.8))


## Ferimento a pé (tiros dos guardas).
func foot_hit(dmg: float) -> void:
	if not on_land():
		return
	hp -= dmg
	_hurt_t = 0.0
	shake(0.2)
	if hud_ref:
		hud_ref.flash_damage()
	if hp <= 0.0:
		hp = 100.0
		var lost := int(Game.gold * 0.1)
		Game.gold -= lost
		Game.notify("Você foi ferido! A tripulação o levou de volta ao navio (-%d moedas)." % lost, Color(1, 0.4, 0.3))
		return_to_ship()


func _foot(delta: float) -> void:
	var w := World.I
	var mv := move_vec
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		mv.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		mv.y -= 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		mv.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		mv.x += 1.0
	mv = mv.limit_length(1.0)
	_shoot_anim = maxf(0.0, _shoot_anim - delta)
	_slash_t = maxf(0.0, _slash_t - delta)
	if avatar.has("sword") and is_instance_valid(avatar["sword"]):
		avatar["sword"].visible = _shoot_anim <= 0.0 and digging <= 0.0
	if digging > 0.0:
		mv = Vector2.ZERO
		var before := digging
		digging -= delta
		if int(before * 2.5) != int(digging * 2.5):
			Sfx.play("dig")
			if not avatar.is_empty():
				avatar["cur"] = ""
				Assets.musket_pose(avatar, MusketRig.NONE)
				Assets.play(avatar, "Punch", 1.3)
		if digging <= 0.0:
			_finish_dig()
	# movimento relativo à câmera; o capitão vira para onde anda
	var fwd := Vector2(-sin(foot_yaw), -cos(foot_yaw))
	var right := Vector2(-fwd.y, fwd.x)
	var wdir := fwd * mv.y + right * mv.x
	var spd := 2.6 if mv.length() < 0.65 else 6.2
	var step := wdir * spd * delta
	var np := Vector2(foot_pos.x, foot_pos.z) + step
	var h := w.walk_height(np.x, np.y)
	var h0 := w.walk_height(foot_pos.x, foot_pos.z)
	if h > -1.1 and h - h0 < 1.2 and not w.building_blocked(np.x, np.y):
		foot_pos = Vector3(np.x, h, np.y)
	elif step.length() > 0.0:
		for alt in [Vector2(step.x, 0.0), Vector2(0.0, step.y)]:
			var ap: Vector2 = Vector2(foot_pos.x, foot_pos.z) + alt
			var ah := w.walk_height(ap.x, ap.y)
			if ah > -1.1 and ah - h0 < 1.2 and not w.building_blocked(ap.x, ap.y):
				foot_pos = Vector3(ap.x, ah, ap.y)
				break
	if not avatar.is_empty():
		var root: Node3D = avatar["root"]
		root.global_position = foot_pos
		if cutscene:
			Assets.musket_pose(avatar, MusketRig.NONE)
		elif _shoot_anim > 0.0:
			Assets.musket_pose(avatar, MusketRig.AIM)
		elif digging <= 0.0:
			Assets.musket_pose(avatar, MusketRig.CARRY)
		if wdir.length() > 0.05:
			avatar_yaw = lerp_angle(avatar_yaw, atan2(-wdir.x, -wdir.y), 1.0 - exp(-delta * 10.0))
			if _shoot_anim <= 0.0 and _slash_t <= 0.0:
				Assets.play(avatar, "Run" if spd > 3.0 else "Walk", 1.0 if spd > 3.0 else 1.1)
		elif digging <= 0.0 and _slash_t <= 0.0:
			Assets.play(avatar, "Idle")
		root.rotation.y = avatar_yaw
	# câmera de terceira pessoa por cima do ombro
	var target := foot_pos + Vector3(0, 1.55, 0)
	var dirc := Vector3(sin(foot_yaw) * cos(foot_pitch), -sin(foot_pitch), cos(foot_yaw) * cos(foot_pitch))
	var side := Vector3(cos(foot_yaw), 0, -sin(foot_yaw)) * 0.55
	# a câmera não entra nas casas: aproxima-se se houver parede atrás
	var dist := 4.2 * zoom
	var t := 0.8
	while t < dist:
		var q := target + dirc * t + side * (t / dist)
		if w.building_blocked(q.x, q.z) and q.y < w.terrain_height(q.x, q.z) + 9.0:
			dist = maxf(0.9, t - 0.5)
			break
		t += 0.35
	var want := target + dirc * dist + side * minf(1.0, dist / 4.2)
	want.y = maxf(want.y, maxf(w.terrain_height(want.x, want.z), Ocean.height_at(want.x, want.z)) + 0.6)
	cam.global_position = want
	cam.look_at(target + side * 0.6 - dirc * 2.0, Vector3.UP)


func _finish_dig() -> void:
	if not near_treasure():
		Game.notify("Nada aqui além de areia...", Color(0.8, 0.8, 0.7))
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var g := rng.randi_range(2500, 7500)
	Game.gold += g
	Game.stats["treasures"] += 1
	if not Game.is_navy():
		Game.add_merit(120)
	Game.treasure = {}
	Sfx.play("coin")
	Sfx.play("bell", -8.0)
	Game.notify("TESOURO! Um baú com %d dobrões de ouro!" % g, Color(1, 0.85, 0.2))
	Game.save_game()
