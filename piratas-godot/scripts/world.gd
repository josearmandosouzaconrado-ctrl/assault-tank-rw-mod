class_name World
extends Node3D
## O mundo aberto: arquipélago, oceano, céu, clima, tráfego de navios, fortes e regras do jogo.

signal player_ship_changed
signal player_died

static var I: World

const GRID := 800.0
const SHALLOW_RES := 384
const ISLAND_BUILD_DIST := 6800.0

var ships: Array[Ship] = []
var player: Ship
var islands: Array[Island] = []
var port_islands: Array[Island] = []
var _grid := {}
var ocean: Ocean
var proj: Projectiles
var fx: Effects
var env: Environment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_mat: ShaderMaterial
var rain: CPUParticles3D
var ctl: Node   # PlayerController

var wind_angle := 0.4
var wind_strength := 1.0
var storm := 0.0
var _storm_target := 0.0
var _storm_timer := 240.0
var _env_timer := 0.0
var _spawn_timer := 1.0
var _fort_reload: Array[float] = []
var port_aggro: Array[bool] = []
var _lightning := 0.0
var _build_queue: Array[Island] = []
var loot: Array = []
var _rng := RandomNumberGenerator.new()
var _treasure_marker: Node3D
var _mission_marker: Node3D
var _cloud_off := Vector2.ZERO
var paused_world := false


func _init() -> void:
	I = self


func _ready() -> void:
	_rng.randomize()
	_setup_environment()
	ocean = Ocean.new()
	add_child(ocean)
	proj = Projectiles.new()
	add_child(proj)
	fx = Effects.new()
	add_child(fx)
	rain = fx.make_rain()
	add_child(rain)
	_generate_islands()
	Island.warm_caches()
	for i in port_islands.size():
		_fort_reload.append(_rng.randf_range(0.0, 4.0))
		port_aggro.append(false)
	_make_shallow_map()
	_update_environment(true)
	_treasure_marker = _make_marker(Color(1.0, 0.85, 0.2))
	_mission_marker = _make_marker(Color(1.0, 0.25, 0.2))


# ================================================================ geração
func _generate_islands() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for i in Game.PORTS_DEF.size():
		var p: Dictionary = Game.PORTS_DEF[i]
		var isl := Island.new(p["pos"], p["r"], rng.randf_range(38.0, 75.0), 1000 + i)
		isl.port_idx = i
		isl.name = p["name"]
		isl.plan_port()
		islands.append(isl)
		port_islands.append(isl)
	var tries := 0
	while islands.size() < Game.PORTS_DEF.size() + 52 and tries < 3000:
		tries += 1
		var r: float = rng.randf_range(70.0, 260.0) if rng.randf() < 0.6 else rng.randf_range(260.0, 620.0)
		var p := Vector2(rng.randf_range(-7600, 7600), rng.randf_range(-7600, 7600))
		var ok := true
		for o in islands:
			if o.pos.distance_to(p) < (o.r + r) * 1.55 + 260.0:
				ok = false
				break
		if not ok:
			continue
		var h: float = clampf(r * rng.randf_range(0.04, 0.13), 3.5, 70.0)
		var isl := Island.new(p, r, h, 2000 + islands.size())
		isl.name = _island_name(rng)
		islands.append(isl)
	for idx in islands.size():
		var isl := islands[idx]
		var b := isl.bound()
		var x0 := int(floor((isl.pos.x - b) / GRID))
		var x1 := int(floor((isl.pos.x + b) / GRID))
		var z0 := int(floor((isl.pos.y - b) / GRID))
		var z1 := int(floor((isl.pos.y + b) / GRID))
		for gx in range(x0, x1 + 1):
			for gz in range(z0, z1 + 1):
				var key := Vector2i(gx, gz)
				if not _grid.has(key):
					_grid[key] = []
				_grid[key].append(idx)


func _island_name(rng: RandomNumberGenerator) -> String:
	var a := ["Ilha", "Cayo", "Isla", "Île", "Ilhéu", "Key"]
	var b := ["das Tartarugas", "do Caveira", "Serpiente", "aux Perles", "do Náufrago", "Sombria", "de los Muertos",
		"das Gaivotas", "Esmeralda", "do Corsário", "Perdida", "dos Coqueiros", "da Lua", "Vermelha", "do Bucaneiro", "Rasa"]
	return "%s %s" % [a[rng.randi() % a.size()], b[rng.randi() % b.size()]]


