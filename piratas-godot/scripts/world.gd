class_name World
extends Node3D
## O mundo aberto: arquipélago, oceano, céu, clima, tráfego de navios, fortes e regras do jogo.

signal player_ship_changed
signal player_died

static var I: World

const GRID := 800.0
const TILE_BUILD_DIST := 4600.0
const TOWN_BUILD_DIST := 3200.0

var ships: Array[Ship] = []
var player: Ship
var islands: Array[Island] = []
var port_islands: Array[PortSite] = []
var tiles: Array[TerrainTile] = []
var roads: Array[PackedVector2Array] = []
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
var map_texture: Texture2D

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
var loot: Array = []
var _rng := RandomNumberGenerator.new()
var _treasure_marker: Node3D
var _mission_marker: Node3D
var _cloud_off := Vector2.ZERO
var paused_world := false
var war := {}              # guerra em curso: {"att", "port", "t", "spawned", "att_ships", "def_ships"}
var _war_timer := 150.0
var _war_marker: Node3D


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
	_generate_world()
	Island.warm_caches()
	Assets.warm()
	TerrainTile.forest_noise()
	for i in port_islands.size():
		_fort_reload.append(_rng.randf_range(0.0, 4.0))
		port_aggro.append(false)
	_make_shallow_map()
	_update_environment(true)
	_treasure_marker = _make_marker(Color(1.0, 0.85, 0.2))
	_mission_marker = _make_marker(Color(1.0, 0.25, 0.2))


# ================================================================ geração
## Dados geográficos reais (Natural Earth, domínio público), convertidos por tools/gerar_mapa.py:
## distância com sinal até a costa (m) e o índice de cada massa de terra.
var _sdf := PackedByteArray()
var _lab := PackedByteArray()
var _gn := 0
var _gpx := 1.0
var _noise_coast: FastNoiseLite
var _noise_h: FastNoiseLite
var _noise_m: FastNoiseLite


func _load_geo() -> void:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/caribe_info.json"))
	_gn = int(info["n"])
	_gpx = 2.0 * float(info["half"]) / _gn
	var raw := FileAccess.get_file_as_bytes("res://data/caribe_sdf.bin")
	_sdf = raw.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	raw = FileAccess.get_file_as_bytes("res://data/caribe_label.bin")
	_lab = raw.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	for L in info["lands"]:
		var isl := Island.single(Vector2(L["x"], L["z"]), maxf(float(L["r"]), 40.0), 30.0, 3000 + int(L["id"]), L["name"])
		isl.bmin = Vector2(L["x0"], L["z0"])
		isl.bmax = Vector2(L["x1"], L["z1"])
		isl.mainland = float(L["r"]) > 2500.0
		islands.append(isl)
	_noise_coast = FastNoiseLite.new()
	_noise_coast.seed = 11
	_noise_coast.frequency = 0.02
	_noise_coast.fractal_octaves = 3
	_noise_h = FastNoiseLite.new()
	_noise_h.seed = 23
	_noise_h.frequency = 0.0035
	_noise_h.fractal_octaves = 4
	_noise_m = FastNoiseLite.new()
	_noise_m.seed = 37
	_noise_m.frequency = 0.0006


## Distância até a costa (metros; positiva em terra), interpolada.
func sdf(x: float, z: float) -> float:
	var half := Game.WORLD_HALF
	var fx := (x + half) / _gpx - 0.5
	var fz := (z + half) / _gpx - 0.5
	var ix := clampi(int(floor(fx)), 0, _gn - 2)
	var iz := clampi(int(floor(fz)), 0, _gn - 2)
	var tx := clampf(fx - ix, 0.0, 1.0)
	var tz := clampf(fz - iz, 0.0, 1.0)
	var o := (iz * _gn + ix) * 2
	var row := _gn * 2
	var a := float(_sdf.decode_s16(o))
	var b := float(_sdf.decode_s16(o + 2))
	var c := float(_sdf.decode_s16(o + row))
	var d := float(_sdf.decode_s16(o + row + 2))
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


func sdf_grad(x: float, z: float) -> Vector2:
	return Vector2(sdf(x + 10.0, z) - sdf(x - 10.0, z), sdf(x, z + 10.0) - sdf(x, z - 10.0))


