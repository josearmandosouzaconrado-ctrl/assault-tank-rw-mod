class_name TownLife
extends Node3D
## Vida na cidade: moradores andando pelas ruas, guardas, a pessoa especial (romance) e cavalos no estábulo.
## Também traz os construtores dos modelos de pessoa e de cavalo.

const SKINS := [Color(0.93, 0.76, 0.62), Color(0.78, 0.57, 0.4), Color(0.55, 0.38, 0.25), Color(0.38, 0.26, 0.17)]
const CLOTHES := [Color(0.75, 0.7, 0.6), Color(0.45, 0.3, 0.2), Color(0.3, 0.35, 0.5), Color(0.6, 0.2, 0.15),
	Color(0.85, 0.82, 0.75), Color(0.35, 0.45, 0.3), Color(0.55, 0.5, 0.35), Color(0.5, 0.25, 0.4)]

const LINES := [
	"Bom dia, capitão! O vento está bom para navegar hoje.",
	"Dizem que há um navio carregado de prata perto daqui.",
	"Cuidado com os piratas nas ilhotas do sul!",
	"A taverna tem o melhor rum das Antilhas. Experimente!",
	"Meu irmão se alistou na marinha... nunca mais voltou.",
	"O governador anda nervoso com a guerra.",
	"Se precisa de homens, a taverna está cheia de marujos sem trabalho.",
	"Já viu uma tempestade daquelas? Recolha as velas, capitão.",
	"O mercado paga bem por especiarias e tecidos.",
	"Há um velho bucaneiro na taverna que vende mapas de tesouro.",
	"Cavalos? O estábulo fica perto da praça.",
	"Com uma bandeira falsa você entra em qualquer porto... até disparar.",
]

var site: PortSite
var people: Array = []   # {"node", "legs", "arms", "target", "wait", "speed", "kind", "phase", "name"}
var horses: Array = []   # Horse
var special: Dictionary = {}
var alarm := false        # o jogador atirou numa cidade amiga
var _panic := 0.0
var _rng := RandomNumberGenerator.new()

static var _mat: StandardMaterial3D


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.roughness = 0.85
	return _mat


# ---------------------------------------------------------------- modelos
static func _part(st_builder: Callable) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_builder.call(st)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material()
	return mi


