class_name Ocean
extends MeshInstance3D
## Oceano infinito: malha radial que acompanha a câmera + ondas Gerstner no shader.
## As funções estáticas reproduzem as ondas na CPU para a flutuação dos navios.

const CHOP := 1.15
const WAVES := [
	[0.0, 64.0, 0.80],
	[0.6, 33.0, 0.44],
	[-0.7, 19.0, 0.25],
	[1.3, 10.5, 0.12],
	[-1.6, 6.0, 0.06],
]

static var wave_time := 0.0
static var sea_state := 1.0
static var wind_angle := 0.3
static var _dirs: Array[Vector2] = []
static var _ks: Array[float] = []
static var _ws: Array[float] = []

var mat: ShaderMaterial
var follow: Node3D


static func update_dirs() -> void:
	_dirs.clear()
	_ks.clear()
	_ws.clear()
	var wd := Vector2(cos(wind_angle), sin(wind_angle))
	for w in WAVES:
		_dirs.append(wd.rotated(w[0]))
		var k: float = TAU / w[1]
		_ks.append(k)
		_ws.append(sqrt(9.8 * k))


static func displacement(p: Vector2) -> Vector3:
	if _dirs.is_empty():
		update_dirs()
	var d := Vector3.ZERO
	for i in WAVES.size():
		var a: float = WAVES[i][2] * sea_state
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
	mesh = _build_mesh()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
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
	material_override = mat


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
		global_position = Vector3(snappedf(p.x, 4.0), 0.0, snappedf(p.z, 4.0))


func _build_mesh() -> ArrayMesh:
	var radii: Array[float] = [0.0]
	var r := 0.0
	var step := 1.2
	while r < 9000.0:
		r += step
		radii.append(r)
		if r > 40.0:
			step *= 1.045
	var seg := 160
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.append(Vector3.ZERO)
	for ri in range(1, radii.size()):
		for s in seg:
			var a := TAU * s / seg
			verts.append(Vector3(cos(a) * radii[ri], 0.0, sin(a) * radii[ri]))
	# centro
	for s in seg:
		idx.append(0)
		idx.append(1 + s)
		idx.append(1 + (s + 1) % seg)
	for ri in range(1, radii.size() - 1):
		var b0 := 1 + (ri - 1) * seg
		var b1 := 1 + ri * seg
		for s in seg:
			var s1 := (s + 1) % seg
			idx.append(b0 + s)
			idx.append(b1 + s)
			idx.append(b0 + s1)
			idx.append(b0 + s1)
			idx.append(b1 + s)
			idx.append(b1 + s1)
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
	m.custom_aabb = AABB(Vector3(-9000, -10, -9000), Vector3(18000, 20, 18000))
	return m
