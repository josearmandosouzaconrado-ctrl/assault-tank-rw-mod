class_name Ship
extends Node3D
## Navio (do jogador ou da IA): navegação a vela, flutuação, canhões, dano e naufrágio.

const MUZZLE := 105.0
const RANGE := 520.0

enum Role { PLAYER, MERCHANT, PATROL, PIRATE, HUNTER }

var def: Dictionary
var type_idx := 0
var nation := 0
var flag_nation := 0
var role := Role.MERCHANT
var is_player := false
var ship_name := ""

var max_hp := 100.0
var hp := 100.0
var sail_hp := 100.0
var crew := 10
var max_crew := 10
var gold := 0
var cargo := {}

var yaw := 0.0
var speed := 0.0
var rudder := 0.0
var sail_level := 0.66
var sail_actual := 0.66
var reload := {1.0: 0.0, -1.0: 0.0}
var reload_time := 7.0
var ammo := 0
var dmg_mult := 1.0
var speed_mult := 1.0
var radius := 10.0
var length := 20.0
var beam := 6.0

var dead := false
var sinking := 0.0
var aggro_player := false
var surrendered := false
var mission_target := false
var velocity := Vector3.ZERO

var model: Dictionary
var _pitch := 0.0
var _roll := 0.0
var _y := 0.0
var _wheel_angle := 0.0
var _sail_update := 0.0
var _last_fill := -9.0
var _last_furl := -9.0
var _last_dmg := -9.0
var _fires: Array = []
var _lantern: OmniLight3D
var _rng := RandomNumberGenerator.new()

# IA
var ai_target: Ship
var ai_dest := Vector2.ZERO
var ai_think := 0.0
var ai_side := 1.0
var ai_flee := false
var ai_avoid := 0.0
var ai_fire_delay := 0.0


func setup(type_i: int, nat: int, r: int, player := false, flag := -1) -> void:
	type_idx = type_i
	def = Game.SHIPS[type_i]
	nation = nat
	flag_nation = flag if flag >= 0 else nat
	role = r
	is_player = player
	_rng.randomize()
	length = def["len"]
	beam = def["beam"]
	radius = length * 0.55
	max_hp = def["hp"]
	hp = max_hp
	max_crew = def["crew"]
	crew = int(max_crew * _rng.randf_range(0.6, 0.95))
	reload_time = 7.5 - minf(def["guns"], 26) * 0.08
	model = ShipBuilder.build(def, nat, Game.NATIONS[flag_nation]["flag"])
	add_child(model["root"])
	if player:
		_lantern = OmniLight3D.new()
		_lantern.light_color = Color(1.0, 0.7, 0.35)
		_lantern.omni_range = 22.0
		_lantern.light_energy = 0.0
		_lantern.shadow_enabled = false
		_lantern.position = model["lantern"]
		model["root"].add_child(_lantern)
	if not player:
		ship_name = _random_name()
		gold = int(def["price"] * _rng.randf_range(0.04, 0.12)) + (300 if role == Role.MERCHANT else 0)
		var g: Dictionary = Game.GOODS[_rng.randi() % Game.GOODS.size()]
		cargo[g["id"]] = int(def["cargo"] * _rng.randf_range(0.2, 0.6)) if role == Role.MERCHANT else _rng.randi_range(0, 10)


func apply_player_stats() -> void:
	var up: Dictionary = Game.upgrades
	max_hp = Game.max_hull()
	hp = minf(Game.hull_hp, max_hp)
	sail_hp = Game.sail_hp
	crew = Game.crew
	max_crew = Game.max_crew()
	reload_time = (7.5 - minf(def["guns"], 26) * 0.08) * pow(0.88, up["artilheiros"])
	dmg_mult = 1.0 + 0.15 * up["canhoes"]
	speed_mult = 1.0 + 0.06 * up["velas"]
	ammo = Game.ammo


func set_flag(flag_type: int) -> void:
	for f in model["flag_mats"]:
		f["mat"].set_shader_parameter("flag_type", flag_type)


