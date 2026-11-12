class_name Assets
extends RefCounted
## Modelos 3D prontos (licença CC0): personagens realistas ("Universal Base Characters") e cavalo da Quaternius,
## peças de cidade, kit pirata e natureza da Kenney. Ver assets/CREDITOS.md.

const HUMAN_M := "res://assets/humans/humano_m.glb"   # 1,81 m, 27 animações
const HUMAN_F := "res://assets/humans/humano_f.glb"   # 1,77 m, usa as animações do homem
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
			if low.ends_with("walk") or low.ends_with("run") or low.ends_with("idle") or low.ends_with("loop") or low.ends_with("gallop"):
				a.loop_mode = Animation.LOOP_LINEAR
			elif an.begins_with("Death") or an.begins_with("Hit") or an.begins_with("Sword") or an.begins_with("Punch"):
				a.loop_mode = Animation.LOOP_NONE


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
const SKIN_TONES := [Color(0.8, 0.62, 0.48), Color(0.72, 0.53, 0.38), Color(0.6, 0.42, 0.29), Color(0.45, 0.3, 0.2), Color(0.32, 0.21, 0.14)]
const HAIR := [Color(0.1, 0.07, 0.05), Color(0.3, 0.18, 0.08), Color(0.55, 0.38, 0.18), Color(0.75, 0.62, 0.35), Color(0.5, 0.5, 0.5)]
const CLOTH := [Color(0.75, 0.7, 0.58), Color(0.45, 0.3, 0.2), Color(0.3, 0.35, 0.5), Color(0.6, 0.2, 0.15), Color(0.86, 0.82, 0.74),
	Color(0.35, 0.45, 0.3), Color(0.55, 0.5, 0.35), Color(0.5, 0.25, 0.4), Color(0.25, 0.3, 0.35), Color(0.65, 0.55, 0.3)]
## Peças de roupa de cada modelo que recebem a cor principal (casaca/vestido) e a secundária (calça).
const COAT_SLOTS := ["Shirt", "Jacket", "LightJacket", "Dress"]
const PANTS_SLOTS := ["Pants"]
const STOCKING := Color(0.86, 0.84, 0.78)


## Roupa-base de cada "look" (cores por região do corpo; null = pele à mostra).
## Regiões: torso, arm (braço), fore (antebraço), front (frente do colete), breeches, stock (meia), shoe, neck.
const FILE_LOOK := {"Smooth_Male_Suit": "casaca", "Smooth_Male_Shirt": "colete", "Smooth_Male_LongSleeve": "camisa",
	"Smooth_Male_Casual": "casaca", "Smooth_Female_Dress": "vestido", "Smooth_Female_Casual": "corpete",
	"Smooth_Female_Alternative": "casaca_f"}
const LINEN := Color(0.9, 0.88, 0.82)
const HUMAN_ANIMS := {"Run": "Jog_Fwd", "Death": "Death01", "Sitting": "Sitting_Idle", "Clapping": "Idle_Talking",
	"Punch": "Punch_Jab", "Sword": "Sword_Regular_A", "Sword2": "Sword_Regular_B", "SwordIdle": "Sword_Idle",
	"Block": "Sword_Block", "Hit": "Hit_Chest", "Drink": "Consume", "Arms": "Idle_FoldArms", "Rail": "Idle_Rail",
	"Lantern": "Idle_Lantern", "Talk": "Idle_Talking"}
const SKIN_REF := Color(0.69, 0.52, 0.36)
static var _lib: AnimationLibrary
static var _body_shader: Shader


