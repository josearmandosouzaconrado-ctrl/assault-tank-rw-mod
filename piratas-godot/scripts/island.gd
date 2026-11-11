class_name Island
extends RefCounted
## Dados e construção de uma ilha: relevo procedural, vegetação e (se houver) a cidade portuária.

var pos := Vector2.ZERO
var r := 300.0
var max_h := 30.0
var seed_i := 0
var port_idx := -1
var noise: FastNoiseLite
var node: Node3D
var building := false
var name := ""
var dock_point := Vector2.ZERO     # água em frente ao cais
var coast_point := Vector2.ZERO
var fort_pos := Vector3.ZERO
var town_center := Vector3.ZERO
var flag_mat: ShaderMaterial
var fort_ruin: Node3D

static var _veg_meshes := {}
static var _terrain_mat: ShaderMaterial
static var _veg_mat: StandardMaterial3D
static var _build_mat: StandardMaterial3D
static var _flag_shader: Shader


func _init(p: Vector2, radius: float, height: float, s: int) -> void:
	pos = p
	r = radius
	max_h = height
	seed_i = s
	noise = FastNoiseLite.new()
	noise.seed = s
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.0035
	noise.fractal_octaves = 4


func bound() -> float:
	return r * 1.55


func height(x: float, z: float) -> float:
	var dx := x - pos.x
	var dz := z - pos.y
	var d2 := dx * dx + dz * dz
	var b := bound()
	if d2 > b * b:
		return -18.0
	var d := sqrt(d2)
	var a := atan2(dz, dx)
	var edge := noise.get_noise_2d(cos(a) * 300.0 + 1000.0, sin(a) * 300.0)
	var re := r * (0.8 + 0.35 * edge)
	var t := d / re
	var n1 := noise.get_noise_2d(dx, dz)
	var core := maxf(1.0 - t, 0.0)
	var h := max_h * pow(core, 1.25) * (0.65 + 0.6 * n1)
	h += 2.6 * (1.0 - smoothstep(0.86, 1.0, t))
	h -= 18.0 * smoothstep(0.96, 1.55, t)
	if port_idx >= 0:
		# planalto suave para a cidade
		var tc := Vector2(town_center.x, town_center.z)
		if tc != Vector2.ZERO:
			var dt := Vector2(x, z).distance_to(tc)
			var flat := 1.0 - smoothstep(110.0, 190.0, dt)
			h = lerpf(h, maxf(minf(h, 6.0), 2.4), flat * (1.0 if h >= 0.0 else 0.0))
	return h


func find_coast(dir: Vector2) -> Vector2:
	var p := pos
	var step := 6.0
	var d := 0.0
	while d < r * 1.6:
		var q := pos + dir * d
		if height(q.x, q.y) < -0.6:
			return q
		d += step
	return pos + dir * r


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


static func warm_caches() -> void:
	_materials()
	_palm_mesh()
	_tree_mesh()
	_rock_mesh()
	ShipBuilder.glow_material()
	_flag_shader = load("res://shaders/flag.gdshader")


# --------------------------------------------------------------- construção
func build() -> Node3D:
	_materials()
	var root := Node3D.new()
	root.name = "Ilha_%d" % seed_i
	var mi := MeshInstance3D.new()
	mi.mesh = _terrain_mesh()
	mi.material_override = _terrain_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(mi)
	_vegetation(root)
	if port_idx >= 0:
		_town(root)
	node = root
	return root