func land_id(x: float, z: float) -> int:
	var half := Game.WORLD_HALF
	var ix := clampi(int((x + half) / _gpx), 0, _gn - 1)
	var iz := clampi(int((z + half) / _gpx), 0, _gn - 1)
	return _lab.decode_u16((iz * _gn + ix) * 2)


func _generate_world() -> void:
	_load_geo()
	# portos
	for i in Game.PORTS_DEF.size():
		port_islands.append(PortSite.new(i, Game.PORTS_DEF[i]))
	for ps in port_islands:
		ps.plan(self)
		ps.land = _land_index(Vector2(ps.town_center.x, ps.town_center.z))
	for ps in port_islands:
		ps.settle(self)
	_make_roads()
	# blocos de terreno onde há terra perto
	var half := Game.WORLD_HALF
	var n := int(ceil(half * 2.0 / TerrainTile.SIZE))
	var t0 := int(floor(-half / TerrainTile.SIZE))
	for tz in range(t0, t0 + n):
		for tx in range(t0, t0 + n):
			var o := Vector2(tx, tz) * TerrainTile.SIZE
			var best := -INF
			for j in 9:
				for i in 9:
					best = maxf(best, sdf(o.x + i * 100.0, o.y + j * 100.0))
			if best > -200.0:
				tiles.append(TerrainTile.new(tx, tz))


func _land_index(p: Vector2) -> int:
	var id := land_id(p.x, p.y)
	return id - 1 if id > 0 else -1


## Estradas entre cidades da mesma terra (até ~5 km), por dentro da terra.
func _make_roads() -> void:
	roads.clear()
	for i in port_islands.size():
		for j in range(i + 1, port_islands.size()):
			var a := port_islands[i]
			var b := port_islands[j]
			if a.land < 0 or a.land != b.land:
				continue
			var pa := Vector2(a.town_center.x, a.town_center.z)
			var pb := Vector2(b.town_center.x, b.town_center.z)
			if pa.distance_to(pb) > 5500.0:
				continue
			var path := _road_path(pa, pb)
			if path.size() >= 2:
				roads.append(path)


func _road_path(pa: Vector2, pb: Vector2) -> PackedVector2Array:
	var n := maxi(4, int(pa.distance_to(pb) / 60.0))
	var pts := PackedVector2Array()
	for k in n + 1:
		var p := pa.lerp(pb, float(k) / n)
		var guard := 0
		while sdf(p.x, p.y) < 70.0 and guard < 80:
			var g := sdf_grad(p.x, p.y)
			if g.length() < 0.001:
				break
			p += g.normalized() * 10.0
			guard += 1
		pts.append(p)
	for it in 3:
		for k in range(1, pts.size() - 1):
			pts[k] = pts[k].lerp((pts[k - 1] + pts[k + 1]) * 0.5, 0.5)
	return pts


func _make_shallow_map() -> void:
	var raso: Texture2D = load("res://data/caribe_raso.png")
	ocean.set_shallow_map(raso, Game.WORLD_HALF)
	map_texture = load("res://data/caribe_mapa.png")


func islands_near(_x: float, _z: float) -> Array:
	return []


## Relevo natural (sem o aplainamento das cidades), a partir da distância até a costa real.
func raw_height(x: float, z: float) -> float:
	var s := sdf(x, z)
	if s < -190.0:
		return -18.0
	s += _noise_coast.get_noise_2d(x, z) * 12.0
	if s < 0.0:
		return maxf(1.0 + s * 0.11, -18.0)
	var n1 := _noise_h.get_noise_2d(x, z)
	var maxh := 35.0 + 150.0 * clampf(_noise_m.get_noise_2d(x, z) * 0.6 + 0.5, 0.0, 1.0)
	var h := 1.0 + 1.7 * smoothstep(0.0, 28.0, s)
	var inner := clampf((s - 25.0) / 420.0, 0.0, 1.0)
	var far := clampf((s - 400.0) / 2500.0, 0.0, 1.0)
	h += maxh * (pow(inner, 1.2) * 0.55 + far * 0.6) * (0.55 + 0.6 * n1)
	# cordilheiras no interior das ilhas grandes e dos continentes
	var ridge := 1.0 - absf(_noise_m.get_noise_2d(x * 3.0 + 500.0, z * 3.0))
	h += 110.0 * pow(ridge, 3.0) * clampf((s - 300.0) / 1500.0, 0.0, 1.0)
	h += _noise_h.get_noise_2d(x * 4.0, z * 4.0) * 3.0 * smoothstep(30.0, 150.0, s)
	return h


