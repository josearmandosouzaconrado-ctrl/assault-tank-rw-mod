class_name Attire
extends RefCounted
## Roupas do início do século XVIII montadas sobre os personagens realistas, presas aos ossos:
## abas da casaca (justaucorps), punhos e lapelas na cor das "vistas" do regimento, talabarte,
## cinturão, faixa de oficial, gravata, saia comprida, avental, calções largos de marinheiro e cabelo.
## As peças são desenhadas no espaço do personagem em T-pose, sem escala (frente = -Z, direita = +X),
## medidas nos modelos "Universal Base Characters" (homem 1,81 m, mulher 1,77 m).

static var _mat: StandardMaterial3D
static var _hair_mat: StandardMaterial3D
static var _cache := {}

## Uniformes (casaca, vistas, colete, calção) por nação, conforme a pesquisa (PESQUISA.md).
const UNIFORMS := {
	0: {"coat": Color(0.62, 0.08, 0.07), "facing": Color(0.1, 0.15, 0.42), "waist": Color(0.1, 0.15, 0.42), "breeches": Color(0.2, 0.22, 0.3)},
	1: {"coat": Color(0.86, 0.84, 0.78), "facing": Color(0.62, 0.08, 0.08), "waist": Color(0.62, 0.08, 0.08), "breeches": Color(0.84, 0.82, 0.76)},
	2: {"coat": Color(0.84, 0.82, 0.76), "facing": Color(0.12, 0.2, 0.52), "waist": Color(0.12, 0.2, 0.52), "breeches": Color(0.82, 0.8, 0.74)},
	3: {"coat": Color(0.14, 0.22, 0.44), "facing": Color(0.58, 0.12, 0.08), "waist": Color(0.58, 0.12, 0.08), "breeches": Color(0.14, 0.22, 0.44)},
	4: {"coat": Color(0.16, 0.32, 0.18), "facing": Color(0.86, 0.85, 0.8), "waist": Color(0.86, 0.85, 0.8), "breeches": Color(0.16, 0.32, 0.18)},
	6: {"coat": Color(0.36, 0.08, 0.3), "facing": Color(0.82, 0.62, 0.2), "waist": Color(0.82, 0.62, 0.2), "breeches": Color(0.2, 0.08, 0.18)},
}
const BUFF := Color(0.86, 0.78, 0.58)
const BRASS := Color(0.85, 0.66, 0.26)

## Medidas do corpo (homem / mulher).
const BODY := {
	false: {"skull": Vector3(0, 1.715, 0.006), "skull_r": Vector3(0.094, 0.098, 0.104), "top": 1.81,
		"waist_y": 1.0, "waist_r": Vector2(0.186, 0.147), "waist_z": 0.027,
		"lapel": [Vector2(1.42, -0.128), Vector2(1.35, -0.146), Vector2(1.25, -0.146), Vector2(1.12, -0.132), Vector2(1.02, -0.116)],
		"forearm": Vector3(0.0, 1.445, 0.077), "wrist": 0.70, "fore_r": 0.06, "leg_x": 0.105, "neck": Vector3(0, 1.45, -0.088)},
	true: {"skull": Vector3(0, 1.67, 0.008), "skull_r": Vector3(0.09, 0.097, 0.104), "top": 1.767,
		"waist_y": 1.0, "waist_r": Vector2(0.2, 0.145), "waist_z": 0.032,
		"lapel": [Vector2(1.40, -0.112), Vector2(1.33, -0.162), Vector2(1.26, -0.162), Vector2(1.19, -0.13), Vector2(1.1, -0.112), Vector2(1.02, -0.106)],
		"forearm": Vector3(0.0, 1.416, 0.05), "wrist": 0.64, "fore_r": 0.05, "leg_x": 0.11, "neck": Vector3(0, 1.43, -0.05)},
}


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.roughness = 0.88
	return _mat


static func hair_material() -> StandardMaterial3D:
	if _hair_mat == null:
		_hair_mat = StandardMaterial3D.new()
		_hair_mat.vertex_color_use_as_albedo = true
		_hair_mat.vertex_color_is_srgb = true
		_hair_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_hair_mat.roughness = 0.55
		_hair_mat.specular = 0.6
	return _hair_mat