## Pessoa simples (≈1,75 m). Retorna {"root","leg_l","leg_r","arm_l","arm_r"}.
static func make_person(coat: Color, pants: Color, skin: Color, hat: int, musket := false, dress := false) -> Dictionary:
	var root := Node3D.new()
	var body := _part(func(st: SurfaceTool):
		if dress:
			ShipBuilder._tube(st, Vector3(0, 0.05, 0), Vector3(0, 1.05, 0), 0.42, 0.2, coat, 10)
		else:
			ShipBuilder._box(st, Transform3D(Basis(), Vector3(0, 0.82, 0)), Vector3(0.5, 0.36, 0.32), coat.darkened(0.08))
		ShipBuilder._box(st, Transform3D(Basis(), Vector3(0, 1.2, 0)), Vector3(0.46, 0.55, 0.28), coat)
		ShipBuilder._box(st, Transform3D(Basis(), Vector3(0, 0.98, 0)), Vector3(0.48, 0.07, 0.3), Color(0.2, 0.14, 0.08))
		Island._sphere(st, Vector3(0, 1.62, 0), Vector3(0.13, 0.15, 0.13), skin, 7, 5)
		match hat:
			1:  # tricórnio
				ShipBuilder._tube(st, Vector3(0, 1.72, 0), Vector3(0, 1.76, 0), 0.24, 0.24, Color(0.1, 0.08, 0.07), 3)
				ShipBuilder._tube(st, Vector3(0, 1.74, 0), Vector3(0, 1.86, 0), 0.13, 0.11, Color(0.1, 0.08, 0.07), 8)
			2:  # lenço
				Island._sphere(st, Vector3(0, 1.7, 0), Vector3(0.14, 0.08, 0.14), Color(0.7, 0.15, 0.12), 7, 4)
			3:  # chapéu de palha
				ShipBuilder._tube(st, Vector3(0, 1.72, 0), Vector3(0, 1.74, 0), 0.3, 0.3, Color(0.85, 0.75, 0.45), 10)
				ShipBuilder._tube(st, Vector3(0, 1.73, 0), Vector3(0, 1.85, 0), 0.14, 0.12, Color(0.85, 0.75, 0.45), 8)
			4:  # cabelo longo
				Island._sphere(st, Vector3(0, 1.62, 0.04), Vector3(0.15, 0.2, 0.15), Color(0.25, 0.15, 0.08), 7, 4)
		if musket:
			ShipBuilder._box(st, Transform3D(Basis(Vector3(1, 0, 0), 0.15), Vector3(0.3, 1.3, -0.05)), Vector3(0.05, 1.4, 0.06), Color(0.3, 0.2, 0.1))
		)
	root.add_child(body)
	var parts := {"root": root}
	for side in [-1.0, 1.0]:
		var leg_pivot := Node3D.new()
		leg_pivot.position = Vector3(side * 0.11, 0.92, 0)
		var leg := _part(func(st: SurfaceTool):
			if not dress:
				ShipBuilder._box(st, Transform3D(Basis(), Vector3(0, -0.4, 0)), Vector3(0.15, 0.8, 0.17), pants)
			ShipBuilder._box(st, Transform3D(Basis(), Vector3(0, -0.85, -0.04)), Vector3(0.15, 0.14, 0.26), Color(0.12, 0.08, 0.05))
			)
		leg_pivot.add_child(leg)
		root.add_child(leg_pivot)
		var arm_pivot := Node3D.new()
		arm_pivot.position = Vector3(side * 0.29, 1.43, 0)
		var arm := _part(func(st: SurfaceTool):
			ShipBuilder._box(st, Transform3D(Basis(), Vector3(0, -0.28, 0)), Vector3(0.11, 0.56, 0.12), coat)
			Island._sphere(st, Vector3(0, -0.6, 0), Vector3(0.06, 0.07, 0.06), skin, 5, 3)
			)
		arm_pivot.add_child(arm)
		root.add_child(arm_pivot)
		parts["leg_l" if side < 0 else "leg_r"] = leg_pivot
		parts["arm_l" if side < 0 else "arm_r"] = arm_pivot
	return parts


static func animate_walk(p: Dictionary, phase: float, amount: float) -> void:
	var a := sin(phase) * 0.6 * amount
	p["leg_l"].rotation.x = a
	p["leg_r"].rotation.x = -a
	p["arm_l"].rotation.x = -a * 0.8
	p["arm_r"].rotation.x = a * 0.8