func _random_name() -> String:
	var pre := ["Santa", "San", "Nuestra Señora", "HMS", "Le", "De", "Bom", "Royal", "La"]
	var names := ["Fortuna", "Esperança", "Vingança", "Trinidad", "Revenge", "Gloire", "Zeeleeuw", "Rosário",
		"Concórdia", "Tempestade", "Sereia", "Dragão", "Victoria", "Défiance", "Amsterdam", "Estrela", "Corvo", "Falcão"]
	match nation:
		Game.ENG: return "HMS " + ["Revenge", "Dover", "Swallow", "Defiance", "Monmouth", "Lion", "Kingfisher"][_rng.randi() % 7]
		Game.ESP: return ["Santa Rosa", "San Felipe", "Nuestra Señora del Carmen", "San José", "Trinidad", "Santa Ana"][_rng.randi() % 6]
		Game.FRA: return ["La Gloire", "Le Triomphant", "La Licorne", "Le Fougueux", "L'Hermine", "La Sirène"][_rng.randi() % 6]
		Game.HOL: return ["Zeeleeuw", "De Zeven Provinciën", "Amsterdam", "Gouden Leeuw", "Hollandia", "Vrijheid"][_rng.randi() % 6]
		Game.POR: return ["Nossa Senhora da Graça", "São Gabriel", "Bom Jesus", "Santa Catarina", "Padre Eterno", "São Bento"][_rng.randi() % 6]
	return ["Vingança da Rainha", "Fortuna Negra", "Corvo do Mar", "Caveira Rubra", "Dragão Faminto", "Sereia Maldita"][_rng.randi() % 6]


func forward() -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))


func pos2() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func display_name() -> String:
	var n: String = ship_name if ship_name != "" else def["name"]
	return "%s (%s %s)" % [n, def["name"], Game.NATIONS[flag_nation]["adj"]]


static func sail_efficiency(angle_from_downwind: float) -> float:
	var a := rad_to_deg(absf(angle_from_downwind))
	var pts := [[0.0, 0.8], [45.0, 1.0], [90.0, 0.95], [120.0, 0.65], [145.0, 0.3], [180.0, 0.12]]
	for i in pts.size() - 1:
		if a <= pts[i + 1][0]:
			var k: float = (a - pts[i][0]) / (pts[i + 1][0] - pts[i][0])
			return lerpf(pts[i][1], pts[i + 1][1], k)
	return 0.12


func wind_angle_from_downwind() -> float:
	var w := World.I.wind_vec()
	return forward().angle_to(w)


# ------------------------------------------------------------------ física
func _physics_process(delta: float) -> void:
	if World.I == null:
		return
	if dead:
		_sink(delta)
		return
	if not is_player:
		_ai(delta)
	for s in reload:
		reload[s] = maxf(0.0, reload[s] - delta)
	var a := wind_angle_from_downwind()
	var eff := sail_efficiency(a)
	sail_actual = move_toward(sail_actual, sail_level, delta * 0.45)
	var max_s: float = def["speed"] * speed_mult
	var target := max_s * sail_actual * eff * (0.35 + 0.65 * sail_hp / 100.0) * World.I.wind_strength
	if crew < max_crew * 0.25:
		target *= 0.6
	var accel := max_s * 0.09
	if speed < target:
		speed = minf(target, speed + accel * delta)
	else:
		speed = maxf(target, speed - (accel * 0.6 + speed * 0.06) * delta)
	var steer := clampf(speed / (max_s * 0.35) + 0.2, 0.25, 1.0)
	var yaw_rate := -rudder * float(def["turn"]) * steer
	yaw = wrapf(yaw + yaw_rate * delta, -PI, PI)
	var f := forward()
	var np := pos2() + f * speed * delta
	# encalhe em ilhas
	var bow := np + f * length * 0.5
	var th := World.I.terrain_height(bow.x, bow.y)
	var th2 := World.I.terrain_height(np.x, np.y)
	if th > -1.6 or th2 > -2.0:
		if speed > 4.0:
			take_raw_damage(speed * 4.0)
			if is_player:
				Game.notify("Encalhou! O casco foi danificado.", Color(1, 0.6, 0.3))
				World.I.shake(0.6)
			Sfx.play_at("hit", global_position, 0.0, 0.6)
		speed = -1.0
		np = pos2() - f * 1.5
	var lim := Game.WORLD_HALF - 100.0
	np.x = clampf(np.x, -lim, lim)
	np.y = clampf(np.y, -lim, lim)
	velocity = Vector3(f.x, 0.0, f.y) * speed
	_float(np, delta, yaw_rate, a)
	_visuals(delta, eff, a)