## Transformação de repouso de um osso no espaço do personagem sem escala (frente = -Z).
static func _rest_char(p: Dictionary, bone: String) -> Array:
	var model: Node3D = p["model"]
	var sk: Skeleton3D = p["sk"]
	var t := Transform3D()
	var n: Node = sk
	while n != model and n != null:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	var bi := sk.find_bone(bone)
	if bi < 0:
		return [sk, bi, Transform3D()]
	return [sk, bi, Transform3D(Basis(Vector3.UP, PI)) * t * sk.get_bone_global_rest(bi)]


## Prende uma malha desenhada no espaço do personagem (T-pose) a um osso.
static func wear(p: Dictionary, bone: String, m: Mesh, mat: Material = null, xf := Transform3D()) -> MeshInstance3D:
	var r := _rest_char(p, bone)
	var sk: Skeleton3D = r[0]
	if r[1] < 0:
		return null
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	sk.add_child(ba)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat if mat != null else material()
	mi.transform = (r[2] as Transform3D).affine_inverse() * xf
	mi.visibility_range_end = 160.0
	ba.add_child(mi)
	return mi


static func _key(parts: Array) -> String:
	var s := ""
	for x in parts:
		s += (x.to_html() if x is Color else str(x)) + "|"
	return s


# ---------------------------------------------------------------- malhas
static func _ring(st: SurfaceTool, y0: float, y1: float, r0: Vector2, r1: Vector2, cz: float, c: Color, gaps := [], seg := 22, cz1 := INF) -> void:
	if cz1 == INF:
		cz1 = cz
	st.set_color(c)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var am := (a0 + a1) * 0.5
		var skip := false
		for g in gaps:
			if absf(angle_difference(am, g[0])) < g[1]:
				skip = true
		if skip:
			continue
		# ângulo 0 = frente (-Z)
		var p00 := Vector3(sin(a0) * r0.x, y0, cz - cos(a0) * r0.y)
		var p01 := Vector3(sin(a1) * r0.x, y0, cz - cos(a1) * r0.y)
		var p10 := Vector3(sin(a0) * r1.x, y1, cz1 - cos(a0) * r1.y)
		var p11 := Vector3(sin(a1) * r1.x, y1, cz1 - cos(a1) * r1.y)
		var n := Vector3(sin(am), 0.2, -cos(am)).normalized()
		st.set_normal(n)
		for v in [p00, p10, p11, p00, p11, p01]:
			st.add_vertex(v)


static func _strip(st: SurfaceTool, a: Vector3, b: Vector3, w: float, nrm: Vector3, c: Color) -> void:
	var side := (b - a).cross(nrm).normalized() * w * 0.5
	st.set_color(c)
	st.set_normal(nrm)
	for v in [a - side, b - side, b + side, a - side, b + side, a + side]:
		st.add_vertex(v)


## Faixa que segue uma linha de pontos (lapela, talabarte).
static func _path(st: SurfaceTool, pts: Array, w: float, nrm: Vector3, c: Color) -> void:
	for i in pts.size() - 1:
		_strip(st, pts[i], pts[i + 1], w, nrm, c)


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_normal(Vector3.UP)
	return st


static func _b(female: bool) -> Dictionary:
	return BODY[female]