func _terrain_mesh() -> ArrayMesh:
	var ext := bound()
	var n := clampi(int(ext * 2.0 / 13.0), 40, 120 if Game.quality > 0 else 80)
	var cell := ext * 2.0 / n
	var hs := PackedFloat32Array()
	hs.resize((n + 1) * (n + 1))
	for j in n + 1:
		for i in n + 1:
			var x := pos.x - ext + i * cell
			var z := pos.y - ext + j * cell
			hs[j * (n + 1) + i] = height(x, z)
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	verts.resize((n + 1) * (n + 1))
	cols.resize(verts.size())
	norms.resize(verts.size())
	var sand := Color(0.86, 0.77, 0.56).srgb_to_linear()
	var grass := Color(0.36, 0.52, 0.2).srgb_to_linear()
	var jungle := Color(0.15, 0.3, 0.09).srgb_to_linear()
	var rock := Color(0.47, 0.44, 0.4).srgb_to_linear()
	var under := Color(0.62, 0.58, 0.44).srgb_to_linear()
	for j in n + 1:
		for i in n + 1:
			var k := j * (n + 1) + i
			var h := hs[k]
			var hl := hs[k - 1] if i > 0 else h
			var hr := hs[k + 1] if i < n else h
			var hd := hs[k - (n + 1)] if j > 0 else h
			var hu := hs[k + (n + 1)] if j < n else h
			var nrm := Vector3(hl - hr, 2.0 * cell, hd - hu).normalized()
			var slope := 1.0 - nrm.y
			var c: Color
			if h < -0.5:
				c = under
			elif h < 2.6:
				c = sand
			else:
				var hn := clampf((h - 2.6) / maxf(max_h * 0.7, 4.0), 0.0, 1.0)
				c = grass.lerp(jungle, clampf(hn * 1.6 + noise.get_noise_2d(i * 37.0, j * 37.0) * 0.4, 0.0, 1.0))
				if h < 4.0:
					c = sand.lerp(c, (h - 2.6) / 1.4)
			if slope > 0.32 or h > max_h * 0.85:
				c = c.lerp(rock, clampf((slope - 0.32) * 5.0 + maxf(0.0, (h - max_h * 0.85) * 0.2), 0.0, 1.0))
			verts[k] = Vector3(-ext + i * cell, h, -ext + j * cell)
			cols[k] = c
			norms[k] = nrm
	var idx := PackedInt32Array()
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			var b := a + 1
			var c := a + (n + 1)
			var d := c + 1
			if hs[a] < -6.0 and hs[b] < -6.0 and hs[c] < -6.0 and hs[d] < -6.0:
				continue
			idx.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


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


func _vegetation(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i * 31 + 7
	var dens: float = [0.45, 0.8, 1.0][Game.quality]
	var area := PI * r * r
	var n_palm := int(clampf(area / 1400.0, 6, 420) * dens)
	var n_tree := int(clampf(area / 1700.0, 0, 380) * dens) if max_h > 12.0 else 0
	var n_rock := int(clampf(area / 9000.0, 2, 60) * dens)
	var palms: Array[Transform3D] = []
	var trees: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var ext := r * 1.05
	var tries := 0
	var tc := Vector2(town_center.x, town_center.z)
	while (palms.size() < n_palm or trees.size() < n_tree) and tries < (n_palm + n_tree) * 6:
		tries += 1
		var lp := Vector2(rng.randf_range(-ext, ext), rng.randf_range(-ext, ext))
		var wp := pos + lp
		if port_idx >= 0 and wp.distance_to(tc) < 170.0:
			continue
		var h := height(wp.x, wp.y)
		if h < 1.4:
			continue
		var h2 := height(wp.x + 3.0, wp.y)
		if absf(h2 - h) > 2.4:
			continue
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.75, 1.35))
		var t := Transform3D(b, Vector3(lp.x, h - 0.3, lp.y))
		if (h < 9.0 or rng.randf() < 0.25) and palms.size() < n_palm:
			palms.append(t)
		elif h >= 5.0 and trees.size() < n_tree:
			trees.append(t)
	tries = 0
	while rocks.size() < n_rock and tries < n_rock * 8:
		tries += 1
		var lp := Vector2(rng.randf_range(-ext, ext), rng.randf_range(-ext, ext))
		var h := height(pos.x + lp.x, pos.y + lp.y)
		if h < -1.5 or h > max_h:
			continue
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rng.randf_range(0.7, 2.4), rng.randf_range(0.6, 1.8), rng.randf_range(0.7, 2.4)))
		rocks.append(Transform3D(b, Vector3(lp.x, h - 0.4, lp.y)))
	var vis: float = [900.0, 1500.0, 2200.0][Game.quality]
	_add_mm(root, _palm_mesh(), palms, vis)
	_add_mm(root, _tree_mesh(), trees, vis)
	_add_mm(root, _rock_mesh(), rocks, vis * 1.3)


