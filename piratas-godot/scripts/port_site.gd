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
var house_face: Array[float] = []
var house_nx: Array[int] = []
var streets: Array[PackedVector2Array] = []
static var _street_mat: StandardMaterial3D
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
	dir = (d["dir"] as Vector2).normalized() if (d["dir"] as Vector2) != Vector2.ZERO else Vector2.ZERO


## Calcula posições (sem construir malhas). Usa só o relevo "cru" (sem o aplainamento das cidades).
func plan(w: World) -> void:
	# a cidade fica ~130 m terra adentro; a direção do mar sai do gradiente da distância à costa
	var p := seed_pos
	for k in 120:
		var sd := w.sdf(p.x, p.y)
		if absf(sd - 130.0) < 4.0:
			break
		var g := w.sdf_grad(p.x, p.y)
		if g.length() < 0.001:
			break
		p += g.normalized() * clampf(130.0 - sd, -20.0, 20.0)
	if dir == Vector2.ZERO:
		var g2 := w.sdf_grad(p.x, p.y)
		dir = -g2.normalized() if g2.length() > 0.001 else Vector2.DOWN
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
	var u := -dir                        # do mar para dentro da terra
	var v := Vector2(-dir.y, dir.x)      # ao longo da costa
	var L := func(a: float, b: float) -> Vector2: return tc + u * a + v * b
	# malha de ruas: avenida do cais à praça, ruas paralelas e transversais
	streets.clear()
	streets.append(PackedVector2Array([coast_point, L.call(-24.0, 0.0)]))
	for sv in [-48.0, 48.0]:
		streets.append(PackedVector2Array([L.call(-95.0, sv), L.call(120.0, sv)]))
	for su in [-70.0, -24.0, 58.0, 112.0]:
		streets.append(PackedVector2Array([L.call(su, -80.0), L.call(su, 80.0)]))
	streets.append(PackedVector2Array([L.call(24.0, 0.0), L.call(112.0, 0.0)]))
	# lotes ao longo das ruas, com a casa virada para a rua
	houses.clear()
	house_face.clear()
	house_nx.clear()
	var count: int = [24, 36, 48][Game.quality]
	var avoid := [[tc, 27.0], [L.call(24.0, 0.0), 15.0], [Vector2(tavern_pos.x, tavern_pos.z), 13.0],
		[Vector2(stable_pos.x, stable_pos.z), 20.0], [Vector2(fort_pos.x, fort_pos.z), 34.0]]
	for si in streets.size():
		var sp: PackedVector2Array = streets[si]
		var a0 := sp[0]
		var a1 := sp[1]
		var along := (a1 - a0).normalized()
		var nrm := Vector2(-along.y, along.x)
		var length := a0.distance_to(a1)
		var t := 10.0
		while t < length - 6.0 and houses.size() < count:
			for side in [-1.0, 1.0]:
				var nx := 3 if rng.randf() < 0.55 else 2
				var hp: Vector2 = a0 + along * t + nrm * side * (3.5 + 6.5)
				if _lot_ok(w, hp, avoid, si):
					houses.append(hp)
					house_face.append(atan2(-nrm.x * side, -nrm.y * side))
					house_nx.append(nx)
			t += rng.randf_range(11.5, 14.0)
	# obstáculos: casas, igreja, torre, taverna, armazéns, forte
	blocks.clear()
	for hi in houses.size():
		var hp := houses[hi]
		var rad := 4.2 if house_nx[hi] == 2 else 5.4
		blocks.append(Vector3(hp.x, hp.y, rad))
	var t2 := Vector2(town_center.x, town_center.z)
	var side2 := Vector2(dir.y, -dir.x)   # +X local da igreja
	for k in [-10.0, -5.0, 0.0, 5.0]:
		var c: Vector2 = t2 - dir * 24.0 + dir * k
		blocks.append(Vector3(c.x, c.y, 5.6))
	var tw := t2 - dir * 24.0 + dir * 5.5 + side2 * 7.5
	blocks.append(Vector3(tw.x, tw.y, 3.0))
	blocks.append(Vector3(t2.x, t2.y, 2.4))
	blocks.append(Vector3(tavern_pos.x, tavern_pos.z, 7.0))
	blocks.append(Vector3(fort_pos.x, fort_pos.z, 24.0))
	var db := Basis(Vector3.UP, atan2(dir.x, dir.y))
	for k in [-30.0, 30.0]:
		var wpos := Vector3(coast_point.x, 0, coast_point.y) + db * Vector3(k, 0, -20)
		blocks.append(Vector3(wpos.x, wpos.z, 7.0))


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


