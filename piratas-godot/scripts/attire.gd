class_name Attire
extends RefCounted
## Roupas do início do século XVIII montadas sobre os personagens, presas aos ossos:
## abas da casaca (justaucorps), punhos e lapelas na cor das "vistas" do regimento,
## talabarte, cinturão, faixa de oficial, gravata, saia comprida, avental e calções largos de marinheiro.
## As peças são desenhadas no espaço do personagem em T-pose (frente = -Z) e herdam o movimento do osso.

static var _mat: StandardMaterial3D
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


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.roughness = 0.9
	return _mat


## Transformação de repouso de um osso no espaço do personagem (sem depender da árvore de cena).
static func _rest_char(p: Dictionary, bone: String) -> Array:
	var root: Node3D = p["root"]
	var sk: Skeleton3D = p["model"].find_children("*", "Skeleton3D", true, false)[0]
	var t := Transform3D()
	var n: Node = sk
	while n != root and n != null:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	var bi := sk.find_bone(bone)
	return [sk, bi, t * sk.get_bone_global_rest(bi)]


## Prende uma malha desenhada no espaço do personagem (T-pose) a um osso.
static func wear(p: Dictionary, bone: String, m: Mesh) -> void:
	var r := _rest_char(p, bone)
	var sk: Skeleton3D = r[0]
	if r[1] < 0:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	sk.add_child(ba)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = material()
	mi.transform = (r[2] as Transform3D).affine_inverse()
	ba.add_child(mi)


static func _key(parts: Array) -> String:
	var s := ""
	for x in parts:
		s += (x.to_html() if x is Color else str(x)) + "|"
	return s


# ---------------------------------------------------------------- malhas
static func _ring(st: SurfaceTool, y0: float, y1: float, r0: Vector2, r1: Vector2, cz: float, c: Color, gaps := [], seg := 22) -> void:
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
		var p10 := Vector3(sin(a0) * r1.x, y1, cz - cos(a0) * r1.y)
		var p11 := Vector3(sin(a1) * r1.x, y1, cz - cos(a1) * r1.y)
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


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_normal(Vector3.UP)
	return st


## Abas da casaca até o joelho, abertas na frente e com fenda atrás (presas ao quadril).
static func coat_skirt(c: Color, facing: Color) -> Mesh:
	var k := "skirt" + _key([c, facing])
	if _cache.has(k):
		return _cache[k]
	var st := _begin()
	_ring(st, 0.97, 0.5, Vector2(0.19, 0.15), Vector2(0.27, 0.22), 0.0, c, [[0.0, 0.42], [PI, 0.18]])
	# barra virada (forro na cor das vistas) na borda de baixo
	_ring(st, 0.53, 0.5, Vector2(0.264, 0.215), Vector2(0.272, 0.222), 0.0, facing, [[0.0, 0.42], [PI, 0.18]])
	_cache[k] = st.commit()
	return _cache[k]


## Punho largo virado (vistas) no antebraço.
static func cuff(c: Color, side: float) -> Mesh:
	var k := "cuff" + _key([c, side])
	if _cache.has(k):
		return _cache[k]
	var st := _begin()
	ShipBuilder._tube(st, Vector3(side * 0.58, 1.385, 0.03), Vector3(side * 0.7, 1.39, 0.03), 0.062, 0.072, c, 10)
	_cache[k] = st.commit()
	return _cache[k]


