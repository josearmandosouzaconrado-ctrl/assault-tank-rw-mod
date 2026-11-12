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
	var grass := Color(0.52, 0.53, 0.3).srgb_to_linear()
	var jungle := Color(0.27, 0.36, 0.15).srgb_to_linear()
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
			# terra batida ao redor das praças
			var town_d := w.town_distance(x, z)
			if town_d < 75.0 and h > 1.0:
				c = c.lerp(Color(0.58, 0.53, 0.43).srgb_to_linear(), (1.0 - smoothstep(35.0, 75.0, town_d)) * 0.75)
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


static var _forest: FastNoiseLite

const PALMS := ["palm-detailed-straight", "palm-detailed-bend", "palm-straight", "palm-bend"]
const TREES := ["tree_default", "tree_default_dark", "tree_detailed", "tree_detailed_dark", "tree_fat", "tree_oak", "tree_oak_dark", "tree_tall"]
const BUSHES := ["plant_bush", "plant_bushDetailed", "plant_bushLarge", "plant_bushSmall", "plant_flatTall"]
const GRASS := ["grass_large", "grass_leafsLarge"]
const FLOWERS := ["flower_redA", "flower_yellowA", "flower_purpleA"]
const ROCKS := ["rock_largeA", "rock_largeB", "rock_largeC", "rock_tallA", "rock_tallB"]


static func forest_noise() -> FastNoiseLite:
	if _forest == null:
		_forest = FastNoiseLite.new()
		_forest.seed = 4242
		_forest.frequency = 0.006
		_forest.fractal_octaves = 3
	return _forest


func _vegetation(w: World, root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(tx, tz)) + 77
	var q := Game.quality
	var dens: float = [0.45, 0.75, 1.0][q]
	var fn := forest_noise()
	var groups := {}   # caminho -> Array[Transform3D]
	var vis := {}      # caminho -> distância de visibilidade
	var o := origin()
	var tries := int(5200 * dens)
	for k in tries:
		var lp := Vector2(rng.randf() * SIZE, rng.randf() * SIZE)
		var wp := o + lp
		var h := w.terrain_height(wp.x, wp.y)
		if h < -1.2:
			continue
		var blocked := w.veg_blocked(wp.x, wp.y)
		var in_town := blocked and w.town_distance(wp.x, wp.y) > 45.0 and not w.on_road(wp.x, wp.y) and not w.building_blocked(wp.x, wp.y)
		var h2 := w.terrain_height(wp.x + 3.0, wp.y)
		var slope := absf(h2 - h) / 3.0
		var forest := fn.get_noise_2d(wp.x, wp.y) * 0.5 + 0.5
		var r := rng.randf()
		var path := ""
		var sc := 1.0
		if h < 1.4:
			# praia: pedras na arrebentação e algumas palmeiras inclinadas
			if r < 0.025:
				path = "res://assets/kenney/pirate/%s.glb" % ["rocks-sand-a", "rocks-sand-b", "rocks-a"][rng.randi() % 3]
				sc = rng.randf_range(0.8, 1.6)
			elif h > 0.6 and r < 0.06 and not blocked:
				path = "res://assets/kenney/pirate/palm-detailed-bend.glb"
				sc = rng.randf_range(2.0, 2.6)
		elif blocked:
			# dentro da cidade só capim e flores entre as casas
			if in_town and r < 0.35:
				path = "res://assets/kenney/nature/%s.glb" % (GRASS[rng.randi() % GRASS.size()] if r < 0.28 else FLOWERS[rng.randi() % FLOWERS.size()])
				sc = rng.randf_range(4.0, 6.0)
			else:
				continue
		elif slope > 0.9:
			if r < 0.25:
				path = "res://assets/kenney/nature/%s.glb" % ROCKS[rng.randi() % ROCKS.size()]
				sc = rng.randf_range(5.0, 11.0)
		elif h < 7.0:
			# faixa litorânea: coqueiral
			if r < 0.22 * (0.4 + forest):
				path = "res://assets/kenney/pirate/%s.glb" % PALMS[rng.randi() % PALMS.size()]
				sc = rng.randf_range(1.9, 2.8)
			elif r < 0.45:
				path = "res://assets/kenney/nature/%s.glb" % BUSHES[rng.randi() % BUSHES.size()]
				sc = rng.randf_range(5.0, 9.0)
			elif r < 0.75:
				path = "res://assets/kenney/nature/%s.glb" % GRASS[rng.randi() % GRASS.size()]
				sc = rng.randf_range(4.0, 7.0)
		else:
			# mata: árvores em manchas densas, clareiras com capim e flores
			if r < forest * 0.7:
				path = "res://assets/kenney/nature/%s.glb" % TREES[rng.randi() % TREES.size()]
				sc = rng.randf_range(7.0, 11.0)
			elif r < forest * 0.7 + 0.08:
				path = "res://assets/kenney/pirate/%s.glb" % PALMS[rng.randi() % 2]
				sc = rng.randf_range(2.0, 2.9)
			elif r < 0.62:
				path = "res://assets/kenney/nature/%s.glb" % BUSHES[rng.randi() % BUSHES.size()]
				sc = rng.randf_range(5.0, 10.0)
			elif r < 0.9:
				path = "res://assets/kenney/nature/%s.glb" % GRASS[rng.randi() % GRASS.size()]
				sc = rng.randf_range(4.0, 7.0)
			elif r < 0.95:
				path = "res://assets/kenney/nature/%s.glb" % FLOWERS[rng.randi() % FLOWERS.size()]
				sc = rng.randf_range(4.0, 6.0)
			elif r < 0.97:
				path = "res://assets/kenney/nature/%s.glb" % ROCKS[rng.randi() % ROCKS.size()]
				sc = rng.randf_range(4.0, 8.0)
		if path == "":
			continue
		if not groups.has(path):
			groups[path] = [] as Array[Transform3D]
			var v: float = [700.0, 1000.0, 1400.0][q]
			if path.contains("grass") or path.contains("flower"):
				v = [90.0, 140.0, 200.0][q]
			elif path.contains("bush") or path.contains("plant"):
				v = [250.0, 380.0, 520.0][q]
			vis[path] = v
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc)
		groups[path].append(Transform3D(b, Vector3(lp.x, h - 0.15, lp.y)))
	for path in groups:
		_add_mm(root, Assets.mesh(path), groups[path], vis[path])


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
	mmi.visibility_range_end = vis
	mmi.visibility_range_end_margin = 80.0
	var big := vis > 500.0
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (Game.quality > 0 and big) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