func terrain_height(x: float, z: float) -> float:
	var h := raw_height(x, z)
	if h < 0.0:
		return h
	for ps in port_islands:
		var dx := x - ps.town_center.x
		var dz := z - ps.town_center.z
		var d2 := dx * dx + dz * dz
		if d2 < 200.0 * 200.0:
			var flat := 1.0 - smoothstep(120.0, 200.0, sqrt(d2))
			h = lerpf(h, clampf(h, 3.6, 7.5), flat)
	return h


## Altura onde se pisa: terreno ou o cais das cidades.
func walk_height(x: float, z: float) -> float:
	var h := terrain_height(x, z)
	for ps in port_islands:
		if absf(x - ps.coast_point.x) < 100.0 and absf(z - ps.coast_point.y) < 100.0:
			h = maxf(h, ps.pier_height(x, z))
		# praça calçada (lajes um pouco acima do chão)
		var px := x - ps.town_center.x
		var pz := z - ps.town_center.z
		if px * px + pz * pz < 21.0 * 21.0:
			h += 0.4
	return h


## Prédios das cidades bloqueiam quem anda a pé ou a cavalo.
func building_blocked(x: float, z: float) -> bool:
	for ps in port_islands:
		var dx := x - ps.town_center.x
		var dz := z - ps.town_center.z
		if dx * dx + dz * dz < 260.0 * 260.0 and ps.blocked(x, z):
			return true
	return false


## Distância até o centro da cidade mais próxima.
func town_distance(x: float, z: float) -> float:
	var best := INF
	for ps in port_islands:
		var d := Vector2(x - ps.town_center.x, z - ps.town_center.z).length()
		best = minf(best, d)
	return best


## Vegetação não nasce nas cidades nem nas estradas.
func veg_blocked(x: float, z: float) -> bool:
	for ps in port_islands:
		var dx := x - ps.town_center.x
		var dz := z - ps.town_center.z
		if dx * dx + dz * dz < 190.0 * 190.0:
			return true
		var fx2 := x - ps.fort_pos.x
		var fz2 := z - ps.fort_pos.z
		if fx2 * fx2 + fz2 * fz2 < 40.0 * 40.0:
			return true
	return on_road(x, z)


func on_road(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	for r in roads:
		for k in r.size() - 1:
			var a := r[k]
			var b := r[k + 1]
			if absf(p.x - a.x) > 80.0 and absf(p.x - b.x) > 80.0:
				continue
			var ab := b - a
			var u := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			if p.distance_squared_to(a + ab * u) < 36.0:
				return true
	return false


func island_at(x: float, z: float) -> Island:
	var i := _land_index(Vector2(x, z))
	return islands[i] if i >= 0 else null


# ---------------------------------------------------------------- construção em segundo plano
var _build_task := -1
var _build_obj: RefCounted


func _job_done(obj: RefCounted) -> void:
	var nd: Node3D = obj.node
	if nd and not nd.is_inside_tree():
		add_child(nd)
		if obj is TerrainTile:
			nd.position = Vector3(obj.origin().x, 0.0, obj.origin().y)


## Constrói o que estiver perto (síncrono, usado na tela de carregamento).
func build_islands_near(p: Vector2, dist: float) -> void:
	if _build_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_build_task)
		_build_task = -1
		_job_done(_build_obj)
		_build_obj = null
	for t in tiles:
		if t.node == null and t.center().distance_to(p) < dist:
			t.build()
			t.building = true
			_job_done(t)
	for ps in port_islands:
		if ps.node == null and ps.dock_point.distance_to(p) < dist:
			ps.build()
			ps.building = true
			_job_done(ps)
	_build_roads_near(p, dist)