## Abas da casaca até o joelho, abertas na frente e com fenda atrás (presas à bacia).
static func coat_skirt(c: Color, facing: Color, female := false) -> Mesh:
	var k := "skirt" + _key([c, facing, female])
	if _cache.has(k):
		return _cache[k]
	var b := _b(female)
	var st := _begin()
	var wr: Vector2 = b["waist_r"] + Vector2(0.016, 0.012)
	var cz: float = b["waist_z"]
	var y0: float = b["waist_y"] + 0.02
	var gaps := [[0.0, 0.5], [PI, 0.12]]
	var mid := wr + Vector2(0.07, 0.05)
	var bot := wr + Vector2(0.16, 0.13)
	_ring(st, y0, 0.86, wr, mid, cz, c, gaps, 24, cz + 0.008)
	_ring(st, 0.86, 0.5, mid, bot, cz + 0.008, c, gaps, 24, cz + 0.025)
	# barra virada (forro na cor das vistas) e bolsos com aba
	_ring(st, 0.535, 0.5, bot - Vector2(0.008, 0.007), bot + Vector2(0.006, 0.005), cz + 0.024, facing, gaps, 24, cz + 0.025)
	var pr := wr.lerp(mid, 0.7) + Vector2(0.004, 0.004)
	for sx in [-1.0, 1.0]:
		var a: float = sx * 1.05
		var pos := Vector3(sin(a) * pr.x, 0.8, cz + 0.006 - cos(a) * pr.y)
		var tan := Vector2(cos(a) * pr.x, sin(a) * pr.y)
		var bs := Basis(Vector3.UP, atan2(-tan.y, tan.x))
		ShipBuilder._box(st, Transform3D(bs, pos), Vector3(0.15, 0.05, 0.01), c.darkened(0.15))
		for i in 3:
			Island._sphere(st, pos + bs.x * ((i - 1) * 0.045) + Vector3(0, -0.02, 0) + bs.z * -0.008, Vector3.ONE * 0.008, BRASS, 5, 3)
	_cache[k] = st.commit()
	return _cache[k]


## Punho largo virado (vistas) no antebraço.
static func cuff(c: Color, side: float, female := false) -> Mesh:
	var k := "cuff" + _key([c, side, female])
	if _cache.has(k):
		return _cache[k]
	var b := _b(female)
	var st := _begin()
	var fa: Vector3 = b["forearm"]
	var w: float = b["wrist"]
	var r: float = b["fore_r"]
	ShipBuilder._tube(st, Vector3(side * (w - 0.14), fa.y, fa.z), Vector3(side * (w - 0.01), fa.y + 0.004, fa.z), r, r + 0.012, c, 12)
	ShipBuilder._tube(st, Vector3(side * (w - 0.01), fa.y + 0.004, fa.z), Vector3(side * w, fa.y + 0.004, fa.z), r + 0.012, r * 0.7, c.darkened(0.2), 12)
	for i in 3:
		Island._sphere(st, Vector3(side * (w - 0.12 + i * 0.04), fa.y + r + 0.008, fa.z - 0.01), Vector3.ONE * 0.008, BRASS, 5, 3)
	_cache[k] = st.commit()
	return _cache[k]


## Lapelas, botões, gravata, talabarte, patrona e faixa (presos ao tronco).
static func chest(facing: Variant, belts: bool, cravat: bool, sash: Variant, female := false) -> Mesh:
	var k := "chest" + _key([facing if facing != null else "n", belts, cravat, sash if sash != null else "n", female])
	if _cache.has(k):
		return _cache[k]
	var b := _b(female)
	var st := _begin()
	if facing != null:
		for sx in [-1.0, 1.0]:
			var pts := []
			var i := 0
			for q in b["lapel"]:
				var t: float = float(i) / (b["lapel"].size() - 1)
				pts.append(Vector3(sx * lerpf(0.075, 0.068, t), q.x, q.y))
				i += 1
			_path(st, pts, 0.055, Vector3(0, 0, -1), facing)
			for j in pts.size():
				var bp: Vector3 = pts[j]
				Island._sphere(st, bp + Vector3(sx * 0.012, -0.03, -0.006), Vector3.ONE * 0.0095, BRASS, 5, 3)
	if cravat:
		var nk: Vector3 = b["neck"]
		ShipBuilder._box(st, Transform3D(Basis(Vector3.RIGHT, 0.35), nk), Vector3(0.085, 0.07, 0.03), Color(0.95, 0.94, 0.9))
		ShipBuilder._box(st, Transform3D(Basis(Vector3.RIGHT, 0.2), nk + Vector3(0, -0.075, -0.035)), Vector3(0.05, 0.1, 0.012), Color(0.95, 0.94, 0.9))
	if belts:
		# talabarte do ombro esquerdo ao quadril direito (frente e costas) e patrona de couro
		_path(st, [Vector3(-0.13, 1.43, -0.118), Vector3(-0.06, 1.31, -0.145), Vector3(0.04, 1.15, -0.133), Vector3(0.15, 0.98, -0.117)], 0.055, Vector3(0, 0, -1), BUFF)
		_path(st, [Vector3(-0.13, 1.43, 0.168), Vector3(0.0, 1.22, 0.172), Vector3(0.15, 0.98, 0.165)], 0.055, Vector3(0, 0, 1), BUFF)
		_path(st, [Vector3(-0.13, 1.43, -0.118), Vector3(-0.15, 1.47, 0.03), Vector3(-0.13, 1.43, 0.168)], 0.055, Vector3.UP, BUFF)
		ShipBuilder._box(st, Transform3D(Basis(), Vector3(0.21, 0.97, 0.03)), Vector3(0.055, 0.12, 0.17), Color(0.13, 0.08, 0.05))
		ShipBuilder._box(st, Transform3D(Basis(), Vector3(0.24, 0.99, 0.03)), Vector3(0.008, 0.05, 0.06), BRASS)
	if sash != null:
		var wr: Vector2 = b["waist_r"] + Vector2(0.008, 0.006)
		_ring(st, b["waist_y"] + 0.03, b["waist_y"] - 0.05, wr, wr + Vector2(0.006, 0.006), b["waist_z"], sash, [], 20)
		ShipBuilder._box(st, Transform3D(Basis(Vector3(0, 0, 1), 0.2), Vector3(0.15, 0.88, -0.1)), Vector3(0.05, 0.17, 0.02), sash)
	_cache[k] = st.commit()
	return _cache[k]