## Cavalo. Retorna {"root","legs":[4 pivôs]}
static func make_horse(coat: Color) -> Dictionary:
	var root := Node3D.new()
	var mane := coat.darkened(0.6)
	var body := _part(func(st: SurfaceTool):
		Island._sphere(st, Vector3(0, 1.35, 0), Vector3(0.42, 0.45, 0.95), coat, 10, 7)
		ShipBuilder._tube(st, Vector3(0, 1.55, -0.75), Vector3(0, 2.15, -1.15), 0.24, 0.17, coat, 8)
		Island._sphere(st, Vector3(0, 2.15, -1.38), Vector3(0.15, 0.17, 0.36), coat, 8, 5)
		ShipBuilder._box(st, Transform3D(Basis(Vector3(1, 0, 0), -0.6), Vector3(0, 2.0, -0.95)), Vector3(0.06, 0.7, 0.18), mane)
		ShipBuilder._tube(st, Vector3(0, 1.5, 0.92), Vector3(0, 0.85, 1.2), 0.08, 0.04, mane, 5)
		ShipBuilder._tube(st, Vector3(-0.07, 2.32, -1.25), Vector3(-0.07, 2.45, -1.22), 0.03, 0.01, coat, 4)
		ShipBuilder._tube(st, Vector3(0.07, 2.32, -1.25), Vector3(0.07, 2.45, -1.22), 0.03, 0.01, coat, 4)
		# sela
		ShipBuilder._box(st, Transform3D(Basis(), Vector3(0, 1.8, -0.1)), Vector3(0.55, 0.12, 0.6), Color(0.35, 0.18, 0.08))
		ShipBuilder._box(st, Transform3D(Basis(), Vector3(0, 1.4, -0.1)), Vector3(0.9, 0.5, 0.05), Color(0.5, 0.12, 0.08))
		)
	root.add_child(body)
	var legs: Array = []
	for lp in [Vector3(-0.22, 1.15, -0.62), Vector3(0.22, 1.15, -0.62), Vector3(-0.22, 1.15, 0.62), Vector3(0.22, 1.15, 0.62)]:
		var piv := Node3D.new()
		piv.position = lp
		var leg := _part(func(st: SurfaceTool):
			ShipBuilder._tube(st, Vector3(0, 0, 0), Vector3(0, -1.05, 0), 0.09, 0.06, coat, 6)
			ShipBuilder._box(st, Transform3D(Basis(), Vector3(0, -1.1, -0.02)), Vector3(0.13, 0.1, 0.16), Color(0.1, 0.08, 0.06))
			)
		piv.add_child(leg)
		root.add_child(piv)
		legs.append(piv)
	return {"root": root, "legs": legs}


static func animate_horse(h: Dictionary, phase: float, amount: float) -> void:
	var legs: Array = h["legs"]
	var a := sin(phase) * 0.55 * amount
	legs[0].rotation.x = a
	legs[3].rotation.x = a
	legs[1].rotation.x = -a
	legs[2].rotation.x = -a


# ---------------------------------------------------------------- vida da cidade
func setup(ps: PortSite) -> void:
	site = ps
	_rng.seed = ps.idx * 101 + Time.get_ticks_msec()
	var w := World.I
	var n_people: int = [6, 10, 14][Game.quality]
	for i in n_people:
		var p := Assets.person("mulher" if _rng.randf() < 0.45 else "homem", _rng)
		var start := _random_spot()
		add_child(p["root"])
		p["root"].global_position = Vector3(start.x, w.terrain_height(start.x, start.y), start.y)
		people.append({"p": p, "target": _random_spot(), "wait": _rng.randf() * 3.0, "speed": _rng.randf_range(1.1, 1.5),
			"kind": "morador", "phase": 0.0, "name": "Morador"})
	# guardas (oficiais) perto da praça e do forte
	var tc := Vector2(ps.town_center.x, ps.town_center.z)
	var fp := Vector2(ps.fort_pos.x, ps.fort_pos.z)
	var owner: int = Game.port_owner[ps.idx]
	var n_guards := 3
	if hostile():
		n_guards = 6 if Game.port_fort_hp[ps.idx] > 0.0 else 4
	for i in n_guards:
		var g := Assets.soldier(owner, _rng)
		add_child(g["root"])
		var spot: Vector2 = tc.lerp(fp, 0.25 + (i % 3) * 0.2) + Vector2(_rng.randf_range(-9, 9), _rng.randf_range(-9, 9))
		g["root"].global_position = Vector3(spot.x, w.terrain_height(spot.x, spot.y), spot.y)
		people.append({"p": g, "target": spot, "wait": 999.0, "speed": 0.0, "kind": "guarda", "phase": 0.0, "name": "Guarda",
			"alive": true, "cd": _rng.randf_range(1.5, 3.5), "post": spot})
	# pessoa especial (romance) na porta da taverna
	var rn := Game.romance_name(ps.idx)
	var female := ps.idx % 2 == 0
	var sp := Assets.person("mulher" if female else "homem", _rng, {"file": "Smooth_Female_Dress" if female else "Smooth_Male_Suit",
		"coat": Color(0.62, 0.1, 0.2) if female else Color(0.12, 0.18, 0.4), "hat": 0 if female else 1})
	add_child(sp["root"])
	var door := Vector2(ps.tavern_pos.x, ps.tavern_pos.z) - ps.dir * 9.0
	sp["root"].global_position = Vector3(door.x, w.terrain_height(door.x, door.y), door.y)
	special = {"p": sp, "target": door, "wait": 999.0, "speed": 0.0, "kind": "especial", "phase": 0.0, "name": rn}
	people.append(special)
	# cavalos no estábulo
	var side := Vector2(-ps.dir.y, ps.dir.x)
	for i in 2:
		var hp := Vector2(ps.stable_pos.x, ps.stable_pos.z) + side * (i * 5.0 - 2.5) + ps.dir * 8.0
		var h := Horse.new(Assets.horse())
		add_child(h)
		h.place(hp, atan2(-ps.dir.x, -ps.dir.y))
		horses.append(h)


