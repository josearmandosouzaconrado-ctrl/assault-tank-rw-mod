class_name Projectiles
extends MultiMeshInstance3D
## Todas as balas de canhão do jogo, simuladas juntas e desenhadas com um único MultiMesh.

const GRAVITY := 11.0
const MAX := 400

static var I: Projectiles

var pos := PackedVector3Array()
var vel := PackedVector3Array()
var data: Array = []   # {"owner": Ship/null, "nation": int, "dmg": float, "ammo": int, "from_player": bool, "age": float}


func _init() -> void:
	I = self
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.64
	sm.radial_segments = 8
	sm.rings = 4
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.05, 0.05)
	m.roughness = 0.4
	m.metallic = 0.6
	sm.material = m
	multimesh.mesh = sm
	multimesh.instance_count = MAX
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0


## extra: {"g": gravidade própria, "slow": freia o alvo (corrente), "mortar": explode em área}
func fire(p: Vector3, v: Vector3, owner: Object, nation: int, dmg: float, ammo: int, from_player: bool, extra := {}) -> void:
	if pos.size() >= MAX:
		return
	pos.append(p)
	vel.append(v)
	var d := {"owner": owner, "nation": nation, "dmg": dmg, "ammo": ammo, "from_player": from_player, "age": 0.0}
	d.merge(extra)
	data.append(d)


## Explosão de bomba de morteiro: atinge navios num raio.
func _explode(w: World, at: Vector3, info: Dictionary, skip: Object) -> void:
	Effects.I.emit("splash", at)
	Effects.I.emit("flash", at + Vector3(0, 1, 0), Vector3.UP)
	Effects.I.emit("smoke", at, Vector3.UP)
	Sfx.play_at("cannon", at, 0.0, 0.7)
	for s in w.ships:
		if s == skip or s == info["owner"] or s.dead:
			continue
		var d := Vector2(s.global_position.x - at.x, s.global_position.z - at.z).length()
		if d < s.radius * 0.6 + 9.0:
			s.take_hit(info["dmg"] * 0.9, 0, info["owner"], s.global_position + Vector3(0, 2, 0), info["from_player"], info["nation"])


## Ângulo de elevação para acertar a distância `d` (com diferença de altura dy) — o tiro baixo.
static func solve_elevation(d: float, dy: float, speed: float) -> float:
	var v2 := speed * speed
	var g := GRAVITY
	var disc := v2 * v2 - g * (g * d * d + 2.0 * dy * v2)
	if disc < 0.0:
		return deg_to_rad(40.0)
	return atan((v2 - sqrt(disc)) / (g * d))


func clear_all() -> void:
	pos.clear()
	vel.clear()
	data.clear()
	multimesh.visible_instance_count = 0


func _physics_process(delta: float) -> void:
	var w := World.I
	if w == null:
		return
	var i := 0
	while i < pos.size():
		var p := pos[i]
		var v := vel[i]
		var info: Dictionary = data[i]
		v.y -= float(info.get("g", GRAVITY)) * delta
		var np := p + v * delta
		info["age"] += delta
		var remove := false
		# navios
		for s in w.ships:
			if s == info["owner"] or s.dead:
				continue
			if s.global_position.distance_squared_to(np) > s.radius * s.radius + 400.0:
				continue
			var hit := s.hit_test(p, np)
			if hit != Vector3.INF:
				s.take_hit(info["dmg"], info["ammo"], info["owner"], hit, info["from_player"], info["nation"])
				if info.get("slow", false) and not s.dead:
					s.speed *= 0.45
					s.sail_hp = maxf(0.0, s.sail_hp - 6.0)
				if info.get("mortar", false):
					_explode(w, hit, info, s)
				remove = true
				break
		# fortes
		if not remove:
			var f := w.fort_hit(np)
			if f >= 0:
				w.damage_fort(f, info["dmg"] * (2.2 if info.get("mortar", false) else 1.0), info["from_player"], np)
				remove = true
		if not remove:
			var th := w.terrain_height(np.x, np.z)
			if np.y < th:
				Effects.I.emit("dust", np)
				Sfx.play_at("hit", np, -6.0, 0.7)
				remove = true
			elif np.y < Ocean.height_at(np.x, np.z):
				if info.get("mortar", false):
					_explode(w, Vector3(np.x, Ocean.height_at(np.x, np.z), np.z), info, null)
				Effects.I.emit("splash", Vector3(np.x, Ocean.height_at(np.x, np.z), np.z))
				if np.distance_to(w.listener_pos()) < 400.0:
					Sfx.play_at("splash", np, -4.0)
				remove = true
		if remove or info["age"] > 16.0:
			pos.remove_at(i)
			vel.remove_at(i)
			data.remove_at(i)
			continue
		pos[i] = np
		vel[i] = v
		i += 1
	var n := pos.size()
	multimesh.visible_instance_count = n
	for k in n:
		multimesh.set_instance_transform(k, Transform3D(Basis(), pos[k]))