static func _clothes(look: String, coat: Color, pants: Color, waist: Color, rng: RandomNumberGenerator) -> Dictionary:
	var dark_shoe := Color(0.07, 0.055, 0.05)
	var c := {"torso": coat, "arm": coat, "fore": coat, "front": waist, "breeches": pants, "stock": STOCKING, "shoe": dark_shoe,
		"neck": LINEN, "loose": Vector3(0.016, 0.016, 0.012)}
	match look:
		"camisa":
			# camisa larga de linho, gola aberta; manga arregaçada e pés descalços às vezes
			c["front"] = coat
			c["neck"] = null
			c["loose"] = Vector3(0.026, 0.032, 0.014)
			if rng.randf() < 0.5:
				c["fore"] = null
			if rng.randf() < 0.45:
				c["stock"] = null
				if rng.randf() < 0.5:
					c["shoe"] = null
			else:
				c["stock"] = Color(0.55, 0.53, 0.5)
		"colete":
			c["arm"] = LINEN
			c["fore"] = LINEN if rng.randf() < 0.5 else null
			c["front"] = coat.darkened(0.08)
			c["neck"] = LINEN if rng.randf() < 0.5 else null
			c["stock"] = Color(0.6, 0.58, 0.54)
			c["shoe"] = Color(0.22, 0.13, 0.07)
			c["loose"] = Vector3(0.018, 0.03, 0.013)
		"corpete":
			c["arm"] = LINEN
			c["fore"] = null
			c["front"] = coat.lightened(0.25)
			c["neck"] = null
			c["loose"] = Vector3(0.01, 0.022, 0.012)
		"vestido":
			c["fore"] = LINEN
			c["front"] = coat.lightened(0.3)
			c["neck"] = null
			c["loose"] = Vector3(0.01, 0.016, 0.012)
		"casaca_f":
			c["front"] = LINEN
			c["stock"] = Color(0.2, 0.12, 0.07)
			c["shoe"] = Color(0.16, 0.1, 0.06)
	return c


static func _anim_library() -> AnimationLibrary:
	if _lib == null:
		var m: Node = scene(HUMAN_M).instantiate()
		var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
		_fix_loops(ap)
		_lib = ap.get_animation_library("")
		m.free()
	return _lib


