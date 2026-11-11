class_name Island
extends RefCounted
## Uma massa de terra (ilha pequena, ilha grande como Cuba ou trecho de continente),
## definida por uma "espinha" de pontos com raios. O relevo é uma função contínua:
## qualquer ponto do mundo pode perguntar a altura do terreno.

var spine := PackedVector2Array()
var radii := PackedFloat32Array()
var pos := Vector2.ZERO      # centro aproximado (rótulos)
var r := 300.0               # maior raio
var max_h := 30.0
var seed_i := 0
var name := ""
var mainland := false
var bmin := Vector2.ZERO
var bmax := Vector2.ZERO
var noise: FastNoiseLite

const SHELF := 170.0         # largura da plataforma submersa além da costa

static var _veg_meshes := {}
static var _terrain_mat: ShaderMaterial
static var _veg_mat: StandardMaterial3D
static var _build_mat: StandardMaterial3D
static var _flag_shader: Shader
static var _road_mat: StandardMaterial3D
static var _stone_shader: Shader


func _init(points: PackedVector2Array, rads: PackedFloat32Array, height: float, s: int, nm := "") -> void:
	spine = points
	radii = rads
	max_h = height
	seed_i = s
	name = nm
	noise = FastNoiseLite.new()
	noise.seed = s
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.0035
	noise.fractal_octaves = 4
	var c := Vector2.ZERO
	r = 0.0
	bmin = Vector2(INF, INF)
	bmax = Vector2(-INF, -INF)
	for i in spine.size():
		c += spine[i]
		r = maxf(r, radii[i])
		var e := radii[i] * 1.25 + SHELF
		bmin = bmin.min(spine[i] - Vector2(e, e))
		bmax = bmax.max(spine[i] + Vector2(e, e))
	pos = c / spine.size()


static func single(p: Vector2, radius: float, height: float, s: int, nm := "") -> Island:
	return Island.new(PackedVector2Array([p]), PackedFloat32Array([radius]), height, s, nm)


func bound() -> float:
	return (bmax - bmin).length() * 0.5


func contains_box(x: float, z: float) -> bool:
	return x >= bmin.x and x <= bmax.x and z >= bmin.y and z <= bmax.y


## Distância (em metros) para dentro da costa: positiva em terra, negativa no mar.
func inland(x: float, z: float) -> Vector2:
	var p := Vector2(x, z)
	var best := INF
	var best_r := radii[0]
	if spine.size() == 1:
		best = p.distance_to(spine[0]) / radii[0]
	else:
		for i in spine.size() - 1:
			var a := spine[i]
			var b := spine[i + 1]
			var ab := b - a
			var u := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var rr := lerpf(radii[i], radii[i + 1], u)
			var t := p.distance_to(a + ab * u) / rr
			if t < best:
				best = t
				best_r = rr
	# costa recortada
	var edge := noise.get_noise_2d(x * 0.55 + 1000.0, z * 0.55)
	best /= 0.85 + 0.3 * edge
	return Vector2((1.0 - best) * best_r, best_r)


func height(x: float, z: float) -> float:
	if not contains_box(x, z):
		return -18.0
	var ir := inland(x, z)
	var s := ir.x
	var rr := ir.y
	if s < -SHELF:
		return -18.0
	if s < 0.0:
		return maxf(1.0 + s * 0.11, -18.0)
	var n1 := noise.get_noise_2d(x, z)
	var h := 1.0 + 1.7 * smoothstep(0.0, 28.0, s)
	var inner := clampf((s - 25.0) / maxf(rr * 0.8, 60.0), 0.0, 1.0)
	h += max_h * pow(inner, 1.15) * (0.55 + 0.6 * n1)
	h += noise.get_noise_2d(x * 4.0, z * 4.0) * 3.0 * smoothstep(30.0, 150.0, s)
	return h


# --------------------------------------------------------------- materiais
static func _materials() -> void:
	if _terrain_mat:
		return
	_terrain_mat = ShaderMaterial.new()
	_terrain_mat.shader = load("res://shaders/terrain.gdshader")
	_veg_mat = StandardMaterial3D.new()
	_veg_mat.vertex_color_use_as_albedo = true
	_veg_mat.vertex_color_is_srgb = true
	_veg_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_veg_mat.roughness = 0.85
	_build_mat = StandardMaterial3D.new()
	_build_mat.vertex_color_use_as_albedo = true
	_build_mat.vertex_color_is_srgb = true
	_build_mat.roughness = 0.9
	_build_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_road_mat = StandardMaterial3D.new()
	_road_mat.albedo_color = Color(0.46, 0.38, 0.27)
	_road_mat.roughness = 1.0


static func warm_caches() -> void:
	_materials()
	_palm_mesh()
	_tree_mesh()
	_rock_mesh()
	ShipBuilder.glow_material()
	_flag_shader = load("res://shaders/flag.gdshader")
	_stone_shader = load("res://shaders/stone.gdshader")