var _roads_built: Array[bool] = []


func _build_roads_near(p: Vector2, dist: float) -> void:
	if _roads_built.size() != roads.size():
		_roads_built.resize(roads.size())
		_roads_built.fill(false)
	for i in roads.size():
		if _roads_built[i]:
			continue
		var r := roads[i]
		if r[0].distance_to(p) < dist + 2000.0 or r[r.size() - 1].distance_to(p) < dist + 2000.0:
			_roads_built[i] = true
			var m := PortSite.road_mesh(self, r, 6.5)
			if m:
				var mi := MeshInstance3D.new()
				mi.mesh = m
				mi.material_override = Island._road_mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.visibility_range_end = 1500.0
				add_child(mi)


var _stream_t := 0.0


func _stream_islands() -> void:
	if _build_task >= 0:
		if not WorkerThreadPool.is_task_completed(_build_task):
			return
		WorkerThreadPool.wait_for_task_completion(_build_task)
		_build_task = -1
		_job_done(_build_obj)
		_build_obj = null
		return
	_stream_t -= get_process_delta_time()
	if _stream_t > 0.0:
		return
	_stream_t = 0.25
	var lp := listener_pos()
	var p2 := Vector2(lp.x, lp.z)
	var best: RefCounted = null
	var bd := INF
	for ps in port_islands:
		if not ps.building:
			var d := ps.dock_point.distance_to(p2)
			if d < TOWN_BUILD_DIST and d < bd:
				bd = d
				best = ps
	for t in tiles:
		if not t.building:
			var d := t.center().distance_to(p2)
			if d < TILE_BUILD_DIST and d < bd:
				bd = d
				best = t
	_build_roads_near(p2, 1500.0)
	if best:
		best.building = true
		_build_obj = best
		_build_task = WorkerThreadPool.add_task(best.build, false, "terreno")


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
	env.adjustment_saturation = 1.0
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


## Envia ao shader do oceano os 8 navios mais próximos da câmera (esteiras).
func _update_wakes() -> void:
	var lp := listener_pos()
	var cands: Array = []
	for s in ships:
		if s.dead:
			continue
		var d2 := s.global_position.distance_squared_to(lp)
		if d2 < 1500.0 * 1500.0:
			cands.append([d2, s])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var aa: Array = []
	var bb: Array = []
	for i in 8:
		if i < cands.size():
			var s: Ship = cands[i][1]
			aa.append(Vector4(s.global_position.x, s.global_position.z, s.yaw, s.speed))
			bb.append(Vector4(s.length, s.beam, 0.0, 0.0))
		else:
			aa.append(Vector4.ZERO)
			bb.append(Vector4.ZERO)
	ocean.mat.set_shader_parameter("ship_a", aa)
	ocean.mat.set_shader_parameter("ship_b", bb)
	ocean.mat.set_shader_parameter("ship_count", mini(cands.size(), 8))


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
	_update_wakes()
	if _mortar_marker and _mortar_marker.visible:
		_marker_t -= delta
		_mortar_marker.rotate_y(delta * 1.5)
		_mortar_marker.visible = _marker_t > 0.0
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
	_wars(delta)
	if not player.dead:
		Game.player_pos = player.pos2()
		Game.player_yaw = player.yaw
		Game.hull_hp = player.hp
		Game.sail_hp = player.sail_hp
		Game.crew = player.crew
		_check_mission_spawn()


# ================================================================ guerras entre nações
func _wars(delta: float) -> void:
	if war.is_empty():
		_war_timer -= delta
		if _war_timer <= 0.0:
			_war_timer = _rng.randf_range(260.0, 480.0)
			_start_war()
		return
	war["t"] -= delta
	var ps := port_islands[war["port"]]
	if _war_marker == null:
		_war_marker = _make_marker(Color(1.0, 0.5, 0.1))
	_war_marker.visible = true
	_war_marker.global_position = Vector3(ps.dock_point.x, 0, ps.dock_point.y)
	if not war["spawned"] and player.pos2().distance_to(ps.dock_point) < 2600.0:
		_spawn_war_fleets()
	if war["t"] <= 0.0:
		_end_war()


