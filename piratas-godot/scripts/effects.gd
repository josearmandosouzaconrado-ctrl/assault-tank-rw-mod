class_name Effects
extends Node3D
## Partículas reutilizáveis: fumaça dos canhões, respingos, estilhaços, fogo e chuva.

static var I: Effects

var _pools := {}
var _next := {}
var _soft_tex: GradientTexture2D


func _init() -> void:
	I = self


func _ready() -> void:
	_soft_tex = GradientTexture2D.new()
	_soft_tex.fill = GradientTexture2D.FILL_RADIAL
	_soft_tex.fill_from = Vector2(0.5, 0.5)
	_soft_tex.fill_to = Vector2(1.0, 0.5)
	_soft_tex.width = 64
	_soft_tex.height = 64
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 0.55))
	_soft_tex.gradient = g
	var q := Game.quality
	_make_pool("smoke", 14 + q * 6, _smoke)
	_make_pool("splash", 12 + q * 4, _splash)
	_make_pool("hit", 10 + q * 4, _hit)
	_make_pool("flash", 12, _flash)
	_make_pool("dust", 6, _dust)


func _mat(additive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if additive else BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_tex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _base(n: int, life: float, additive := false, size := 1.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.92
	p.emitting = false
	p.local_coords = false
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	qm.material = _mat(additive)
	p.mesh = qm
	return p


func _smoke() -> CPUParticles3D:
	var p := _base(14, 3.2, false, 3.0)
	p.direction = Vector3(0, 0.3, 1)
	p.spread = 25.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 11.0
	p.damping_min = 3.0
	p.damping_max = 5.0
	p.gravity = Vector3(0, 0.6, 0)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 2.6))
	p.scale_amount_curve = c
	var gr := Gradient.new()
	gr.set_color(0, Color(0.85, 0.83, 0.8, 0.85))
	gr.set_color(1, Color(0.7, 0.7, 0.7, 0.0))
	p.color_ramp = gr
	return p


func _splash() -> CPUParticles3D:
	var p := _base(22, 1.5, false, 1.4)
	p.direction = Vector3(0, 1, 0)
	p.spread = 18.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 15.0
	p.gravity = Vector3(0, -14, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.8
	p.scale_amount_min = 0.8
	p.scale_amount_max = 2.0
	var gr := Gradient.new()
	gr.set_color(0, Color(0.95, 0.98, 1.0, 0.9))
	gr.set_color(1, Color(0.85, 0.92, 0.95, 0.0))
	p.color_ramp = gr
	return p


func _hit() -> CPUParticles3D:
	var p := _base(18, 1.4, false, 0.5)
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 14.0
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	var gr := Gradient.new()
	gr.set_color(0, Color(0.45, 0.3, 0.18, 1.0))
	gr.set_color(1, Color(0.25, 0.18, 0.1, 0.0))
	p.color_ramp = gr
	return p


func _flash() -> CPUParticles3D:
	var p := _base(6, 0.35, true, 2.4)
	p.direction = Vector3(0, 0, 1)
	p.spread = 12.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3.ZERO
	var gr := Gradient.new()
	gr.set_color(0, Color(1.0, 0.85, 0.5, 1.0))
	gr.set_color(1, Color(1.0, 0.3, 0.05, 0.0))
	p.color_ramp = gr
	return p


func _dust() -> CPUParticles3D:
	var p := _base(16, 2.0, false, 3.0)
	p.direction = Vector3(0, 1, 0)
	p.spread = 60.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -2, 0)
	var gr := Gradient.new()
	gr.set_color(0, Color(0.6, 0.55, 0.45, 0.8))
	gr.set_color(1, Color(0.6, 0.55, 0.45, 0.0))
	p.color_ramp = gr
	return p


func _make_pool(id: String, n: int, maker: Callable) -> void:
	var arr: Array = []
	for i in n:
		var p: CPUParticles3D = maker.call()
		add_child(p)
		arr.append(p)
	_pools[id] = arr
	_next[id] = 0


func emit(id: String, pos: Vector3, dir := Vector3.ZERO) -> void:
	if not _pools.has(id):
		return
	var arr: Array = _pools[id]
	var p: CPUParticles3D = arr[_next[id]]
	_next[id] = (_next[id] + 1) % arr.size()
	p.global_position = pos
	if dir != Vector3.ZERO:
		p.direction = dir.normalized()
	p.restart()
	p.emitting = true


## Fogo + fumaça preta contínuos presos a um navio (incêndio/naufrágio).
func make_fire(parent: Node3D, offset: Vector3, big := false) -> CPUParticles3D:
	var f := CPUParticles3D.new()
	f.amount = 24 if big else 12
	f.lifetime = 1.2
	f.local_coords = false
	var qm := QuadMesh.new()
	qm.size = Vector2(2.2, 2.2) if big else Vector2(1.4, 1.4)
	qm.material = _mat(true)
	f.mesh = qm
	f.direction = Vector3(0, 1, 0)
	f.spread = 15.0
	f.initial_velocity_min = 2.0
	f.initial_velocity_max = 5.0
	f.gravity = Vector3(0, 2, 0)
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	f.emission_box_extents = Vector3(1.5, 0.3, 3.0) if big else Vector3(0.6, 0.2, 0.6)
	var gr := Gradient.new()
	gr.set_color(0, Color(1.0, 0.75, 0.3, 1.0))
	gr.set_color(1, Color(0.9, 0.2, 0.02, 0.0))
	f.color_ramp = gr
	parent.add_child(f)
	f.position = offset
	var s := CPUParticles3D.new()
	s.amount = 16 if big else 8
	s.lifetime = 5.0
	s.local_coords = false
	var sm := QuadMesh.new()
	sm.size = Vector2(5, 5)
	sm.material = _mat(false)
	s.mesh = sm
	s.direction = Vector3(0, 1, 0)
	s.spread = 10.0
	s.initial_velocity_min = 3.0
	s.initial_velocity_max = 6.0
	s.gravity = Vector3(1.0, 1.0, 0)
	var c := Curve.new()
	c.add_point(Vector2(0, 0.5))
	c.add_point(Vector2(1, 3.0))
	s.scale_amount_curve = c
	var g2 := Gradient.new()
	g2.set_color(0, Color(0.12, 0.11, 0.1, 0.7))
	g2.set_color(1, Color(0.3, 0.3, 0.3, 0.0))
	s.color_ramp = g2
	f.add_child(s)
	s.position = Vector3(0, 2, 0)
	return f


func make_rain() -> CPUParticles3D:
	var r := CPUParticles3D.new()
	r.amount = 500 if Game.quality > 0 else 250
	r.lifetime = 0.9
	r.local_coords = false
	r.emitting = false
	var qm := QuadMesh.new()
	qm.size = Vector2(0.04, 1.4)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.8, 0.9, 0.35)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	qm.material = m
	r.mesh = qm
	r.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	r.emission_box_extents = Vector3(30, 1, 30)
	r.direction = Vector3(0.15, -1, 0)
	r.spread = 2.0
	r.initial_velocity_min = 30.0
	r.initial_velocity_max = 36.0
	r.gravity = Vector3(0, -10, 0)
	return r
