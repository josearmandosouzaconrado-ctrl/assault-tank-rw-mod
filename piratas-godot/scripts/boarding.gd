class_name Boarding
extends RefCounted
## Abordagem em tempo real (no estilo de Black Flag): os navios ficam presos pelos ganchos e o capitão
## luta no convés inimigo com o sabre, ao lado da sua tripulação.
##   ESPADA   golpes em sequência (combo); trava no inimigo mais próximo
##   DEFENDER aparar: se um inimigo golpear enquanto você apara, vem o contra-ataque (mata na hora)
##   PISTOLA  um tiro a cada 6 s no inimigo à frente
## Inimigos avisam antes de atacar (marca vermelha sobre a cabeça). Vence quem derrubar todos.

const DECK_T := Vector2(0.14, 0.86)
const PISTOL_CD := 6.0

var ctl: PlayerController
var ship: Ship          # navio abordado
var mine: Ship          # navio do jogador
var root: Node3D        # raiz do modelo do navio abordado (tudo em coordenadas locais do convés)
var captain: Dictionary
var cap_pos := Vector3.ZERO
var cap_yaw := 0.0
var hp := 100.0
var units: Array = []   # {"p", "team" (0 aliado, 1 inimigo), "pos", "yaw", "hp", "state", "t", "cd", "marine", "mark"}
var atk_t := 0.0
var combo := 0
var block_t := 0.0
var pistol_cd := 0.0
var finished := false
var won := false
var kills := 0
var allies_lost := 0
var on_finish: Callable
var _rng := RandomNumberGenerator.new()
var _mark_mesh: Mesh
var _msg_t := 0.0


func _init(c: PlayerController, target: Ship, player_ship: Ship, enemy_crew: int, done: Callable) -> void:
	ctl = c
	ship = target
	mine = player_ship
	on_finish = done
	_rng.randomize()
	root = ship.model["root"]
	# os navios ficam lado a lado, presos pelos ganchos
	ship.lashed = mine
	mine.lashed = ship
	var side := Vector2(-ship.forward().y, ship.forward().x)
	var to_me := mine.pos2() - ship.pos2()
	var sgn := 1.0 if to_me.dot(side) >= 0.0 else -1.0
	var gap := (ship.beam + mine.beam) * 0.5 + 1.2
	var np := ship.pos2() + side * sgn * gap
	mine.global_position = Vector3(np.x, mine.global_position.y, np.y)
	mine.yaw = ship.yaw
	mine.rotation.y = ship.rotation.y
	for n in ship.crew_nodes:
		if is_instance_valid(n["root"]):
			n["root"].visible = false
	# capitão com o sabre, entrando pelo costado do lado do seu navio
	var rr := RandomNumberGenerator.new()
	rr.seed = 11
	captain = Assets.captain(rr, false)
	_give_sword(captain)
	root.add_child(captain["root"])
	cap_pos = _deck_point(0.5, -sgn * 0.6)
	cap_yaw = PI * 0.5 * sgn
	# tripulações
	var n_enemy := clampi(enemy_crew / 5, 3, 9)
	var n_ally := clampi(mine.crew / 12 + Game.soldiers / 2, 2, 7)
	var navy := Game.is_navy()
	for i in n_ally:
		var p: Dictionary
		var marine := navy and i % 2 == 1 or (Game.soldiers > i * 2)
		if marine:
			p = Assets.soldier(Game.career if navy else Game.PIR, rr)
		else:
			p = Assets.person("homem", rr, {"look": ["camisa", "colete"][i % 2], "hat": [2, 0, 3][i % 3]})
			_give_sword(p)
		_add_unit(p, 0, _deck_point(rr.randf_range(0.25, 0.75), -sgn * rr.randf_range(0.45, 0.85)), marine)
	var nat: int = ship.flag_nation
	for i in n_enemy:
		var p: Dictionary
		var marine := nat != Game.PIR and i % 3 == 0
		if marine:
			p = Assets.soldier(nat, rr)
		else:
			p = Assets.person("homem", rr, {"look": ["camisa", "colete", "camisa"][i % 3], "hat": [2, 0, 3, 1][i % 4]})
			_give_sword(p)
		_add_unit(p, 1, _deck_point(rr.randf_range(0.2, 0.8), sgn * rr.randf_range(-0.2, 0.85)), marine)
	ctl.foot_yaw = ship.rotation.y + cap_yaw + PI
	ctl.foot_pitch = -0.15
	_update_nodes()
	Game.notify("Abordagem! Derrube a tripulação inimiga (%d). DEFENDER na hora certa = contra-ataque." % n_enemy, Color(1, 0.85, 0.5))
	Sfx.play("cannon_big", -6.0)