static func _body_material(female: bool, skin: Color, cl: Dictionary) -> ShaderMaterial:
	var key := "body%s%s%s" % [female, skin.to_html(), cl["loose"]]
	for r in ["torso", "arm", "fore", "front", "breeches", "stock", "shoe", "neck"]:
		key += "|" + (cl[r].to_html() if cl[r] != null else "-")
	if _mats.has(key):
		return _mats[key]
	if _body_shader == null:
		_body_shader = load("res://shaders/person.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _body_shader
	var tag := "f" if female else "m"
	m.set_shader_parameter("tex_albedo", load("res://assets/humans/corpo_%s_cor.jpg" % tag))
	m.set_shader_parameter("tex_normal", load("res://assets/humans/corpo_%s_normal.png" % tag))
	var sl := skin.srgb_to_linear()
	var rl := SKIN_REF.srgb_to_linear()
	m.set_shader_parameter("skin_mul", Vector3(sl.r / rl.r, sl.g / rl.g, sl.b / rl.b))
	m.set_shader_parameter("loose", cl["loose"])
	m.set_shader_parameter("m1", Vector4(0.17, 0.392, 0.625, 0.98) if female else Vector4(0.2, 0.463, 0.69, 0.99))
	m.set_shader_parameter("m2", Vector4(0.465, 0.105, 1.38, 1.53) if female else Vector4(0.47, 0.115, 1.48, 1.57))
	for r in [["torso", "c_torso"], ["arm", "c_arm"], ["fore", "c_fore"], ["front", "c_front"], ["breeches", "c_breeches"],
			["stock", "c_stock"], ["shoe", "c_shoe"], ["neck", "c_neck"]]:
		var v: Variant = cl[r[0]]
		m.set_shader_parameter(r[1], Color(v.r, v.g, v.b, 1.0) if v != null else Color(0, 0, 0, 0))
	_mats[key] = m
	return m


## Pessoa animada (modelo humano realista). kind: "homem", "mulher", "oficial" ou "capitao".
## opts: "file"/"look", "coat", "pants", "tie" (colete), "skin", "hair" (Color), "hair_style" (int), "hat" (int),
## "musket" (bool), "bayonet" (bool), "style" (peças por cima: ver Attire.apply).
## Retorna {"root", "ap", "pre", "cur", "model", "sk", "female"}.
static func person(kind: String, rng: RandomNumberGenerator, opts := {}) -> Dictionary:
	var file: String = opts.get("file", "")
	var female := kind == "mulher" or file.contains("Female")
	var look: String = opts.get("look", FILE_LOOK.get(file, ""))
	if look == "":
		if female:
			look = "corpete" if rng.randf() < 0.7 else "vestido"
		elif kind == "homem":
			look = ["camisa", "colete", "colete", "casaca"][rng.randi() % 4]
		else:
			look = "casaca"
	var root := Node3D.new()
	var model: Node3D = scene(HUMAN_F if female else HUMAN_M).instantiate()
	var sc := (1.0 if kind == "capitao" else rng.randf_range(0.95, 1.04))
	# físicos diferentes: magros, normais e mais corpulentos
	var build := 1.0 if kind == "capitao" else rng.randf_range(0.92, 1.1)
	model.scale = Vector3(sc * build, sc, sc * build)
	model.rotation.y = PI   # o modelo olha para +Z; no jogo a frente é -Z
	if female:
		model.position.y = -0.017   # a mulher usa as animações do homem (bacia um pouco mais alta)
	root.add_child(model)
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	# cores
	var coat: Color = opts.get("coat", CLOTH[rng.randi() % CLOTH.size()])
	var pants: Color = opts.get("pants", CLOTH[rng.randi() % CLOTH.size()].darkened(0.35))
	var waist: Color = opts.get("tie", CLOTH[rng.randi() % CLOTH.size()] if kind != "capitao" else Color(0.72, 0.6, 0.4))
	var skin: Color = opts.get("skin", SKIN_TONES[rng.randi() % SKIN_TONES.size()])
	var hair_c: Color = opts.get("hair", HAIR[rng.randi() % HAIR.size()])
	if opts.get("wig", false):
		hair_c = Color(0.86, 0.85, 0.8)   # peruca empoada dos oficiais
	var cl := _clothes(look, coat, pants, waist, rng)
	# animações (a mulher usa a biblioteca do homem)
	var ap: AnimationPlayer
	var aps := model.find_children("*", "AnimationPlayer", true, false)
	if aps.is_empty():
		ap = AnimationPlayer.new()
		model.add_child(ap)
		ap.add_animation_library("", _anim_library())
	else:
		ap = aps[0]
		_fix_loops(ap)
	var p := {"root": root, "ap": ap, "pre": "", "cur": "", "model": model, "sk": sk, "female": female, "human": true}
	# cabelo e chapéu
	var hs: int = opts.get("hair_style", -1)
	if hs < 0:
		hs = ([2, 2, 3][rng.randi() % 3]) if female else ([1, 1, 0, 3][rng.randi() % 4])
		if kind == "oficial" or kind == "capitao":
			hs = 1 if not female else 3
	var style: Dictionary = opts.get("style", {})
	if (kind == "homem" or kind == "mulher") and not opts.has("style") and not opts.has("file"):
		style = {}
		if female:
			if look == "corpete" or rng.randf() < 0.5:
				style["petticoat"] = CLOTH[rng.randi() % CLOTH.size()].darkened(0.1) if look == "corpete" else coat
			else:
				style["petticoat"] = coat
			style["apron"] = rng.randf() < 0.5
			if not opts.has("hat") and rng.randf() < 0.55:
				opts["hat"] = 5
		else:
			if look == "casaca":
				style["skirt"] = coat
			elif look == "camisa" and rng.randf() < 0.4:
				style["slops"] = LINEN.darkened(rng.randf() * 0.2)
			style["belt"] = Color(0.18, 0.12, 0.07)
			if not opts.has("hat") and rng.randf() < 0.55:
				opts["hat"] = [1, 3, 3, 2][rng.randi() % 4]
	if female and look == "vestido" and not style.has("petticoat"):
		style["petticoat"] = coat
	# por baixo da saia ou dos calções largos, a perna tem a mesma cor (nada "vaza" ao andar)
	if style.has("petticoat"):
		cl["breeches"] = style["petticoat"]
		cl["stock"] = (style["petticoat"] as Color).darkened(0.1)
	elif style.has("slops"):
		cl["breeches"] = style["slops"]
	for mi: MeshInstance3D in sk.find_children("*", "MeshInstance3D", true, false):
		mi.visibility_range_end = 170.0
		var mat: Material = mi.mesh.surface_get_material(0)
		var nm := mat.resource_name if mat else ""
		if nm.contains("Superhero"):
			mi.material_override = _body_material(female, skin, cl)
		elif nm.contains("Hair"):
			mi.material_override = _tinted_keep(mat, hair_c.lightened(0.1))
	var hat := int(opts.get("hat", 0))
	Attire.wear(p, "Head", Attire.hair(hs, hair_c, female), Attire.hair_material())
	if hat == 2:
		Attire.wear(p, "Head", Attire.bandana(Color(0.62, 0.1, 0.08) if rng.randf() < 0.6 else Color(0.15, 0.2, 0.45), female))
	elif hat == 5:
		Attire.wear(p, "Head", Attire.coif(female))
	elif hat > 0:
		var b: Dictionary = Attire.BODY[female]
		var sk_c: Vector3 = b["skull"]
		Attire.wear(p, "Head", hat_mesh(hat), null, Transform3D(Basis().scaled(Vector3.ONE * 0.9), Vector3(0, b["top"] - 0.065, sk_c.z)))
	Attire.apply(p, style)
	if opts.get("musket", false):
		var rig := MusketRig.new()
		sk.add_child(rig)
		rig.setup(root, sk, opts.get("bayonet", false))
		p["rig"] = rig
	play(p, "Idle")
	ap.seek(rng.randf() * 2.0, true)
	return p


static func _tinted_keep(mat: Material, c: Color) -> Material:
	var key := "k%d_%s" % [mat.get_instance_id(), c.to_html()]
	if not _mats.has(key):
		var nm: Material = mat.duplicate()
		if nm is BaseMaterial3D:
			(nm as BaseMaterial3D).albedo_color = c
		_mats[key] = nm
	return _mats[key]


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


## Mosquete de pederneira tipo "Brown Bess" (1,58 m): coronha de nogueira moldada, chapa de coice,
## guarda-mato e braçadeiras de latão, fecho com cão, pederneira, fuzil e caçoleta, vareta de ferro,
## bandoleira de couro e (opcional) baioneta de alvado. Eixo Y = da coronha (y = -0,9) para a boca (y = 0,68);
## +Z = parte de cima do cano, +X = lado do fecho (direita do atirador).
static func musket_mesh(bayonet := false) -> Mesh:
	var key := "musket_%s" % bayonet
	if _meshes.has(key):
		return _meshes[key]
	var wood := Color(0.33, 0.17, 0.08)
	var wood_dark := Color(0.24, 0.12, 0.06)
	var brass := Color(0.8, 0.62, 0.26)
	var iron := Color(0.2, 0.2, 0.22)
	var steel := Color(0.55, 0.56, 0.58)
	var leather := Color(0.45, 0.3, 0.16)
	var sw := SurfaceTool.new()   # madeira e couro
	sw.begin(Mesh.PRIMITIVE_TRIANGLES)
	sw.set_uv(Vector2.ZERO)
	var sm := SurfaceTool.new()   # metais
	sm.begin(Mesh.PRIMITIVE_TRIANGLES)
	sm.set_uv(Vector2.ZERO)
	# coronha: seções (y, topo z, base z, meia-largura)
	var stock := [
		[-0.9, -0.045, -0.178, 0.021], [-0.86, -0.04, -0.172, 0.024], [-0.78, -0.033, -0.145, 0.023],
		[-0.7, -0.026, -0.112, 0.02], [-0.64, -0.02, -0.08, 0.017], [-0.59, -0.016, -0.06, 0.0155],
		[-0.54, -0.006, -0.058, 0.019], [-0.46, -0.004, -0.054, 0.021], [-0.34, -0.004, -0.046, 0.02],
		[-0.26, -0.006, -0.038, 0.016], [-0.1, -0.007, -0.034, 0.0145], [0.3, -0.008, -0.031, 0.014], [0.58, -0.008, -0.029, 0.013]]
	_loft(sw, stock, wood, 12)
	# pente (comb) mais escuro na parte de cima da coronha
	_loft(sw, [[-0.88, -0.041, -0.06, 0.017], [-0.72, -0.027, -0.05, 0.014], [-0.66, -0.022, -0.045, 0.012]], wood_dark, 8)
	# chapa de coice de latão e ponteira do guarda-mão
	_loft(sm, [[-0.905, -0.043, -0.18, 0.0225], [-0.892, -0.043, -0.18, 0.0225]], brass, 12)
	ShipBuilder._box(sm, Transform3D(Basis(), Vector3(0, -0.85, -0.042)), Vector3(0.012, 0.09, 0.006), brass)
	_loft(sm, [[0.58, -0.006, -0.031, 0.0145], [0.61, -0.006, -0.03, 0.0135]], brass, 10)
	# cano (sai da coronha e vai até a boca), com reforço na culatra e anel na boca
	ShipBuilder._tube(sm, Vector3(0, -0.52, 0.0), Vector3(0, -0.3, 0.0), 0.0165, 0.0155, iron, 12)
	ShipBuilder._tube(sm, Vector3(0, -0.3, 0.0), Vector3(0, 0.68, 0.0), 0.0155, 0.0118, iron, 12)
	ShipBuilder._tube(sm, Vector3(0, 0.665, 0.0), Vector3(0, 0.68, 0.0), 0.0128, 0.0128, iron, 12)
	_disc(sm, Vector3(0, 0.68, 0), 0.0128, Color(0.03, 0.03, 0.03))
	ShipBuilder._box(sm, Transform3D(Basis(), Vector3(0, 0.645, 0.013)), Vector3(0.004, 0.012, 0.006), brass)   # massa de mira
	ShipBuilder._box(sm, Transform3D(Basis(), Vector3(0, -0.6, -0.012)), Vector3(0.012, 0.12, 0.004), iron)      # espiga da culatra
	# vareta de ferro sob o cano, com 3 passadores de latão
	ShipBuilder._tube(sm, Vector3(0, -0.28, -0.036), Vector3(0, 0.672, -0.036), 0.0045, 0.0045, steel, 6)
	ShipBuilder._tube(sm, Vector3(0, 0.668, -0.036), Vector3(0, 0.682, -0.036), 0.007, 0.006, steel, 6)
	for y in [0.0, 0.3, 0.55]:
		ShipBuilder._tube(sm, Vector3(0, y - 0.025, -0.036), Vector3(0, y + 0.025, -0.036), 0.0075, 0.0075, brass, 8)
	# fecho de pederneira (lado direito): chapa, cão com pederneira, fuzil (bateria) e caçoleta
	var lx := 0.021
	_loft(sm, [[-0.48, -0.006, -0.036, 0.0], [-0.46, -0.004, -0.04, 0.0], [-0.36, -0.004, -0.036, 0.0], [-0.34, -0.008, -0.03, 0.0]], iron, 4, lx + 0.003)
	var cock := Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(lx + 0.009, -0.44, 0.004))
	ShipBuilder._box(sm, cock, Vector3(0.006, 0.05, 0.012), iron)
	ShipBuilder._box(sm, Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(lx + 0.009, -0.425, 0.026)), Vector3(0.01, 0.022, 0.012), iron)   # mandíbulas
	ShipBuilder._box(sm, Transform3D(Basis(), Vector3(lx + 0.009, -0.411, 0.03)), Vector3(0.012, 0.012, 0.006), Color(0.3, 0.3, 0.32))  # pederneira
	ShipBuilder._box(sm, Transform3D(Basis(Vector3.RIGHT, 0.15), Vector3(lx + 0.009, -0.392, 0.024)), Vector3(0.012, 0.004, 0.032), steel)  # fuzil
	ShipBuilder._box(sm, Transform3D(Basis(), Vector3(lx + 0.007, -0.392, 0.005)), Vector3(0.014, 0.022, 0.008), iron)   # caçoleta
	ShipBuilder._tube(sm, Vector3(lx + 0.004, -0.37, -0.02), Vector3(lx + 0.004, -0.355, -0.02), 0.006, 0.006, iron, 6)  # mola
	# contraplaca de latão do lado esquerdo
	ShipBuilder._box(sm, Transform3D(Basis(), Vector3(-0.0215, -0.41, -0.024)), Vector3(0.003, 0.12, 0.012), brass)
	# guarda-mato e gatilho
	var guard := [Vector3(0, -0.58, -0.062), Vector3(0, -0.545, -0.088), Vector3(0, -0.5, -0.094), Vector3(0, -0.455, -0.085), Vector3(0, -0.43, -0.058)]
	for i in guard.size() - 1:
		ShipBuilder._tube(sm, guard[i], guard[i + 1], 0.0045, 0.0045, brass, 6)
	ShipBuilder._box(sm, Transform3D(Basis(), Vector3(0, -0.51, -0.058)), Vector3(0.008, 0.16, 0.005), brass)
	ShipBuilder._tube(sm, Vector3(0, -0.495, -0.056), Vector3(0, -0.505, -0.08), 0.0035, 0.0025, iron, 5)
	# bandoleira de couro (passador do guarda-mato até o guarda-mão), um pouco frouxa
	var sl := [Vector3(0, -0.47, -0.095), Vector3(0, -0.2, -0.105), Vector3(0, 0.05, -0.098), Vector3(0, 0.18, -0.04)]
	for i in sl.size() - 1:
		ShipBuilder._box(sw, _seg_xf(sl[i], sl[i + 1]), Vector3(0.024, sl[i].distance_to(sl[i + 1]), 0.003), leather)
	ShipBuilder._tube(sm, Vector3(-0.012, 0.18, -0.036), Vector3(0.012, 0.18, -0.036), 0.008, 0.008, brass, 6)
	if bayonet:
		# alvado em volta da boca e lâmina triangular deslocada para o lado
		ShipBuilder._tube(sm, Vector3(0, 0.6, 0.0), Vector3(0, 0.68, 0.0), 0.016, 0.016, steel, 10)
		ShipBuilder._box(sm, Transform3D(Basis(), Vector3(0.017, 0.672, 0.014)), Vector3(0.012, 0.016, 0.01), steel)
		var b0 := Vector3(0.024, 0.68, 0.022)
		var b1 := Vector3(0.024, 1.09, 0.026)
		sm.set_color(Color(0.72, 0.73, 0.75))
		var tri := [Vector3(0.0, 0, 0.0), Vector3(0.007, 0, 0.0), Vector3(0.0035, 0, 0.011)]
		for i in 3:
			var p0: Vector3 = b0 + tri[i] * 1.4
			var p1: Vector3 = b0 + tri[(i + 1) % 3] * 1.4
			var n := ((p1 - p0).cross(Vector3.UP)).normalized()
			sm.set_normal(n)
			for v in [p0, p1, b1, p0, b1, b1]:
				sm.add_vertex(v)
	var m := ArrayMesh.new()
	sw.commit(m)
	sm.commit(m)
	var mw := StandardMaterial3D.new()
	mw.vertex_color_use_as_albedo = true
	mw.vertex_color_is_srgb = true
	mw.roughness = 0.5
	mw.specular = 0.45
	mw.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mm := StandardMaterial3D.new()
	mm.vertex_color_use_as_albedo = true
	mm.vertex_color_is_srgb = true
	mm.metallic = 0.75
	mm.roughness = 0.32
	mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.surface_set_material(0, mw)
	m.surface_set_material(1, mm)
	_meshes[key] = m
	return m