func _make_shallow_map() -> void:
	var img := Image.create(SHALLOW_RES, SHALLOW_RES, false, Image.FORMAT_L8)
	img.fill(Color(0, 0, 0))
	var half := Game.WORLD_HALF
	var texel := half * 2.0 / SHALLOW_RES
	for isl in islands:
		var b := isl.bound() + texel
		var x0 := clampi(int((isl.pos.x - b + half) / texel), 0, SHALLOW_RES - 1)
		var x1 := clampi(int((isl.pos.x + b + half) / texel), 0, SHALLOW_RES - 1)
		var z0 := clampi(int((isl.pos.y - b + half) / texel), 0, SHALLOW_RES - 1)
		var z1 := clampi(int((isl.pos.y + b + half) / texel), 0, SHALLOW_RES - 1)
		for zi in range(z0, z1 + 1):
			for xi in range(x0, x1 + 1):
				var wx := -half + (xi + 0.5) * texel
				var wz := -half + (zi + 0.5) * texel
				var h := isl.height(wx, wz)
				var v := clampf(1.0 + h / 15.0, 0.0, 1.0)
				if v > img.get_pixel(xi, zi).r:
					img.set_pixel(xi, zi, Color(v, v, v))
	var tex := ImageTexture.create_from_image(img)
	ocean.set_shallow_map(tex, half)


func islands_near(x: float, z: float) -> Array:
	return _grid.get(Vector2i(int(floor(x / GRID)), int(floor(z / GRID))), [])


func terrain_height(x: float, z: float) -> float:
	var best := -18.0
	for idx in islands_near(x, z):
		var h := islands[idx].height(x, z)
		if h > best:
			best = h
	return best


func island_at(x: float, z: float) -> Island:
	var best: Island = null
	var bd := INF
	for idx in islands_near(x, z):
		var isl := islands[idx]
		var d := isl.pos.distance_to(Vector2(x, z))
		if d < bd and d < isl.bound():
			bd = d
			best = isl
	return best


func nearest_island(p: Vector2) -> Island:
	var best: Island = null
	var bd := INF
	for isl in islands:
		var d := isl.pos.distance_to(p) - isl.r
		if d < bd:
			bd = d
			best = isl
	return best


## Constrói as ilhas próximas (síncrono, usado na tela de carregamento).
func build_islands_near(p: Vector2, dist: float) -> void:
	if _build_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_build_task)
		_build_task = -1
		if _build_isl and _build_isl.node and not _build_isl.node.is_inside_tree():
			add_child(_build_isl.node)
			_build_isl.node.position = Vector3(_build_isl.pos.x, 0.0, _build_isl.pos.y)
		_build_isl = null
	for isl in islands:
		if isl.node == null and isl.pos.distance_to(p) < dist + isl.r:
			add_child(isl.build())
			isl.node.position = Vector3(isl.pos.x, 0.0, isl.pos.y)


var _build_task := -1
var _build_isl: Island


func _stream_islands() -> void:
	# a malha da ilha é gerada numa thread para não travar o jogo
	if _build_task >= 0:
		if not WorkerThreadPool.is_task_completed(_build_task):
			return
		WorkerThreadPool.wait_for_task_completion(_build_task)
		_build_task = -1
		if _build_isl.node:
			add_child(_build_isl.node)
			_build_isl.node.position = Vector3(_build_isl.pos.x, 0.0, _build_isl.pos.y)
		_build_isl = null
		return
	var p := listener_pos()
	var p2 := Vector2(p.x, p.z)
	if _build_queue.is_empty():
		for isl in islands:
			if isl.node == null and not isl.building and isl.pos.distance_to(p2) < ISLAND_BUILD_DIST + isl.r:
				isl.building = true
				_build_queue.append(isl)
		_build_queue.sort_custom(func(a, b): return a.pos.distance_to(p2) < b.pos.distance_to(p2))
	if not _build_queue.is_empty():
		_build_isl = _build_queue.pop_front()
		if _build_isl.node != null:
			_build_isl = null
			return
		_build_task = WorkerThreadPool.add_task(_build_isl.build, false, "ilha")


func _exit_tree() -> void:
	if _build_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_build_task)
		_build_task = -1


# ================================================================ ambiente
func _setup_environment() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	var nt := NoiseTexture2D.new()
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.008
	fn.fractal_octaves = 5
	nt.noise = fn
	sky_mat.set_shader_parameter("cloud_noise", nt)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64 if Game.quality < 2 else Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_AUTOMATIC
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.glow_enabled = Game.quality > 0
	env.glow_intensity = 0.55
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_density = 0.00016
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = Game.quality > 0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 220.0 if Game.quality < 2 else 380.0
	sun.shadow_blur = 1.5
	sun.light_angular_distance = 0.5
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = 0.18
	moon.shadow_enabled = false
	add_child(moon)


func night_factor() -> float:
	var e := sin((Game.time_of_day - 0.25) * TAU)
	return 1.0 - smoothstep(-0.12, 0.12, e)


func _sun_dir() -> Vector3:
	var a := (Game.time_of_day - 0.25) * TAU
	var elev := sin(a) * deg_to_rad(68.0)
	var az := -cos(a) * 1.4 + 0.5
	return Vector3(cos(elev) * cos(az), sin(elev), cos(elev) * sin(az)).normalized()


var _rad_day := -1.0
var _rad_storm := -1.0
var _rad_flip := false