func _give_sword(p: Dictionary) -> void:
	p["sword"] = Attire.wear(p, "hand_r", Attire.cutlass(p.get("female", false)), Attire.metal_material())


func _add_unit(p: Dictionary, team: int, pos: Vector3, marine: bool) -> void:
	root.add_child(p["root"])
	var u := {"p": p, "team": team, "pos": pos, "yaw": 0.0, "hp": 70.0 if team == 1 else 80.0, "state": "idle",
		"t": 0.0, "cd": _rng.randf_range(0.5, 2.0), "marine": marine, "mark": null}
	if marine:
		Assets.musket_pose(p, MusketRig.AIM)
	units.append(u)


## Ponto do convés: t ao longo do navio (0 popa, 1 proa) e s através (-1 bombordo, +1 estibordo).
func _deck_point(t: float, s: float) -> Vector3:
	t = clampf(t, DECK_T.x, DECK_T.y)
	var hw := ShipBuilder.half_width(t, ship.beam) * 0.8
	return Vector3(clampf(s, -1.0, 1.0) * hw, ShipBuilder.deck_height(t, ship.def), ShipBuilder.t_to_z(t, ship.length))


func _clamp_deck(p: Vector3) -> Vector3:
	var t := clampf(inverse_lerp(ship.length * 0.5, -ship.length * 0.5, p.z), DECK_T.x, DECK_T.y)
	var hw := ShipBuilder.half_width(t, ship.beam) * 0.8
	return Vector3(clampf(p.x, -hw, hw), ShipBuilder.deck_height(t, ship.def), ShipBuilder.t_to_z(t, ship.length))


func enemies_left() -> int:
	var n := 0
	for u in units:
		if u["team"] == 1 and u["hp"] > 0.0:
			n += 1
	return n


# ---------------------------------------------------------------- comandos do jogador
func attack() -> void:
	if finished or atk_t > 0.0 or hp <= 0.0:
		return
	atk_t = 0.42
	combo = (combo + 1) % 2
	captain["cur"] = ""
	Assets.play(captain, "Sword" if combo == 0 else "Sword2", 1.35)
	Sfx.play("click", -10.0)
	var u := _nearest(cap_pos, 1, 3.2)
	if u.is_empty():
		return
	var to: Vector3 = u["pos"] - cap_pos
	cap_yaw = atan2(-to.x, -to.z)
	# avança um passo para o golpe
	if to.length() > 1.3:
		cap_pos = _clamp_deck(cap_pos + to.normalized() * minf(to.length() - 1.2, 0.9))
	_hit(u, _rng.randf_range(30.0, 42.0) * (1.0 + Game.rank_index() * 0.05), true)


func block() -> void:
	if finished or hp <= 0.0:
		return
	block_t = 0.6
	captain["cur"] = ""
	Assets.play(captain, "Block", 1.2)


func pistol() -> void:
	if finished or pistol_cd > 0.0 or hp <= 0.0:
		return
	var fwd := Vector3(-sin(cap_yaw), 0, -cos(cap_yaw))
	var best: Dictionary = {}
	var bd := 18.0
	for u in units:
		if u["team"] != 1 or u["hp"] <= 0.0:
			continue
		var to: Vector3 = u["pos"] - cap_pos
		var d := to.length()
		if d < bd and (d < 3.0 or fwd.dot(to / maxf(d, 0.01)) > 0.5):
			bd = d
			best = u
	pistol_cd = PISTOL_CD
	captain["cur"] = ""
	Assets.play(captain, "Pistol_Shoot", 1.2)
	var from: Vector3 = root.to_global(cap_pos + Vector3(0, 1.4, 0))
	var dir := root.global_transform.basis * fwd
	if not best.is_empty():
		var to: Vector3 = best["pos"] - cap_pos
		cap_yaw = atan2(-to.x, -to.z)
		dir = (root.to_global(best["pos"] + Vector3(0, 1.3, 0)) - from).normalized()
		if _rng.randf() < 0.85:
			_hit(best, 999.0, true)
		else:
			Game.notify("Errou!", Color(1, 1, 1))
	ctl._musket_fx(from, dir)


