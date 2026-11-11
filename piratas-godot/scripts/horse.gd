class_name Horse
extends Node3D
## Cavalo de montaria: anda pelo relevo, não entra no mar e anima as patas.

var parts: Dictionary
var ridden := false
var yaw := 0.0
var speed := 0.0
var _phase := 0.0
var rider: Dictionary = {}


func _init(model: Dictionary) -> void:
	parts = model
	add_child(model["root"])


func place(p: Vector2, y: float) -> void:
	yaw = y
	var w := World.I
	global_position = Vector3(p.x, w.terrain_height(p.x, p.y), p.y)
	rotation.y = yaw


func forward() -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))


## Controle do jogador: throttle -1..1, turn -1..1 (direita positivo).
func drive(delta: float, throttle: float, turn: float) -> void:
	var w := World.I
	var target := 0.0
	if throttle > 0.05:
		target = lerpf(3.0, 13.0, clampf((throttle - 0.05) / 0.95, 0.0, 1.0))
	elif throttle < -0.3:
		target = -2.0
	speed = move_toward(speed, target, delta * (5.0 if target > speed else 7.0))
	yaw = wrapf(yaw - turn * delta * lerpf(1.8, 1.1, clampf(speed / 13.0, 0.0, 1.0)), -PI, PI)
	var p := Vector2(global_position.x, global_position.z)
	var np := p + forward() * speed * delta
	var h0 := w.terrain_height(p.x, p.y)
	var h1 := w.terrain_height(np.x, np.y)
	var ahead := np + forward() * 1.6
	if w.terrain_height(ahead.x, ahead.y) < 0.35 or h1 - h0 > maxf(absf(speed) * delta * 1.4, 0.25) or w.building_blocked(ahead.x, ahead.y):
		speed = 0.0
		np = p
		h1 = h0
	global_position = Vector3(np.x, h1, np.y)
	rotation.y = yaw
	# inclinar no relevo
	var hb := w.terrain_height(np.x + forward().x, np.y + forward().y)
	rotation.x = clampf(atan2(hb - h1, 1.0), -0.35, 0.35)
	_phase += delta * absf(speed) * 1.3
	TownLife.animate_horse(parts, _phase, clampf(absf(speed) / 4.0, 0.0, 1.0))


func _process(delta: float) -> void:
	if not ridden:
		speed = 0.0
		TownLife.animate_horse(parts, 0.0, 0.0)
