class_name ShipBuilder
extends RefCounted
## Constrói proceduralmente o modelo 3D de cada tipo de navio (casco, conveses,
## mastros, vergas, velas, cordame, canhões, timão, lanternas e bandeiras).

static var _cache := {}
static var _wood_mat: ShaderMaterial
static var _rig_mat: StandardMaterial3D
static var _glow_mat: StandardMaterial3D
static var _sail_shader: Shader
static var _flag_shader: Shader


static func _mats() -> void:
	if _wood_mat:
		return
	_wood_mat = ShaderMaterial.new()
	_wood_mat.shader = load("res://shaders/wood.gdshader")
	_rig_mat = StandardMaterial3D.new()
	_rig_mat.vertex_color_use_as_albedo = true
	_rig_mat.vertex_color_is_srgb = true
	_rig_mat.roughness = 0.7
	_rig_mat.metallic_specular = 0.3
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.albedo_color = Color(1.0, 0.75, 0.35)
	_glow_mat.emission_enabled = true
	_glow_mat.emission = Color(1.0, 0.62, 0.25)
	_glow_mat.emission_energy_multiplier = 1.0
	_sail_shader = load("res://shaders/sail.gdshader")
	_flag_shader = load("res://shaders/flag.gdshader")


static func glow_material() -> StandardMaterial3D:
	_mats()
	return _glow_mat


# ------------------------------------------------------------- forma do casco
static func half_width(t: float, beam: float) -> float:
	var w: float
	if t < 0.45:
		w = lerpf(0.78, 1.0, sqrt(t / 0.45))
	else:
		var k := (t - 0.45) / 0.55
		w = pow(maxf(cos(k * PI * 0.5), 0.0), 0.72)
	return maxf(w, 0.015) * beam * 0.5


static func deck_height(t: float, d: Dictionary) -> float:
	var beam: float = d["beam"]
	var base := beam * 0.3 + 0.6
	var sheer := 0.9 * pow((t - 0.5) * 2.0, 2.0)
	var castle: float = d["castle"]
	var q := castle * (1.0 - smoothstep(0.2, 0.25, t))
	var fc := castle * 0.35 * smoothstep(0.84, 0.88, t)
	return base + sheer + q + fc


static func keel_depth(t: float, beam: float) -> float:
	var dd := beam * 0.42
	var bow := pow(smoothstep(0.62, 1.0, t), 1.6)
	return dd * (1.0 - 0.92 * bow) * (1.0 - 0.3 * smoothstep(0.1, 0.0, t))


static func t_to_z(t: float, length: float) -> float:
	return lerpf(length * 0.5, -length * 0.5, t)


# ------------------------------------------------------------- utilitários de malha
static func _lin(c: Color) -> Color:
	return c.srgb_to_linear()


