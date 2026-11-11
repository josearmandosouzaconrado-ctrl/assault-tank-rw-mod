class_name PortSite
extends RefCounted
## Uma cidade portuária: cais, casas no estilo da nação, igreja, taverna, estábulo, forte e bandeira.

var idx := 0
var name := ""
var nation := 0
var seed_pos := Vector2.ZERO
var dir := Vector2.DOWN          # do continente para o mar
var coast_point := Vector2.ZERO
var dock_point := Vector2.ZERO   # água em frente ao cais
var town_center := Vector3.ZERO
var fort_pos := Vector3.ZERO
var stable_pos := Vector3.ZERO
var tavern_pos := Vector3.ZERO
var pier_end := Vector3.ZERO
var houses: Array[Vector2] = []
var blocks: Array[Vector3] = []   # obstáculos (x, z, raio) para quem anda a pé ou a cavalo
var flag_mat: ShaderMaterial
var fort_ruin: Node3D
var node: Node3D
var building := false
var land := -1                   # índice da massa de terra


func _init(i: int, d: Dictionary) -> void:
	idx = i
	name = d["name"]
	nation = d["nation"]
	seed_pos = d["pos"]
	dir = (d["dir"] as Vector2).normalized()


## Calcula posições (sem construir malhas). Usa só o relevo "cru" (sem o aplainamento das cidades).
func plan(w: World) -> void:
	var p := seed_pos
	# se o ponto inicial estiver no mar, anda para terra
	var guard := 0
	while w.raw_height(p.x, p.y) < 1.5 and guard < 300:
		p -= dir * 6.0
		guard += 1
	coast_point = _march_to_sea(w, p, dir)
	dock_point = coast_point + dir * 95.0
	var tc := coast_point - dir * 125.0
	town_center = Vector3(tc.x, 0.0, tc.y)
	var fdir := dir.rotated(0.6)
	var fc := _march_to_sea(w, tc, fdir) - fdir * 24.0
	fort_pos = Vector3(fc.x, 0.0, fc.y)
	var side := Vector2(-dir.y, dir.x)
	var sp := tc - side * 95.0 - dir * 40.0
	stable_pos = Vector3(sp.x, 0.0, sp.y)
	var tv := tc + side * 30.0 + dir * 35.0
	tavern_pos = Vector3(tv.x, 0.0, tv.y)
	var pe := coast_point + dir * 62.0
	pier_end = Vector3(pe.x, 1.65, pe.y)


## Depois que as cidades foram registradas no mundo (aplainamento), fixa as alturas.
func settle(w: World) -> void:
	town_center.y = w.terrain_height(town_center.x, town_center.z)
	fort_pos.y = maxf(w.terrain_height(fort_pos.x, fort_pos.z), 1.5)
	stable_pos.y = w.terrain_height(stable_pos.x, stable_pos.z)
	tavern_pos.y = w.terrain_height(tavern_pos.x, tavern_pos.z)
	var rng := RandomNumberGenerator.new()
	rng.seed = idx * 977 + 13
	var tc := Vector2(town_center.x, town_center.z)
	var tries := 0
	var count := 30 if Game.quality > 0 else 20
	houses.clear()
	while houses.size() < count and tries < 500:
		tries += 1
		var wp := tc + Vector2(rng.randf_range(-135, 135), rng.randf_range(-135, 135))
		var h := w.terrain_height(wp.x, wp.y)
		if h < 1.8 or h > 16.0:
			continue
		if wp.distance_to(tc) < 22.0 or wp.distance_to(Vector2(tavern_pos.x, tavern_pos.z)) < 16.0 or wp.distance_to(Vector2(stable_pos.x, stable_pos.z)) < 18.0:
			continue
		var ok := true
		for q in houses:
			if q.distance_to(wp) < 18.0:
				ok = false
				break
		if ok:
			houses.append(wp)
	# obstáculos: casas, igreja, torre, taverna, armazéns, forte
	blocks.clear()
	for hp in houses:
		blocks.append(Vector3(hp.x, hp.y, 5.6))
	var t2 := Vector2(town_center.x, town_center.z)
	for k in [17.0, 31.0]:
		var c: Vector2 = t2 - dir * k
		blocks.append(Vector3(c.x, c.y, 7.0))
	var tw := t2 - dir * 10.0
	blocks.append(Vector3(tw.x, tw.y, 4.2))
	blocks.append(Vector3(t2.x, t2.y, 2.4))
	blocks.append(Vector3(tavern_pos.x, tavern_pos.z, 7.0))
	blocks.append(Vector3(fort_pos.x, fort_pos.z, 24.0))
	var db := Basis(Vector3.UP, atan2(dir.x, dir.y))
	for k in 3:
		var wpos := Vector3(coast_point.x, 0, coast_point.y) + db * Vector3(-24 + k * 24, 0, -20)
		blocks.append(Vector3(wpos.x, wpos.z, 8.0))


