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
		w = pow(maxf(cos(k * PI * 0.5), 0.0), 0.55)
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


## Inclinação da roda de proa (para a frente) e do painel de popa (para trás), conforme a altura.
static func rake_z(t: float, y: float, d: Dictionary) -> float:
	var length: float = d["len"]
	var kd := keel_depth(t, d["beam"])
	var top := deck_height(t, d) + 1.0
	var z := 0.0
	if t > 0.8:
		z -= smoothstep(0.8, 1.0, t) * pow(clampf((y + kd) / (top + kd), 0.0, 1.0), 1.4) * length * 0.07
	if t < 0.1:
		z += smoothstep(0.1, 0.0, t) * clampf((y + 0.5) / (top + 0.5), 0.0, 1.0) * length * 0.025
	return z


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
	var tar_c := _lin(Color(0.07, 0.06, 0.05))
	var bottom_c := _lin(Color(0.3, 0.27, 0.2))
	var wale_c := _lin(Color(0.08, 0.07, 0.06))
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
		pts.append(Vector3(w * 0.86, dh + 1.0, z))
		pts.append(Vector3(w * 0.9, dh + 0.3, z))
		pts.append(Vector3(w * 0.96, dh * 0.6, z))
		pts.append(Vector3(w, dh * 0.2, z))
		pts.append(Vector3(w * 0.995, 0.0, z))
		for k in range(1, 6):
			var a := float(k) / 5.0 * PI * 0.47
			pts.append(Vector3(maxf(w * pow(cos(a), 0.55), 0.15), -kd * pow(sin(a) / sin(PI * 0.47), 1.3), z))
		pts.append(Vector3(0.15, -kd - 0.35, z))
		pts.append(Vector3(0.0, -kd - 0.35, z))
		for pi in pts.size():
			var pp: Vector3 = pts[pi]
			pp.z += rake_z(t, pp.y, d)
			pts[pi] = pp
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
					var dh := deck_height(clampf(1.0 - (p.z / length + 0.5), 0.0, 1.0), d)
					var c := hull_c
					var two_decks: bool = int(d["guns"]) > 18
					if p.y < -0.15:
						c = bottom_c
					elif p.y < 0.3:
						c = tar_c
					elif p.y > dh * 0.12 and p.y < dh * 0.26:
						c = wale_c
					elif p.y > dh * 0.56 and p.y < dh * 0.66:
						c = wale_c
					elif two_decks and p.y > dh * 0.3 and p.y < dh * 0.52:
						c = stripe_c
					elif p.y > dh * 0.72 and p.y < dh * 0.9:
						c = stripe_c
					elif p.y >= dh + 0.75:
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
		z0 += rake_z(t0, y0, d)
		z1 += rake_z(t1, y1, d)
		var q := [Vector3(-w0, y0, z0), Vector3(w0, y0, z0), Vector3(w1, y1, z1), Vector3(-w1, y1, z1)]
		for k in [0, 2, 1, 0, 3, 2]:
			var p: Vector3 = q[k]
			st.set_color(Color(deck_c.r, deck_c.g, deck_c.b, 0.45))
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
	var gold_c := Color(0.85, 0.65, 0.22)
	var wood_c := Color(0.36, 0.24, 0.14)
	var lay := _layout(d)
	var mr := 0.22 + length * 0.009
	var square: bool = d["rig"] == "square"
	var bow_t := 0.985
	var bow_p := Vector3(0.0, deck_height(bow_t, d) + 0.6, t_to_z(bow_t, length) + rake_z(bow_t, deck_height(bow_t, d), d))
	var bowsprit_end := bow_p + Vector3(0.0, length * 0.1, -length * 0.28)
	_tube(rs, bow_p + Vector3(0, -0.3, length * 0.05), bowsprit_end, mr * 0.8, mr * 0.4, mast_c, 6)
	# pau da bujarrona (continuação mais fina)
	var jibboom_end := bowsprit_end + (bowsprit_end - bow_p).normalized() * length * 0.12
	_tube(rs, bowsprit_end - (bowsprit_end - bow_p).normalized() * 1.5, jibboom_end, mr * 0.35, mr * 0.2, mast_c, 5)
	# carranca dourada sob o gurupés
	var fh := Vector3(0.0, deck_height(0.99, d) * 0.75, t_to_z(0.99, length) + rake_z(0.99, deck_height(0.99, d) * 0.75, d) - 0.3)
	Island._sphere(rs, fh, Vector3(0.35, 0.7, 0.6) * (0.6 + length * 0.015), gold_c, 6, 4)
	var stern_top := Vector3(0.0, deck_height(0.0, d) + 1.0, t_to_z(0.0, length))
	for mi in lay["ts"].size():
		var t: float = lay["ts"][mi]
		var h: float = lay["heights"][mi]
		var dk := deck_height(t, d)
		var base := Vector3(0.0, dk, t_to_z(t, length))
		var top := base + Vector3(0, h, 0)
		var w := half_width(t, beam)
		if square:
			# mastro real + mastaréu com sobreposição (dobra) e cesto da gávea
			_tube(rs, base - Vector3(0, 1.0, 0), base + Vector3(0, h * 0.55, 0), mr, mr * 0.8, mast_c, 8)
			var tm0 := base + Vector3(0, h * 0.46, -mr * 1.3)
			_tube(rs, tm0, top + Vector3(0, 0, -mr * 1.3), mr * 0.62, mr * 0.32, mast_c, 6)
			_box(rs, Transform3D(Basis(), base + Vector3(0, h * 0.55, -mr * 0.6)), Vector3(mr * 2.6, mr * 1.2, mr * 3.6), wood_c)
			_box(rs, Transform3D(Basis(), base + Vector3(0, h * 0.5, 0)), Vector3(mr * 10.0, 0.22, mr * 7.0), wood_c)
			_box(rs, Transform3D(Basis(), base + Vector3(0, h * 0.8, -mr * 1.3)), Vector3(mr * 6.0, 0.15, 0.2), wood_c)
			_box(rs, Transform3D(Basis(), base + Vector3(0, h * 0.8, -mr * 1.3)), Vector3(0.2, 0.15, mr * 4.0), wood_c)
		else:
			_tube(rs, base - Vector3(0, 1.0, 0), top, mr, mr * 0.4, mast_c, 8)
			_box(rs, Transform3D(Basis(), base + Vector3(0, h * 0.78, 0)), Vector3(mr * 5.0, 0.15, 0.2), wood_c)
		# mesas de enxárcia (chainwales) com bigotas
		var ch_len := 2.2 + length * 0.06
		var ch_y := dk + 0.35
		for side in [1.0, -1.0]:
			_box(rs, Transform3D(Basis(), Vector3(side * (w + 0.3), ch_y, base.z + 1.0)), Vector3(0.6, 0.14, ch_len), wood_c)
		# enxárcias com enfrechates (escadinhas de corda)
		var n_sh := 4 if length < 30 else 6
		var mast_head := base + Vector3(0, h * (0.5 if square else 0.75), 0)
		for side in [1.0, -1.0]:
			var feet: Array[Vector3] = []
			for k in n_sh:
				var dz := lerpf(-ch_len * 0.4, ch_len * 0.4, float(k) / (n_sh - 1)) + 1.0
				var foot := Vector3(side * (w + 0.55), ch_y + 0.1, base.z + dz)
				feet.append(foot)
				_box(rs, Transform3D(Basis(), foot + Vector3(0, 0.15, 0)), Vector3(0.18, 0.3, 0.3), Color(0.12, 0.09, 0.06))
				_tube(rs, foot + Vector3(0, 0.3, 0), mast_head + Vector3(side * mr, 0, 0), 0.035, 0.035, rope_c, 3)
			var hgt := mast_head.y - feet[0].y
			var yy := 0.6
			while yy < hgt * 0.85:
				var f := yy / hgt
				var a0: Vector3 = feet[0].lerp(mast_head + Vector3(side * mr, 0, 0), f) + Vector3(0, 0.3 * (1.0 - f), 0)
				var a1: Vector3 = feet[n_sh - 1].lerp(mast_head + Vector3(side * mr, 0, 0), f) + Vector3(0, 0.3 * (1.0 - f), 0)
				_tube(rs, a0, a1, 0.018, 0.018, rope_c, 3)
				yy += 0.75
			# ovéns do mastaréu
			if square:
				for k in 3:
					var p0 := base + Vector3(side * mr * 4.5, h * 0.5, (k - 1) * mr * 2.0)
					_tube(rs, p0, top - Vector3(0, h * 0.05, mr * 1.3) + Vector3(side * mr * 0.6, 0, 0), 0.025, 0.025, rope_c, 3)
			# brandal (backstay) até o costado, atrás
			_tube(rs, top - Vector3(0, h * 0.04, 0), Vector3(side * (w + 0.5), ch_y, base.z + ch_len * 0.5 + 2.5), 0.03, 0.03, rope_c, 3)
		# estais
		if mi == lay["ts"].size() - 1:
			_tube(rs, top, jibboom_end, 0.05, 0.05, rope_c, 3)
			_tube(rs, top - Vector3(0, h * 0.25, 0), bowsprit_end, 0.05, 0.05, rope_c, 3)
			_tube(rs, mast_head, bow_p + Vector3(0, 0.5, 0), 0.06, 0.06, rope_c, 3)
		else:
			var nt: float = lay["ts"][mi + 1]
			var nb := Vector3(0.0, deck_height(nt, d), t_to_z(nt, length))
			_tube(rs, top, nb + Vector3(0, lay["heights"][mi + 1] * 0.55, 0), 0.04, 0.04, rope_c, 3)
			_tube(rs, mast_head, nb + Vector3(0, 1.2, 0), 0.05, 0.05, rope_c, 3)
		if mi == 0:
			_tube(rs, top, stern_top, 0.05, 0.05, rope_c, 3)
		# malagueta (cunhos) ao pé do mastro
		_tube(rs, base + Vector3(0, 0.0, 0), base + Vector3(0, 0.5, 0), mr * 2.2, mr * 2.2, wood_c, 8)
	# amuradas: corrimão e balaústres
	for side in [1.0, -1.0]:
		var segs := 14
		for i in segs:
			var t0 := float(i) / segs
			var t1 := float(i + 1) / segs
			var y0 := deck_height(t0, d) + 1.05
			var y1 := deck_height(t1, d) + 1.05
			var a := Vector3(side * half_width(t0, beam) * 0.86, y0, t_to_z(t0, length) + rake_z(t0, y0, d))
			var b := Vector3(side * half_width(t1, beam) * 0.86, y1, t_to_z(t1, length) + rake_z(t1, y1, d))
			_tube(rs, a, b, 0.1, 0.1, Color(0.3, 0.2, 0.12), 4)
	# lado de dentro da amurada, pintado de vermelho como nos navios da época
	var inner_c := Color(0.48, 0.11, 0.07)
	var nseg := 24
	for side in [1.0, -1.0]:
		for i in nseg:
			var t0 := float(i) / nseg
			var t1 := float(i + 1) / nseg
			var tm := (t0 + t1) * 0.5
			var dm := deck_height(tm, d)
			var a0 := Vector3(side * half_width(t0, beam) * 0.84, 0.0, t_to_z(t0, length) + rake_z(t0, dm, d))
			var a1 := Vector3(side * half_width(t1, beam) * 0.84, 0.0, t_to_z(t1, length) + rake_z(t1, dm, d))
			var seg_v := a1 - a0
			var seg_len := seg_v.length()
			if seg_len < 0.05:
				continue
			var b := Basis(Vector3.UP, atan2(seg_v.x, seg_v.z))
			var mid := (a0 + a1) * 0.5 + Vector3(0, dm + 0.5, 0)
			_box(rs, Transform3D(b, mid), Vector3(0.06, 1.0, seg_len + 0.05), inner_c)
	# castelo de popa: corrimão transversal com balaústres
	var castle: float = d["castle"]
	if castle > 0.3:
		var tq := 0.235
		var qy := deck_height(0.2, d)
		var qw := half_width(tq, beam) * 0.86
		var qz := t_to_z(tq, length)
		_tube(rs, Vector3(-qw, qy + 1.0, qz), Vector3(qw, qy + 1.0, qz), 0.08, 0.08, Color(0.3, 0.2, 0.12), 4)
		var nb := int(qw * 2.0 / 0.45)
		for k in nb:
			var x := lerpf(-qw, qw, (k + 0.5) / nb)
			_tube(rs, Vector3(x, qy, qz), Vector3(x, qy + 1.0, qz), 0.05, 0.05, Color(0.75, 0.68, 0.55), 4)
	# canhões, carretas e portinholas
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
			var xf := Transform3D(Basis(), Vector3(side * (w * 0.985 + 0.03), y, z))
			_box(rs, xf, Vector3(0.08, 0.8, 0.85), iron_c)
			# tampa da portinhola aberta (vermelha por dentro)
			if decks == 2:
				var lid := Transform3D(Basis(Vector3(0, 0, 1), side * 0.9), Vector3(side * (w + 0.3), y + 0.62, z))
				_box(rs, lid, Vector3(0.07, 0.8, 0.85), Color(0.55, 0.12, 0.08))
			var outer := Vector3(side * (w + 0.75), y, z)
			_tube(rs, Vector3(side * (w * 0.7), y, z), outer, 0.21, 0.15, Color(0.1, 0.1, 0.1), 6)
			if decks == 1:
				_box(rs, Transform3D(Basis(), Vector3(side * (w * 0.62), dh + 0.25, z)), Vector3(1.1, 0.5, 0.7), wood_c)
	# objetos do convés
	var cap_t := 0.42
	var cap := Vector3(0.0, deck_height(cap_t, d), t_to_z(cap_t, length))
	_tube(rs, cap, cap + Vector3(0, 0.95, 0), 0.45, 0.35, wood_c, 10)
	for k in 4:
		var ang := k * PI * 0.25
		_tube(rs, cap + Vector3(cos(ang), 0, sin(ang)) * -1.3 + Vector3(0, 0.8, 0), cap + Vector3(cos(ang), 0, sin(ang)) * 1.3 + Vector3(0, 0.8, 0), 0.05, 0.05, wood_c, 4)
	for ht2 in [0.3, 0.56, 0.7]:
		var hp2 := Vector3(0.0, deck_height(ht2, d), t_to_z(ht2, length))
		_box(rs, Transform3D(Basis(), hp2 + Vector3(0, 0.18, 0)), Vector3(beam * 0.24, 0.36, beam * 0.2), Color(0.22, 0.15, 0.09))
		_box(rs, Transform3D(Basis(), hp2 + Vector3(0, 0.37, 0)), Vector3(beam * 0.2, 0.04, beam * 0.16), Color(0.12, 0.08, 0.05))
	if length > 19.0:
		var bt := 0.49
		var bp := Vector3(0.0, deck_height(bt, d) + 0.55, t_to_z(bt, length))
		Island._sphere(rs, bp, Vector3(beam * 0.15, 0.5, length * 0.08), Color(0.55, 0.42, 0.28), 8, 4)
	for k in 6:
		var bt2 := 0.84 + (k % 3) * 0.02
		var bw := half_width(bt2, beam) * 0.6 * (1.0 if k < 3 else -1.0)
		var bpos := Vector3(bw, deck_height(bt2, d), t_to_z(bt2, length))
		_tube(rs, bpos, bpos + Vector3(0, 0.9, 0), 0.32, 0.32, Color(0.4, 0.27, 0.15), 7)
	# timão do castelo de popa (pedestal) e bitácula
	var ht := 0.13
	var hp := Vector3(0.0, deck_height(ht, d), t_to_z(ht, length))
	_box(rs, Transform3D(Basis(), hp + Vector3(0, 0.55, 0)), Vector3(0.3, 1.1, 0.5), Color(0.3, 0.2, 0.12))
	_box(rs, Transform3D(Basis(), hp + Vector3(0, 0.5, -1.4)), Vector3(0.6, 1.0, 0.5), Color(0.3, 0.2, 0.12))
	_box(rs, Transform3D(Basis(), hp + Vector3(0, 1.05, -1.4)), Vector3(0.5, 0.12, 0.4), gold_c)
	# popa decorada: corrimão dourado e galerias laterais
	var sz0 := t_to_z(0.0, length) + rake_z(0.0, deck_height(0.0, d), d)
	var sdh0 := deck_height(0.0, d)
	var sw0 := half_width(0.0, beam)
	_box(rs, Transform3D(Basis(), Vector3(0, sdh0 + 1.0, sz0 + 0.12)), Vector3(sw0 * 1.75, 0.35, 0.2), gold_c)
	_box(rs, Transform3D(Basis(), Vector3(0, sdh0 * 0.7, sz0 + 0.1)), Vector3(sw0 * 1.4, 1.0, 0.1), Color(0.18, 0.13, 0.08))
	_box(rs, Transform3D(Basis(), Vector3(0, sdh0 * 0.7 - 0.6, sz0 + 0.12)), Vector3(sw0 * 1.5, 0.15, 0.25), gold_c)
	if length > 30.0:
		for side in [1.0, -1.0]:
			var gt := 0.06
			var gw := half_width(gt, beam)
			var gp := Vector3(side * (gw + 0.25), deck_height(gt, d) * 0.72, t_to_z(gt, length))
			_box(rs, Transform3D(Basis(), gp), Vector3(0.6, 1.8, length * 0.07), Color(0.22, 0.15, 0.09))
			_box(rs, Transform3D(Basis(), gp + Vector3(0, 1.05, 0)), Vector3(0.7, 0.2, length * 0.075), gold_c)
	var rmesh := rs.commit(mesh)
	mesh.surface_set_material(1, _rig_mat)

	# ---- terceira superfície: janelas e lanternas (brilham)
	var gs := SurfaceTool.new()
	gs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sz := t_to_z(0.0, length) + rake_z(0.0, deck_height(0.0, d) * 0.7, d) + 0.16
	var sdh := deck_height(0.0, d)
	var sw := half_width(0.0, beam)
	var wins := clampi(int(beam / 1.6), 2, 7)
	for i in wins:
		var x := lerpf(-sw * 0.6, sw * 0.6, (i + 0.5) / wins)
		_box(gs, Transform3D(Basis(), Vector3(x, sdh * 0.7, sz)), Vector3(0.5, 0.6, 0.06), Color(1, 1, 1))
	_box(gs, Transform3D(Basis(), Vector3(0.0, sdh + 2.0, sz)), Vector3(0.4, 0.6, 0.4), Color(1, 1, 1))
	for side in [1.0, -1.0]:
		_box(gs, Transform3D(Basis(), Vector3(side * sw * 0.8, sdh + 1.8, sz)), Vector3(0.3, 0.45, 0.3), Color(1, 1, 1))
	if length > 30.0:
		for side in [1.0, -1.0]:
			var gt := 0.06
			var gp := Vector3(side * (half_width(gt, beam) + 0.56), deck_height(gt, d) * 0.72, t_to_z(gt, length))
			for k in 2:
				_box(gs, Transform3D(Basis(), gp + Vector3(0, 0.1, (k - 0.5) * length * 0.03)), Vector3(0.06, 0.6, 0.5), Color(1, 1, 1))
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
			var spanker: bool = lay["ts"].size() == 3 and mi == 0
			if spanker:
				var fa := Node3D.new()
				fa.position = base
				root.add_child(fa)
				fore_aft.append(fa)
				var boom_y := 2.4
				var gaff_y := h * 0.5
				var sl := length * 0.26
				var sp_sail := MeshInstance3D.new()
				sp_sail.mesh = sail_mesh(sl, gaff_y - boom_y, 0.75)
				var spm := ShaderMaterial.new()
				spm.shader = _sail_shader
				spm.set_shader_parameter("sail_color", sail_col)
				spm.set_shader_parameter("sail_w", sl)
				spm.set_shader_parameter("sail_h", gaff_y - boom_y)
				spm.set_shader_parameter("depth", sl * 0.08)
				sp_sail.material_override = spm
				sp_sail.rotation = Vector3(0, PI * 0.5, 0)
				sp_sail.position = Vector3(0, gaff_y, sl * 0.5 + mr)
				fa.add_child(sp_sail)
				sails.append(spm)
				for yy2 in [boom_y, gaff_y]:
					var spar2 := MeshInstance3D.new()
					var cm2 := CylinderMesh.new()
					cm2.top_radius = mr * 0.3
					cm2.bottom_radius = mr * 0.4
					cm2.height = sl
					cm2.radial_segments = 6
					cm2.rings = 1
					var ym2 := StandardMaterial3D.new()
					ym2.albedo_color = mast_c.linear_to_srgb()
					cm2.material = ym2
					spar2.mesh = cm2
					spar2.rotation = Vector3(PI * 0.5, 0, 0)
					spar2.position = Vector3(0, yy2, sl * 0.5 + mr)
					fa.add_child(spar2)
			for li in levels.size():
				if spanker and li == 0:
					continue
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
				yard.position = Vector3(0, top_y, -mr * (1.3 if li > 0 else 0.0) - mr * 0.7)
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
				sail.position = Vector3(0, top_y - 0.2, -mr * (1.3 if li > 0 else 0.0) - mr * 1.6)
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