static func _box(st: SurfaceTool, xf: Transform3D, size: Vector3, c: Color) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
		[Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
		[Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	]
	st.set_color(c)
	for f in faces:
		var n: Vector3 = f[0]
		var a: Vector3 = f[1]
		var b: Vector3 = f[2]
		var center := n * h
		var ea := a * h
		var eb := b * h
		var p0 := xf * (center - ea - eb)
		var p1 := xf * (center + ea - eb)
		var p2 := xf * (center + ea + eb)
		var p3 := xf * (center - ea + eb)
		var nn := (xf.basis * n).normalized()
		st.set_normal(nn)
		st.set_uv(Vector2.ZERO)
		for p in [p0, p2, p1, p0, p3, p2]:
			st.add_vertex(p)


static func _tube(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, c: Color, seg := 6) -> void:
	var axis := b - a
	if axis.length() < 0.001:
		return
	var dir := axis.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var u := dir.cross(up).normalized()
	var v := dir.cross(u).normalized()
	st.set_color(c)
	st.set_uv(Vector2.ZERO)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var n0 := u * cos(a0) + v * sin(a0)
		var n1 := u * cos(a1) + v * sin(a1)
		var p00 := a + n0 * r0
		var p01 := a + n1 * r0
		var p10 := b + n0 * r1
		var p11 := b + n1 * r1
		st.set_normal(n0)
		st.add_vertex(p00)
		st.set_normal(n1)
		st.add_vertex(p11)
		st.set_normal(n1)
		st.add_vertex(p01)
		st.set_normal(n0)
		st.add_vertex(p00)
		st.set_normal(n0)
		st.add_vertex(p10)
		st.set_normal(n1)
		st.add_vertex(p11)


static func sail_mesh(w: float, h: float, top_scale := 1.0, cols := 8, rows := 8) -> ArrayMesh:
	# Vela com origem na borda superior, pendendo para -Y, face para +Z.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for j in rows + 1:
		var row := []
		var v := float(j) / rows
		var rw := lerpf(w * top_scale, w, v)
		for i in cols + 1:
			var u := float(i) / cols
			row.append([Vector3((u - 0.5) * rw, -v * h, 0.0), Vector2(u, v)])
		pts.append(row)
	for j in rows:
		for i in cols:
			var q := [pts[j][i], pts[j][i + 1], pts[j + 1][i + 1], pts[j + 1][i]]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3(0, 0, 1))
				st.set_uv(q[k][1])
				st.add_vertex(q[k][0])
	return st.commit()


static func flag_mesh(w: float, h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 10
	var rows := 4
	for j in rows:
		for i in cols:
			var q := []
			for c in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var u := float(c[0]) / cols
				var v := float(c[1]) / rows
				q.append([Vector3(u * w, -v * h, 0.0), Vector2(u, v)])
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3(0, 0, 1))
				st.set_uv(q[k][1])
				st.add_vertex(q[k][0])
	return st.commit()


# ------------------------------------------------------------- casco + estrutura (cache)
static func _layout(d: Dictionary) -> Dictionary:
	var length: float = d["len"]
	var masts: int = d["masts"]
	var ts: Array = []
	match masts:
		1: ts = [0.6]
		2: ts = [0.36, 0.68]
		_: ts = [0.22, 0.5, 0.76]
	var heights: Array = []
	for i in ts.size():
		var h := length * 0.82 + 6.0
		if masts == 3 and i != 1:
			h *= 0.84
		if masts == 2 and i == 0 and d["rig"] == "square":
			h *= 1.0
		elif masts == 2 and i == 1:
			h *= 0.92
		heights.append(h)
	return {"ts": ts, "heights": heights}