## Altura do piso do cais (ou -INF fora dele).
func pier_height(x: float, z: float) -> float:
	var d := Vector2(x, z) - coast_point
	var lz := d.dot(dir)
	var lx := d.dot(Vector2(dir.y, -dir.x))
	if (lz > -10.0 and lz < 70.0 and absf(lx) < 3.6) or (lz > 61.5 and lz < 70.5 and absf(lx) < 11.2):
		return 1.65
	return -INF


func blocked(x: float, z: float) -> bool:
	for b in blocks:
		var dx := x - b.x
		var dz := z - b.y
		if dx * dx + dz * dz < b.z * b.z:
			return true
	return false


func _march_to_sea(w: World, from: Vector2, d: Vector2) -> Vector2:
	var q := from
	for k in 600:
		if w.raw_height(q.x, q.y) < -0.6:
			return q
		q += d * 5.0
	return q


func set_owner_flag(nat: int) -> void:
	if flag_mat:
		flag_mat.set_shader_parameter("flag_type", Game.NATIONS[nat]["flag"])


# --------------------------------------------------------------- construção (pode rodar numa thread)
const M := 3.0    # todas as casas usam o mesmo módulo de 3 m (largura, altura e fundo)


## Casa montada com peças da Kenney: nx × nz módulos de 3 m, 1 a 3 andares, telhado de duas águas.
func _house_k(mg: Assets.Merger, mt: Material, origin: Vector3, ang: float, nx: int, nz: int, floors: int,
		rng: RandomNumberGenerator, wood_upper: bool, m := M, round_windows := false) -> void:
	var base := Transform3D(Basis(Vector3.UP, ang).scaled(Vector3.ONE * m), origin)
	var door_cell := nx / 2
	for f in floors:
		var wood := wood_upper and f > 0
		var plain := "wall-wood" if wood else "wall"
		var window := "wall-window-round" if round_windows else ("wall-wood-window-shutters" if wood else "wall-window-shutters")
		var small := "wall-wood-window-small" if wood else "wall-window-small"
		for cx in nx:
			for cz in nz:
				var c := Vector3(cx - (nx - 1) * 0.5, f, cz - (nz - 1) * 0.5)
				if cz == nz - 1:
					var front := window
					if f == 0 and cx == door_cell:
						front = "wall-door"
					mg.add(Assets.town(front), base * Transform3D(Basis(Vector3.UP, -PI * 0.5), c), mt)
				if cz == 0:
					mg.add(Assets.town(window if rng.randf() < 0.6 else plain), base * Transform3D(Basis(Vector3.UP, PI * 0.5), c), mt)
				if cx == nx - 1:
					mg.add(Assets.town(small if rng.randf() < 0.5 else plain), base * Transform3D(Basis(), c), mt)
				if cx == 0:
					mg.add(Assets.town(small if rng.randf() < 0.5 else plain), base * Transform3D(Basis(Vector3.UP, PI), c), mt)
	for cx in nx:
		for cz in nz:
			var c := Vector3(cx - (nx - 1) * 0.5, floors, cz - (nz - 1) * 0.5)
			if nx == 1 and nz == 1:
				mg.add(Assets.town("roof-point"), base * Transform3D(Basis(), c), mt)
			elif nz == 2:
				mg.add(Assets.town("roof"), base * Transform3D(Basis(Vector3.UP, PI * 0.5 if cz == 1 else -PI * 0.5), c), mt)
			elif cx == 0:
				mg.add(Assets.town("roof-gable-end"), base * Transform3D(Basis(), c), mt)
			elif cx == nx - 1:
				mg.add(Assets.town("roof-gable-end"), base * Transform3D(Basis(Vector3.UP, PI), c), mt)
			else:
				mg.add(Assets.town("roof-gable"), base * Transform3D(Basis(), c), mt)
	if rng.randf() < 0.4:
		mg.add(Assets.town("chimney"), base * Transform3D(Basis(), Vector3((nx - 1) * 0.5 - 0.1, floors + 0.05, -0.3)), mt)


