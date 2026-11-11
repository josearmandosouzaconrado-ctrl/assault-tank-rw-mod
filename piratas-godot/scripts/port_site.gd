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
		blocks.append(Vector3(hp.x, hp.y, 6.2))
	var t2 := Vector2(town_center.x, town_center.z)
	for k in [17.0, 31.0]:
		var c: Vector2 = t2 - dir * k
		blocks.append(Vector3(c.x, c.y, 7.0))
	var tw := t2 - dir * 10.0
	blocks.append(Vector3(tw.x, tw.y, 4.2))
	blocks.append(Vector3(t2.x, t2.y, 2.4))
	blocks.append(Vector3(tavern_pos.x, tavern_pos.z, 8.0))
	blocks.append(Vector3(fort_pos.x, fort_pos.z, 17.0))
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
func build() -> void:
	Island._materials()
	var w := World.I
	var root := Node3D.new()
	root.name = "Cidade_" + name
	var rng := RandomNumberGenerator.new()
	rng.seed = idx * 17 + 3
	var nat: int = Game.port_owner[idx]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var gs := SurfaceTool.new()
	gs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ang := atan2(dir.x, dir.y)
	var walls := [Color(0.92, 0.88, 0.78), Color(0.95, 0.85, 0.65), Color(0.85, 0.75, 0.6)]
	var roofs := [Color(0.62, 0.25, 0.15), Color(0.55, 0.3, 0.2)]
	match nation:
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
	for wp in houses:
		var h := w.terrain_height(wp.x, wp.y)
		var hw := rng.randf_range(7, 12)
		var dd := rng.randf_range(7, 11)
		var hh := rng.randf_range(4.5, 8.5) * (1.4 if nation == Game.HOL else 1.0)
		var a := ang + (rng.randi() % 4) * PI * 0.5
		Island._house(st, gs, Vector3(wp.x, h - 0.5, wp.y), Basis(Vector3.UP, a), hw, dd, hh, walls[rng.randi() % walls.size()], roofs[rng.randi() % roofs.size()])
	# praça e igreja
	var cb := Basis(Vector3.UP, ang)
	var cpos := town_center - Vector3(0, 0.5, 0) - Vector3(dir.x, 0, dir.y) * 6.0
	Island._house(st, gs, cpos - cb * Vector3(0, 0, 18), cb, 12, 26, 10, Color(0.93, 0.9, 0.82), Color(0.55, 0.28, 0.18))
	ShipBuilder._box(st, Transform3D(cb, cpos - cb * Vector3(0, -11, 4)), Vector3(6, 22, 6), Color(0.93, 0.9, 0.82))
	ShipBuilder._box(st, Transform3D(cb, cpos - cb * Vector3(0, -23.5, 4)), Vector3(4, 3, 4), Color(0.55, 0.28, 0.18))
	# poço/chafariz no centro da praça
	ShipBuilder._tube(st, town_center + Vector3(0, -0.3, 0), town_center + Vector3(0, 0.9, 0), 2.0, 2.0, Color(0.6, 0.58, 0.52), 12)
	# taverna (com placa) e estábulo
	var tb := Basis(Vector3.UP, ang + PI)
	Island._house(st, gs, tavern_pos - Vector3(0, 0.5, 0), tb, 14, 11, 6.5, Color(0.55, 0.38, 0.24), Color(0.4, 0.22, 0.14))
	ShipBuilder._box(st, Transform3D(tb, tavern_pos + tb * Vector3(3.5, 4.0, 6.2)), Vector3(2.2, 1.2, 0.12), Color(0.85, 0.65, 0.2))
	var sb := Basis(Vector3.UP, ang + PI * 0.5)
	ShipBuilder._box(st, Transform3D(sb, stable_pos + Vector3(0, 2.0, 0)), Vector3(16, 4.0, 0.4), Color(0.45, 0.32, 0.2))
	ShipBuilder._box(st, Transform3D(sb, stable_pos + sb * Vector3(0, 4.2, 1.5)), Vector3(17, 0.3, 4.5), Color(0.5, 0.42, 0.25))
	for k in 5:
		ShipBuilder._tube(st, stable_pos + sb * Vector3(-8 + k * 4, 0, 3.6), stable_pos + sb * Vector3(-8 + k * 4, 4.2, 3.6), 0.15, 0.15, Color(0.4, 0.3, 0.2), 5)
	# cais
	var cp := Vector3(coast_point.x, 0.0, coast_point.y)
	var db := Basis(Vector3.UP, ang)
	var plank := Color(0.45, 0.33, 0.22)
	ShipBuilder._box(st, Transform3D(db, cp + db * Vector3(0, 1.4, 30)), Vector3(7, 0.5, 80), plank)
	for k in 9:
		for sx in [-3.2, 3.2]:
			ShipBuilder._box(st, Transform3D(db, cp + db * Vector3(sx, -2.0, k * 9.5 - 6.0)), Vector3(0.6, 7.0, 0.6), plank.darkened(0.3))
	ShipBuilder._box(st, Transform3D(db, cp + db * Vector3(0, 1.4, 66)), Vector3(22, 0.5, 8), plank)
	for k in 3:
		var wp := cp + db * Vector3(-24 + k * 24, 0, -20)
		var h := w.terrain_height(wp.x, wp.z)
		Island._house(st, null, Vector3(wp.x, maxf(h, 1.0) - 0.5, wp.z), db, 14, 10, 6, Color(0.5, 0.38, 0.26), Color(0.42, 0.3, 0.2))
	# forte
	var fp := fort_pos
	var fb := Basis(Vector3.UP, ang + 0.6)
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
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Island._build_mat
	root.add_child(mi)
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
	flag_mat.shader = Island._flag_shader
	flag_mat.set_shader_parameter("flag_type", Game.NATIONS[nat]["flag"])
	flag.material_override = flag_mat
	flag.position = fp + Vector3(0.2, 19.8, 0)
	root.add_child(flag)
	var glow := MeshInstance3D.new()
	glow.mesh = gs.commit()
	glow.material_override = ShipBuilder.glow_material()
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow)
	fort_ruin = Node3D.new()
	fort_ruin.position = fp + Vector3(0, 8, 0)
	root.add_child(fort_ruin)
	# ruas da cidade: cais -> praça -> forte, praça -> estábulo/taverna
	var streets: Array[PackedVector2Array] = [
		PackedVector2Array([coast_point, Vector2(town_center.x, town_center.z)]),
		PackedVector2Array([Vector2(town_center.x, town_center.z), Vector2(fort_pos.x, fort_pos.z)]),
		PackedVector2Array([Vector2(town_center.x, town_center.z), Vector2(stable_pos.x, stable_pos.z)]),
	]
	for s in streets:
		var rm := road_mesh(w, s, 6.0)
		if rm:
			var rmi := MeshInstance3D.new()
			rmi.mesh = rm
			rmi.material_override = Island._road_mat
			rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(rmi)
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
