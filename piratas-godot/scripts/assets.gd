class_name Assets
extends RefCounted
## Modelos 3D prontos (licença CC0): personagens e cavalo animados da Quaternius,
## peças de cidade, kit pirata e natureza da Kenney. Ver assets/CREDITOS.md.

const PEOPLE_M := ["Smooth_Male_Shirt", "Smooth_Male_LongSleeve", "Smooth_Male_Casual"]
const PEOPLE_F := ["Smooth_Female_Dress", "Smooth_Female_Casual", "Smooth_Female_Alternative"]
const OFFICER := "Smooth_Male_Suit"
const PERSON_SCALE := 0.37     # 4,74 unidades -> 1,75 m
const HORSE_SCALE := 0.35

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


const OUTFITS := [
	{"id": "Smooth_Male_Suit", "name": "Casaca de capitão (justaucorps)", "price": 0, "style": {"skirt": true, "facing": true, "cravat": true, "sash": true}},
	{"id": "Smooth_Male_LongSleeve", "name": "Camisa e calções de marinheiro", "price": 250, "style": {"slops": true, "belt": true}},
	{"id": "Smooth_Male_Shirt", "name": "Colete de bucaneiro", "price": 400, "style": {"slops": true, "belts": true, "belt": true}},
	{"id": "Smooth_Male_Casual", "name": "Casaca de viagem", "price": 250, "style": {"skirt": true, "belt": true}},
	{"id": "Smooth_Female_Alternative", "name": "Casaca de corsária (como Anne Bonny)", "price": 450, "style": {"skirt": true, "facing": true, "belts": true, "belt": true}},
	{"id": "Smooth_Female_Casual", "name": "Corpete e saia longa", "price": 250, "style": {"petticoat": true, "belt": true}},
	{"id": "Smooth_Female_Dress", "name": "Vestido de capitã", "price": 500, "style": {"apron": false}},
]
const COAT_COLORS := [
	["Preto", Color(0.09, 0.08, 0.08)], ["Vermelho", Color(0.55, 0.08, 0.07)], ["Azul-marinho", Color(0.07, 0.12, 0.32)],
	["Verde-escuro", Color(0.1, 0.28, 0.14)], ["Bordô", Color(0.36, 0.07, 0.14)], ["Marrom", Color(0.34, 0.21, 0.11)],
	["Branco", Color(0.86, 0.83, 0.76)], ["Dourado", Color(0.62, 0.46, 0.15)],
]
const HATS := [
	{"name": "Sem chapéu", "price": 0}, {"name": "Tricórnio", "price": 200}, {"name": "Lenço pirata", "price": 80},
	{"name": "Chapéu de abas largas", "price": 150}, {"name": "Bicórnio de almirante", "price": 600},
	{"name": "Touca de linho", "price": 40},
]
const MUSKETS := [
	{"name": "Mosquete comum", "price": 0, "reload": 2.6, "acc": 0.72, "range": 45.0},
	{"name": "Par de pistolas", "price": 1200, "reload": 1.5, "acc": 0.62, "range": 28.0},
	{"name": "Mosquete de precisão", "price": 1800, "reload": 3.4, "acc": 0.93, "range": 75.0},
]
const SKIN_TONES := [Color(0.93, 0.76, 0.62), Color(0.8, 0.6, 0.45), Color(0.62, 0.43, 0.29), Color(0.42, 0.28, 0.18), Color(0.3, 0.2, 0.13)]
const HAIR := [Color(0.1, 0.07, 0.05), Color(0.3, 0.18, 0.08), Color(0.55, 0.38, 0.18), Color(0.75, 0.62, 0.35), Color(0.5, 0.5, 0.5)]
const CLOTH := [Color(0.75, 0.7, 0.58), Color(0.45, 0.3, 0.2), Color(0.3, 0.35, 0.5), Color(0.6, 0.2, 0.15), Color(0.86, 0.82, 0.74),
	Color(0.35, 0.45, 0.3), Color(0.55, 0.5, 0.35), Color(0.5, 0.25, 0.4), Color(0.25, 0.3, 0.35), Color(0.65, 0.55, 0.3)]