func _float(np: Vector2, delta: float, yaw_rate: float, wind_a: float) -> void:
	var f := forward()
	var r := Vector2(-f.y, f.x)  # direita (estibordo)
	var hl := length * 0.38
	var hb := beam * 0.45
	var hb_ := Ocean.height_at(np.x + f.x * hl, np.y + f.y * hl)
	var hs := Ocean.height_at(np.x - f.x * hl, np.y - f.y * hl)
	var hp_ := Ocean.height_at(np.x - r.x * hb, np.y - r.y * hb)
	var hst := Ocean.height_at(np.x + r.x * hb, np.y + r.y * hb)
	var avg := (hb_ + hs + hp_ + hst) * 0.25
	var size_lag := clampf(20.0 / length, 0.35, 1.0)
	var t_pitch := atan2(hb_ - hs, hl * 2.0) * 0.9
	var t_roll := atan2(hst - hp_, hb * 2.0) * 0.7
	# adernar com o vento lateral e nas curvas
	var side_wind := sin(wind_a)
	t_roll += side_wind * sail_actual * 0.07 * World.I.wind_strength
	t_roll += yaw_rate * speed * 0.012
	var k := 1.0 - exp(-delta * 3.0 * size_lag)
	_pitch = lerpf(_pitch, t_pitch, k)
	_roll = lerpf(_roll, t_roll, k)
	_y = lerpf(_y, avg, 1.0 - exp(-delta * 4.0 * size_lag))
	global_position = Vector3(np.x, _y - sinking, np.y)
	basis = Basis.from_euler(Vector3(_pitch, yaw, _roll))


func _visuals(delta: float, eff: float, wind_a: float) -> void:
	_wheel_angle = lerpf(_wheel_angle, -rudder * 2.4, delta * 4.0)
	var wheel: Node3D = model["wheel"]
	wheel.rotation.z = _wheel_angle
	_sail_update -= delta
	var near := is_player or World.I.listener_pos().distance_squared_to(global_position) < 900.0 * 900.0
	if _sail_update > 0.0 or not near:
		return
	_sail_update = 0.08
	var w := World.I.wind_vec()
	# vento em coordenadas locais do navio (x = estibordo, z = popa)
	var f := forward()
	var right := Vector2(-f.y, f.x)
	var wx := w.dot(right)
	var wz := -w.dot(f)
	var brace := -clampf(atan2(wx, -wz) * 0.5, -0.6, 0.6)
	for y in model["yards"]:
		y.rotation.y = lerp_angle(y.rotation.y, brace, 0.25)
	var running := clampf(1.0 - absf(wind_a) / PI, 0.0, 1.0)
	var boom := signf(wx if absf(wx) > 0.05 else 0.05) * lerpf(0.25, 1.2, running)
	for p in model["fore_aft"]:
		p.rotation.y = lerp_angle(p.rotation.y, boom, 0.2)
	var fill := clampf(eff * 1.05, 0.0, 1.0) * World.I.wind_strength
	if eff < 0.2:
		fill = -0.15
	var furl := sail_actual
	var dmg := clampf(1.0 - sail_hp / 100.0, 0.0, 1.0)
	if absf(fill - _last_fill) > 0.02 or absf(furl - _last_furl) > 0.01 or absf(dmg - _last_dmg) > 0.02:
		_last_fill = fill
		_last_furl = furl
		_last_dmg = dmg
		for m in model["sails"]:
			m.set_shader_parameter("fill", fill)
			m.set_shader_parameter("furl", clampf(furl, 0.0, 1.0))
			m.set_shader_parameter("damage", dmg)
	var flag_rot := atan2(-wz, wx)
	for fm in model["flag_mats"]:
		var n: Node3D = fm["node"]
		n.rotation.y = lerp_angle(n.rotation.y, flag_rot, 0.2)
	if _lantern:
		_lantern.light_energy = World.I.night_factor() * 1.6