## O renderizador de compatibilidade não refaz o reflexo do céu quando os parâmetros mudam;
## trocamos o tamanho do mapa de radiância para forçar a atualização quando a luz muda bastante.
func _refresh_radiance(day: float, force: bool) -> void:
	if not force and absf(day - _rad_day) < 0.05 and absf(storm - _rad_storm) < 0.1:
		return
	_rad_day = day
	_rad_storm = storm
	_rad_flip = not _rad_flip
	var sizes := [Sky.RADIANCE_SIZE_32, Sky.RADIANCE_SIZE_64] if Game.quality < 2 else [Sky.RADIANCE_SIZE_64, Sky.RADIANCE_SIZE_128]
	env.sky.radiance_size = sizes[1] if _rad_flip else sizes[0]


func _update_environment(force := false) -> void:
	var sd := _sun_dir()
	var e := sd.y
	var day := smoothstep(-0.12, 0.25, e)
	var low := 1.0 - smoothstep(0.0, 0.35, e)
	var st := storm
	sun.visible = e > -0.08
	if sun.visible:
		sun.basis = Basis.looking_at(-sd, Vector3.UP if absf(sd.y) < 0.99 else Vector3.FORWARD)
	sun.light_color = Color(1.0, 0.97, 0.9).lerp(Color(1.0, 0.55, 0.28), low)
	sun.light_energy = smoothstep(-0.06, 0.12, e) * 1.35 * (1.0 - st * 0.75)
	var md := Vector3(-sd.x, absf(sd.y) * 0.8 + 0.25, -sd.z).normalized()
	moon.visible = e < 0.05
	if moon.visible:
		moon.basis = Basis.looking_at(-md, Vector3.UP)
	moon.light_energy = 0.75 * (1.0 - st * 0.7)
	sky_mat.set_shader_parameter("moon_dir", md)
	sky_mat.set_shader_parameter("sun_dir", sd)
	sky_mat.set_shader_parameter("storm", st)
	sky_mat.set_shader_parameter("cloud_offset", _cloud_off)
	sky_mat.set_shader_parameter("cloud_cover", 0.38 + st * 0.4)
	env.ambient_light_energy = lerpf(0.8, 0.85, day) * (1.0 - st * 0.3)
	env.ambient_light_sky_contribution = lerpf(0.35, 1.0, day)
	env.ambient_light_color = Color(0.2, 0.27, 0.45)
	_refresh_radiance(day + sd.y * 0.0, force)
	env.tonemap_exposure = lerpf(1.25, 0.95, day)
	var hor := Color(0.06, 0.09, 0.17).lerp(Color(0.62, 0.78, 0.9), day)
	hor = hor.lerp(Color(1.0, 0.55, 0.24), clampf(1.0 - absf(e - 0.02) * 4.0, 0.0, 1.0) * 0.6)
	hor = hor.lerp(Color(0.35, 0.38, 0.42) * (0.3 + 0.7 * day), st * 0.8)
	env.fog_light_color = hor
	env.fog_density = 0.00016 + st * 0.0006
	ocean.mat.set_shader_parameter("light_level", 0.25 + day * 0.75 * (1.0 - st * 0.5))
	var glow := ShipBuilder.glow_material()
	var nf := night_factor()
	glow.emission_energy_multiplier = nf * 2.2 + 0.05
	glow.albedo_color = Color(0.25, 0.2, 0.15).lerp(Color(1.0, 0.75, 0.35), nf)


func _weather(delta: float) -> void:
	_storm_timer -= delta
	if _storm_timer <= 0.0:
		_storm_timer = _rng.randf_range(150.0, 420.0)
		_storm_target = 1.0 if (_storm_target < 0.5 and _rng.randf() < 0.3) else 0.0
		if _storm_target > 0.5:
			Game.notify("O céu escurece... uma tempestade se aproxima!", Color(0.7, 0.8, 1.0))
	storm = move_toward(storm, _storm_target, delta / 40.0)
	wind_angle += (sin(Time.get_ticks_msec() * 0.00002) * 0.004 + (_rng.randf() - 0.5) * 0.002) * delta * 10.0
	wind_strength = 0.85 + 0.12 * sin(Time.get_ticks_msec() * 0.00005) + storm * 0.35
	Ocean.wind_angle = wind_angle
	Ocean.sea_state = 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.00003) + storm * 1.05
	Ocean.update_dirs()
	_cloud_off += Vector2(cos(wind_angle), sin(wind_angle)) * delta * 0.0012 * wind_strength
	var lp := listener_pos()
	rain.global_position = lp + Vector3(0, 18, 0)
	rain.emitting = storm > 0.45
	if storm > 0.6:
		_lightning -= delta
		if _lightning <= 0.0:
			_lightning = _rng.randf_range(6.0, 18.0)
			_flash_lightning()
	Sfx.set_wind_level(wind_strength * 0.5 + storm * 0.5)
	Sfx.set_ocean_level(0.4 + storm * 0.6)


func _flash_lightning() -> void:
	var e0 := env.ambient_light_energy
	env.ambient_light_energy = 3.0
	await get_tree().create_timer(0.12).timeout
	env.ambient_light_energy = e0
	await get_tree().create_timer(_rng.randf_range(0.4, 1.6)).timeout
	Sfx.play("cannon", -4.0, 0.45)


