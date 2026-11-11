class_name PlayerController
extends Node3D
## Câmeras (terceira pessoa, timão em primeira pessoa, luneta) e o modo a pé nas ilhas.

enum Mode { THIRD, HELM, FOOT, HORSE }

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
		Mode.FOOT:
			foot_yaw -= d.x * k
			foot_pitch = clampf(foot_pitch - d.y * k, -1.3, 1.3)


func cycle_camera() -> void:
	if on_land():
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
	foot_pitch = 0.0
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
	_rider = Assets.person("oficial", rr)
	h.add_child(_rider["root"])
	# costas do cavalo a ~1,38 m; quadril do capitão sentado fica 0,43 m acima dos pés
	_rider["root"].position = Vector3(0, 1.0, 0.2)
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
	horse = null
	mode = Mode.FOOT


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
		var p := Assets.person("homem" if Game.career == Game.PIR else "oficial", rr)
		World.I.add_child(p["root"])
		p["root"].global_position = foot_pos + Vector3(i - n * 0.5, 0, 3)
		p["phase"] = 0.0
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
		if moving:
			Assets.play(p, "Run" if d.length() > 4.0 else "Walk")
		else:
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
	if mode == Mode.FOOT:
		_foot(delta)
		_update_followers(delta, foot_pos, foot_yaw)
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
	elif mode == Mode.FOOT:
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
	if digging > 0.0:
		mv = Vector2.ZERO
		var before := digging
		digging -= delta
		if int(before * 2.5) != int(digging * 2.5):
			Sfx.play("dig")
		if digging <= 0.0:
			_finish_dig()
	var fwd := Vector2(-sin(foot_yaw), -cos(foot_yaw))
	var right := Vector2(-fwd.y, fwd.x)
	var step := (fwd * mv.y + right * mv.x) * 6.5 * delta
	var np := Vector2(foot_pos.x, foot_pos.z) + step
	var h := w.walk_height(np.x, np.y)
	var h0 := w.walk_height(foot_pos.x, foot_pos.z)
	if h > -1.1 and h - h0 < 1.2 and not w.building_blocked(np.x, np.y):
		foot_pos = Vector3(np.x, h, np.y)
	elif step.length() > 0.0:
		# desliza ao longo do obstáculo
		for alt in [Vector2(step.x, 0.0), Vector2(0.0, step.y)]:
			var ap: Vector2 = Vector2(foot_pos.x, foot_pos.z) + alt
			var ah := w.walk_height(ap.x, ap.y)
			if ah > -1.1 and ah - h0 < 1.2 and not w.building_blocked(ap.x, ap.y):
				foot_pos = Vector3(ap.x, ah, ap.y)
				break
	if step.length() > 0.001:
		_bob += step.length() * 1.6
	var eye := foot_pos + Vector3(0, 1.7 + sin(_bob) * 0.06 - (0.4 if digging > 0.0 else 0.0), 0)
	eye.y = maxf(eye.y, Ocean.height_at(eye.x, eye.z) + 0.5)
	cam.global_position = eye
	var pitch := foot_pitch - (0.6 + sin(digging * 9.0) * 0.1 if digging > 0.0 else 0.0)
	cam.global_basis = Basis.from_euler(Vector3(pitch, foot_yaw, 0.0))


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