# ------------------------------------------------------------------ combate
func side_normal(side: float) -> Vector2:
	var f := forward()
	return Vector2(-f.y, f.x) * side


func can_fire(side: float) -> bool:
	return reload[side] <= 0.0 and not dead and crew > 3


func reload_frac(side: float) -> float:
	var rt := reload_time * (1.0 + clampf(1.0 - float(crew) / max_crew, 0.0, 1.0) * 1.5)
	return clampf(1.0 - reload[side] / rt, 0.0, 1.0)


## Procura o melhor alvo dentro do arco do costado.
func find_target(side: float, only_hostile: bool) -> Ship:
	var best: Ship = null
	var best_score := INF
	var sn := side_normal(side)
	for s in World.I.ships:
		if s == self or s.dead:
			continue
		var d := s.pos2() - pos2()
		var dist := d.length()
		if dist > RANGE + 40.0 or dist < 5.0:
			continue
		var ang := absf(sn.angle_to(d))
		if ang > deg_to_rad(42.0):
			continue
		if only_hostile and not World.I.hostile(self, s):
			continue
		var score := dist * (1.0 + ang)
		if is_player and (s.aggro_player or Game.nation_hostile_to_player(s.flag_nation)):
			score *= 0.5
		if score < best_score:
			best_score = score
			best = s
	return best


func fire(side: float) -> void:
	if not can_fire(side):
		return
	var rt := reload_time * (1.0 + clampf(1.0 - float(crew) / max_crew, 0.0, 1.0) * 1.5)
	reload[side] = rt
	var target := find_target(side, not is_player)
	var guns: Array = model["guns"][side]
	var dmg := 26.0 * dmg_mult
	var aim_dir := side_normal(side)
	var elev := deg_to_rad(5.0)
	if target:
		var tp := target.pos2()
		var dist := tp.distance_to(pos2())
		var flight := dist / (MUZZLE * 0.97)
		tp += Vector2(target.velocity.x, target.velocity.z) * flight
		var to := tp - pos2()
		var ang := clampf(side_normal(side).angle_to(to), -0.5, 0.5)
		aim_dir = side_normal(side).rotated(ang)
		elev = Projectiles.solve_elevation(to.length(), -2.0, MUZZLE)
	var main_pos := Vector3.ZERO
	for i in guns.size():
		var lp: Vector3 = guns[i]
		var wp := global_transform * lp
		main_pos += wp
		var spread := 0.025 if is_player else 0.05
		var d2 := aim_dir.rotated(_rng.randf_range(-spread, spread))
		var e := elev + _rng.randf_range(-spread, spread) * 0.6
		var v := Vector3(d2.x * cos(e), sin(e), d2.y * cos(e)) * MUZZLE * _rng.randf_range(0.97, 1.03)
		v += velocity
		var delay := i * 0.05 + _rng.randf_range(0.0, 0.08)
		_fire_one.call_deferred(wp, v, dmg, delay, Vector3(d2.x, 0.15, d2.y))
	main_pos /= maxf(guns.size(), 1)
	Sfx.play_at("cannon", main_pos, 6.0 if is_player else 2.0)
	if guns.size() > 6:
		get_tree().create_timer(0.25).timeout.connect(func(): Sfx.play_at("cannon", main_pos, 2.0, 0.85))
	if is_player:
		World.I.shake(0.35)