func wind_vec() -> Vector2:
	return Vector2(cos(wind_angle), sin(wind_angle))


func listener_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam:
		return cam.global_position
	return player.global_position if player else Vector3.ZERO


func shake(v: float) -> void:
	if ctl:
		ctl.shake(v)


func player_hit() -> void:
	Game.hull_hp = player.hp
	Game.crew = player.crew
	Game.sail_hp = player.sail_hp


# ================================================================ loop
func _process(delta: float) -> void:
	if paused_world:
		return
	Game.advance_time(delta)
	_env_timer -= delta
	if _env_timer <= 0.0:
		_env_timer = 1.0
		_update_environment()
	_weather(delta)
	_stream_islands()
	_update_loot(delta)
	_update_markers()


func _physics_process(delta: float) -> void:
	if paused_world or player == null:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 2.0
		_spawn_tick()
	_separate_ships()
	_forts(delta)
	if not player.dead:
		Game.player_pos = player.pos2()
		Game.player_yaw = player.yaw
		Game.hull_hp = player.hp
		Game.sail_hp = player.sail_hp
		Game.crew = player.crew
		_check_mission_spawn()


func _separate_ships() -> void:
	for i in ships.size():
		var a := ships[i]
		if a.dead:
			continue
		for j in range(i + 1, ships.size()):
			var b := ships[j]
			if b.dead:
				continue
			var d := b.pos2() - a.pos2()
			var min_d := (a.radius + b.radius) * 0.55
			var dist := d.length()
			if dist < min_d and dist > 0.01:
				var push := d / dist * (min_d - dist) * 0.5
				a.global_position -= Vector3(push.x, 0, push.y)
				b.global_position += Vector3(push.x, 0, push.y)
				var rel := absf(a.speed - b.speed)
				if rel > 3.0:
					a.speed *= 0.6
					b.speed *= 0.6


# ================================================================ navios
func spawn_player() -> void:
	if player:
		ships.erase(player)
		player.queue_free()
	player = Ship.new()
	player.setup(Game.ship_type, Game.career, Ship.Role.PLAYER, true, Game.player_flag())
	player.ship_name = "Capitão " + Game.captain_name
	player.yaw = Game.player_yaw
	player.apply_player_stats()
	player.sail_level = 0.0
	player.sail_actual = 0.0
	add_child(player)
	var p := Game.player_pos
	if terrain_height(p.x, p.y) > -6.0:
		p = _find_water_near(p)
	player.global_position = Vector3(p.x, 0.0, p.y)
	ships.append(player)
	player_ship_changed.emit()


func _find_water_near(p: Vector2) -> Vector2:
	for r in range(50, 3000, 50):
		for k in 16:
			var q := p + Vector2.from_angle(TAU * k / 16.0) * r
			if terrain_height(q.x, q.y) < -10.0:
				return q
	return p


func spawn_ship(type_i: int, nat: int, role: int, p: Vector2, yaw := 0.0) -> Ship:
	var s := Ship.new()
	s.setup(type_i, nat, role)
	s.yaw = yaw
	add_child(s)
	s.global_position = Vector3(p.x, 0.0, p.y)
	ships.append(s)
	return s


func remove_ship(s: Ship) -> void:
	ships.erase(s)
	if s == player:
		return
	s.queue_free()


func npc_count() -> int:
	var n := 0
	for s in ships:
		if not s.is_player and not s.dead:
			n += 1
	return n


func _spawn_tick() -> void:
	var lp := player.pos2()
	# remover navios distantes
	for s in ships.duplicate():
		if s.is_player or s.mission_target:
			continue
		if s.pos2().distance_to(lp) > 3800.0:
			remove_ship(s)
	var want: int = [5, 7, 10][Game.quality]
	if npc_count() >= want:
		return
	var p := Vector2.ZERO
	var ok := false
	for k in 12:
		p = lp + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(1300.0, 2600.0)
		if absf(p.x) < Game.WORLD_HALF - 300 and absf(p.y) < Game.WORLD_HALF - 300 and terrain_height(p.x, p.y) < -12.0:
			ok = true
			break
	if not ok:
		return
	var near_port := nearest_port(p)
	var nat: int = Game.port_owner[near_port] if _rng.randf() < 0.65 else _rng.randi() % 5
	var roll := _rng.randf()
	var role := Ship.Role.MERCHANT
	var type_i := 1
	var power := Game.rank_index()
	if Game.career == Game.PIR and Game.bounty > 1500 and roll < 0.18:
		role = Ship.Role.HUNTER
		nat = _rng.randi() % 5
		type_i = [2, 3, 3, 4][mini(power, 3)] if _rng.randf() < 0.8 else 5
	elif roll < 0.42 or nat == Game.PIR:
		if nat == Game.PIR or roll < 0.2:
			role = Ship.Role.PIRATE
			nat = Game.PIR
			type_i = [0, 1, 1, 2, 3][clampi(power + _rng.randi_range(-1, 1), 0, 4)]
		else:
			role = Ship.Role.PATROL
			type_i = [2, 2, 3, 3, 5][clampi(power + _rng.randi_range(-1, 1), 0, 4)]
	else:
		role = Ship.Role.MERCHANT
		type_i = [1, 2, 4, 4][_rng.randi() % 4]
	var s := spawn_ship(type_i, nat, role, p, _rng.randf() * TAU)
	s.ai_dest = random_destination(s)
	s.speed = s.def["speed"] * 0.6
	s.sail_actual = 1.0
	if role == Ship.Role.HUNTER:
		s.ai_target = player
		s.aggro_player = true