# --------------------------------------------------------------- vegetação
static func _palm_mesh() -> ArrayMesh:
	if _veg_meshes.has("palm"):
		return _veg_meshes["palm"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := Color(0.45, 0.35, 0.24)
	var leaf := Color(0.22, 0.45, 0.14)
	var pts: Array[Vector3] = []
	for i in 7:
		var t := i / 6.0
		pts.append(Vector3(t * t * 2.2, t * 9.0, 0.0))
	for i in 6:
		ShipBuilder._tube(st, pts[i], pts[i + 1], 0.32 - i * 0.03, 0.29 - i * 0.03, trunk, 6)
	var top := pts[6]
	for f in 8:
		var a := TAU * f / 8.0 + 0.3
		var dir := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-dir.z, 0.0, dir.x)
		var prev := top
		for s in 5:
			var t := (s + 1) / 5.0
			var p := top + dir * t * 4.6 + Vector3(0, 1.0 * sin(t * PI * 0.6) - t * t * 2.6, 0)
			var w0 := 0.7 * sin((s / 5.0) * PI) + 0.12
			var w1 := 0.7 * sin(t * PI) + 0.12
			var q := [prev - side * w0, prev + side * w0, p + side * w1, p - side * w1]
			st.set_color(leaf.lerp(Color(0.35, 0.55, 0.15), t * 0.5))
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2.ZERO)
			for k in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(q[k])
			prev = p
	var m := st.commit()
	_veg_meshes["palm"] = m
	return m


static func _sphere(st: SurfaceTool, c: Vector3, rad: Vector3, col: Color, seg := 7, rings := 5) -> void:
	st.set_color(col)
	st.set_uv(Vector2.ZERO)
	for j in rings:
		var v0 := PI * j / rings
		var v1 := PI * (j + 1) / rings
		for i in seg:
			var u0 := TAU * i / seg
			var u1 := TAU * (i + 1) / seg
			var p := [
				Vector3(sin(v0) * cos(u0), cos(v0), sin(v0) * sin(u0)),
				Vector3(sin(v0) * cos(u1), cos(v0), sin(v0) * sin(u1)),
				Vector3(sin(v1) * cos(u1), cos(v1), sin(v1) * sin(u1)),
				Vector3(sin(v1) * cos(u0), cos(v1), sin(v1) * sin(u0)),
			]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(p[k])
				st.add_vertex(c + p[k] * rad)


static func _tree_mesh() -> ArrayMesh:
	if _veg_meshes.has("tree"):
		return _veg_meshes["tree"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	ShipBuilder._tube(st, Vector3.ZERO, Vector3(0, 5, 0), 0.45, 0.3, Color(0.35, 0.25, 0.16), 6)
	var g := Color(0.2, 0.42, 0.13)
	_sphere(st, Vector3(0, 6.5, 0), Vector3(3.6, 2.8, 3.6), g)
	_sphere(st, Vector3(1.8, 5.6, 0.8), Vector3(2.4, 2.0, 2.4), g.lightened(0.1))
	_sphere(st, Vector3(-1.5, 5.8, -1.2), Vector3(2.6, 2.1, 2.6), g.darkened(0.1))
	_sphere(st, Vector3(0.2, 8.4, 0.3), Vector3(2.2, 1.7, 2.2), g.lightened(0.15))
	var m := st.commit()
	_veg_meshes["tree"] = m
	return m


static func _rock_mesh() -> ArrayMesh:
	if _veg_meshes.has("rock"):
		return _veg_meshes["rock"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_sphere(st, Vector3(0, 0.4, 0), Vector3(2.2, 1.4, 1.7), Color(0.46, 0.44, 0.41), 6, 4)
	_sphere(st, Vector3(1.2, 0.2, 0.6), Vector3(1.2, 0.9, 1.0), Color(0.4, 0.38, 0.36), 5, 3)
	var m := st.commit()
	_veg_meshes["rock"] = m
	return m


static func _house(st: SurfaceTool, gs: SurfaceTool, base: Vector3, b: Basis, w: float, d: float, h: float, wall: Color, roof: Color) -> void:
	ShipBuilder._box(st, Transform3D(b, base + b * Vector3(0, h * 0.5, 0)), Vector3(w, h, d), wall)
	# telhado de duas águas
	var rh := w * 0.42
	var p := [
		base + b * Vector3(-w * 0.55, h, -d * 0.55), base + b * Vector3(w * 0.55, h, -d * 0.55),
		base + b * Vector3(w * 0.55, h, d * 0.55), base + b * Vector3(-w * 0.55, h, d * 0.55),
		base + b * Vector3(0, h + rh, -d * 0.55), base + b * Vector3(0, h + rh, d * 0.55),
	]
	st.set_color(roof)
	st.set_uv(Vector2.ZERO)
	var tris := [[0, 4, 5], [0, 5, 3], [1, 2, 5], [1, 5, 4], [0, 1, 4], [3, 5, 2]]
	for t in tris:
		var a: Vector3 = p[t[0]]
		var c: Vector3 = p[t[1]]
		var e: Vector3 = p[t[2]]
		var n := (c - a).cross(e - a).normalized()
		if n.y < 0.0 and absf(n.y) > 0.1:
			n = -n
		st.set_normal(n)
		st.add_vertex(a)
		st.set_normal(n)
		st.add_vertex(c)
		st.set_normal(n)
		st.add_vertex(e)
	# porta e janelas
	ShipBuilder._box(st, Transform3D(b, base + b * Vector3(0, 1.3, d * 0.5 + 0.05)), Vector3(1.4, 2.6, 0.1), Color(0.25, 0.16, 0.1))
	var win_st := gs if gs != null else st
	for sx in [-w * 0.3, w * 0.3]:
		ShipBuilder._box(win_st, Transform3D(b, base + b * Vector3(sx, h * 0.6, d * 0.5 + 0.05)), Vector3(1.1, 1.3, 0.1), Color(1, 1, 1) if gs != null else Color(0.15, 0.12, 0.1))
		ShipBuilder._box(win_st, Transform3D(b, base + b * Vector3(sx, h * 0.6, -d * 0.5 - 0.05)), Vector3(1.1, 1.3, 0.1), Color(1, 1, 1) if gs != null else Color(0.15, 0.12, 0.1))