static func _seg_xf(a: Vector3, b: Vector3) -> Transform3D:
	var y := (b - a).normalized()
	var x := Vector3.RIGHT
	var z := x.cross(y).normalized()
	return Transform3D(Basis(x, y, z), (a + b) * 0.5)


## Superfície "lofted" por seções arredondadas ao longo de Y: [y, topo z, base z, meia-largura].
## Com x_plate > 0 vira uma chapa plana no lado direito (x = x_plate).
static func _loft(st: SurfaceTool, secs: Array, c: Color, seg := 12, x_plate := 0.0) -> void:
	st.set_color(c)
	var rings := []
	for s in secs:
		var ring := []
		var mz: float = (s[1] + s[2]) * 0.5
		var hz: float = (s[1] - s[2]) * 0.5
		for i in seg:
			var a := TAU * i / seg
			var ca := cos(a)
			var sa := sin(a)
			var x: float = s[3] * signf(ca) * pow(absf(ca), 0.7)
			var z: float = mz + hz * signf(sa) * pow(absf(sa), 0.7)
			if x_plate > 0.0:
				x = x_plate + 0.002 * ca
			ring.append(Vector3(x, s[0], z))
		rings.append(ring)
	for r in rings.size() - 1:
		for i in seg:
			var j := (i + 1) % seg
			var a: Vector3 = rings[r][i]
			var b: Vector3 = rings[r][j]
			var c2: Vector3 = rings[r + 1][j]
			var d: Vector3 = rings[r + 1][i]
			var n := (b - a).cross(d - a).normalized()
			if n.dot(Vector3(a.x, 0, a.z - (secs[r][1] + secs[r][2]) * 0.5)) < 0.0:
				n = -n
				st.set_normal(n)
				for v in [a, c2, b, a, d, c2]:
					st.add_vertex(v)
			else:
				st.set_normal(n)
				for v in [a, b, c2, a, c2, d]:
					st.add_vertex(v)
	# tampas nas pontas
	for e in [0, rings.size() - 1]:
		var ctr := Vector3.ZERO
		for v in rings[e]:
			ctr += v
		ctr /= seg
		var n := Vector3.DOWN if e == 0 else Vector3.UP
		st.set_normal(n)
		for i in seg:
			var a: Vector3 = rings[e][i]
			var b: Vector3 = rings[e][(i + 1) % seg]
			for v in ([ctr, b, a] if e == 0 else [ctr, a, b]):
				st.add_vertex(v)


