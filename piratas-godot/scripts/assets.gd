class_name Assets
extends RefCounted
## Modelos 3D prontos (licença CC0): personagens e cavalo animados da Quaternius,
## peças de cidade, kit pirata e natureza da Kenney. Ver assets/CREDITOS.md.

const PEOPLE_M := ["Smooth_Male_Shirt", "Smooth_Male_LongSleeve", "Smooth_Male_Casual"]
const PEOPLE_F := ["Smooth_Female_Dress", "Smooth_Female_Casual", "Smooth_Female_Alternative"]
const OFFICER := "Smooth_Male_Suit"
const PERSON_SCALE := 0.37     # 4,74 unidades -> 1,75 m
const HORSE_SCALE := 0.4

static var _scenes := {}
static var _meshes := {}
static var _mats := {}
static var _anims_fixed := {}


static func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


## Primeira malha de um .glb (peças estáticas).
static func mesh(path: String) -> Mesh:
	if _meshes.has(path):
		return _meshes[path]
	var n: Node = scene(path).instantiate()
	var found: Array = n.find_children("*", "MeshInstance3D", true, false)
	var m: Mesh = found[0].mesh if not found.is_empty() else null
	n.free()
	if m and path.contains("/nature/"):
		m = _tint_nature(m)
	elif m and path.contains("/pirate/"):
		m = m.duplicate()
		for s in m.get_surface_count():
			m.surface_set_material(s, pirate_material())
	_meshes[path] = m
	return m


## Cores mais tropicais e menos saturadas para a natureza da Kenney.
static func _tint_nature(src: Mesh) -> Mesh:
	var m: Mesh = src.duplicate()
	var colors := {"leafsGreen": Color(0.22, 0.42, 0.14), "leafsDark": Color(0.14, 0.3, 0.1), "grass": Color(0.34, 0.5, 0.17),
		"woodBark": Color(0.36, 0.25, 0.16), "woodBarkDark": Color(0.28, 0.2, 0.13), "dirt": Color(0.4, 0.31, 0.21),
		"stone": Color(0.5, 0.48, 0.44), "_defaultMat": Color(0.3, 0.45, 0.15)}
	for s in m.get_surface_count():
		var old: Material = m.surface_get_material(s)
		var key := old.resource_name if old else ""
		if colors.has(key):
			var nm := StandardMaterial3D.new()
			nm.albedo_color = colors[key]
			nm.roughness = 0.9
			nm.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.surface_set_material(s, nm)
	return m


static func town(piece: String) -> Mesh:
	return mesh("res://assets/kenney/town/%s.glb" % piece)


static func pirate(piece: String) -> Mesh:
	return mesh("res://assets/kenney/pirate/%s.glb" % piece)


static func nature(piece: String) -> Mesh:
	return mesh("res://assets/kenney/nature/%s.glb" % piece)


## Material das casas com as cores da nação (telhado e parede recoloridos).
static func town_material(nation: int) -> StandardMaterial3D:
	var key := "town_%d" % nation
	if not _mats.has(key):
		var suffix: String = ["eng", "esp", "fra", "hol", "por", "pir"][nation]
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/kenney/town/Textures/colormap_%s.png" % suffix)
		m.roughness = 0.9
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


static func pirate_material() -> StandardMaterial3D:
	if not _mats.has("pirate"):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/kenney/pirate/Textures/colormap_natural.png")
		m.roughness = 0.85
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats["pirate"] = m
	return _mats["pirate"]


static func _fix_loops(ap: AnimationPlayer) -> void:
	for lib_name in ap.get_animation_library_list():
		var lib := ap.get_animation_library(lib_name)
		for an in lib.get_animation_list():
			var a := lib.get_animation(an)
			if _anims_fixed.has(a):
				continue
			_anims_fixed[a] = true
			var low := an.to_lower()
			if low.ends_with("walk") or low.ends_with("run") or low.ends_with("idle") or low.ends_with("walkslow") or low.ends_with("sitting") or low.ends_with("clapping"):
				a.loop_mode = Animation.LOOP_LINEAR