## Cinturão na cintura com fivela de latão.
static func waist_belt(c: Color, female := false) -> Mesh:
	var k := "belt" + _key([c, female])
	if _cache.has(k):
		return _cache[k]
	var b := _b(female)
	var st := _begin()
	var wr: Vector2 = b["waist_r"] + Vector2(0.004, 0.004)
	var y: float = b["waist_y"] - 0.02
	_ring(st, y + 0.025, y - 0.025, wr, wr + Vector2(0.004, 0.004), b["waist_z"], c, [], 20)
	ShipBuilder._box(st, Transform3D(Basis(), Vector3(0, y, b["waist_z"] - wr.y - 0.006)), Vector3(0.055, 0.05, 0.01), BRASS)
	_cache[k] = st.commit()
	return _cache[k]


## Saia comprida (anágua) até o tornozelo, com avental opcional.
static func petticoat(c: Color, apron: bool, female := true) -> Mesh:
	var k := "pet" + _key([c, apron, female])
	if _cache.has(k):
		return _cache[k]
	var b := _b(female)
	var st := _begin()
	var wr: Vector2 = b["waist_r"] + Vector2(0.015, 0.012)
	var cz: float = b["waist_z"]
	_ring(st, b["waist_y"] + 0.03, 0.75, wr, wr + Vector2(0.06, 0.06), cz, c, [], 26)
	_ring(st, 0.75, 0.04, wr + Vector2(0.06, 0.06), wr + Vector2(0.17, 0.16), cz, c, [], 26, cz + 0.02)
	_ring(st, 0.12, 0.04, wr + Vector2(0.155, 0.145), wr + Vector2(0.172, 0.162), cz + 0.018, c.darkened(0.2), [], 26, cz + 0.02)
	if apron:
		var col := Color(0.93, 0.91, 0.85)
		_path(st, [Vector3(0, b["waist_y"], cz - wr.y - 0.012), Vector3(0, 0.75, cz - wr.y - 0.072), Vector3(0, 0.3, cz - wr.y - 0.14)], 0.3, Vector3(0, 0.12, -1).normalized(), col)
	_cache[k] = st.commit()
	return _cache[k]


## Calções largos de marinheiro ("slops"), um por perna.
static func slops(c: Color, side: float, female := false) -> Mesh:
	var k := "slops" + _key([c, side, female])
	if _cache.has(k):
		return _cache[k]
	var b := _b(female)
	var st := _begin()
	var lx: float = b["leg_x"]
	ShipBuilder._tube(st, Vector3(side * lx, 0.96, 0.027), Vector3(side * (lx + 0.01), 0.47, 0.05), 0.125, 0.115, c, 14)
	ShipBuilder._tube(st, Vector3(side * (lx + 0.01), 0.47, 0.05), Vector3(side * (lx + 0.01), 0.44, 0.05), 0.115, 0.075, c.darkened(0.15), 14)
	_cache[k] = st.commit()
	return _cache[k]