func nearest_port(p: Vector2) -> int:
	var best := 0
	var bd := INF
	for i in port_islands.size():
		var d := port_islands[i].dock_point.distance_to(p)
		if d < bd:
			bd = d
			best = i
	return best


func random_destination(s: Ship) -> Vector2:
	if s.role == Ship.Role.MERCHANT:
		var cands: Array[int] = []
		for i in port_islands.size():
			if not Game.are_enemies(Game.port_owner[i], s.nation) and port_islands[i].dock_point.distance_to(s.pos2()) > 1500.0:
				cands.append(i)
		if not cands.is_empty():
			var pi := cands[_rng.randi() % cands.size()]
			return port_islands[pi].dock_point + Vector2.from_angle(_rng.randf() * TAU) * 160.0
	if s.role == Ship.Role.HUNTER and player:
		return player.pos2()
	for k in 10:
		var q := s.pos2() + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(800.0, 2500.0)
		if absf(q.x) < 7600 and absf(q.y) < 7600 and terrain_height(q.x, q.y) < -10.0:
			return q
	return Vector2.ZERO


func _player_vs(s: Ship) -> bool:
	return s.aggro_player or s.role == Ship.Role.HUNTER or Game.nation_hostile_to_player(s.flag_nation)


func hostile(a: Ship, b: Ship) -> bool:
	if a.dead or b.dead:
		return false
	if a.is_player:
		return _player_vs(b)
	if b.is_player:
		return _player_vs(a)
	return Game.are_enemies(a.flag_nation, b.flag_nation)


func on_ship_attacked(victim: Ship, attacker: Ship, from_player: bool) -> void:
	if not from_player or victim.is_player:
		return
	if Game.false_flag >= 0:
		Game.false_flag = -1
		player.set_flag(Game.NATIONS[Game.career]["flag"])
		player.flag_nation = Game.career
		Game.notify("Você abriu fogo: a bandeira falsa caiu!", Color(1, 0.5, 0.3))
	var was_hostile := _player_vs(victim)
	if not victim.aggro_player:
		victim.aggro_player = true
		if not was_hostile:
			Game.change_rep(victim.flag_nation, -18)
			Game.notify("Você atacou um navio %s sem estar em guerra!" % Game.NATIONS[victim.flag_nation]["adj"], Color(1, 0.4, 0.3))
			if Game.career == Game.PIR:
				Game.bounty += 400
		# a frota da mesma bandeira vem ajudar
		for s in ships:
			if s != victim and not s.is_player and s.flag_nation == victim.flag_nation and s.pos2().distance_to(victim.pos2()) < 1500.0:
				s.aggro_player = true
				if s.role != Ship.Role.MERCHANT:
					s.ai_target = player
	if victim.ai_target == null or victim.ai_target.is_player == false:
		victim.ai_target = player


func on_ship_sunk(s: Ship, by_player: bool) -> void:
	if s.is_player:
		_player_sunk()
		return
	var p := s.global_position
	_spawn_loot(s)
	if not by_player:
		return
	Game.stats["sunk"] += 1
	var guns: int = s.def["guns"]
	var msg := "Você afundou o %s!" % s.display_name()
	if Game.is_navy():
		if Game.are_enemies(s.flag_nation, Game.career):
			var prize := int(s.def["price"] * 0.06)
			Game.gold += prize
			Game.add_merit(guns * 5)
			Game.change_rep(Game.career, 3)
			msg += " Prêmio da Coroa: %d moedas." % prize
		else:
			Game.change_rep(Game.career, -25)
			msg += " A Coroa não aprova isso!"
	else:
		Game.add_merit(guns * 4)
		Game.bounty += guns * 40
	Game.change_rep(s.flag_nation, -6)
	Game.notify(msg, Color(1, 0.85, 0.4))
	if s.mission_target:
		_complete_hunt()
	Sfx.play("bell", -6.0)


func _player_sunk() -> void:
	Game.notify("Seu navio está afundando!", Color(1, 0.2, 0.2))
	await get_tree().create_timer(5.0).timeout
	player_died.emit()