func _start_war() -> void:
	var cands: Array = []
	for i in port_islands.size():
		var o: int = Game.port_owner[i]
		for a in 5:
			if a != o and Game.are_enemies(a, o) and not (o == Game.PIR and a == Game.PIR):
				# atacantes preferem portos perto dos seus
				var w := 1.0
				for j in port_islands.size():
					if Game.port_owner[j] == a and port_islands[j].dock_point.distance_to(port_islands[i].dock_point) < 6000.0:
						w += 1.0
				cands.append([w, a, i])
	if cands.is_empty():
		return
	var total := 0.0
	for c in cands:
		total += c[0]
	var r := _rng.randf() * total
	var pick: Array = cands[0]
	for c in cands:
		r -= c[0]
		if r <= 0.0:
			pick = c
			break
	war = {"att": pick[1], "port": pick[2], "t": 200.0, "spawned": false, "att_ships": [], "def_ships": []}
	var o2: int = Game.port_owner[pick[2]]
	var txt := "GUERRA! Uma frota %s ataca %s (%s)." % [Game.NATIONS[pick[1]]["adj"], Game.PORTS_DEF[pick[2]]["name"], Game.NATIONS[o2]["name"]]
	if o2 == Game.career:
		txt += " Defenda a cidade!"
	elif pick[1] == Game.career:
		txt += " Junte-se ao ataque!"
	Game.notify(txt, Color(1, 0.55, 0.3))
	Sfx.play("bell", -4.0, 0.8)


func _spawn_war_fleets() -> void:
	war["spawned"] = true
	var ps := port_islands[war["port"]]
	var a: int = war["att"]
	var o: int = Game.port_owner[war["port"]]
	var base := ps.dock_point + ps.dir * 450.0
	for k in 3:
		var p := _find_water_near(base + Vector2(-ps.dir.y, ps.dir.x) * (k - 1) * 120.0)
		var s := spawn_ship([3, 2, 4][k] if a != Game.PIR else [1, 2, 2][k], a, Ship.Role.PIRATE if a == Game.PIR else Ship.Role.PATROL, p, atan2(ps.dir.x, ps.dir.y))
		s.mission_target = true   # não some por distância durante a batalha
		s.ai_dest = ps.dock_point
		war["att_ships"].append(s)
	for k in 2:
		var p := _find_water_near(ps.dock_point + Vector2(-ps.dir.y, ps.dir.x) * (k * 2 - 1) * 90.0)
		var s := spawn_ship(2 + k, o, Ship.Role.PIRATE if o == Game.PIR else Ship.Role.PATROL, p, atan2(-ps.dir.x, -ps.dir.y))
		s.mission_target = true
		war["def_ships"].append(s)


func _end_war() -> void:
	var i: int = war["port"]
	var a: int = war["att"]
	var o: int = Game.port_owner[i]
	var att_win := false
	var player_near := player.pos2().distance_to(port_islands[i].dock_point) < 3000.0
	if war["spawned"]:
		var att := 0
		var dfn := 0
		for s in war["att_ships"]:
			if is_instance_valid(s) and not s.dead:
				att += 1
		for s in war["def_ships"]:
			if is_instance_valid(s) and not s.dead:
				dfn += 1
		var fort := 2 if Game.port_fort_hp[i] > Game.fort_max_hp() * 0.4 else 0
		att_win = att * 2 > dfn * 2 + fort
		for s in war["att_ships"] + war["def_ships"]:
			if is_instance_valid(s):
				s.mission_target = false
	else:
		att_win = _rng.randf() < (0.3 if o == Game.KIN else 0.4)
	if att_win and Game.port_owner[i] == o:
		Game.port_owner[i] = a
		Game.port_fort_hp[i] = Game.fort_max_hp() * 0.4
		port_islands[i].set_owner_flag(a)
		var txt := "%s caiu! Agora pertence a %s." % [Game.PORTS_DEF[i]["name"], Game.NATIONS[a]["name"]]
		if o == Game.KIN:
			txt = "Seu reino perdeu %s para a %s!" % [Game.PORTS_DEF[i]["name"], Game.NATIONS[a]["name"]]
		Game.notify(txt, Color(1, 0.5, 0.3))
		if a == Game.career and player_near and war["spawned"]:
			Game.gold += 2500
			Game.add_merit(180)
			Game.notify("Você ajudou na conquista! +2500 moedas.", Color(0.6, 1, 0.6))
	else:
		Game.notify("%s resistiu ao ataque %s." % [Game.PORTS_DEF[i]["name"], Game.NATIONS[a]["adj"]], Color(0.8, 0.9, 1))
		if o == Game.career and player_near and war["spawned"]:
			Game.gold += 2000
			Game.add_merit(150)
			Game.change_rep(o, 8)
			Game.notify("Você defendeu a cidade! +2000 moedas.", Color(0.6, 1, 0.6))
	war = {}
	if _war_marker:
		_war_marker.visible = false