func _add_mm(root: Node3D, mesh: Mesh, xfs: Array[Transform3D], vis: float) -> void:
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _veg_mat
	mmi.visibility_range_end = vis
	mmi.visibility_range_end_margin = 80.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Game.quality > 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)


# --------------------------------------------------------------- cidade portuária
## Calcula posições da cidade, do cais e do forte (sem construir malhas).
func plan_port() -> void:
	var dir := Game.dock_offset(port_idx)
	coast_point = find_coast(dir)
	dock_point = coast_point + dir * 95.0
	var tc := coast_point - dir * 120.0
	town_center = Vector3(tc.x, 0.0, tc.y)
	town_center.y = height(tc.x, tc.y)
	var fdir := dir.rotated(0.55)
	var fc := find_coast(fdir) - fdir * 22.0
	fort_pos = Vector3(fc.x, maxf(height(fc.x, fc.y), 1.5), fc.y)


func _town(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i * 17 + 3
	var nat: int = Game.port_owner[port_idx]
	var orig: int = Game.PORTS_DEF[port_idx]["nation"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var gs := SurfaceTool.new()
	gs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dir := Game.dock_offset(port_idx)
	var ang := atan2(dir.x, dir.y)
	var walls := [Color(0.92, 0.88, 0.78), Color(0.95, 0.85, 0.65), Color(0.85, 0.75, 0.6)]
	var roofs := [Color(0.62, 0.25, 0.15), Color(0.55, 0.3, 0.2)]
	match orig:
		Game.ENG:
			walls = [Color(0.6, 0.32, 0.24), Color(0.75, 0.7, 0.62), Color(0.55, 0.42, 0.3)]
			roofs = [Color(0.3, 0.3, 0.32), Color(0.4, 0.3, 0.22)]
		Game.HOL:
			walls = [Color(0.62, 0.28, 0.2), Color(0.9, 0.82, 0.55), Color(0.4, 0.55, 0.62), Color(0.85, 0.55, 0.35)]
			roofs = [Color(0.55, 0.22, 0.14), Color(0.3, 0.28, 0.28)]
		Game.FRA:
			walls = [Color(0.9, 0.84, 0.7), Color(0.78, 0.72, 0.6), Color(0.88, 0.78, 0.58)]
			roofs = [Color(0.36, 0.38, 0.42), Color(0.6, 0.32, 0.2)]
		Game.PIR:
			walls = [Color(0.48, 0.38, 0.27), Color(0.4, 0.32, 0.22), Color(0.55, 0.45, 0.32)]
			roofs = [Color(0.62, 0.55, 0.35), Color(0.38, 0.3, 0.2)]
		Game.POR:
			walls = [Color(0.96, 0.95, 0.9), Color(0.95, 0.85, 0.45), Color(0.55, 0.7, 0.85)]
			roofs = [Color(0.7, 0.32, 0.18), Color(0.62, 0.28, 0.16)]
	var tc := Vector2(town_center.x, town_center.z)
	var placed: Array[Vector2] = []
	var count := 34 if Game.quality > 0 else 22
	var tries := 0
	while placed.size() < count and tries < 400:
		tries += 1
		var off := Vector2(rng.randf_range(-130, 130), rng.randf_range(-130, 130))
		var wp := tc + off
		var h := height(wp.x, wp.y)
		if h < 1.8 or h > 14.0:
			continue
		var ok := true
		for q in placed:
			if q.distance_to(wp) < 17.0:
				ok = false
				break
		if not ok:
			continue
		placed.append(wp)
		var w := rng.randf_range(7, 12)
		var dd := rng.randf_range(7, 11)
		var hh := rng.randf_range(4.5, 8.5) * (1.4 if orig == Game.HOL else 1.0)
		var a := ang + (rng.randi() % 4) * PI * 0.5
		var b := Basis(Vector3.UP, a)
		var base := Vector3(wp.x - pos.x, h - 0.5, wp.y - pos.y)
		_house(st, gs, base, b, w, dd, hh, walls[rng.randi() % walls.size()], roofs[rng.randi() % roofs.size()])
	# igreja
	var cb := Basis(Vector3.UP, ang)
	var cpos := Vector3(tc.x - pos.x, town_center.y - 0.5, tc.y - pos.y)
	_house(st, gs, cpos, cb, 12, 26, 10, Color(0.93, 0.9, 0.82), Color(0.55, 0.28, 0.18))
	ShipBuilder._box(st, Transform3D(cb, cpos + cb * Vector3(0, 11, 14)), Vector3(6, 22, 6), Color(0.93, 0.9, 0.82))
	ShipBuilder._box(st, Transform3D(cb, cpos + cb * Vector3(0, 23.5, 14)), Vector3(4, 3, 4), Color(0.55, 0.28, 0.18))
	# cais
	var cp := Vector3(coast_point.x - pos.x, 0.0, coast_point.y - pos.y)
	var db := Basis(Vector3.UP, ang)
	var plank := Color(0.45, 0.33, 0.22)
	ShipBuilder._box(st, Transform3D(db, cp + db * Vector3(0, 1.4, 30)), Vector3(7, 0.5, 80), plank)
	for k in 9:
		for sx in [-3.2, 3.2]:
			ShipBuilder._box(st, Transform3D(db, cp + db * Vector3(sx, -2.0, k * 9.5 - 6.0)), Vector3(0.6, 7.0, 0.6), plank.darkened(0.3))
	ShipBuilder._box(st, Transform3D(db, cp + db * Vector3(0, 1.4, 66)), Vector3(22, 0.5, 8), plank)
	# armazéns no porto
	for k in 3:
		var wp := cp + db * Vector3(-22 + k * 22, 0, -18)
		var h := height(pos.x + wp.x, pos.y + wp.z)
		_house(st, null, Vector3(wp.x, maxf(h, 1.0) - 0.5, wp.z), db, 14, 10, 6, Color(0.5, 0.38, 0.26), Color(0.42, 0.3, 0.2))
	# forte
	var fp := fort_pos - Vector3(pos.x, 0, pos.y)
	var fb := Basis(Vector3.UP, ang + 0.55)
	var stone := Color(0.6, 0.57, 0.5)
	var fs := 30.0
	for k in 4:
		var kb := fb * Basis(Vector3.UP, k * PI * 0.5)
		ShipBuilder._box(st, Transform3D(kb, fp + kb * Vector3(0, 3.0, fs * 0.5)), Vector3(fs, 9.0, 3.0), stone)
		ShipBuilder._tube(st, fp + kb * Vector3(fs * 0.5, -1.5, fs * 0.5), fp + kb * Vector3(fs * 0.5, 9.5, fs * 0.5), 4.2, 3.8, stone.darkened(0.1), 8)
		for g in 3:
			var gp := fp + kb * Vector3(-8.0 + g * 8.0, 7.8, fs * 0.5)
			ShipBuilder._tube(st, gp, gp + kb * Vector3(0, 0.3, 3.2), 0.32, 0.26, Color(0.1, 0.1, 0.1), 6)
	ShipBuilder._box(st, Transform3D(fb, fp + Vector3(0, 1.5, 0)), Vector3(fs - 2, 5.0, fs - 2), stone.darkened(0.2))
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _build_mat
	root.add_child(mi)
	# mastro e bandeira do dono do porto
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.15
	pm.bottom_radius = 0.22
	pm.height = 16.0
	pole.mesh = pm
	pole.position = fp + Vector3(0, 12.0, 0)
	root.add_child(pole)
	var flag := MeshInstance3D.new()
	flag.mesh = ShipBuilder.flag_mesh(7.5, 5.0)
	flag_mat = ShaderMaterial.new()
	flag_mat.shader = _flag_shader
	flag_mat.set_shader_parameter("flag_type", Game.NATIONS[nat]["flag"])
	flag.material_override = flag_mat
	flag.position = fp + Vector3(0.2, 19.8, 0)
	root.add_child(flag)
	# luzes das janelas à noite
	var glow := MeshInstance3D.new()
	glow.mesh = gs.commit()
	glow.material_override = ShipBuilder.glow_material()
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow)
	fort_ruin = Node3D.new()
	fort_ruin.position = fp + Vector3(0, 8, 0)
	root.add_child(fort_ruin)


func set_owner_flag(nat: int) -> void:
	if flag_mat:
		flag_mat.set_shader_parameter("flag_type", Game.NATIONS[nat]["flag"])


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