## Recomeço após naufrágio: no porto amigo mais próximo, com um saveiro.
func respawn_after_sinking() -> void:
	var best := -1
	var bd := INF
	for i in port_islands.size():
		if Game.can_dock(i):
			var d := port_islands[i].dock_point.distance_to(Game.player_pos)
			if d < bd:
				bd = d
				best = i
	if best < 0:
		best = Game.home_port(Game.career)
	Game.ship_type = 0
	Game.cargo = {}
	Game.gold = int(Game.gold * 0.5)
	Game.upgrades = {"casco": 0, "velas": 0, "canhoes": 0, "artilheiros": 0}
	Game.hull_hp = Game.max_hull()
	Game.sail_hp = 100.0
	Game.crew = 25
	var isl := port_islands[best]
	var dir := Game.dock_offset(best)
	Game.player_pos = isl.dock_point + dir * 60.0
	Game.player_yaw = atan2(-dir.x, -dir.y)
	proj.clear_all()
	for s in ships.duplicate():
		if not s.is_player:
			remove_ship(s)
	spawn_player()
	Game.notify("Você sobreviveu ao naufrágio e conseguiu um saveiro em %s." % isl.name, Color(0.9, 0.9, 0.6))
	Game.save_game()


func change_player_ship(type_i: int, keep_pos := true) -> void:
	Game.ship_type = type_i
	Game.hull_hp = Game.max_hull()
	Game.crew = mini(Game.crew, Game.max_crew())
	var p := player.pos2()
	var y := player.yaw
	spawn_player()
	if keep_pos:
		player.global_position = Vector3(p.x, 0, p.y)
		player.yaw = y


# ================================================================ abordagem
func boarding_candidate() -> Ship:
	if player == null or player.dead:
		return null
	var best: Ship = null
	var bd := INF
	for s in ships:
		if s.is_player or s.dead:
			continue
		var d := s.pos2().distance_to(player.pos2())
		var reach := (s.radius + player.radius) * 0.9 + 14.0
		if d < reach and d < bd and (s.hp < s.max_hp * 0.4 or s.surrendered or s.crew < s.max_crew * 0.3 or s.sail_hp < 25.0):
			bd = d
			best = s
	return best


## Luta de abordagem. Retorna {"win": bool, "lost": int, "killed": int}
func resolve_boarding(enemy_crew: int, bonus := 1.0) -> Dictionary:
	var mine := float(player.crew) * (1.0 + Game.rank_index() * 0.08) * bonus * _rng.randf_range(0.8, 1.25)
	var theirs := float(enemy_crew) * _rng.randf_range(0.8, 1.2)
	var win := mine > theirs
	var lost := int(minf(player.crew - 1, theirs * _rng.randf_range(0.25, 0.5) * (0.6 if win else 1.0)))
	player.crew = maxi(1, player.crew - lost)
	Game.crew = player.crew
	return {"win": win, "lost": lost, "killed": int(minf(enemy_crew, mine * 0.6))}


func board_loot(s: Ship) -> Dictionary:
	var got := {"gold": s.gold, "cargo": {}}
	Game.gold += s.gold
	for k in s.cargo:
		var n := Game.add_cargo(k, int(s.cargo[k]))
		if n > 0:
			got["cargo"][k] = n
	s.gold = 0
	s.cargo = {}
	Game.stats["captured"] += 1
	if Game.is_navy() and Game.are_enemies(s.flag_nation, Game.career):
		Game.add_merit(int(s.def["guns"]) * 6)
	elif not Game.is_navy():
		Game.add_merit(int(s.def["guns"]) * 5)
		Game.bounty += 300
	if not (Game.is_navy() and Game.are_enemies(s.flag_nation, Game.career)):
		Game.change_rep(s.flag_nation, -10)
	if s.mission_target:
		_complete_hunt()
	return got


func take_over_ship(s: Ship) -> void:
	var t := s.type_idx
	var hp_frac := clampf(s.hp / s.max_hp, 0.25, 1.0)
	var old_crew := player.crew
	var p := s.pos2()
	var y := s.yaw
	remove_ship(s)
	Game.ship_type = t
	Game.hull_hp = Game.max_hull() * hp_frac
	Game.sail_hp = maxf(40.0, s.sail_hp)
	Game.crew = mini(old_crew, Game.max_crew())
	Game.upgrades = {"casco": 0, "velas": 0, "canhoes": 0, "artilheiros": 0}
	spawn_player()
	player.global_position = Vector3(p.x, 0, p.y)
	player.yaw = y
	Game.notify("O %s agora é seu!" % Game.SHIPS[t]["name"], Color(0.5, 1, 0.5))


# ================================================================ fortes
func fort_hit(p: Vector3) -> int:
	for i in port_islands.size():
		var f := port_islands[i].fort_pos
		if absf(p.x - f.x) < 22.0 and absf(p.z - f.z) < 22.0 and p.y < f.y + 11.0:
			return i
	return -1


func damage_fort(i: int, dmg: float, from_player: bool, p: Vector3) -> void:
	fx.emit("dust", p)
	Sfx.play_at("hit", p, 0.0, 0.6)
	if Game.port_fort_hp[i] <= 0.0:
		return
	Game.port_fort_hp[i] = maxf(0.0, Game.port_fort_hp[i] - dmg * 0.7)
	if from_player and not port_aggro[i]:
		port_aggro[i] = true
		var owner: int = Game.port_owner[i]
		if not Game.nation_hostile_to_player(owner):
			Game.change_rep(owner, -20)
		Game.notify("O forte de %s abre fogo contra você!" % port_islands[i].name, Color(1, 0.4, 0.3))
	if Game.port_fort_hp[i] <= 0.0:
		Game.notify("O forte de %s foi silenciado! Atraque para invadir a cidade." % port_islands[i].name, Color(1, 0.85, 0.3))
		var isl := port_islands[i]
		if isl.fort_ruin:
			fx.make_fire(isl.fort_ruin, Vector3.ZERO, true)