func _separate_ships() -> void:
	for i in ships.size():
		var a := ships[i]
		if a.dead:
			continue
		for j in range(i + 1, ships.size()):
			var b := ships[j]
			if b.dead or a.lashed == b or b.lashed == a:
				continue
			var d := b.pos2() - a.pos2()
			var min_d := (a.radius + b.radius) * 0.55
			var dist := d.length()
			if dist < min_d and dist > 0.01:
				var push := d / dist * (min_d - dist) * 0.5
				a.global_position -= Vector3(push.x, 0, push.y)
				b.global_position += Vector3(push.x, 0, push.y)
				var n := d / dist
				var va := Vector2(a.velocity.x, a.velocity.z).dot(n)
				var vb := Vector2(b.velocity.x, b.velocity.z).dot(-n)
				var closing := va + vb
				if closing > 3.0:
					_ram(a, b, va, vb, closing)
					a.speed *= 0.5
					b.speed *= 0.5


## Abalroamento: quem vem de proa causa mais dano; o esporão de ferro aumenta o dano e protege o casco.
func _ram(a: Ship, b: Ship, va: float, vb: float, closing: float) -> void:
	var rammer := a if va >= vb else b
	var victim := b if rammer == a else a
	var bonus := 1.0
	var self_k := 0.35
	if rammer.is_player:
		bonus += 0.4 * Game.upgrades["esporao"]
		self_k = maxf(0.08, 0.35 - 0.09 * Game.upgrades["esporao"])
	var dmg := closing * 10.0 * bonus * clampf(rammer.length / victim.length, 0.5, 2.0)
	victim.take_raw_damage(dmg, rammer.is_player)
	rammer.take_raw_damage(dmg * self_k, false)
	Sfx.play_at("hit", victim.global_position, 6.0, 0.5)
	fx.emit("hit", victim.global_position + Vector3(0, 2, 0))
	if rammer.is_player or victim.is_player:
		shake(0.8)
	if rammer.is_player:
		Game.notify("Abalroou o %s!" % victim.def["name"], Color(1, 0.7, 0.3))
		on_ship_attacked(victim, rammer, true)
	elif victim.is_player:
		player_hit()


var _mortar_marker: MeshInstance3D
var _marker_t := 0.0


func show_mortar_marker(p: Vector3, t: float) -> void:
	if _mortar_marker == null:
		_mortar_marker = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 10.0
		tm.outer_radius = 11.5
		tm.rings = 32
		tm.ring_segments = 4
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.25, 0.15, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = true
		tm.material = m
		_mortar_marker.mesh = tm
		_mortar_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_mortar_marker)
	_mortar_marker.global_position = Vector3(p.x, Ocean.height_at(p.x, p.z) + 0.5 if p.y < 3.0 else p.y, p.z)
	_mortar_marker.visible = true
	_marker_t = t


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
	if Game.spawn_port >= 0:
		var ps := port_islands[Game.spawn_port]
		p = dock_spawn(Game.spawn_port)
		player.yaw = atan2(ps.dir.y, -ps.dir.x)
		Game.spawn_port = -1
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
		if absf(q.x) < Game.WORLD_HALF - 600.0 and absf(q.y) < Game.WORLD_HALF - 600.0 and terrain_height(q.x, q.y) < -10.0:
			return q
	return Vector2.ZERO


func _player_vs(s: Ship) -> bool:
	return s.aggro_player or s.role == Ship.Role.HUNTER or Game.nation_hostile_to_player(s.flag_nation)