## Cabelo: 0 curto, 1 rabo-de-cavalo com fita (queue), 2 coque, 3 solto até os ombros.
static func hair(style: int, c: Color, female: bool) -> Mesh:
	var k := "hair" + _key([style, c, female])
	if _cache.has(k):
		return _cache[k]
	var b := _b(female)
	var ctr: Vector3 = b["skull"]
	var rad: Vector3 = b["skull_r"] + Vector3.ONE * 0.008
	var st := _begin()
	st.set_color(c)
	_cap(st, ctr, rad, 0.55, -0.25, -0.75 - (0.35 if style == 3 else 0.0))
	var nape := ctr + Vector3(0, -0.06, rad.z - 0.01)
	match style:
		1:
			ShipBuilder._tube(st, nape, nape + Vector3(0, -0.17, 0.035), 0.024, 0.01, c, 8)
			var bow := nape + Vector3(0, -0.015, 0.012)
			ShipBuilder._box(st, Transform3D(Basis(Vector3.BACK, 0.5), bow + Vector3(-0.025, 0, 0.02)), Vector3(0.045, 0.02, 0.01), Color(0.05, 0.05, 0.05))
			ShipBuilder._box(st, Transform3D(Basis(Vector3.BACK, -0.5), bow + Vector3(0.025, 0, 0.02)), Vector3(0.045, 0.02, 0.01), Color(0.05, 0.05, 0.05))
		2:
			st.set_color(c)
			Island._sphere(st, ctr + Vector3(0, 0.03, rad.z + 0.015), Vector3(0.05, 0.045, 0.04), c, 8, 5)
		3:
			# cabelo solto caindo atrás até os ombros (uma "cortina" que abre um pouco embaixo)
			var segs := 14
			var y_top := ctr.y - 0.01
			for i in segs:
				var a0 := PI * 0.5 + PI * float(i) / segs + 0.15
				var a1 := PI * 0.5 + PI * float(i + 1) / segs + 0.15
				a0 = minf(a0, PI * 1.5 - 0.15)
				a1 = minf(a1, PI * 1.5 - 0.15)
				var rows := [[y_top, 1.0], [ctr.y - 0.1, 1.04], [ctr.y - 0.2, 1.12], [ctr.y - 0.26, 1.2]]
				for r in rows.size() - 1:
					var ya: float = rows[r][0]
					var yb: float = rows[r + 1][0]
					var ka: float = rows[r][1]
					var kb: float = rows[r + 1][1]
					var p00 := Vector3(sin(a0) * rad.x * ka, ya, ctr.z - cos(a0) * rad.z * ka)
					var p01 := Vector3(sin(a1) * rad.x * ka, ya, ctr.z - cos(a1) * rad.z * ka)
					var p10 := Vector3(sin(a0) * rad.x * kb, yb, ctr.z - cos(a0) * rad.z * kb)
					var p11 := Vector3(sin(a1) * rad.x * kb, yb, ctr.z - cos(a1) * rad.z * kb)
					var n := Vector3(sin(a0), 0.0, -cos(a0))
					st.set_normal(n)
					for v in [p00, p10, p11, p00, p11, p01]:
						st.add_vertex(v)
	_cache[k] = st.commit()
	return _cache[k]