## Pessoa animada. kind: "homem", "mulher" ou "oficial". Retorna {"root", "ap", "pre", "cur"}.
static func person(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var file := OFFICER
	if kind == "homem":
		file = PEOPLE_M[rng.randi() % PEOPLE_M.size()]
	elif kind == "mulher":
		file = PEOPLE_F[rng.randi() % PEOPLE_F.size()]
	var root := Node3D.new()
	var model: Node3D = scene("res://assets/people/%s.fbx" % file).instantiate()
	model.scale = Vector3.ONE * PERSON_SCALE * rng.randf_range(0.94, 1.05)
	model.rotation.y = PI   # o modelo olha para +Z; no jogo a frente é -Z
	root.add_child(model)
	var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	_fix_loops(ap)
	var pre := "HumanArmature|Female_" if file.contains("Female") else "HumanArmature|Man_"
	var p := {"root": root, "ap": ap, "pre": pre, "cur": ""}
	play(p, "Idle")
	ap.seek(rng.randf() * 2.0, true)
	return p


static func play(p: Dictionary, anim: String, speed := 1.0) -> void:
	var ap: AnimationPlayer = p["ap"]
	var full: String = p["pre"] + anim
	if p["cur"] != full:
		if ap.has_animation(full):
			ap.play(full, 0.25)
			p["cur"] = full
	ap.speed_scale = speed


static func horse() -> Dictionary:
	var root := Node3D.new()
	var model: Node3D = scene("res://assets/animals/Horse.fbx").instantiate()
	model.scale = Vector3.ONE * HORSE_SCALE
	model.rotation.y = PI
	root.add_child(model)
	var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	_fix_loops(ap)
	var h := {"root": root, "ap": ap, "pre": "Armature|", "cur": ""}
	play(h, "Idle")
	return h


## Carrega tudo no thread principal (as threads de construção só reutilizam o cache).
static func warm() -> void:
	for d in [["town", ["wall", "wall-door", "wall-window-shutters", "wall-window-small", "wall-wood", "wall-wood-window-shutters",
			"wall-wood-door", "wall-wood-window-small", "roof-gable", "roof-gable-end", "roof-point", "chimney", "stall-red", "stall-green",
			"fountain-round", "lantern", "cart", "banner-red", "banner-green", "wall-doorway-round", "overhang", "wall-window-round"]],
		["pirate", ["barrel", "crate", "crate-bottles", "chest", "cannon", "tower-complete-large", "tower-complete-small", "castle-wall",
			"castle-gate", "structure-platform-dock", "structure", "structure-roof", "palm-detailed-straight", "palm-detailed-bend",
			"palm-straight", "palm-bend", "rocks-a", "rocks-b", "rocks-c", "rocks-sand-a", "rocks-sand-b", "boat-row-small"]],
		["nature", ["tree_default", "tree_default_dark", "tree_detailed", "tree_detailed_dark", "tree_fat", "tree_oak", "tree_oak_dark",
			"tree_tall", "plant_bush", "plant_bushDetailed", "plant_bushLarge", "plant_bushSmall", "plant_flatTall", "grass_large",
			"grass_leafsLarge", "flower_redA", "flower_yellowA", "flower_purpleA", "rock_largeA", "rock_largeB", "rock_largeC",
			"rock_tallA", "rock_tallB", "log", "stump_old"]]]:
		for piece in d[1]:
			mesh("res://assets/kenney/%s/%s.glb" % [d[0], piece])
	for f in PEOPLE_M + PEOPLE_F + [OFFICER]:
		scene("res://assets/people/%s.fbx" % f)
	scene("res://assets/animals/Horse.fbx")
	for n in 6:
		town_material(n)
	pirate_material()


# ---------------------------------------------------------------- junção de peças numa malha só
## Junta várias peças (com transformações) numa única malha por material — poucos "draw calls".
class Merger:
	var tools := {}   # material -> SurfaceTool
	var mat_override: Material = null

	func add(m: Mesh, xf: Transform3D, override: Material = null) -> void:
		if m == null:
			return
		for s in m.get_surface_count():
			var mat: Material = override if override else (mat_override if mat_override else m.surface_get_material(s))
			if not tools.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[mat] = st
			tools[mat].append_from(m, s, xf)

	func commit() -> ArrayMesh:
		var out := ArrayMesh.new()
		for mat in tools:
			var st: SurfaceTool = tools[mat]
			st.commit(out)
			out.surface_set_material(out.get_surface_count() - 1, mat)
		return out