static func _disc(st: SurfaceTool, c: Vector3, r: float, col: Color) -> void:
	st.set_color(col)
	st.set_normal(Vector3.UP)
	for i in 10:
		var a0 := TAU * i / 10
		var a1 := TAU * (i + 1) / 10
		for v in [c, c + Vector3(cos(a1) * r, 0.001, sin(a1) * r), c + Vector3(cos(a0) * r, 0.001, sin(a0) * r)]:
			st.add_vertex(v)


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
	var opts := {"file": o["id"], "coat": coat, "skin": SKIN_TONES[1], "hair": HAIR[1], "pants": Color(0.18, 0.16, 0.14), "hat": Game.hat, "musket": with_musket, "style": st}
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
	return person("oficial", rng, {"coat": u["coat"], "pants": u["breeches"], "tie": u["waist"], "look": "casaca", "wig": officer, "hair_style": 1,
		"skin": SKIN_TONES[rng.randi() % SKIN_TONES.size()], "hat": 1 if officer else 6, "musket": not officer, "bayonet": true, "style": st})


## Posição do mosquete (MusketRig.CARRY, ORDER, AIM ou NONE).
static func musket_pose(p: Dictionary, mode: int) -> void:
	if p.has("rig") and is_instance_valid(p["rig"]) and p["rig"].mode != mode:
		p["rig"].set_mode(mode)


static func play(p: Dictionary, anim: String, speed := 1.0) -> void:
	var ap: AnimationPlayer = p["ap"]
	var full: String = p["pre"] + (HUMAN_ANIMS.get(anim, anim) if p.get("human", false) else anim)
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
	scene(HUMAN_M)
	scene(HUMAN_F)
	_anim_library()
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