static func _hull_mesh(d: Dictionary, nation: int) -> ArrayMesh:
	_mats()
	var key := "%s_%d" % [d["id"], nation]
	if _cache.has(key):
		return _cache[key]
	var nat: Dictionary = Game.NATIONS[nation]
	var length: float = d["len"]
	var beam: float = d["beam"]
	var hull_c := _lin(nat["hull"])
	var stripe_c := _lin(nat["stripe"])
	var tar_c := _lin(Color(0.09, 0.075, 0.06))
	var deck_c := _lin(Color(0.62, 0.48, 0.32))
	var rail_c := _lin(nat["hull"].darkened(0.3))
	var N := 26
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# seções transversais
	var sections := []
	for i in N + 1:
		var t := float(i) / N
		var w := half_width(t, beam)
		var dh := deck_height(t, d)
		var kd := keel_depth(t, beam)
		var z := t_to_z(t, length)
		var pts := []
		pts.append(Vector3(w * 0.9, dh + 1.0, z))
		pts.append(Vector3(w * 0.95, dh + 0.2, z))
		pts.append(Vector3(w * 0.985, dh * 0.55, z))
		pts.append(Vector3(w, 0.0, z))
		for k in range(1, 6):
			var a := float(k) / 5.0 * PI * 0.5
			pts.append(Vector3(w * pow(cos(a), 0.7), -kd * sin(a), z))
		sections.append(pts)
	for side in [1.0, -1.0]:
		for i in N:
			var s0: Array = sections[i]
			var s1: Array = sections[i + 1]
			for j in s0.size() - 1:
				var q := [s0[j], s1[j], s1[j + 1], s0[j + 1]]
				var order := [0, 1, 2, 0, 2, 3] if side > 0 else [0, 2, 1, 0, 3, 2]
				for k in order:
					var p: Vector3 = q[k]
					p.x *= side
					var dh := deck_height(1.0 - (p.z / length + 0.5), d)
					var c := hull_c
					if p.y < 0.35:
						c = tar_c
					elif p.y > dh * 0.28 and p.y < dh * 0.58:
						c = stripe_c
					elif p.y > dh + 0.75:
						c = rail_c
					st.set_color(Color(c.r, c.g, c.b, 1.0))
					st.set_uv(Vector2(p.z, p.y))
					st.add_vertex(p)
	# popa (espelho)
	var s_st: Array = sections[0]
	var center := Vector3(0.0, deck_height(0.0, d) * 0.4, s_st[0].z)
	for side in [1.0, -1.0]:
		for j in s_st.size() - 1:
			var a: Vector3 = s_st[j]
			var b: Vector3 = s_st[j + 1]
			a.x *= side
			b.x *= side
			var tri := [center, a, b] if side > 0 else [center, b, a]
			for p in tri:
				st.set_color(Color(hull_c.r, hull_c.g, hull_c.b, 1.0))
				st.set_uv(Vector2(p.x, p.y))
				st.add_vertex(p)
	# convés
	for i in N:
		var t0 := float(i) / N
		var t1 := float(i + 1) / N
		var w0 := half_width(t0, beam) * 0.9
		var w1 := half_width(t1, beam) * 0.9
		var y0 := deck_height(t0, d)
		var y1 := deck_height(t1, d)
		var z0 := t_to_z(t0, length)
		var z1 := t_to_z(t1, length)
		var q := [Vector3(-w0, y0, z0), Vector3(w0, y0, z0), Vector3(w1, y1, z1), Vector3(-w1, y1, z1)]
		for k in [0, 2, 1, 0, 3, 2]:
			var p: Vector3 = q[k]
			st.set_color(Color(deck_c.r, deck_c.g, deck_c.b, 1.0))
			st.set_uv(Vector2(p.z, p.x))
			st.add_vertex(p)
		# degrau do castelo de popa
		if absf(y1 - y0) > 0.6:
			var lo := minf(y0, y1)
			var hi := maxf(y0, y1)
			var zz := z0 if y0 > y1 else z1
			var ww := w0 if y0 > y1 else w1
			var wall := [Vector3(-ww, lo, zz), Vector3(ww, lo, zz), Vector3(ww, hi, zz), Vector3(-ww, hi, zz)]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_color(Color(hull_c.r, hull_c.g, hull_c.b, 1.0))
				st.set_uv(Vector2(wall[k].x, wall[k].y))
				st.add_vertex(wall[k])
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, _wood_mat)

	# ---- segunda superfície: mastros, vergas, cordame, canhões, detalhes
	var rs := SurfaceTool.new()
	rs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mast_c := Color(0.42, 0.3, 0.18)
	var rope_c := Color(0.16, 0.12, 0.08)
	var iron_c := Color(0.08, 0.08, 0.09)
	var lay := _layout(d)
	var mr := 0.22 + length * 0.009
	var bow_t := 0.985
	var bow_p := Vector3(0.0, deck_height(bow_t, d) + 0.6, t_to_z(bow_t, length))
	var bowsprit_end := bow_p + Vector3(0.0, length * 0.1, -length * 0.28)
	_tube(rs, bow_p + Vector3(0, -0.3, length * 0.05), bowsprit_end, mr * 0.8, mr * 0.35, mast_c, 6)
	var stern_top := Vector3(0.0, deck_height(0.0, d) + 1.0, t_to_z(0.0, length))
	for mi in lay["ts"].size():
		var t: float = lay["ts"][mi]
		var h: float = lay["heights"][mi]
		var base := Vector3(0.0, deck_height(t, d), t_to_z(t, length))
		var top := base + Vector3(0, h, 0)
		_tube(rs, base - Vector3(0, 1.0, 0), top, mr, mr * 0.4, mast_c, 8)
		# cesto da gávea
		if d["rig"] == "square":
			var nest := base + Vector3(0, h * 0.5, 0)
			_tube(rs, nest - Vector3(0, 0.25, 0), nest + Vector3(0, 0.15, 0), mr * 4.0, mr * 4.0, mast_c.darkened(0.2), 10)
		# enxárcias (ovéns) para os bordos
		var w := half_width(t, beam)
		for k in 4:
			var dz := (k - 1.5) * 0.9
			for side in [1.0, -1.0]:
				var foot := Vector3(side * w * 0.95, deck_height(t, d) + 0.9, base.z + dz + 1.2)
				_tube(rs, foot, base + Vector3(0, h * 0.5, 0), 0.04, 0.04, rope_c, 3)
				_tube(rs, base + Vector3(0, h * 0.5, 0), top - Vector3(0, h * 0.08, 0) + Vector3(side * mr * 3.0, 0, 0), 0.03, 0.03, rope_c, 3)
		# estais
		if mi == lay["ts"].size() - 1:
			_tube(rs, top, bowsprit_end, 0.05, 0.05, rope_c, 3)
			_tube(rs, top - Vector3(0, h * 0.4, 0), bow_p + Vector3(0, 0.5, 0), 0.05, 0.05, rope_c, 3)
		else:
			var nt: float = lay["ts"][mi + 1]
			var nb := Vector3(0.0, deck_height(nt, d), t_to_z(nt, length))
			_tube(rs, top, nb + Vector3(0, lay["heights"][mi + 1] * 0.55, 0), 0.04, 0.04, rope_c, 3)
		if mi == 0:
			_tube(rs, top, stern_top, 0.05, 0.05, rope_c, 3)
	# amuradas: corrimão de madeira
	for side in [1.0, -1.0]:
		for i in 12:
			var t0 := float(i) / 12.0
			var t1 := float(i + 1) / 12.0
			var a := Vector3(side * half_width(t0, beam) * 0.9, deck_height(t0, d) + 1.05, t_to_z(t0, length))
			var b := Vector3(side * half_width(t1, beam) * 0.9, deck_height(t1, d) + 1.05, t_to_z(t1, length))
			_tube(rs, a, b, 0.09, 0.09, Color(0.3, 0.2, 0.12), 4)
	# canhões e portinholas
	var guns: int = d["guns"]
	var decks := 2 if guns > 18 else 1
	var per_deck := int(ceil(float(guns) / decks))
	for side in [1.0, -1.0]:
		for g in guns:
			var row := g / per_deck
			var col := g % per_deck
			var t := lerpf(0.18, 0.78, (col + 0.5) / per_deck)
			var w := half_width(t, beam)
			var dh := deck_height(t, d)
			var y := dh * (0.72 if row == 0 else 0.42)
			if decks == 1:
				y = dh + 0.55
			var z := t_to_z(t, length)
			var xf := Transform3D(Basis(), Vector3(side * (w * 0.985 + 0.02), y, z))
			if decks == 2 or y < dh:
				_box(rs, xf, Vector3(0.08, 0.75, 0.8), iron_c)
			var outer := Vector3(side * (w + 0.75), y, z)
			_tube(rs, Vector3(side * (w * 0.7), y, z), outer, 0.2, 0.16, Color(0.1, 0.1, 0.1), 6)
	# timão do castelo de popa (pedestal)
	var ht := 0.13
	var hp := Vector3(0.0, deck_height(ht, d), t_to_z(ht, length))
	_box(rs, Transform3D(Basis(), hp + Vector3(0, 0.55, 0)), Vector3(0.3, 1.1, 0.5), Color(0.3, 0.2, 0.12))
	var rmesh := rs.commit(mesh)
	mesh.surface_set_material(1, _rig_mat)

	# ---- terceira superfície: janelas e lanternas (brilham)
	var gs := SurfaceTool.new()
	gs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sz := t_to_z(0.0, length) + 0.05
	var sdh := deck_height(0.0, d)
	var sw := half_width(0.0, beam)
	var wins := clampi(int(beam / 1.6), 2, 7)
	for i in wins:
		var x := lerpf(-sw * 0.6, sw * 0.6, (i + 0.5) / wins)
		_box(gs, Transform3D(Basis(), Vector3(x, sdh * 0.7, sz)), Vector3(0.5, 0.6, 0.06), Color(1, 1, 1))
	_box(gs, Transform3D(Basis(), Vector3(0.0, sdh + 2.0, sz)), Vector3(0.4, 0.6, 0.4), Color(1, 1, 1))
	for side in [1.0, -1.0]:
		_box(gs, Transform3D(Basis(), Vector3(side * sw * 0.8, sdh + 1.8, sz)), Vector3(0.3, 0.45, 0.3), Color(1, 1, 1))
	gs.commit(rmesh)
	rmesh.surface_set_material(2, _glow_mat)
	_cache[key] = rmesh
	return rmesh