func _lot_ok(w: World, hp: Vector2, avoid: Array, own_street: int) -> bool:
	var h := w.raw_height(hp.x, hp.y)
	if h < 1.6 or h > 40.0:
		return false
	for av in avoid:
		if hp.distance_to(av[0]) < av[1]:
			return false
	for q in houses:
		if q.distance_to(hp) < 9.5:
			return false
	for si in streets.size():
		if si == own_street:
			continue
		var sp: PackedVector2Array = streets[si]
		var ab := sp[1] - sp[0]
		var k := clampf((hp - sp[0]).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if hp.distance_to(sp[0] + ab * k) < 9.0:
			return false
	# não invade o caminho do cais
	var c := hp - coast_point
	if absf(c.dot(Vector2(-dir.y, dir.x))) < 9.0 and c.dot(-dir) < 105.0:
		return false
	return true


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
const M := 3.0


## Forte abaluartado de pedra, como os castelos espanhóis do Caribe (El Morro) e os fortes de Black Flag:
## muralhas em talude, baluartes com guaritas, canhoneiras com canhões, torre de menagem, quartel, paiol e morteiros.
func _fort(root: Node3D, mp: Material, rng: RandomNumberGenerator) -> void:
	var fp := fort_pos
	var fb := Basis(Vector3.UP, atan2(dir.x, dir.y) + 0.6)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var guns := Structures.fort(st, Transform3D(fb, fp), rng)
	# morteiros (bocas largas apontadas para o céu) no pátio
	for k in 2:
		var mpos := fp + fb * Vector3(-3.0 + k * 6.0, 7.5, 9.0)
		Structures.box(st, Transform3D(fb, mpos + Vector3(0, 0.25, 0)), Vector3(1.6, 0.5, 2.0), Color(0.4, 0.3, 0.2), Structures.WOOD)
		Structures.cyl(st, mpos + Vector3(0, 0.5, 0), mpos + fb * Vector3(0, 1.4, 0.5), 0.55, 0.5, Color(0.2, 0.2, 0.22), Structures.PLAIN, 10, true)
		Structures.cyl(st, mpos + fb * Vector3(0, 1.38, 0.49), mpos + fb * Vector3(0, 1.42, 0.5), 0.36, 0.36, Color(0.02, 0.02, 0.02), Structures.DARK, 10, true)
		# pirâmide de balas
		for j in 6:
			Island._sphere(st, mpos + fb * Vector3(1.4 + (j % 3) * 0.3, 0.15 + (j / 3) * 0.25, -1.0 + (j / 3) * 0.15), Vector3.ONE * 0.15, Color(0.12, 0.12, 0.13), 5, 3)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Structures.material()
	root.add_child(mi)
	var mg := Assets.Merger.new()
	for g in guns:
		var gd: Vector3 = g[1]
		var cb := Basis(Vector3.UP, atan2(gd.x, gd.z))
		mg.add(Assets.pirate("cannon"), Transform3D(cb.scaled(Vector3.ONE * 1.35), g[0]), mp)
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
	var bs := SurfaceTool.new()   # construções procedurais (casas, igreja, píer)
	bs.begin(Mesh.PRIMITIVE_TRIANGLES)
	# casas coloniais viradas para a rua
	for hi in houses.size():
		var wp := houses[hi]
		var h := w.terrain_height(wp.x, wp.y)
		var hst := Structures.house_style(nation, rng)
		var hw := 6.0 if house_nx[hi] == 2 else 8.8
		Structures.house(bs, Transform3D(Basis(Vector3.UP, house_face[hi]), Vector3(wp.x, h - 0.05, wp.y)), hw, 6.4, hst, rng)
		# barris e caixotes encostados em algumas casas
		if rng.randf() < 0.35:
			var hb := Basis(Vector3.UP, house_face[hi])
			var pp := Vector3(wp.x, h, wp.y) + hb * Vector3(hw * 0.5 + 0.7, 0, 1.0)
			mg.add(Assets.pirate("barrel" if rng.randf() < 0.5 else "crate"), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * 0.9), pp), mp)
	Structures.plaza(bs, w, town_center, 21.0)
	# igreja barroca com torre sineira, de frente para a praça
	var cpos := town_center - Vector3(dir.x, 0, dir.y) * 24.0
	cpos.y = w.terrain_height(cpos.x, cpos.z) - 0.05
	Structures.church(bs, Transform3D(Basis(Vector3.UP, ang), cpos), nation, rng)
	# taverna (sobrado com sacada) e a placa
	var tb := ang + PI
	var tst := Structures.house_style(nation, rng)
	tst["floors"] = 2
	tst["balcony"] = true
	tst["flat"] = false
	tst["dutch"] = false
	Structures.house(bs, Transform3D(Basis(Vector3.UP, tb), tavern_pos - Vector3(0, 0.05, 0)), 10.0, 7.0, tst, rng)
	var tbb := Basis(Vector3.UP, tb)
	Structures.beam(bs, tavern_pos + tbb * Vector3(-3.5, 3.9, 3.6), tavern_pos + tbb * Vector3(-3.5, 3.9, 5.0), 0.08, 0.08, Color(0.15, 0.15, 0.16), Structures.PLAIN)
	Structures.box(bs, Transform3D(tbb * Basis(Vector3.UP, PI * 0.5), tavern_pos + tbb * Vector3(-3.5, 3.3, 4.6)), Vector3(0.9, 0.9, 0.06), Color(0.45, 0.3, 0.18), Structures.WOOD)
	Island._sphere(bs, tavern_pos + tbb * Vector3(-3.46, 3.3, 4.6), Vector3(0.12, 0.3, 0.3), Color(0.75, 0.6, 0.25), 6, 4)
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
	# píer de madeira sobre estacas
	var cp := Vector3(coast_point.x, 0.0, coast_point.y)
	var db := Basis(Vector3.UP, ang)
	Structures.pier(bs, gs, Transform3D(db, cp), rng)
	# barris, caixotes e botes no cais
	for k in 10:
		var bp := cp + db * Vector3(rng.randf_range(-2.8, 2.8), 1.7, rng.randf_range(4.0, 60.0))
		var piece: String = ["barrel", "crate", "crate-bottles", "barrel"][k % 4]
		mg.add(Assets.pirate(piece), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * 1.0), bp), mp)
	for k in 2:
		mg.add(Assets.pirate("boat-row-small"), Transform3D(db * Basis(Vector3.UP, 0.3 * k).scaled(Vector3.ONE * 2.2), cp + db * Vector3(6.5 + k * 3.0, 0.1, 20.0 + k * 9.0)), mp)
	# armazéns do porto
	for k in [-30.0, 30.0]:
		var wpos := cp + db * Vector3(k, 0, -20)
		var h2 := w.terrain_height(wpos.x, wpos.z)
		Structures.warehouse(bs, Transform3D(Basis(Vector3.UP, ang + PI), Vector3(wpos.x, maxf(h2, 1.0) - 0.05, wpos.z)), 11.0, 7.0, rng)
		for j in 3:
			var bp2 := Vector3(wpos.x, maxf(h2, 1.0), wpos.z) + db * Vector3(-4.0 + j * 3.0, 0, 5.0)
			mg.add(Assets.pirate("crate" if j % 2 == 0 else "barrel"), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), bp2), mp)
	_fort(root, mp, rng)
	var fp := fort_pos
	var mi := MeshInstance3D.new()
	mi.mesh = mg.commit()
	root.add_child(mi)
	var bmi := MeshInstance3D.new()
	bmi.mesh = bs.commit()
	bmi.material_override = Structures.material()
	root.add_child(bmi)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.15
	pm.bottom_radius = 0.22
	pm.height = 10.0
	pole.mesh = pm
	var fbb := Basis(Vector3.UP, atan2(dir.x, dir.y) + 0.6)
	var pole_base := fp + fbb * Vector3(0, 8.3, -6.0)   # no alto da torre de menagem
	pole.position = pole_base + Vector3(0, 7.5 + 5.0, 0)
	root.add_child(pole)
	var flag := MeshInstance3D.new()
	flag.mesh = ShipBuilder.flag_mesh(7.5, 5.0)
	flag_mat = ShaderMaterial.new()
	flag_mat.shader = Island._flag_shader
	flag_mat.set_shader_parameter("flag_type", Game.NATIONS[nat]["flag"])
	flag.material_override = flag_mat
	flag.position = pole_base + Vector3(0.2, 7.5 + 9.8, 0)
	root.add_child(flag)
	var glow := MeshInstance3D.new()
	glow.mesh = gs.commit()
	glow.material_override = ShipBuilder.glow_material()
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow)
	fort_ruin = Node3D.new()
	fort_ruin.position = fp + Vector3(0, 9, 0)
	root.add_child(fort_ruin)
	if _street_mat == null:
		_street_mat = StandardMaterial3D.new()
		_street_mat.albedo_color = Color(0.56, 0.52, 0.46)
		_street_mat.roughness = 0.95
	var all_streets: Array[PackedVector2Array] = streets.duplicate()
	all_streets.append(PackedVector2Array([tc, Vector2(fort_pos.x, fort_pos.z)]))
	all_streets.append(PackedVector2Array([tc, Vector2(stable_pos.x, stable_pos.z)]))
	var lamps := Assets.Merger.new()
	var lg := SurfaceTool.new()
	lg.begin(Mesh.PRIMITIVE_TRIANGLES)
	for si in all_streets.size():
		var st2 := all_streets[si]
		var rm := road_mesh(w, st2, 9.0 if si == 0 else 7.0)
		if rm:
			var rmi := MeshInstance3D.new()
			rmi.mesh = rm
			rmi.material_override = _street_mat if si < streets.size() else Island._road_mat
			rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(rmi)
		if si < streets.size():
			for end in [st2[0], st2[1]]:
				var lp := Vector3(end.x, w.terrain_height(end.x, end.y), end.y) + Vector3(4.5, 0, 4.5)
				if w.terrain_height(lp.x, lp.z) > 1.0:
					lamps.add(Assets.town("lantern"), Transform3D(Basis.from_scale(Vector3.ONE * 2.2), lp), mt)
					ShipBuilder._box(lg, Transform3D(Basis(), lp + Vector3(0, 3.1, 0)), Vector3(0.3, 0.35, 0.3), Color(1, 1, 1))
	var lmi := MeshInstance3D.new()
	lmi.mesh = lamps.commit()
	root.add_child(lmi)
	var lgi := MeshInstance3D.new()
	lgi.mesh = lg.commit()
	lgi.material_override = ShipBuilder.glow_material()
	lgi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lgi)
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
