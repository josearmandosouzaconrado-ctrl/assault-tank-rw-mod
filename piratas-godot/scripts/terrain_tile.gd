class_name TerrainTile
extends RefCounted
## Bloco quadrado de terreno (800 m) gerado a partir de World.terrain_height.
## Dois níveis de detalhe (perto/longe) + vegetação. Pode ser construído numa thread.

const SIZE := 800.0

var tx := 0
var tz := 0
var node: Node3D
var building := false


func _init(x: int, z: int) -> void:
	tx = x
	tz = z


func origin() -> Vector2:
	return Vector2(tx * SIZE, tz * SIZE)


func center() -> Vector2:
	return origin() + Vector2(SIZE, SIZE) * 0.5


func build() -> void:
	Island._materials()
	var w := World.I
	var root := Node3D.new()
	root.name = "Terreno_%d_%d" % [tx, tz]
	var hi_res := 64 if Game.quality > 0 else 48
	var near := _mesh(w, hi_res)
	if near == null:
		node = root
		return
	var far := _mesh(w, 16)
	var vis_near: float = [900.0, 1300.0, 1700.0][Game.quality]
	var mi := MeshInstance3D.new()
	mi.mesh = near
	mi.material_override = Island._terrain_mat
	mi.visibility_range_end = vis_near
	mi.visibility_range_end_margin = 50.0
	root.add_child(mi)
	if far:
		var mf := MeshInstance3D.new()
		mf.mesh = far
		mf.material_override = Island._terrain_mat
		mf.visibility_range_begin = vis_near
		mf.visibility_range_begin_margin = 50.0
		mf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mf)
	_vegetation(w, root)
	node = root


func _mesh(w: World, n: int) -> ArrayMesh:
	var o := origin()
	var cell := SIZE / n
	var row := n + 1
	var hs := PackedFloat32Array()
	hs.resize(row * row)
	var any_land := false
	for j in row:
		for i in row:
			var h := w.terrain_height(o.x + i * cell, o.y + j * cell)
			hs[j * row + i] = h
			if h > -6.0:
				any_land = true
	if not any_land:
		return null
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	verts.resize(row * row)
	cols.resize(row * row)
	norms.resize(row * row)
	var sand := Color(0.86, 0.77, 0.56).srgb_to_linear()
	var grass := Color(0.36, 0.52, 0.2).srgb_to_linear()
	var jungle := Color(0.15, 0.3, 0.09).srgb_to_linear()
	var rock := Color(0.47, 0.44, 0.4).srgb_to_linear()
	var under := Color(0.62, 0.58, 0.44).srgb_to_linear()
	for j in row:
		for i in row:
			var k := j * row + i
			var h := hs[k]
			var x := o.x + i * cell
			var z := o.y + j * cell
			var hl := hs[k - 1] if i > 0 else w.terrain_height(x - cell, z)
			var hr := hs[k + 1] if i < n else w.terrain_height(x + cell, z)
			var hd := hs[k - row] if j > 0 else w.terrain_height(x, z - cell)
			var hu := hs[k + row] if j < n else w.terrain_height(x, z + cell)
			var nrm := Vector3(hl - hr, 2.0 * cell, hd - hu).normalized()
			var slope := 1.0 - nrm.y
			var c: Color
			if h < -0.5:
				c = under
			elif h < 2.7:
				c = sand
			else:
				var hn := clampf((h - 2.7) / 40.0, 0.0, 1.0)
				var nv := sin(x * 0.013 + sin(z * 0.009) * 2.0) * 0.3
				c = grass.lerp(jungle, clampf(hn * 1.8 + nv + 0.2, 0.0, 1.0))
				if h < 4.0:
					c = sand.lerp(c, (h - 2.7) / 1.3)
			if slope > 0.3 or h > 70.0:
				c = c.lerp(rock, clampf((slope - 0.3) * 5.0 + maxf(0.0, (h - 70.0) * 0.05), 0.0, 1.0))
			if w.on_road(x, z):
				c = c.lerp(Color(0.5, 0.4, 0.28).srgb_to_linear(), 0.85)
			verts[k] = Vector3(i * cell, h, j * cell)
			cols[k] = c
			norms[k] = nrm
	var idx := PackedInt32Array()
	for j in n:
		for i in n:
			var a := j * row + i
			var b := a + 1
			var c := a + row
			var d := c + 1
			if hs[a] < -8.0 and hs[b] < -8.0 and hs[c] < -8.0 and hs[d] < -8.0:
				continue
			idx.append_array(PackedInt32Array([a, b, c, b, d, c]))
	if idx.is_empty():
		return null
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func _vegetation(w: World, root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(tx, tz)) + 77
	var dens: float = [0.4, 0.75, 1.0][Game.quality]
	var tries := int(520 * dens)
	var palms: Array[Transform3D] = []
	var trees: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var o := origin()
	for k in tries:
		var lp := Vector2(rng.randf() * SIZE, rng.randf() * SIZE)
		var wp := o + lp
		var h := w.terrain_height(wp.x, wp.y)
		if h < 1.4:
			if h > -1.5 and rng.randf() < 0.04:
				rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rng.randf_range(0.7, 2.2), rng.randf_range(0.6, 1.6), rng.randf_range(0.7, 2.2))), Vector3(lp.x, h - 0.4, lp.y)))
			continue
		if w.veg_blocked(wp.x, wp.y):
			continue
		var h2 := w.terrain_height(wp.x + 3.0, wp.y)
		if absf(h2 - h) > 2.6:
			if rng.randf() < 0.3:
				rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.0, 2.5)), Vector3(lp.x, h - 0.4, lp.y)))
			continue
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.75, 1.35))
		var t := Transform3D(b, Vector3(lp.x, h - 0.3, lp.y))
		if h < 9.0 or rng.randf() < 0.2:
			palms.append(t)
		else:
			trees.append(t)
	var vis: float = [800.0, 1300.0, 1900.0][Game.quality]
	_add_mm(root, Island._palm_mesh(), palms, vis)
	_add_mm(root, Island._tree_mesh(), trees, vis)
	_add_mm(root, Island._rock_mesh(), rocks, vis * 1.2)


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
	mmi.material_override = Island._veg_mat
	mmi.visibility_range_end = vis
	mmi.visibility_range_end_margin = 80.0
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Game.quality > 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