func _fire_one(wp: Vector3, v: Vector3, dmg: float, delay: float, dir: Vector3) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_inside_tree() or dead:
		return
	Projectiles.I.fire(wp, v, self, flag_nation, dmg, ammo, is_player)
	Effects.I.emit("flash", wp, dir)
	Effects.I.emit("smoke", wp, dir)


## Retorna o ponto de impacto (ou Vector3.INF) do segmento a->b contra o casco e as velas.
func hit_test(a: Vector3, b: Vector3) -> Vector3:
	var inv := global_transform.affine_inverse()
	for k in 3:
		var p: Vector3 = (a.lerp(b, (k + 1) / 3.0))
		var l := inv * p
		var t := clampf(0.5 - l.z / length, 0.0, 1.0)
		var hw := ShipBuilder.half_width(t, beam) + 0.4
		var top := ShipBuilder.deck_height(t, def) + 1.4
		if absf(l.z) < length * 0.5 and absf(l.x) < hw and l.y > -beam * 0.4 and l.y < top:
			return p
		# velas/mastros (só altura acima do convés)
		if absf(l.z) < length * 0.38 and absf(l.x) < beam * 0.9 and l.y > top and l.y < length * 0.8:
			return p + Vector3(0, 0.001, 0)
	return Vector3.INF


func take_hit(dmg: float, ammo_t: int, attacker: Object, point: Vector3, from_player: bool, attacker_nation: int) -> void:
	if dead:
		return
	var l := global_transform.affine_inverse() * point
	var high := l.y > ShipBuilder.deck_height(0.5, def) + 1.4
	match ammo_t:
		0:
			if high:
				sail_hp = maxf(0.0, sail_hp - dmg * 0.12)
			else:
				hp -= dmg
				if _rng.randf() < 0.3:
					crew = maxi(0, crew - 1)
		1:
			sail_hp = maxf(0.0, sail_hp - dmg * (0.55 if high else 0.25))
			hp -= dmg * 0.25
		2:
			crew = maxi(0, crew - _rng.randi_range(1, 3))
			hp -= dmg * 0.3
	Effects.I.emit("hit", point)
	if World.I.listener_pos().distance_to(point) < 500.0:
		Sfx.play_at("hit", point, 2.0)
	if is_player:
		World.I.shake(0.25)
		World.I.player_hit()
	if attacker is Ship:
		World.I.on_ship_attacked(self, attacker, from_player)
	if hp < max_hp * 0.45 and _fires.size() < 1:
		_fires.append(Effects.I.make_fire(self, Vector3(_rng.randf_range(-1, 1), ShipBuilder.deck_height(0.5, def), _rng.randf_range(-length * 0.3, length * 0.3))))
	if hp < max_hp * 0.2 and _fires.size() < 2:
		_fires.append(Effects.I.make_fire(self, Vector3(0, ShipBuilder.deck_height(0.3, def), length * 0.2), true))
	if hp <= 0.0:
		die(from_player)


func take_raw_damage(v: float) -> void:
	hp -= v
	if hp <= 0.0 and not dead:
		die(false)


func die(by_player: bool) -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	sinking = 0.0
	if _fires.size() < 2:
		_fires.append(Effects.I.make_fire(self, Vector3(0, ShipBuilder.deck_height(0.5, def), 0), true))
	World.I.on_ship_sunk(self, by_player)


func _sink(delta: float) -> void:
	sinking += delta * (0.55 + sinking * 0.05)
	_roll = lerpf(_roll, 0.7, delta * 0.15)
	_pitch = lerpf(_pitch, -0.25, delta * 0.1)
	speed = move_toward(speed, 0.0, delta * 2.0)
	var p := pos2() + forward() * speed * delta
	global_position = Vector3(p.x, _y - sinking, p.y)
	basis = Basis.from_euler(Vector3(_pitch, yaw, _roll))
	if sinking > 6.0:
		for f in _fires:
			if is_instance_valid(f):
				f.emitting = false
	if sinking > length * 0.9 + 12.0:
		World.I.remove_ship(self)