## Lapelas, botões, gravata, talabarte e cinturão (presos ao tronco).
static func chest(facing: Variant, belts: bool, cravat: bool, sash: Variant) -> Mesh:
	var k := "chest" + _key([facing if facing != null else "n", belts, cravat, sash if sash != null else "n"])
	if _cache.has(k):
		return _cache[k]
	var st := _begin()
	var fz := -0.118
	if facing != null:
		for sx in [-1.0, 1.0]:
			_strip(st, Vector3(sx * 0.062, 1.41, fz), Vector3(sx * 0.07, 1.02, fz - 0.004), 0.06, Vector3(0, 0, -1), facing)
		for i in 6:
			Island._sphere(st, Vector3(0.1, 1.38 - i * 0.065, fz - 0.006), Vector3.ONE * 0.011, Color(0.85, 0.68, 0.25), 5, 3)
			Island._sphere(st, Vector3(-0.1, 1.38 - i * 0.065, fz - 0.006), Vector3.ONE * 0.011, Color(0.85, 0.68, 0.25), 5, 3)
	if cravat:
		ShipBuilder._box(st, Transform3D(Basis(), Vector3(0, 1.44, -0.095)), Vector3(0.07, 0.07, 0.03), Color(0.95, 0.94, 0.9))
		ShipBuilder._box(st, Transform3D(Basis(), Vector3(0, 1.38, -0.115)), Vector3(0.045, 0.08, 0.02), Color(0.95, 0.94, 0.9))
	if belts:
		# talabarte do ombro esquerdo ao quadril direito (frente e costas)
		_strip(st, Vector3(-0.13, 1.43, -0.105), Vector3(0.15, 0.96, fz - 0.008), 0.055, Vector3(0, 0, -1), BUFF)
		_strip(st, Vector3(-0.13, 1.43, 0.12), Vector3(0.15, 0.96, 0.13), 0.055, Vector3(0, 0, 1), BUFF)
		ShipBuilder._box(st, Transform3D(Basis(), Vector3(0.17, 0.95, 0.06)), Vector3(0.05, 0.12, 0.16), Color(0.15, 0.1, 0.06))
	if sash != null:
		_ring(st, 1.02, 0.94, Vector2(0.165, 0.132), Vector2(0.168, 0.135), -0.005, sash, [], 18)
		ShipBuilder._box(st, Transform3D(Basis(Vector3(0, 0, 1), 0.2), Vector3(0.14, 0.86, -0.08)), Vector3(0.05, 0.16, 0.02), sash)
	_cache[k] = st.commit()
	return _cache[k]


## Cinturão na cintura (preso ao abdômen).
static func waist_belt(c: Color) -> Mesh:
	var k := "belt" + _key([c])
	if _cache.has(k):
		return _cache[k]
	var st := _begin()
	_ring(st, 0.96, 0.92, Vector2(0.168, 0.136), Vector2(0.17, 0.138), -0.005, c, [], 18)
	ShipBuilder._box(st, Transform3D(Basis(), Vector3(0, 0.94, -0.145)), Vector3(0.05, 0.045, 0.012), Color(0.8, 0.65, 0.25))
	_cache[k] = st.commit()
	return _cache[k]


## Saia comprida (anágua) até o tornozelo, com avental opcional.
static func petticoat(c: Color, apron: bool) -> Mesh:
	var k := "pet" + _key([c, apron])
	if _cache.has(k):
		return _cache[k]
	var st := _begin()
	_ring(st, 0.98, 0.05, Vector2(0.17, 0.14), Vector2(0.33, 0.29), 0.0, c, [], 24)
	if apron:
		var col := Color(0.93, 0.91, 0.85)
		var top := Vector3(0, 0.96, -0.15)
		var bot := Vector3(0, 0.36, -0.245)
		_strip(st, top, bot, 0.26, Vector3(0, 0.15, -1).normalized(), col)
	_cache[k] = st.commit()
	return _cache[k]


## Calções largos de marinheiro ("slops"), um por perna.
static func slops(c: Color, side: float) -> Mesh:
	var k := "slops" + _key([c, side])
	if _cache.has(k):
		return _cache[k]
	var st := _begin()
	ShipBuilder._tube(st, Vector3(side * 0.11, 0.84, -0.01), Vector3(side * 0.115, 0.42, -0.04), 0.1, 0.12, c, 12)
	_cache[k] = st.commit()
	return _cache[k]


# ---------------------------------------------------------------- aplicar um estilo
## style: "skirt"/"facing" (Color), "belts", "cravat" (bool), "sash", "petticoat", "slops" (Color), "apron" (bool), "belt" (Color)
static func apply(p: Dictionary, style: Dictionary) -> void:
	var facing: Variant = style.get("facing", null)
	if style.has("skirt"):
		wear(p, "Hips", coat_skirt(style["skirt"], facing if facing != null else (style["skirt"] as Color).darkened(0.25)))
	if facing != null:
		wear(p, "LowerArm.L", cuff(facing, -1.0))
		wear(p, "LowerArm.R", cuff(facing, 1.0))
	if facing != null or style.get("belts", false) or style.get("cravat", false) or style.has("sash"):
		wear(p, "Torso", chest(style.get("lapels", facing), style.get("belts", false), style.get("cravat", false), style.get("sash", null)))
	if style.has("belt"):
		wear(p, "Abdomen", waist_belt(style["belt"]))
	if style.has("petticoat"):
		wear(p, "Hips", petticoat(style["petticoat"], style.get("apron", false)))
	if style.has("slops"):
		wear(p, "UpperLeg.L", slops(style["slops"], -1.0))
		wear(p, "UpperLeg.R", slops(style["slops"], 1.0))