# ---------------------------------------------------------------- simulação
func update(delta: float) -> void:
	if finished:
		return
	atk_t = maxf(0.0, atk_t - delta)
	block_t = maxf(0.0, block_t - delta)
	pistol_cd = maxf(0.0, pistol_cd - delta)
	_msg_t = maxf(0.0, _msg_t - delta)
	# capitão: anda em relação à câmera (joystick)
	var mv := ctl.move_vec
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		mv.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		mv.y -= 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		mv.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		mv.x += 1.0
	mv = mv.limit_length(1.0)
	var cam_fwd := Vector3(-sin(ctl.foot_yaw), 0, -cos(ctl.foot_yaw))
	var cam_right := Vector3(-cam_fwd.z, 0, cam_fwd.x)
	var wdir := cam_fwd * mv.y + cam_right * mv.x
	var ldir := root.global_transform.basis.inverse() * wdir
	ldir.y = 0.0
	if hp > 0.0 and ldir.length() > 0.05 and atk_t <= 0.0 and block_t <= 0.0:
		var spd := 2.4 if mv.length() < 0.65 else 4.6
		cap_pos = _clamp_deck(cap_pos + ldir.normalized() * spd * mv.length() * delta)
		cap_yaw = lerp_angle(cap_yaw, atan2(-ldir.x, -ldir.z), 1.0 - exp(-delta * 10.0))
		Assets.play(captain, "Run" if spd > 3.0 else "Walk")
	elif hp > 0.0 and atk_t <= 0.0 and block_t <= 0.0 and captain["cur"] != "Pistol_Shoot":
		Assets.play(captain, "SwordIdle")
	if captain["cur"] == "Pistol_Shoot" and not (captain["ap"] as AnimationPlayer).is_playing():
		captain["cur"] = ""
	# tripulações
	for u in units:
		_unit(u, delta)
	_update_nodes()
	_camera(delta)
	if enemies_left() == 0:
		_end(true)
	elif hp <= 0.0:
		_end(false)


func _nearest(from: Vector3, team: int, max_d: float) -> Dictionary:
	var best: Dictionary = {}
	var bd := max_d
	for u in units:
		if u["team"] != team or u["hp"] <= 0.0:
			continue
		var d: float = (u["pos"] as Vector3).distance_to(from)
		if d < bd:
			bd = d
			best = u
	return best


func _unit(u: Dictionary, delta: float) -> void:
	var p: Dictionary = u["p"]
	if u["hp"] <= 0.0:
		return
	u["cd"] = float(u["cd"]) - delta
	# alvo: o mais perto do outro lado (os inimigos preferem o capitão)
	var foe: Dictionary = _nearest(u["pos"], 1 - int(u["team"]), 40.0)
	var tpos := Vector3.INF
	var tgt_captain := false
	if u["team"] == 1 and hp > 0.0:
		var dc: float = (u["pos"] as Vector3).distance_to(cap_pos)
		if foe.is_empty() or dc < (foe["pos"] as Vector3).distance_to(u["pos"]) + 2.5:
			tpos = cap_pos
			tgt_captain = true
	if tpos == Vector3.INF:
		if foe.is_empty():
			Assets.play(p, "Idle")
			return
		tpos = foe["pos"]
	var to: Vector3 = tpos - u["pos"]
	to.y = 0.0
	var d := to.length()
	var reach := 1.9 if u["marine"] else 1.45
	u["yaw"] = lerp_angle(u["yaw"], atan2(-to.x, -to.z), 1.0 - exp(-delta * 8.0))
	match u["state"]:
		"idle":
			if d > reach:
				# não amontoa: afasta dos companheiros
				var push := Vector3.ZERO
				for o in units:
					if o != u and o["hp"] > 0.0:
						var dd: Vector3 = u["pos"] - o["pos"]
						if dd.length() < 1.0:
							push += dd.normalized() * (1.0 - dd.length())
				u["pos"] = _clamp_deck(u["pos"] + (to / d * 3.2 + push * 2.0) * delta)
				Assets.play(p, "Run" if d > 4.0 else "Walk")
			elif u["cd"] <= 0.0:
				u["state"] = "windup"
				u["t"] = 0.7 if u["team"] == 1 else 0.9
				u["tgt_captain"] = tgt_captain
				p["cur"] = ""
				Assets.play(p, "SwordIdle" if not u["marine"] else "Idle")
				if u["team"] == 1 and tgt_captain:
					_show_mark(u, true)
			else:
				Assets.play(p, "SwordIdle" if not u["marine"] else "Idle")
		"windup":
			u["t"] = float(u["t"]) - delta
			if u["t"] <= 0.0:
				_show_mark(u, false)
				u["state"] = "idle"
				u["cd"] = _rng.randf_range(1.4, 2.6)
				p["cur"] = ""
				Assets.play(p, "Sword" if _rng.randf() < 0.5 else "Sword2", 1.2)
				if d <= reach + 0.4:
					_strike(u, foe, tgt_captain and u.get("tgt_captain", false))