func hostile(a: Ship, b: Ship) -> bool:
	if a.dead or b.dead:
		return false
	# navio ancorado enquanto o capitão está em terra fica fora do combate (como no Black Flag)
	if (a.is_player or b.is_player) and ctl and ctl.on_land():
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
	Game.upgrades = {"casco": 0, "velas": 0, "canhoes": 0, "artilheiros": 0, "morteiro": 0, "proa": 0, "esporao": 0}
	Game.hull_hp = Game.max_hull()
	Game.sail_hp = 100.0
	Game.crew = 25
	var isl := port_islands[best]
	Game.spawn_port = best
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
	var mine := Game.fighting_power(player.crew) * (1.0 + Game.rank_index() * 0.08) * bonus * _rng.randf_range(0.8, 1.25)
	var theirs := float(enemy_crew) * _rng.randf_range(0.8, 1.2)
	var win := mine > theirs
	var total_lost := theirs * _rng.randf_range(0.25, 0.5) * (0.6 if win else 1.0)
	# as tropas absorvem parte das baixas
	var share := float(Game.soldiers) * 2.2 / maxf(float(player.crew) + Game.soldiers * 2.2, 1.0)
	var lost_soldiers := mini(Game.soldiers, int(total_lost * share / 2.2))
	var lost := int(minf(player.crew - 1, total_lost * (1.0 - share)))
	Game.soldiers -= lost_soldiers
	player.crew = maxi(1, player.crew - lost)
	Game.crew = player.crew
	Game.morale = clampf(Game.morale + (10.0 if win else -12.0), 0.0, 100.0)
	return {"win": win, "lost": lost, "lost_soldiers": lost_soldiers, "killed": int(minf(enemy_crew, mine * 0.6))}


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
	Game.upgrades = {"casco": 0, "velas": 0, "canhoes": 0, "artilheiros": 0, "morteiro": 0, "proa": 0, "esporao": 0}
	spawn_player()
	player.global_position = Vector3(p.x, 0, p.y)
	player.yaw = y
	Game.notify("O %s agora é seu!" % Game.SHIPS[t]["name"], Color(0.5, 1, 0.5))


# ================================================================ fortes
func fort_hit(p: Vector3) -> int:
	for i in port_islands.size():
		var f := port_islands[i].fort_pos
		if absf(p.x - f.x) < 25.0 and absf(p.z - f.z) < 25.0 and p.y < f.y + 9.5:
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
func capture_port(i: int, garrison_mult := 1.0) -> Dictionary:
	var garrison := int((120 + Game.rank_index() * 30) * garrison_mult)
	var res := resolve_boarding(garrison, 1.15)
	if not res["win"]:
		return res
	var old: int = Game.port_owner[i]
	var new_owner := Game.career
	Game.port_owner[i] = new_owner
	if not Game.conquered.has(i):
		Game.conquered.append(i)
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
		if not isl.mainland and isl.r < 900.0 and isl.r > 60.0:
			cands.append(isl)
	for tries in 40:
		var isl: Island = cands[_rng.randi() % cands.size()]
		for k in 120:
			var p := isl.pos + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, isl.r * 0.8)
			var h := terrain_height(p.x, p.y)
			if h > 1.6 and h < 14.0 and not veg_blocked(p.x, p.y):
				return {"pos": p, "island": isl.name}
	return {"pos": islands[0].pos, "island": islands[0].name}


## Ponto de desembarque: praia mais próxima do navio (ou INF).
func landing_point() -> Vector2:
	if player == null:
		return Vector2.INF
	var p := player.pos2()
	var best := Vector2.INF
	var bd := INF
	for k in 24:
		var dir := Vector2.from_angle(TAU * k / 24.0)
		for d in range(8, 200, 6):
			var q := p + dir * d
			if terrain_height(q.x, q.y) > 0.8:
				if d < bd:
					bd = d
					best = q
				break
	return best


## Lugar livre na água perto de um porto.
func dock_spawn(i: int) -> Vector2:
	var ps := port_islands[i]
	return _find_water_near(ps.dock_point + ps.dir * 60.0)