## Peças de roupa de cada modelo que recebem a cor principal (casaca/vestido) e a secundária (calça).
const COAT_SLOTS := ["Shirt", "Jacket", "LightJacket", "Dress"]
const PANTS_SLOTS := ["Pants"]
const STOCKING := Color(0.86, 0.84, 0.78)


## Pessoa animada. kind: "homem", "mulher", "oficial" ou "capitao".
## opts: "file", "coat", "pants", "skin", "hair" (Color), "hat" (int), "musket" (bool).
## Retorna {"root", "ap", "pre", "cur", "model"}.
static func person(kind: String, rng: RandomNumberGenerator, opts := {}) -> Dictionary:
	var file := OFFICER
	if opts.has("file"):
		file = opts["file"]
	elif kind == "homem":
		file = PEOPLE_M[rng.randi() % PEOPLE_M.size()]
	elif kind == "mulher":
		file = PEOPLE_F[rng.randi() % PEOPLE_F.size()]
	var root := Node3D.new()
	var model: Node3D = scene("res://assets/people/%s.fbx" % file).instantiate()
	var sc := PERSON_SCALE * (1.0 if kind == "capitao" else rng.randf_range(0.94, 1.05))
	model.scale = Vector3.ONE * sc
	model.rotation.y = PI   # o modelo olha para +Z; no jogo a frente é -Z
	root.add_child(model)
	# cores: moradores recebem roupas e tons de pele variados
	var colors := {}
	if kind == "homem" or kind == "mulher":
		colors["coat"] = CLOTH[rng.randi() % CLOTH.size()]
		colors["pants"] = CLOTH[rng.randi() % CLOTH.size()].darkened(0.35)
		colors["skin"] = SKIN_TONES[rng.randi() % SKIN_TONES.size()]
		colors["hair"] = HAIR[rng.randi() % HAIR.size()]
	colors.merge(opts, true)
	_dress(model, colors)
	if (kind == "homem" or kind == "mulher") and not opts.has("style") and not opts.has("file"):
		var st := {}
		if file.contains("Female"):
			if file != "Smooth_Female_Dress":
				st["petticoat"] = CLOTH[rng.randi() % CLOTH.size()].darkened(0.1)
			st["apron"] = rng.randf() < 0.5
			if file == "Smooth_Female_Dress" and st["apron"]:
				st["petticoat"] = colors["coat"]
			if rng.randf() < 0.6:
				opts["hat"] = 5
		else:
			if rng.randf() < 0.65:
				st["skirt"] = colors["coat"]
			st["belt"] = Color(0.18, 0.12, 0.07)
			if rng.randf() < 0.55:
				opts["hat"] = [1, 3, 3][rng.randi() % 3]
		opts["style"] = st
	var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	_fix_loops(ap)
	var pre := "HumanArmature|Female_" if file.contains("Female") else "HumanArmature|Man_"
	var p := {"root": root, "ap": ap, "pre": pre, "cur": "", "model": model}
	var hat := int(opts.get("hat", 0))
	if hat > 0:
		attach(p, "Head", hat_mesh(hat), Vector3(0, 0.155, 0.01), sc)
	if opts.has("style"):
		Attire.apply(p, opts["style"])
	if opts.get("musket", false):
		var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
		var rig := MusketRig.new()
		sk.add_child(rig)
		rig.setup(root, sk)
		p["rig"] = rig
	play(p, "Idle")
	ap.seek(rng.randf() * 2.0, true)
	return p