func _strike(u: Dictionary, foe: Dictionary, at_captain: bool) -> void:
	if at_captain:
		if block_t > 0.0:
			# contra-ataque: o capitão desvia e derruba o atacante
			captain["cur"] = ""
			Assets.play(captain, "Sword", 1.5)
			var to: Vector3 = u["pos"] - cap_pos
			cap_yaw = atan2(-to.x, -to.z)
			block_t = 0.0
			_hit(u, 999.0, true)
			Game.notify("Contra-ataque!", Color(1, 0.9, 0.4))
			Sfx.play("hit", -4.0)
		else:
			hp -= _rng.randf_range(9.0, 14.0)
			if ctl.hud_ref:
				ctl.hud_ref.flash_damage()
			captain["cur"] = ""
			Assets.play(captain, "Hit", 1.3)
			atk_t = 0.25
			Sfx.play("hit", -8.0)
	elif not foe.is_empty():
		var dmg := _rng.randf_range(12.0, 22.0) if u["team"] == 0 else _rng.randf_range(10.0, 20.0)
		_hit(foe, dmg, false)


func _hit(u: Dictionary, dmg: float, by_captain: bool) -> void:
	if u["hp"] <= 0.0:
		return
	u["hp"] = float(u["hp"]) - dmg
	var p: Dictionary = u["p"]
	p["cur"] = ""
	_show_mark(u, false)
	u["state"] = "idle"
	u["cd"] = maxf(float(u["cd"]), 0.6)
	if u["hp"] <= 0.0:
		Assets.musket_pose(p, MusketRig.NONE)
		Assets.play(p, "Death")
		if u["team"] == 1:
			kills += 1
		else:
			allies_lost += 1
		if by_captain:
			Sfx.play("hit", -6.0)
	else:
		Assets.play(p, "Hit", 1.3)


func _show_mark(u: Dictionary, on: bool) -> void:
	if on:
		if u["mark"] == null:
			if _mark_mesh == null:
				var pm := PrismMesh.new()
				pm.size = Vector3(0.22, 0.22, 0.04)
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(1.0, 0.12, 0.08)
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.no_depth_test = true
				pm.material = mat
				_mark_mesh = pm
			var mi := MeshInstance3D.new()
			mi.mesh = _mark_mesh
			mi.rotation.z = PI
			u["p"]["root"].add_child(mi)
			mi.position = Vector3(0, 2.25, 0)
			u["mark"] = mi
	elif u["mark"] != null:
		(u["mark"] as Node).queue_free()
		u["mark"] = null


func _update_nodes() -> void:
	var cr: Node3D = captain["root"]
	cr.position = cap_pos
	cr.rotation.y = cap_yaw
	for u in units:
		var r: Node3D = u["p"]["root"]
		r.position = u["pos"]
		r.rotation.y = u["yaw"]


func _camera(delta: float) -> void:
	var cam := ctl.cam
	var target: Vector3 = root.to_global(cap_pos) + Vector3(0, 1.6, 0)
	var dirc := Vector3(sin(ctl.foot_yaw) * cos(ctl.foot_pitch), -sin(ctl.foot_pitch), cos(ctl.foot_yaw) * cos(ctl.foot_pitch))
	var want := target + dirc * 4.6 + Vector3(0, 0.6, 0)
	cam.global_position = cam.global_position.lerp(want, 1.0 - exp(-delta * 10.0)) if cam.global_position.distance_to(want) < 8.0 else want
	cam.look_at(target, Vector3.UP)


func _end(win: bool) -> void:
	finished = true
	won = win
	for u in units:
		_show_mark(u, false)
	if win:
		Game.notify("O navio é seu! %d inimigos derrubados." % kills, Color(1, 0.9, 0.4))
	else:
		Game.notify("Você caiu no convés... seus homens o arrastam de volta.", Color(1, 0.5, 0.4))
	on_finish.call(win)


## Remove tudo e solta os navios.
func cleanup() -> void:
	if is_instance_valid(captain["root"]):
		captain["root"].queue_free()
	for u in units:
		if is_instance_valid(u["p"]["root"]):
			u["p"]["root"].queue_free()
	units.clear()
	if is_instance_valid(ship):
		ship.lashed = null
		for n in ship.crew_nodes:
			if is_instance_valid(n["root"]):
				n["root"].visible = true
	if is_instance_valid(mine):
		mine.lashed = null