func repair_from_game() -> void:
	apply_player_stats()


# ------------------------------------------------------------------ IA
func _ai(delta: float) -> void:
	ai_think -= delta
	ai_fire_delay -= delta
	if surrendered:
		sail_level = 0.0
		rudder = 0.0
		return
	if ai_think <= 0.0:
		ai_think = 0.4 + _rng.randf() * 0.2
		_ai_decide()
	var desired := yaw
	var p := pos2()
	if ai_target and is_instance_valid(ai_target) and not ai_target.dead and not ai_flee:
		var to := ai_target.pos2() - p
		var dist := to.length()
		var bearing := atan2(-to.x, -to.y)
		if dist > 430.0:
			desired = bearing
			sail_level = 1.0
		else:
			var b1 := wrapf(bearing + PI * 0.5, -PI, PI)  # alvo a bombordo... ajustado abaixo
			var b2 := wrapf(bearing - PI * 0.5, -PI, PI)
			var d1 := absf(angle_difference(yaw, b1))
			var d2 := absf(angle_difference(yaw, b2))
			desired = b1 if d1 < d2 else b2
			if dist < 110.0:
				desired = wrapf(bearing + PI, -PI, PI) if dist < 60.0 else desired + (0.35 if d1 < d2 else -0.35)
			sail_level = 0.75
		# disparar quando o alvo estiver no arco do costado
		if ai_fire_delay <= 0.0 and dist < RANGE:
			for side in [1.0, -1.0]:
				var ang := absf(side_normal(side).angle_to(to))
				if ang < deg_to_rad(22.0) and can_fire(side):
					fire(side)
					ai_fire_delay = 1.0
					break
	else:
		var to := ai_dest - p
		if ai_flee and ai_target and is_instance_valid(ai_target):
			to = p - ai_target.pos2()
		desired = atan2(-to.x, -to.y)
		sail_level = 1.0
	# desviar de ilhas
	if ai_avoid != 0.0:
		desired = yaw + ai_avoid
	var diff := angle_difference(yaw, desired)
	rudder = clampf(-diff * 2.2, -1.0, 1.0)


func _ai_decide() -> void:
	var p := pos2()
	# sondagem de terra à frente
	ai_avoid = 0.0
	var f := forward()
	var look := 70.0 + speed * 9.0
	for k in [0.0, 0.45, -0.45]:
		var d := f.rotated(k) * look
		var probe := p + d
		if World.I.terrain_height(probe.x, probe.y) > -3.0:
			var l := p + f.rotated(-0.7) * look
			var r := p + f.rotated(0.7) * look
			var hl := World.I.terrain_height(l.x, l.y)
			var hr := World.I.terrain_height(r.x, r.y)
			ai_avoid = 0.9 if hl < hr else -0.9
			break
	if ai_target and (not is_instance_valid(ai_target) or ai_target.dead or ai_target.pos2().distance_to(p) > 1300.0):
		ai_target = null
		ai_flee = false
	var hostile_near: Ship = null
	var best := INF
	var sight := 950.0 if role != Role.MERCHANT else 650.0
	for s in World.I.ships:
		if s == self or s.dead:
			continue
		var dist := s.pos2().distance_to(p)
		if dist < sight and dist < best and World.I.hostile(self, s):
			best = dist
			hostile_near = s
	if hostile_near and ai_target == null:
		ai_target = hostile_near
	match role:
		Role.MERCHANT:
			ai_flee = ai_target != null and hp > max_hp * 0.15
			if ai_target and best < 220.0 and hp < max_hp * 0.5 and not surrendered:
				surrendered = true
				sail_level = 0.0
		Role.PIRATE:
			ai_flee = ai_target != null and hp < max_hp * 0.3
		_:
			ai_flee = false
	if ai_dest == Vector2.ZERO or p.distance_to(ai_dest) < 250.0:
		ai_dest = World.I.random_destination(self)
