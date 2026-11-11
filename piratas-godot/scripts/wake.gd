class_name Wake
extends MeshInstance3D
## Esteira de espuma que segue o caminho real do navio (inclusive nas curvas):
## um rastro de pontos vira três faixas — turbulência no centro e as duas ondas que se abrem em V.

const MAX_PTS := 44
const STEP := 0.22   # segundos entre pontos do rastro

static var _mat: ShaderMaterial

var ship: Node3D
var pts: Array = []   # cada ponto: [Vector2 pos, Vector2 lado(direita), velocidade, idade]
var _t := 0.0
var _im: ImmediateMesh


func _init(owner_ship: Node3D) -> void:
	ship = owner_ship
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_im = ImmediateMesh.new()
	mesh = _im
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/wake.gdshader")
		var nt := NoiseTexture2D.new()
		nt.width = 256
		nt.height = 256
		nt.seamless = true
		var fn := FastNoiseLite.new()
		fn.frequency = 0.035
		fn.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		nt.noise = fn
		_mat.set_shader_parameter("noise", nt)
	material_override = _mat
	extra_cull_margin = 400.0


## Chamado pelo navio a cada quadro de física.
func record(pos: Vector2, fwd: Vector2, speed: float, beam: float, length: float, delta: float) -> void:
	_t += delta
	for p in pts:
		p[3] += delta
	while not pts.is_empty() and pts[-1][3] > 14.0:
		pts.pop_back()
	if _t >= STEP:
		_t = 0.0
		var stern := pos - fwd * length * 0.42
		pts.push_front([stern, Vector2(-fwd.y, fwd.x), speed, 0.0, beam])
		if pts.size() > MAX_PTS:
			pts.pop_back()


func _process(_delta: float) -> void:
	_im.clear_surfaces()
	if ship == null or not is_instance_valid(ship) or pts.size() < 2:
		return
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(ship.global_position) > 1100.0:
		return
	global_transform = Transform3D.IDENTITY
	# altura da água uma vez por ponto
	var hs: Array[float] = []
	for p in pts:
		hs.append(Ocean.height_at(p[0].x, p[0].y) + 0.15)
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# faixa central (turbulência)
	_strip(hs, 0.0, 0)
	# ondas laterais que se abrem
	_strip(hs, 1.0, 1)
	_strip(hs, -1.0, 1)
	_im.surface_end()


func _strip(hs: Array[float], side: float, kind: int) -> void:
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_a := 0.0
	for i in pts.size():
		var p: Array = pts[i]
		var pos: Vector2 = p[0]
		var lat: Vector2 = p[1]
		var spd: float = p[2]
		var age: float = p[3]
		var beam: float = p[4]
		var k := clampf(spd / 8.0, 0.0, 1.2)
		var a := 0.0
		var center := pos
		var half_w := 0.0
		if kind == 0:
			half_w = beam * 0.35 + age * (0.5 + spd * 0.12)
			a = exp(-age / (2.5 + 5.0 * k)) * minf(k * 1.3, 1.0) * 0.85
		else:
			var spread := beam * 0.5 + age * spd * 0.33
			center = pos + lat * side * spread
			half_w = 0.7 + age * 0.35
			a = exp(-age / (3.0 + 7.0 * k)) * minf(k * 1.3, 1.0) * 0.6
		if i == 0:
			a = 0.0
		var y: float = hs[i]
		var l := Vector3(center.x - lat.x * half_w, y, center.y - lat.y * half_w)
		var r := Vector3(center.x + lat.x * half_w, y, center.y + lat.y * half_w)
		if i > 0:
			_vert(prev_l, prev_a, 0.0)
			_vert(prev_r, prev_a, 1.0)
			_vert(r, a, 1.0)
			_vert(prev_l, prev_a, 0.0)
			_vert(r, a, 1.0)
			_vert(l, a, 0.0)
		prev_l = l
		prev_r = r
		prev_a = a


func _vert(p: Vector3, a: float, v: float) -> void:
	_im.surface_set_color(Color(1, 1, 1, a))
	_im.surface_set_uv(Vector2(0.0, v))
	_im.surface_set_normal(Vector3.UP)
	_im.surface_add_vertex(p)