## Um ponto ao acaso nas ruas (os moradores andam pelas ruas, não atravessam casas).
func _random_spot() -> Vector2:
	var tc := Vector2(site.town_center.x, site.town_center.z)
	if site.streets.is_empty() or _rng.randf() < 0.25:
		return tc + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(4.0, 20.0)
	var sp: PackedVector2Array = site.streets[_rng.randi() % site.streets.size()]
	return sp[0].lerp(sp[1], _rng.randf()) + Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-2, 2))


func hostile() -> bool:
	return alarm or Game.nation_hostile_to_player(Game.port_owner[site.idx])


## O jogador disparou: numa cidade amiga, isso vira um crime.
func provoke() -> void:
	_panic = 20.0
	if not hostile():
		alarm = true
		var owner: int = Game.port_owner[site.idx]
		Game.change_rep(owner, -15)
		Game.notify("Você atirou nos guardas! %s agora é hostil a você." % site.name, Color(1, 0.35, 0.3))


func kill(e: Dictionary) -> void:
	if not e.get("alive", true):
		return
	e["alive"] = false
	var p: Dictionary = e["p"]
	p["cur"] = ""
	Assets.play(p, "Death")
	Sfx.play_at("hit", p["root"].global_position, -4.0, 1.4)
	if guards_alive() == 0 and hostile():
		Game.notify("Todos os guardas de %s caíram!" % site.name, Color(1, 0.85, 0.4))


func guards_alive() -> int:
	var n := 0
	for e in people:
		if e["kind"] == "guarda" and e.get("alive", true):
			n += 1
	return n


func nearest_enemy(p: Vector3, max_d: float) -> Dictionary:
	if not hostile():
		return {}
	var best := {}
	var bd := max_d
	for e in people:
		if e["kind"] != "guarda" or not e.get("alive", true):
			continue
		var d: float = e["p"]["root"].global_position.distance_to(p)
		if d < bd:
			bd = d
			best = e
	return best


func _process(delta: float) -> void:
	var w := World.I
	var ctl: PlayerController = w.ctl
	var lp: Vector3 = ctl.foot_pos if ctl else w.listener_pos()
	var hot := hostile()
	_panic = maxf(0.0, _panic - delta)
	for e in people:
		var p: Dictionary = e["p"]
		var root: Node3D = p["root"]
		var pos := Vector2(root.global_position.x, root.global_position.z)
		if not e.get("alive", true):
			continue
		if e["kind"] == "guarda":
			_guard(e, p, root, pos, lp, hot, delta)
			continue
		if e["kind"] != "morador":
			var to := Vector2(lp.x, lp.z) - pos
			if to.length() < 15.0:
				root.rotation.y = lerp_angle(root.rotation.y, atan2(-to.x, -to.y), delta * 3.0)
			Assets.play(p, "Idle")
			continue
		var running := _panic > 0.0
		if e["wait"] > 0.0 and not running:
			e["wait"] -= delta
			Assets.play(p, "Idle")
			continue
		var tgt: Vector2 = e["target"]
		var d := tgt - pos
		if d.length() < 1.0:
			e["target"] = _random_spot()
			e["wait"] = _rng.randf_range(1.5, 6.0)
			continue
		var spd: float = e["speed"] * (3.2 if running else 1.0)
		var step: Vector2 = d.normalized() * spd * delta
		if w.building_blocked(pos.x + step.x, pos.y + step.y):
			e["target"] = _random_spot()
			continue
		pos += step
		root.global_position = Vector3(pos.x, w.terrain_height(pos.x, pos.y), pos.y)
		root.rotation.y = lerp_angle(root.rotation.y, atan2(-d.x, -d.y), delta * 6.0)
		if running:
			Assets.play(p, "Run")
		else:
			Assets.play(p, "Walk", e["speed"] / 1.3)


