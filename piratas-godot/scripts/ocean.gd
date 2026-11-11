class_name Ocean
extends Node3D
## Oceano infinito: anéis de grade (clipmap) presos a posições fixas do mundo, para a água
## não "deslizar" quando a câmera anda, + ondas Gerstner no shader.
## As funções estáticas reproduzem as ondas na CPU para a flutuação dos navios.

const CHOP := 1.15
const SPEED := 0.8   # ondulação um pouco mais lenta = mar mais calmo
# [ângulo relativo ao vento, comprimento de onda, amplitude, onda pequena?]
const WAVES := [
	[0.0, 64.0, 0.80, false],
	[0.6, 33.0, 0.44, false],
	[-0.7, 19.0, 0.25, false],
	[1.3, 10.5, 0.12, true],
	[-1.6, 6.0, 0.06, true],
]
# mesmas distâncias de esmaecimento do vértice no shader
const BIG_FADE := Vector2(190.0, 250.0)
const SMALL_FADE := Vector2(60.0, 90.0)
# níveis do clipmap: [espaçamento, células por lado]
const LEVELS := [[1.5, 128], [6.0, 96], [24.0, 64], [96.0, 64], [384.0, 64]]

static var wave_time := 0.0
static var sea_state := 1.0
static var wind_angle := 0.3
static var cam_pos := Vector2.ZERO
static var _dirs: Array[Vector2] = []
static var _ks: Array[float] = []
static var _ws: Array[float] = []

var mat: ShaderMaterial
var _rings: Array[MeshInstance3D] = []


static func update_dirs() -> void:
	_dirs.clear()
	_ks.clear()
	_ws.clear()
	var wd := Vector2(cos(wind_angle), sin(wind_angle))
	for w in WAVES:
		_dirs.append(wd.rotated(w[0]))
		var k: float = TAU / w[1]
		_ks.append(k)
		_ws.append(sqrt(9.8 * k) * SPEED)


static func displacement(p: Vector2) -> Vector3:
	if _dirs.is_empty():
		update_dirs()
	var dist := p.distance_to(cam_pos)
	var big := 1.0 - smoothstep(BIG_FADE.x, BIG_FADE.y, dist)
	var small := 1.0 - smoothstep(SMALL_FADE.x, SMALL_FADE.y, dist)
	var d := Vector3.ZERO
	if big <= 0.0:
		return d
	for i in WAVES.size():
		var a: float = WAVES[i][2] * sea_state * (small if WAVES[i][3] else big)
		if a <= 0.0:
			continue
		var f: float = _ks[i] * _dirs[i].dot(p) - _ws[i] * wave_time
		var c := cos(f)
		d.x += CHOP * a * _dirs[i].x * c
		d.z += CHOP * a * _dirs[i].y * c
		d.y += a * sin(f)
	return d


## Altura da superfície em (x, z) — uma iteração para compensar o deslocamento horizontal.
static func height_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := displacement(p)
	d = displacement(p - Vector2(d.x, d.z))
	return d.y


func _init() -> void:
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/ocean.gdshader")
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 6.0
	var fn := FastNoiseLite.new()
	fn.frequency = 0.04
	fn.fractal_octaves = 3
	nt.noise = fn
	mat.set_shader_parameter("detail_normal", nt)
	var ft := NoiseTexture2D.new()
	ft.width = 256
	ft.height = 256
	ft.seamless = true
	var fn2 := FastNoiseLite.new()
	fn2.frequency = 0.03
	fn2.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ft.noise = fn2
	mat.set_shader_parameter("foam_noise", ft)
	var prev_ext := 0.0
	var prev_s := 0.0
	for li in LEVELS.size():
		var sp: float = LEVELS[li][0]
		var n: int = LEVELS[li][1]
		var hole := 0.0
		if li > 0:
			hole = floorf((prev_ext - prev_s - sp) / sp) * sp
		var mi := MeshInstance3D.new()
		mi.mesh = _ring_mesh(sp, n, hole, -0.07 * li)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 64.0
		mi.top_level = true
		add_child(mi)
		_rings.append(mi)
		prev_ext = n * 0.5 * sp
		prev_s = sp


func set_shallow_map(tex: Texture2D, half: float) -> void:
	mat.set_shader_parameter("shallow_map", tex)
	mat.set_shader_parameter("world_half", half)


func _process(delta: float) -> void:
	wave_time += delta
	mat.set_shader_parameter("wave_time", wave_time)
	mat.set_shader_parameter("sea_state", sea_state)
	mat.set_shader_parameter("wind_dir", Vector2(cos(wind_angle), sin(wind_angle)))
	var cam := get_viewport().get_camera_3d()
	if cam:
		var p := cam.global_position
		cam_pos = Vector2(p.x, p.z)
		mat.set_shader_parameter("cam_xz", cam_pos)
		for li in _rings.size():
			var sp: float = LEVELS[li][0] * 2.0
			_rings[li].global_position = Vector3(snappedf(p.x, sp), 0.0, snappedf(p.z, sp))


## Anel de grade quadrada com espaçamento `sp`, `n` células por lado e um buraco central.
func _ring_mesh(sp: float, n: int, hole: float, y: float) -> ArrayMesh:
	var half := n * 0.5 * sp
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var row := n + 1
	verts.resize(row * row)
	for j in row:
		for i in row:
			verts[j * row + i] = Vector3(-half + i * sp, y, -half + j * sp)
	for j in n:
		for i in n:
			var x0 := -half + i * sp
			var z0 := -half + j * sp
			if hole > 0.0 and x0 >= -hole and x0 + sp <= hole and z0 >= -hole and z0 + sp <= hole:
				continue
			var a := j * row + i
			var b := a + 1
			var c := a + row
			var d := c + 1
			idx.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.custom_aabb = AABB(Vector3(-half, -8, -half), Vector3(half * 2, 16, half * 2))
	return m