# ------------------------------------------------------------- modelo completo
## Retorna {"root", "yards"(Array de pivôs), "sails"(Array de ShaderMaterial), "fore_aft",
##          "wheel", "flag_mats", "guns" (posições locais por bordo), "helm", "length", "beam", "lantern"}
static func build(d: Dictionary, nation: int, flag_type: int) -> Dictionary:
	_mats()
	var nat: Dictionary = Game.NATIONS[nation]
	var root := Node3D.new()
	root.name = "Model"
	var hull := MeshInstance3D.new()
	hull.mesh = _hull_mesh(d, nation)
	root.add_child(hull)
	var length: float = d["len"]
	var beam: float = d["beam"]
	var lay := _layout(d)
	var yards: Array = []
	var sails: Array = []
	var fore_aft: Array = []
	var flag_mats: Array = []
	var mast_c := _lin(Color(0.38, 0.27, 0.16))
	var sail_col: Color = nat["sail"]
	var emblem := 0
	var emblem_col := Color(0.7, 0.05, 0.05)
	match nation:
		Game.ESP:
			emblem = 1
		Game.ENG:
			emblem = 2
			emblem_col = Color(0.75, 0.08, 0.1)
		Game.POR:
			emblem = 2
			emblem_col = Color(0.75, 0.1, 0.08)
		Game.PIR:
			emblem = 3
			emblem_col = Color(0.85, 0.82, 0.75)
	var mr := 0.22 + length * 0.009
	for mi in lay["ts"].size():
		var t: float = lay["ts"][mi]
		var h: float = lay["heights"][mi]
		var base := Vector3(0.0, deck_height(t, d), t_to_z(t, length))
		var pivot := Node3D.new()
		pivot.position = base
		root.add_child(pivot)
		if d["rig"] == "square":
			yards.append(pivot)
			var levels := [0.3, 0.58, 0.82]
			var widths := [1.0, 0.82, 0.6]
			var ylen := beam * 1.75
			for li in levels.size():
				var yy: float = h * levels[li]
				var top_y: float = h * (levels[li + 1] - 0.02) if li < 2 else h * 0.98
				var yl: float = ylen * widths[li] * (0.9 if mi != 1 and lay["ts"].size() == 3 else 1.0)
				var yard := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = mr * 0.45
				cm.bottom_radius = mr * 0.45
				cm.height = yl
				cm.radial_segments = 6
				cm.rings = 1
				var ym := StandardMaterial3D.new()
				ym.albedo_color = mast_c.linear_to_srgb()
				ym.roughness = 0.8
				cm.material = ym
				yard.mesh = cm
				yard.rotation = Vector3(0, 0, PI * 0.5)
				yard.position = Vector3(0, top_y, 0)
				pivot.add_child(yard)
				# vela pendendo da verga
				var sh: float = top_y - yy
				var sw: float = yl * 0.92
				var sail := MeshInstance3D.new()
				sail.mesh = sail_mesh(sw, sh, 0.86)
				var sm := ShaderMaterial.new()
				sm.shader = _sail_shader
				sm.set_shader_parameter("sail_color", sail_col)
				sm.set_shader_parameter("sail_w", sw)
				sm.set_shader_parameter("sail_h", sh)
				sm.set_shader_parameter("depth", sw * 0.12)
				sm.set_shader_parameter("emblem", emblem if (li == 0 and mi == lay["ts"].size() / 2) else 0)
				sm.set_shader_parameter("emblem_color", emblem_col)
				sail.material_override = sm
				sail.position = Vector3(0, top_y - 0.2, -mr * 1.6)
				sail.rotation = Vector3(0, PI, 0)
				sail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				pivot.add_child(sail)
				sails.append(sm)
		else:
			# vela latina (carangueja): gira em torno do mastro
			fore_aft.append(pivot)
			var boom_y := 2.2
			var gaff_y := h * 0.72
			var sl := minf(length * 0.42, 14.0)
			var sail := MeshInstance3D.new()
			sail.mesh = sail_mesh(sl, gaff_y - boom_y, 0.8)
			var sm := ShaderMaterial.new()
			sm.shader = _sail_shader
			sm.set_shader_parameter("sail_color", sail_col)
			sm.set_shader_parameter("sail_w", sl)
			sm.set_shader_parameter("sail_h", gaff_y - boom_y)
			sm.set_shader_parameter("depth", sl * 0.1)
			sm.set_shader_parameter("emblem", emblem if mi == lay["ts"].size() - 1 else 0)
			sm.set_shader_parameter("emblem_color", emblem_col)
			sail.material_override = sm
			sail.rotation = Vector3(0, PI * 0.5, 0)
			sail.position = Vector3(0, gaff_y, sl * 0.5 + mr)
			pivot.add_child(sail)
			sails.append(sm)
			for yy in [boom_y, gaff_y]:
				var spar := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = mr * 0.4
				cm.bottom_radius = mr * 0.5
				cm.height = sl
				cm.radial_segments = 6
				cm.rings = 1
				var ym := StandardMaterial3D.new()
				ym.albedo_color = mast_c.linear_to_srgb()
				cm.material = ym
				spar.mesh = cm
				spar.rotation = Vector3(PI * 0.5, 0, 0)
				spar.position = Vector3(0, yy, sl * 0.5 + mr)
				pivot.add_child(spar)
		# flâmula no topo do mastro
		var pen := MeshInstance3D.new()
		var fw := 1.2 + length * 0.05
		pen.mesh = flag_mesh(fw, fw * 0.62)
		var fm := ShaderMaterial.new()
		fm.shader = _flag_shader
		fm.set_shader_parameter("flag_type", flag_type)
		pen.material_override = fm
		pen.position = base + Vector3(0, h + 0.1, 0)
		root.add_child(pen)
		flag_mats.append({"node": pen, "mat": fm})
	# bujarrona (vela de proa triangular)
	var bow_p := Vector3(0.0, deck_height(0.985, d) + 0.6, t_to_z(0.985, length))
	var bow_end := bow_p + Vector3(0.0, length * 0.1, -length * 0.28)
	var fmast_t: float = lay["ts"][-1]
	var fmast_top := Vector3(0.0, deck_height(fmast_t, d) + lay["heights"][-1] * 0.72, t_to_z(fmast_t, length))
	var apex := fmast_top.lerp(bow_end, 0.3)
	var jh := maxf(apex.y - (deck_height(0.92, d) + 1.6), 2.0)
	var jw := absf(bow_end.z - fmast_top.z) * 0.55
	var jib := MeshInstance3D.new()
	jib.mesh = sail_mesh(jw, jh, 0.02, 6, 6)
	var jm := ShaderMaterial.new()
	jm.shader = _sail_shader
	jm.set_shader_parameter("sail_color", sail_col)
	jm.set_shader_parameter("sail_w", jw)
	jm.set_shader_parameter("sail_h", jh)
	jm.set_shader_parameter("depth", jw * 0.1)
	jib.material_override = jm
	var jib_pivot := Node3D.new()
	jib_pivot.position = apex
	root.add_child(jib_pivot)
	jib.rotation = Vector3(0, PI * 0.5, 0)
	jib_pivot.add_child(jib)
	fore_aft.append(jib_pivot)
	sails.append(jm)
	# bandeira de popa (pavilhão nacional)
	var stern := Vector3(0.0, deck_height(0.0, d) + 1.0, t_to_z(0.0, length) + 0.6)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.06
	pm.bottom_radius = 0.08
	pm.height = 4.0 + length * 0.05
	pm.radial_segments = 5
	pm.rings = 1
	pole.mesh = pm
	pole.position = stern + Vector3(0, pm.height * 0.5, 0.0)
	pole.rotation = Vector3(-0.35, 0, 0)
	root.add_child(pole)
	var ens := MeshInstance3D.new()
	var ew := 2.4 + length * 0.07
	ens.mesh = flag_mesh(ew, ew * 0.66)
	var em := ShaderMaterial.new()
	em.shader = _flag_shader
	em.set_shader_parameter("flag_type", flag_type)
	ens.material_override = em
	ens.position = stern + Vector3(0, pm.height * 0.92, pm.height * 0.33)
	root.add_child(ens)
	flag_mats.append({"node": ens, "mat": em})
	# timão (roda do leme), visto da câmera em primeira pessoa
	var ht := 0.13
	var hp := Vector3(0.0, deck_height(ht, d) + 1.25, t_to_z(ht, length) - 0.35)
	var wheel := Node3D.new()
	wheel.position = hp
	root.add_child(wheel)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.36, 0.22, 0.12)
	wm.roughness = 0.55
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.6
	tm.outer_radius = 0.7
	tm.rings = 24
	tm.ring_segments = 6
	tm.material = wm
	ring.mesh = tm
	ring.rotation = Vector3(PI * 0.5, 0, 0)
	wheel.add_child(ring)
	for k in 8:
		var sp := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.045
		cm.height = 1.75
		cm.radial_segments = 5
		cm.rings = 1
		cm.material = wm
		sp.mesh = cm
		sp.rotation = Vector3(0, 0, k * PI / 4.0)
		wheel.add_child(sp)
	var hub := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.14
	hm.bottom_radius = 0.14
	hm.height = 0.35
	hm.material = wm
	hub.mesh = hm
	hub.rotation = Vector3(PI * 0.5, 0, 0)
	wheel.add_child(hub)
	# posições dos canhões por bordo (para disparo)
	var guns: int = d["guns"]
	var decks := 2 if guns > 18 else 1
	var per_deck := int(ceil(float(guns) / decks))
	var gun_pos := {1.0: [], -1.0: []}
	for side in [1.0, -1.0]:
		for g in guns:
			var row := g / per_deck
			var col := g % per_deck
			var t := lerpf(0.18, 0.78, (col + 0.5) / per_deck)
			var w := half_width(t, beam)
			var dh := deck_height(t, d)
			var y := dh * (0.72 if row == 0 else 0.42)
			if decks == 1:
				y = dh + 0.55
			gun_pos[side].append(Vector3(side * (w + 0.8), y, t_to_z(t, length)))
	return {
		"root": root, "yards": yards, "sails": sails, "fore_aft": fore_aft, "wheel": wheel,
		"flag_mats": flag_mats, "guns": gun_pos, "helm": hp + Vector3(0, 0.75, 2.1),
		"length": length, "beam": beam, "lantern": Vector3(0.0, deck_height(0.0, d) + 2.0, t_to_z(0.0, length)),
		"deck_mid": deck_height(0.5, d),
	}