static func _dress(model: Node3D, colors: Dictionary) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = mi.mesh
		for s in m.get_surface_count():
			var mat: Material = m.surface_get_material(s)
			if mat == null:
				continue
			var nm := mat.resource_name
			var c: Variant = null
			if nm in COAT_SLOTS and colors.has("coat"):
				c = colors["coat"]
				if nm == "LightJacket" or nm == "Shirt2":
					c = (c as Color).lightened(0.2)
			elif nm in PANTS_SLOTS and colors.has("pants"):
				c = colors["pants"]
			elif nm == "Skin" and colors.has("skin"):
				c = colors["skin"]
			elif (nm == "Hair" or nm == "Hair2" or nm == "HairBase") and colors.has("hair"):
				c = colors["hair"]
			elif nm == "TieTexture" and colors.has("tie"):
				c = colors["tie"]
			elif nm == "Socks":
				c = colors.get("socks", STOCKING)
			elif nm == "Shoes":
				c = Color(0.1, 0.07, 0.05)
			elif nm == "Shirt2" and colors.has("coat"):
				c = (colors["coat"] as Color).lightened(0.25)
			if c != null:
				mi.set_surface_override_material(s, _tinted(mat, c))


static func _tinted(mat: Material, c: Color) -> Material:
	var key := "%d_%s" % [mat.get_instance_id(), c.to_html()]
	if not _mats.has(key):
		var nm: Material = mat.duplicate()
		if nm is BaseMaterial3D:
			(nm as BaseMaterial3D).albedo_color = c
			(nm as BaseMaterial3D).albedo_texture = null
		_mats[key] = nm
	return _mats[key]


## Prende uma malha a um osso (chapéu na cabeça, mosquete na mão), compensando a escala do esqueleto.
static func attach(p: Dictionary, bone: String, m: Mesh, offset: Vector3, model_scale: float, rot := Basis()) -> void:
	var sk: Skeleton3D = p["model"].find_children("*", "Skeleton3D", true, false)[0]
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	sk.add_child(ba)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var k := 1.0 / (100.0 * model_scale)
	mi.basis = rot.scaled(Vector3.ONE * k)
	mi.position = offset * k
	ba.add_child(mi)
	p[bone] = mi


static func hat_mesh(kind: int) -> Mesh:
	var key := "hat_%d" % kind
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_normal(Vector3.UP)
	var black := Color(0.06, 0.05, 0.05)
	var gold := Color(0.85, 0.65, 0.2)
	match kind:
		1:  # tricórnio: aba de três pontas viradas para cima
			_brim(st, func(a: float) -> float: return 0.2 + 0.05 * cos(3.0 * a), 0.07, black, gold)
			ShipBuilder._tube(st, Vector3(0, 0.0, 0), Vector3(0, 0.11, 0), 0.115, 0.1, black, 10)
		2:  # lenço
			Island._sphere(st, Vector3(0, 0.03, -0.015), Vector3(0.118, 0.085, 0.125), Color(0.65, 0.1, 0.08), 9, 5)
			Island._sphere(st, Vector3(0, -0.01, -0.13), Vector3(0.04, 0.04, 0.05), Color(0.65, 0.1, 0.08), 5, 3)
		3:  # abas largas
			_brim(st, func(a: float) -> float: return 0.25, 0.02, Color(0.3, 0.2, 0.12), Color(0.25, 0.16, 0.1))
			ShipBuilder._tube(st, Vector3(0, 0.0, 0), Vector3(0, 0.13, 0), 0.12, 0.105, Color(0.3, 0.2, 0.12), 10)
			ShipBuilder._tube(st, Vector3(0, 0.0, 0), Vector3(0, 0.03, 0), 0.122, 0.122, Color(0.12, 0.08, 0.05), 10)
		5:  # touca de linho (coif)
			Island._sphere(st, Vector3(0, 0.02, 0.015), Vector3(0.125, 0.1, 0.13), Color(0.94, 0.93, 0.88), 9, 5)
			ShipBuilder._tube(st, Vector3(0, -0.02, -0.11), Vector3(0, 0.06, -0.12), 0.02, 0.02, Color(0.94, 0.93, 0.88), 6)
		6:  # tricórnio de soldado (galão branco)
			_brim(st, func(a: float) -> float: return 0.2 + 0.05 * cos(3.0 * a), 0.07, black, Color(0.93, 0.92, 0.88))
			ShipBuilder._tube(st, Vector3(0, 0.0, 0), Vector3(0, 0.11, 0), 0.115, 0.1, black, 10)
		4:  # bicórnio: meia-lua atravessada, com galão dourado
			for side in [-1.0, 1.0]:
				var q := [Vector3(-0.24, 0.0, 0.0), Vector3(0.24, 0.0, 0.0), Vector3(0.0, 0.17, side * 0.02)]
				st.set_color(black)
				st.set_normal(Vector3(0, 0, side))
				for v in ([q[0], q[1], q[2]] if side > 0 else [q[0], q[2], q[1]]):
					st.add_vertex(v)
			ShipBuilder._tube(st, Vector3(-0.24, 0.0, 0), Vector3(0.24, 0.0, 0), 0.02, 0.02, gold, 5)
			Island._sphere(st, Vector3(0.0, 0.1, 0.03), Vector3(0.03, 0.03, 0.01), gold, 6, 3)
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.8
	m.surface_set_material(0, mat)
	_meshes[key] = m
	return m