func _forts(delta: float) -> void:
	for i in port_islands.size():
		var isl := port_islands[i]
		var fp := isl.fort_pos
		if Game.port_fort_hp[i] <= 0.0:
			continue
		if player and fp.distance_to(player.global_position) > 1800.0:
			Game.port_fort_hp[i] = minf(Game.fort_max_hp(), Game.port_fort_hp[i] + delta * 4.0)
			port_aggro[i] = false
			continue
		_fort_reload[i] -= delta
		if _fort_reload[i] > 0.0:
			continue
		var owner: int = Game.port_owner[i]
		var target: Ship = null
		var bd := 560.0
		for s in ships:
			if s.dead:
				continue
			var hostile_s := false
			if s.is_player:
				hostile_s = port_aggro[i] or Game.nation_hostile_to_player(owner)
			else:
				hostile_s = Game.are_enemies(owner, s.flag_nation)
			if not hostile_s:
				continue
			var d := Vector2(s.global_position.x - fp.x, s.global_position.z - fp.z).length()
			if d < bd:
				bd = d
				target = s
		if target == null:
			_fort_reload[i] = 1.0
			continue
		_fort_reload[i] = 4.5
		var muzzle := fp + Vector3(0, 9.0, 0)
		var tp := target.global_position
		var flight := bd / Ship.MUZZLE
		tp += target.velocity * flight
		var to := Vector2(tp.x - muzzle.x, tp.z - muzzle.z)
		var elev := Projectiles.solve_elevation(to.length(), tp.y - muzzle.y, Ship.MUZZLE)
		for k in 4:
			var dir := to.normalized().rotated(_rng.randf_range(-0.04, 0.04))
			var e := elev + _rng.randf_range(-0.02, 0.02)
			var v := Vector3(dir.x * cos(e), sin(e), dir.y * cos(e)) * Ship.MUZZLE
			var off := Vector3(_rng.randf_range(-10, 10), 0, _rng.randf_range(-10, 10))
			proj.fire(muzzle + off, v, null, owner, 30.0, 0, false)
			fx.emit("smoke", muzzle + off, Vector3(dir.x, 0.2, dir.y))
		Sfx.play_at("cannon", muzzle, 4.0, 0.8)


## Conquista de um porto cujo forte foi silenciado.
func capture_port(i: int) -> Dictionary:
	var garrison := 120 + Game.rank_index() * 30
	var res := resolve_boarding(garrison, 1.15)
	if not res["win"]:
		return res
	var old: int = Game.port_owner[i]
	var new_owner := Game.career
	Game.port_owner[i] = new_owner
	Game.port_fort_hp[i] = Game.fort_max_hp() * 0.3
	port_aggro[i] = false
	port_islands[i].set_owner_flag(new_owner)
	Game.change_rep(old, -35)
	Game.stats["ports"] += 1
	var loot_gold := 4000 + _rng.randi_range(0, 6000)
	Game.gold += loot_gold
	res["gold"] = loot_gold
	if Game.is_navy():
		Game.add_merit(600)
		Game.change_rep(Game.career, 25)
	else:
		Game.add_merit(500)
		Game.bounty += 5000
	if Game.mission.get("type", "") == "capture" and int(Game.mission.get("port", -1)) == i:
		var r: int = Game.mission["reward"]
		Game.gold += r
		Game.add_merit(200)
		Game.notify("Missão cumprida! Recompensa: %d moedas." % r, Color(0.5, 1, 0.5))
		Game.mission = {}
	return res


# ================================================================ saque flutuante
func _spawn_loot(s: Ship) -> void:
	var n := 2 + _rng.randi() % 3
	var total_gold := s.gold
	for i in n:
		var b := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.6
		cm.bottom_radius = 0.6
		cm.height = 1.4
		cm.radial_segments = 8
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.45, 0.3, 0.16)
		m.emission_enabled = true
		m.emission = Color(0.6, 0.45, 0.1)
		m.emission_energy_multiplier = 0.35
		cm.material = m
		b.mesh = cm
		add_child(b)
		var p := s.pos2() + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(4.0, s.length * 0.6)
		b.global_position = Vector3(p.x, 0, p.y)
		var cargo := {}
		if not s.cargo.is_empty() and i == 0:
			cargo = s.cargo.duplicate()
		loot.append({"node": b, "gold": int(total_gold / n) + _rng.randi_range(20, 120), "cargo": cargo, "life": 180.0, "phase": _rng.randf() * TAU})
	s.gold = 0
	s.cargo = {}