## Guarda: parado no posto; se a cidade for hostil, vai até o jogador e atira com o mosquete.
func _guard(e: Dictionary, p: Dictionary, root: Node3D, pos: Vector2, lp: Vector3, hot: bool, delta: float) -> void:
	var w := World.I
	var to := Vector2(lp.x, lp.z) - pos
	var dist := to.length()
	var ctl: PlayerController = w.ctl
	var player_on_land := ctl != null and ctl.on_land()
	if not hot or not player_on_land or dist > 80.0:
		var post: Vector2 = e.get("post", pos)
		var back := post - pos
		if back.length() > 1.5 and hot:
			pos += back.normalized() * 2.0 * delta
			root.global_position = Vector3(pos.x, w.terrain_height(pos.x, pos.y), pos.y)
			root.rotation.y = lerp_angle(root.rotation.y, atan2(-back.x, -back.y), delta * 6.0)
			Assets.play(p, "Walk")
			return
		if dist < 15.0:
			root.rotation.y = lerp_angle(root.rotation.y, atan2(-to.x, -to.y), delta * 3.0)
		Assets.play(p, "Idle")
		return
	root.rotation.y = lerp_angle(root.rotation.y, atan2(-to.x, -to.y), delta * 6.0)
	e["cd"] = float(e["cd"]) - delta
	if dist > 16.0:
		var stp := to.normalized() * 4.2 * delta
		if not w.building_blocked(pos.x + stp.x, pos.y + stp.y):
			pos += stp
			root.global_position = Vector3(pos.x, w.terrain_height(pos.x, pos.y), pos.y)
		if not (p["cur"].ends_with("Punch") and p["ap"].is_playing()):
			Assets.play(p, "Run")
	elif not (p["cur"].ends_with("Punch") and p["ap"].is_playing()):
		Assets.play(p, "Idle")
	if e["cd"] <= 0.0 and dist < 45.0:
		e["cd"] = _rng.randf_range(2.6, 4.2)
		p["cur"] = ""
		Assets.play(p, "Punch", 1.4)
		var dir3 := Vector3(to.x, 0, to.y).normalized()
		var muzzle := root.global_position + Vector3(0, 1.3, 0) + dir3 * 0.9
		Effects.I.emit("flash", muzzle, dir3)
		Effects.I.emit("smoke", muzzle, dir3)
		Sfx.play_at("cannon", muzzle, -10.0, 2.6)
		var chance := 0.32 * (1.0 - dist / 60.0)
		if ctl.mode == PlayerController.Mode.HORSE:
			chance *= 0.6
		if _rng.randf() < chance:
			ctl.foot_hit(_rng.randf_range(10.0, 18.0))


## Pessoa mais próxima do ponto (para conversar), ou {}.
func nearest_person(p: Vector3, max_d: float) -> Dictionary:
	var best := {}
	var bd := max_d
	for e in people:
		if not e.get("alive", true):
			continue
		var d: float = e["p"]["root"].global_position.distance_to(p)
		if d < bd:
			bd = d
			best = e
	return best


func nearest_horse(p: Vector3, max_d: float) -> Horse:
	var best: Horse = null
	var bd := max_d
	for h in horses:
		if h.ridden or not is_instance_valid(h):
			continue
		var d: float = h.global_position.distance_to(p)
		if d < bd:
			bd = d
			best = h
	return best


func random_line() -> String:
	return LINES[_rng.randi() % LINES.size()]