## Forte abaluartado de pedra, como os castelos espanhóis do Caribe (El Morro):
## muralhas inclinadas, quatro baluartes em ponta, parapeito com canhoneiras e canhões no alto.
func _fort(root: Node3D, mp: Material, mt: Material, rng: RandomNumberGenerator) -> void:
	var fp := fort_pos
	var fb := Basis(Vector3.UP, atan2(dir.x, dir.y) + 0.6)
	var a := 15.0
	var H := 7.5
	var sq := [Vector2(a, a), Vector2(-a, a), Vector2(-a, -a), Vector2(a, -a)]
	var poly := PackedVector2Array()
	for i in 4:
		var v: Vector2 = sq[i]
		var vp: Vector2 = sq[(i + 3) % 4]
		var vn: Vector2 = sq[(i + 1) % 4]
		var e_in := (v - vp).normalized()
		var e_out := (vn - v).normalized()
		var n_in := Vector2(e_in.y, -e_in.x)
		var n_out := Vector2(e_out.y, -e_out.x)
		if n_in.dot(v) < 0.0:
			n_in = -n_in
		if n_out.dot(v) < 0.0:
			n_out = -n_out
		var p1 := v - e_in * 6.5
		poly.append(p1)
		poly.append(p1 + n_in * 3.5)
		poly.append(v + v.normalized() * 10.0)
		poly.append(v + e_out * 6.5 + n_out * 3.5)
		poly.append(v + e_out * 6.5)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stone := Color(0.74, 0.68, 0.56).srgb_to_linear()
	var n := poly.size()
	var inner := PackedVector2Array()
	for i in n:
		inner.append(poly[i] * (1.0 - 2.2 / poly[i].length()))
	var dist := 0.0
	var y0 := -3.0
	for i in n:
		var p0 := poly[i]
		var p1 := poly[(i + 1) % n]
		var seg_len := p0.distance_to(p1)
		var t0 := p0 * (1.0 - 1.0 / p0.length())   # topo recuado (talude)
		var t1 := p1 * (1.0 - 1.0 / p1.length())
		var q := [Vector3(p0.x, y0, p0.y), Vector3(p1.x, y0, p1.y), Vector3(t1.x, H, t1.y), Vector3(t0.x, H, t0.y)]
		var uvs := [Vector2(dist, 0), Vector2(dist + seg_len, 0), Vector2(dist + seg_len, H - y0), Vector2(dist, H - y0)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_color(stone)
			st.set_uv(uvs[k])
			st.add_vertex(fb * q[k] + fp)
		# parapeito com merlões e canhoneiras
		var segs := maxi(1, int(seg_len / 2.6))
		for sgi in segs:
			var u0 := float(sgi) / segs
			var u1 := float(sgi + 1) / segs
			var top := H + (1.4 if sgi % 2 == 0 else 0.6)
			var a0 := t0.lerp(t1, u0)
			var a1 := t0.lerp(t1, u1)
			var b0 := inner[i].lerp(inner[(i + 1) % n], u0).lerp(a0, 0.55)
			var b1 := inner[i].lerp(inner[(i + 1) % n], u1).lerp(a1, 0.55)
			var faces := [
				[Vector3(a0.x, H, a0.y), Vector3(a1.x, H, a1.y), Vector3(a1.x, top, a1.y), Vector3(a0.x, top, a0.y)],
				[Vector3(b1.x, H, b1.y), Vector3(b0.x, H, b0.y), Vector3(b0.x, top, b0.y), Vector3(b1.x, top, b1.y)],
				[Vector3(a0.x, top, a0.y), Vector3(a1.x, top, a1.y), Vector3(b1.x, top, b1.y), Vector3(b0.x, top, b0.y)],
			]
			for fq in faces:
				var fu := [Vector2(dist + u0 * seg_len, H - y0), Vector2(dist + u1 * seg_len, H - y0), Vector2(dist + u1 * seg_len, top - y0), Vector2(dist + u0 * seg_len, top - y0)]
				for k in [0, 1, 2, 0, 2, 3]:
					st.set_color(stone * 0.95)
					st.set_uv(fu[k])
					st.add_vertex(fb * fq[k] + fp)
		dist += seg_len
	# piso do terrapleno
	var tri := Geometry2D.triangulate_polygon(poly)
	for k in tri:
		var pp := poly[k] * (1.0 - 1.0 / poly[k].length())
		st.set_color(stone * 0.8)
		st.set_uv(pp)
		st.add_vertex(fb * Vector3(pp.x, H - 0.05, pp.y) + fp)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var smat := ShaderMaterial.new()
	smat.shader = Island._stone_shader
	mi.material_override = smat
	root.add_child(mi)
	# canhões nas canhoneiras dos baluartes e quartel no centro
	var mg := Assets.Merger.new()
	for i in n:
		if i % 5 == 1 or i % 5 == 3:
			var p0 := poly[i]
			var p1 := poly[(i + 1) % n]
			var mid := (p0 + p1) * 0.5
			var out := Vector2((p1 - p0).y, -(p1 - p0).x).normalized()
			if out.dot(mid) < 0.0:
				out = -out
			var cp := mid - out * 2.6
			var cb := fb * Basis(Vector3.UP, atan2(out.x, out.y))
			mg.add(Assets.pirate("cannon"), Transform3D(cb.scaled(Vector3.ONE * 1.3), fb * Vector3(cp.x, H, cp.y) + fp), mp)
	_house_k(mg, mt, fp + Vector3(0, H - 0.05, 0), atan2(dir.x, dir.y) + 0.6, 2, 2, 1, rng, false)
	var mi2 := MeshInstance3D.new()
	mi2.mesh = mg.commit()
	root.add_child(mi2)


func build() -> void:
	Island._materials()
	var w := World.I
	var root := Node3D.new()
	root.name = "Cidade_" + name
	var rng := RandomNumberGenerator.new()
	rng.seed = idx * 17 + 3
	var nat: int = Game.port_owner[idx]
	var mt := Assets.town_material(nation)
	var mp := Assets.pirate_material()
	var mg := Assets.Merger.new()
	var gs := SurfaceTool.new()
	gs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ang := atan2(dir.x, dir.y)
	var tc := Vector2(town_center.x, town_center.z)
	var wood_style := nation == Game.ENG or nation == Game.HOL or nation == Game.FRA
	# casas viradas para a praça
	for wp in houses:
		var h := w.terrain_height(wp.x, wp.y)
		var to := tc - wp
		var face := atan2(to.x, to.y)
		face = snappedf(face, PI * 0.5) + rng.randf_range(-0.05, 0.05)
		var nx := 3 if rng.randf() < 0.6 else 2
		var floors := 2
		_house_k(mg, mt, Vector3(wp.x, h - 0.15, wp.y), face, nx, 2, floors, rng, wood_style)
	# igreja com torre
	var cpos := town_center - Vector3(0, 0.15, 0) - Vector3(dir.x, 0, dir.y) * 24.0
	_house_k(mg, mt, cpos, ang + PI * 0.5, 4, 2, 3, rng, false, M, true)
	var tpos := town_center - Vector3(0, 0.15, 0) - Vector3(dir.x, 0, dir.y) * 10.0
	_house_k(mg, mt, tpos, ang, 1, 1, 6, rng, false, 3.6, true)
	# taverna
	var tb := ang + PI
	_house_k(mg, mt, tavern_pos - Vector3(0, 0.15, 0), tb, 3, 2, 2, rng, true)
	var tbb := Basis(Vector3.UP, tb)
	mg.add(Assets.town("banner-red"), Transform3D(tbb * Basis.from_scale(Vector3.ONE * M) * Basis(Vector3.UP, -PI * 0.5), tavern_pos + tbb * Vector3(-M, 2.2, M + 0.2)), mt)
	# praça: chafariz, barracas, lampiões e carroças
	mg.add(Assets.town("fountain-round"), Transform3D(Basis.from_scale(Vector3.ONE * 2.4), town_center + Vector3(0, -0.1, 0)), mt)
	mg.add(Assets.town("fountain-center"), Transform3D(Basis.from_scale(Vector3.ONE * 2.4), town_center + Vector3(0, -0.1, 0)), mt)
	for k in 4:
		var a2 := ang + PI * 0.25 + k * PI * 0.5
		var sp := town_center + Vector3(sin(a2), 0, cos(a2)) * 15.0
		sp.y = w.terrain_height(sp.x, sp.z)
		mg.add(Assets.town("stall-red" if k % 2 == 0 else "stall-green"), Transform3D(Basis(Vector3.UP, a2 + PI).scaled(Vector3(3.0, 2.6, 3.0)), sp), mt)
	for k in 6:
		var a3 := ang + k * TAU / 6.0
		var lp := town_center + Vector3(sin(a3), 0, cos(a3)) * 9.0
		lp.y = w.terrain_height(lp.x, lp.z)
		mg.add(Assets.town("lantern"), Transform3D(Basis.from_scale(Vector3.ONE * 2.2), lp), mt)
		ShipBuilder._box(gs, Transform3D(Basis(), lp + Vector3(0, 3.1, 0)), Vector3(0.3, 0.35, 0.3), Color(1, 1, 1))
	for k in 2:
		var cp2 := town_center + Vector3(dir.x, 0, dir.y) * (20.0 + k * 6.0) + Vector3(-dir.y, 0, dir.x) * (8.0 - k * 16.0)
		cp2.y = w.terrain_height(cp2.x, cp2.z)
		mg.add(Assets.town("cart"), Transform3D(Basis(Vector3.UP, ang + k).scaled(Vector3.ONE * 2.6), cp2), mt)
	# cais de tábuas
	var cp := Vector3(coast_point.x, 0.0, coast_point.y)
	var db := Basis(Vector3.UP, ang)
	for k in 11:
		mg.add(Assets.pirate("structure-platform-dock"), Transform3D(db * Basis.from_scale(Vector3(2.9, 1.3, 2.8)), cp + db * Vector3(0, 0, -3.5 + k * 7.0)), mp)
	for sx in [-1.0, 1.0]:
		mg.add(Assets.pirate("structure-platform-dock"), Transform3D(db * Basis.from_scale(Vector3(2.9, 1.3, 2.8)), cp + db * Vector3(sx * 7.25, 0, 66.0)), mp)
	# barris, caixotes e botes no cais
	for k in 10:
		var bp := cp + db * Vector3(rng.randf_range(-2.8, 2.8), 1.7, rng.randf_range(4.0, 60.0))
		var piece: String = ["barrel", "crate", "crate-bottles", "barrel"][k % 4]
		mg.add(Assets.pirate(piece), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * 1.0), bp), mp)
	for k in 2:
		mg.add(Assets.pirate("boat-row-small"), Transform3D(db * Basis(Vector3.UP, 0.3 * k).scaled(Vector3.ONE * 2.2), cp + db * Vector3(6.5 + k * 3.0, 0.1, 20.0 + k * 9.0)), mp)
	# armazéns do porto
	for k in 3:
		var wpos := cp + db * Vector3(-24 + k * 24, 0, -20)
		var h2 := w.terrain_height(wpos.x, wpos.z)
		_house_k(mg, mt, Vector3(wpos.x, maxf(h2, 1.0) - 0.15, wpos.z), ang + PI, 3, 2, 1, rng, true)
		for j in 3:
			var bp2 := Vector3(wpos.x, maxf(h2, 1.0), wpos.z) + db * Vector3(-4.0 + j * 3.0, 0, 5.0)
			mg.add(Assets.pirate("crate" if j % 2 == 0 else "barrel"), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), bp2), mp)
	_fort(root, mp, mt, rng)
	var fp := fort_pos
	var mi := MeshInstance3D.new()
	mi.mesh = mg.commit()
	root.add_child(mi)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.15
	pm.bottom_radius = 0.22
	pm.height = 16.0
	pole.mesh = pm
	var fbb := Basis(Vector3.UP, atan2(dir.x, dir.y) + 0.6)
	var pole_base := fp + fbb * Vector3(0, 0, -9.0)
	pole.position = pole_base + Vector3(0, 7.5 + 8.0, 0)
	root.add_child(pole)
	var flag := MeshInstance3D.new()
	flag.mesh = ShipBuilder.flag_mesh(7.5, 5.0)
	flag_mat = ShaderMaterial.new()
	flag_mat.shader = Island._flag_shader
	flag_mat.set_shader_parameter("flag_type", Game.NATIONS[nat]["flag"])
	flag.material_override = flag_mat
	flag.position = pole_base + Vector3(0.2, 7.5 + 15.8, 0)
	root.add_child(flag)
	var glow := MeshInstance3D.new()
	glow.mesh = gs.commit()
	glow.material_override = ShipBuilder.glow_material()
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow)
	fort_ruin = Node3D.new()
	fort_ruin.position = fp + Vector3(0, 9, 0)
	root.add_child(fort_ruin)
	var streets: Array[PackedVector2Array] = [
		PackedVector2Array([coast_point, tc]),
		PackedVector2Array([tc, Vector2(fort_pos.x, fort_pos.z)]),
		PackedVector2Array([tc, Vector2(stable_pos.x, stable_pos.z)]),
	]
	for st2 in streets:
		var rm := road_mesh(w, st2, 6.0)
		if rm:
			var rmi := MeshInstance3D.new()
			rmi.mesh = rm
			rmi.material_override = Island._road_mat
			rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(rmi)
	# estábulo (estrutura de madeira do kit pirata)
	var sb := Basis(Vector3.UP, ang + PI * 0.5)
	var stable := Assets.Merger.new()
	for k in 3:
		stable.add(Assets.pirate("structure"), Transform3D(sb.scaled(Vector3(2.0, 1.9, 2.0)), stable_pos + sb * Vector3(-5.0 + k * 5.0, -0.1, 0.0)), mp)
	var smi := MeshInstance3D.new()
	smi.mesh = stable.commit()
	root.add_child(smi)
	node = root


## Faixa de estrada que acompanha o relevo.
static func road_mesh(w: World, pts: PackedVector2Array, width: float) -> ArrayMesh:
	var dense := PackedVector2Array()
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var n := maxi(1, int(a.distance_to(b) / 5.0))
		for k in n:
			dense.append(a.lerp(b, float(k) / n))
	dense.append(pts[pts.size() - 1])
	if dense.size() < 2:
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_ok := false
	for i in dense.size():
		var p := dense[i]
		var d := (dense[mini(i + 1, dense.size() - 1)] - dense[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-d.y, d.x) * width * 0.5
		var hl := w.terrain_height(p.x + side.x, p.y + side.y)
		var hr := w.terrain_height(p.x - side.x, p.y - side.y)
		var l := Vector3(p.x + side.x, hl + 0.18, p.y + side.y)
		var r := Vector3(p.x - side.x, hr + 0.18, p.y - side.y)
		var ok := hl > 0.4 and hr > 0.4
		if i > 0 and ok and prev_ok:
			for v in [prev_l, prev_r, r, prev_l, r, l]:
				st.add_vertex(v)
		prev_l = l
		prev_r = r
		prev_ok = ok
	return st.commit()