func _update_loot(delta: float) -> void:
	var i := 0
	while i < loot.size():
		var l: Dictionary = loot[i]
		var b: MeshInstance3D = l["node"]
		l["life"] -= delta
		var p := b.global_position
		p.y = Ocean.height_at(p.x, p.z) + 0.2
		b.global_position = p
		b.rotation = Vector3(sin(Time.get_ticks_msec() * 0.001 + l["phase"]) * 0.3, l["phase"], PI * 0.5)
		var take := player and not player.dead and player.pos2().distance_to(Vector2(p.x, p.z)) < player.radius * 0.8 + 8.0
		if take or l["life"] <= 0.0:
			if take:
				Game.gold += l["gold"]
				var txt := "Saque recolhido: +%d moedas" % l["gold"]
				for k in l["cargo"]:
					var n := Game.add_cargo(k, int(l["cargo"][k]))
					if n > 0:
						txt += ", %d %s" % [n, Game.good_name(k)]
				Game.notify(txt, Color(1, 0.9, 0.4))
				Sfx.play("coin")
			b.queue_free()
			loot.remove_at(i)
			continue
		i += 1


# ================================================================ missões e tesouros
func _make_marker(c: Color) -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.2
	cm.bottom_radius = 1.2
	cm.height = 300.0
	cm.radial_segments = 8
	cm.cap_top = false
	cm.cap_bottom = false
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c.r, c.g, c.b, 0.35)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	cm.material = m
	mi.mesh = cm
	mi.position.y = 150.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	n.visible = false
	add_child(n)
	return n


func _update_markers() -> void:
	if Game.treasure.has("pos"):
		var tp: Vector2 = Game.treasure["pos"]
		_treasure_marker.global_position = Vector3(tp.x, terrain_height(tp.x, tp.y), tp.y)
		_treasure_marker.visible = listener_pos().distance_to(_treasure_marker.global_position) > 45.0
	else:
		_treasure_marker.visible = false
	var mp := mission_point()
	_mission_marker.visible = mp != Vector2.INF
	if _mission_marker.visible:
		_mission_marker.global_position = Vector3(mp.x, 0, mp.y)
		_mission_marker.visible = listener_pos().distance_to(_mission_marker.global_position) > 80.0


func mission_point() -> Vector2:
	var m := Game.mission
	if m.is_empty():
		return Vector2.INF
	match m.get("type", ""):
		"hunt":
			for s in ships:
				if s.mission_target and not s.dead:
					return s.pos2()
			return m["pos"]
		"deliver", "capture":
			var pi := int(m.get("port", -1))
			if pi >= 0:
				return port_islands[pi].dock_point
	return Vector2.INF


func _check_mission_spawn() -> void:
	var m := Game.mission
	if m.get("type", "") != "hunt" or m.get("spawned", false):
		return
	var mp: Vector2 = m["pos"]
	if player.pos2().distance_to(mp) < 1700.0:
		var p := mp
		if terrain_height(p.x, p.y) > -10.0:
			p = _find_water_near(p)
		var role := Ship.Role.PIRATE if int(m["nation"]) == Game.PIR else Ship.Role.PATROL
		if m.get("role", "") == "merchant":
			role = Ship.Role.MERCHANT
		var s := spawn_ship(int(m["ship"]), int(m["nation"]), role, p, _rng.randf() * TAU)
		s.mission_target = true
		s.ship_name = m.get("target_name", s.ship_name)
		s.gold += 800
		m["spawned"] = true
		Game.notify("Avistado: %s! Afunde ou aborde o alvo." % s.display_name(), Color(1, 0.5, 0.3))


func _complete_hunt() -> void:
	if Game.mission.get("type", "") != "hunt":
		return
	var r: int = Game.mission["reward"]
	Game.gold += r
	Game.add_merit(int(Game.mission.get("merit", 80)))
	var giver: int = int(Game.mission.get("giver", Game.career))
	if giver >= 0 and giver < 6:
		Game.change_rep(giver, 8)
	Game.notify("Missão cumprida! Recompensa: %d moedas." % r, Color(0.5, 1, 0.5))
	Game.mission = {}
	Sfx.play("coin")


func make_treasure_map() -> Dictionary:
	var cands: Array[Island] = []
	for isl in islands:
		if isl.port_idx < 0 and isl.max_h > 4.0:
			cands.append(isl)
	var isl: Island = cands[_rng.randi() % cands.size()]
	for k in 200:
		var p := isl.pos + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, isl.r * 0.8)
		var h := isl.height(p.x, p.y)
		if h > 1.6 and h < 12.0:
			return {"pos": p, "island": isl.name}
	return {"pos": isl.pos, "island": isl.name}


## Ponto de desembarque: praia mais próxima do navio (ou INF).
func landing_point() -> Vector2:
	if player == null:
		return Vector2.INF
	var p := player.pos2()
	var isl := nearest_island(p)
	if isl == null:
		return Vector2.INF
	var dir := (isl.pos - p).normalized()
	for d in range(0, 200, 4):
		var q := p + dir * d
		if isl.height(q.x, q.y) > 0.6:
			return q
	return Vector2.INF