static func _brim(st: SurfaceTool, radius: Callable, lift: float, c: Color, trim: Color) -> void:
	var n := 24
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var r0: float = radius.call(a0)
		var r1: float = radius.call(a1)
		var p0 := Vector3(cos(a0) * r0, lift * (r0 - 0.15) / 0.1, sin(a0) * r0)
		var p1 := Vector3(cos(a1) * r1, lift * (r1 - 0.15) / 0.1, sin(a1) * r1)
		var i0 := Vector3(cos(a0) * 0.11, 0.0, sin(a0) * 0.11)
		var i1 := Vector3(cos(a1) * 0.11, 0.0, sin(a1) * 0.11)
		st.set_color(c)
		st.set_normal(Vector3.UP)
		for v in [i0, p0, p1, i0, p1, i1]:
			st.add_vertex(v)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var r0: float = radius.call(a0)
		var r1: float = radius.call(a1)
		ShipBuilder._tube(st, Vector3(cos(a0) * r0, lift * (r0 - 0.15) / 0.1, sin(a0) * r0), Vector3(cos(a1) * r1, lift * (r1 - 0.15) / 0.1, sin(a1) * r1), 0.008, 0.008, trim, 3)


## Mosquete de pederneira (~1,45 m), segurado pelo meio; o eixo Y acompanha o osso da mão.
static func musket_mesh() -> Mesh:
	if _meshes.has("musket"):
		return _meshes["musket"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := Color(0.36, 0.2, 0.1)
	var iron := Color(0.18, 0.18, 0.2)
	ShipBuilder._box(st, Transform3D(Basis(), Vector3(0, -0.35, 0.02)), Vector3(0.045, 0.75, 0.07), wood)
	ShipBuilder._box(st, Transform3D(Basis(Vector3(1, 0, 0), 0.25), Vector3(0, -0.78, 0.05)), Vector3(0.05, 0.25, 0.12), wood)
	ShipBuilder._tube(st, Vector3(0, -0.1, 0.0), Vector3(0, 0.68, 0.0), 0.016, 0.013, iron, 6)
	ShipBuilder._box(st, Transform3D(Basis(), Vector3(0, -0.12, 0.04)), Vector3(0.03, 0.08, 0.03), iron)
	ShipBuilder._tube(st, Vector3(0, 0.68, 0.0), Vector3(0, 0.88, 0.0), 0.006, 0.002, Color(0.75, 0.75, 0.78), 4)
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.6
	m.surface_set_material(0, mat)
	_meshes["musket"] = m
	return m


## O capitão, com a roupa, a cor, o chapéu e a arma escolhidos pelo jogador.
static func captain(rng: RandomNumberGenerator, with_musket := true) -> Dictionary:
	var o: Dictionary = OUTFITS[clampi(Game.outfit, 0, OUTFITS.size() - 1)]
	var coat: Color = COAT_COLORS[clampi(Game.coat_color, 0, COAT_COLORS.size() - 1)][1]
	var st := {}
	var os: Dictionary = o["style"]
	if os.get("skirt", false):
		st["skirt"] = coat
	if os.get("facing", false):
		st["facing"] = Color(0.85, 0.68, 0.25) if coat.v < 0.5 else Color(0.1, 0.1, 0.12)
	if os.get("cravat", false):
		st["cravat"] = true
	if os.get("sash", false):
		st["sash"] = Color(0.6, 0.08, 0.12)
	if os.get("slops", false):
		st["slops"] = Color(0.88, 0.86, 0.8)
	if os.get("belts", false):
		st["belts"] = true
	if os.get("belt", false):
		st["belt"] = Color(0.2, 0.13, 0.07)
	if os.get("petticoat", false):
		st["petticoat"] = coat.darkened(0.2)
	var opts := {"file": o["id"], "coat": coat, "pants": Color(0.18, 0.16, 0.14), "hat": Game.hat, "musket": with_musket, "style": st}
	return person("capitao", rng, opts)


## Uniforme de soldado/guarda de uma nação (início do século XVIII): casaca comprida com vistas coloridas,
## colete, calção, talabarte, tricórnio com galão e mosquete. Piratas e marujos usam camisa, colete e calções largos.
static func soldier(nation: int, rng: RandomNumberGenerator, officer := false) -> Dictionary:
	if nation == Game.PIR or not Attire.UNIFORMS.has(nation):
		var shirt: Color = [Color(0.9, 0.88, 0.82), Color(0.75, 0.72, 0.65), Color(0.55, 0.15, 0.12), Color(0.3, 0.32, 0.4)][rng.randi() % 4]
		return person("homem", rng, {"file": ["Smooth_Male_Shirt", "Smooth_Male_LongSleeve"][rng.randi() % 2], "hat": [2, 3, 0][rng.randi() % 3],
			"musket": true, "coat": shirt, "pants": Color(0.3, 0.25, 0.2), "skin": SKIN_TONES[rng.randi() % SKIN_TONES.size()],
			"style": {"slops": Color(0.86, 0.84, 0.78) if rng.randf() < 0.6 else Color(0.35, 0.3, 0.25), "belts": true, "belt": Color(0.2, 0.13, 0.07)}})
	var u: Dictionary = Attire.UNIFORMS[nation]
	var st := {"skirt": u["coat"], "facing": u["facing"], "belts": not officer, "belt": Attire.BUFF if not officer else Color(0.15, 0.1, 0.06)}
	if officer:
		st["sash"] = Color(0.6, 0.08, 0.12) if nation != Game.FRA else Color(0.85, 0.85, 0.85)
		st["cravat"] = true
	return person("oficial", rng, {"coat": u["coat"], "pants": u["breeches"], "tie": u["waist"],
		"skin": SKIN_TONES[rng.randi() % SKIN_TONES.size()], "hat": 1 if officer else 6, "musket": not officer, "style": st})


## Posição do mosquete (MusketRig.CARRY, ORDER, AIM ou NONE).
static func musket_pose(p: Dictionary, mode: int) -> void:
	if p.has("rig") and is_instance_valid(p["rig"]) and p["rig"].mode != mode:
		p["rig"].set_mode(mode)


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
			"fountain-round", "lantern", "cart", "banner-red", "banner-green", "wall-doorway-round", "overhang", "wall-window-round", "roof", "fountain-center"]],
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