## Calota elíptica sobre o crânio que termina numa linha (seno da latitude) na frente, dos lados e atrás.
static func _cap(st: SurfaceTool, ctr: Vector3, rad: Vector3, front_line: float, side_line: float, back_line: float, cols := 20, rows := 7) -> void:
	var grid := []
	for i in cols + 1:
		var az := TAU * i / cols   # 0 = frente
		var front := maxf(0.0, cos(az))
		var back := maxf(0.0, -cos(az))
		var line := front_line * front + side_line * (1.0 - front - back) + back_line * back
		var lat_min := asin(clampf(line, -0.95, 0.95))
		var col := []
		for j in rows + 1:
			var lat := lerpf(PI * 0.5, lat_min, float(j) / rows)
			col.append(Vector3(sin(az) * cos(lat), sin(lat), -cos(az) * cos(lat)))
		grid.append(col)
	for i in cols:
		for j in rows:
			var q := [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
			for idx in [0, 1, 2, 0, 2, 3]:
				var u: Vector3 = q[idx]
				st.set_normal(u)
				st.add_vertex(ctr + u * rad)


## Lenço de pirata amarrado na nuca, com as pontas soltas.
static func bandana(c: Color, female := false) -> Mesh:
	var k := "band" + _key([c, female])
	if _cache.has(k):
		return _cache[k]
	var b := _b(female)
	var ctr: Vector3 = b["skull"]
	var rad: Vector3 = b["skull_r"] + Vector3.ONE * 0.017
	var st := _begin()
	st.set_color(c)
	_cap(st, ctr, rad, 0.42, -0.05, -0.45)
	var knot := ctr + Vector3(0, -0.035, rad.z - 0.005)
	Island._sphere(st, knot, Vector3(0.03, 0.025, 0.022), c.darkened(0.1), 6, 4)
	ShipBuilder._tube(st, knot, knot + Vector3(-0.02, -0.13, 0.03), 0.022, 0.006, c, 5)
	ShipBuilder._tube(st, knot, knot + Vector3(0.025, -0.11, 0.035), 0.02, 0.006, c, 5)
	_cache[k] = st.commit()
	return _cache[k]


## Touca de linho (coif) das mulheres.
static func coif(female := true) -> Mesh:
	var k := "coif" + _key([female])
	if _cache.has(k):
		return _cache[k]
	var b := _b(female)
	var ctr: Vector3 = b["skull"] + Vector3(0, 0.008, 0.012)
	var rad: Vector3 = b["skull_r"] + Vector3(0.022, 0.03, 0.03)
	var white := Color(0.95, 0.94, 0.9)
	var st := _begin()
	st.set_color(white)
	_cap(st, ctr, rad, 0.5, -0.3, -0.85)
	# babado na borda da frente
	for i in 12:
		var az0 := -1.2 + 2.4 * i / 12.0
		var az1 := -1.2 + 2.4 * (i + 1) / 12.0
		var l := asin(0.5)
		var p0 := ctr + Vector3(sin(az0) * cos(l), sin(l), -cos(az0) * cos(l)) * (rad + Vector3.ONE * 0.004)
		var p1 := ctr + Vector3(sin(az1) * cos(l), sin(l), -cos(az1) * cos(l)) * (rad + Vector3.ONE * 0.004)
		ShipBuilder._tube(st, p0, p1, 0.012, 0.012, white, 5)
	_cache[k] = st.commit()
	return _cache[k]


# ---------------------------------------------------------------- aplicar um estilo
## style: "skirt"/"facing" (Color), "belts", "cravat" (bool), "sash", "petticoat", "slops" (Color), "apron" (bool), "belt" (Color)
static func apply(p: Dictionary, style: Dictionary) -> void:
	var f: bool = p.get("female", false)
	var facing: Variant = style.get("facing", null)
	if style.has("skirt"):
		wear(p, "pelvis", coat_skirt(style["skirt"], facing if facing != null else (style["skirt"] as Color).darkened(0.25), f))
	if facing != null:
		wear(p, "lowerarm_l", cuff(facing, -1.0, f))
		wear(p, "lowerarm_r", cuff(facing, 1.0, f))
	if facing != null or style.get("belts", false) or style.get("cravat", false) or style.has("sash"):
		wear(p, "spine_03", chest(style.get("lapels", facing), style.get("belts", false), style.get("cravat", false), style.get("sash", null), f))
	if style.has("belt"):
		wear(p, "spine_01", waist_belt(style["belt"], f))
	if style.has("petticoat"):
		wear(p, "pelvis", petticoat(style["petticoat"], style.get("apron", false), f))
	if style.has("slops"):
		wear(p, "thigh_l", slops(style["slops"], -1.0, f))
		wear(p, "thigh_r", slops(style["slops"], 1.0, f))
