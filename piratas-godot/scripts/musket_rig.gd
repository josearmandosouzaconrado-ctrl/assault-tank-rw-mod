class_name MusketRig
extends SkeletonModifier3D
## Posiciona o mosquete conforme a ordem de armas do início do século XVIII e
## dobra os braços (cinemática inversa de dois ossos) para segurá-lo de verdade:
##   CARRY  "ombro-armas": coronha na mão esquerda, cano apoiado na frente do ombro esquerdo, fecho para fora
##   ORDER  "descansar": coronha no chão ao lado do pé direito, mão direita no cano
##   AIM    "apontar/fogo": coronha no ombro direito, mão direita no punho, mão esquerda sob o cano
## O mosquete fica sempre por fora do corpo (afastado do ombro) para não atravessar a roupa.

enum { NONE, CARRY, ORDER, AIM }

var mode := CARRY
var root: Node3D            # nó raiz do personagem (espaço do personagem: frente = -Z, direita = +X)
var musket: MeshInstance3D  # filho de root
var kick := 0.0             # recuo após o disparo
var _b := {}


func setup(person_root: Node3D, sk: Skeleton3D, bayonet := false) -> void:
	root = person_root
	for n in ["upperarm_l", "lowerarm_l", "hand_l", "upperarm_r", "lowerarm_r", "hand_r", "spine_03"]:
		_b[n] = sk.find_bone(n)
	musket = MeshInstance3D.new()
	musket.mesh = Assets.musket_mesh(bayonet)
	musket.visibility_range_end = 160.0
	root.add_child(musket)


func set_mode(m: int) -> void:
	mode = m
	if musket:
		musket.visible = m != NONE


func fire_kick() -> void:
	kick = 1.0


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or root == null or mode == NONE or not is_instance_valid(root):
		return
	kick = maxf(0.0, kick - get_process_delta_time() * 6.0)
	# espaço do esqueleto <-> espaço do personagem
	var to_sk: Transform3D = sk.global_transform.affine_inverse() * root.global_transform
	var to_ch: Transform3D = to_sk.affine_inverse()
	var sh_l: Vector3 = to_ch * sk.get_bone_global_pose(_b["upperarm_l"]).origin
	var sh_r: Vector3 = to_ch * sk.get_bone_global_pose(_b["upperarm_r"]).origin
	var butt := Vector3.ZERO
	var dir := Vector3.UP
	var side := Vector3.RIGHT   # lado do fecho
	match mode:
		CARRY:
			# na frente do ombro esquerdo, por fora do deltoide; coronha na mão esquerda na altura do quadril
			var at_sh := sh_l + Vector3(-0.07, 0.0, -0.1)
			dir = Vector3(-0.05, 1.0, 0.22).normalized()
			butt = at_sh - dir * 0.47
			side = Vector3.LEFT
		ORDER:
			butt = Vector3(sh_r.x + 0.02, 0.02, sh_r.z - 0.16)
			dir = Vector3(0.03, 1.0, -0.04).normalized()
			side = Vector3.FORWARD
		AIM:
			dir = Vector3(-0.06, 0.03, -1.0).normalized()
			butt = sh_r + Vector3(-0.06, -0.03, -0.12) - dir * (0.1 * kick)
			side = Vector3.RIGHT
	# o mosquete: eixo Y do modelo = da coronha para a boca; a coronha fica a 0,9 m da origem do modelo
	var x := (side - dir * side.dot(dir)).normalized()
	var z := x.cross(dir)
	var up_kick := Basis(x, 0.12 * kick) if mode == AIM else Basis()
	musket.transform = Transform3D(up_kick * Basis(x, dir, z), butt + dir * 0.9)
	# braços (mão = ponta do osso "hand"; o punho fica ~8 cm antes da palma)
	match mode:
		CARRY:
			_ik(sk, to_sk, "l", butt + dir * 0.05 + Vector3(0.04, -0.02, 0.0), sh_l + Vector3(-0.3, -0.25, 0.2))
		ORDER:
			_ik(sk, to_sk, "r", butt + dir * 0.86 + Vector3(0.04, 0, 0.03), sh_r + Vector3(0.3, -0.3, 0.3))
		AIM:
			_ik(sk, to_sk, "r", butt + dir * 0.36 + Vector3(0.035, -0.07, 0.04), sh_r + Vector3(0.35, -0.4, 0.15))
			_ik(sk, to_sk, "l", butt + dir * 0.72 + Vector3(0.0, -0.07, 0.04), sh_l + Vector3(0.05, -0.5, -0.1))


## IK analítico de dois ossos (braço e antebraço) no espaço do esqueleto.
func _ik(sk: Skeleton3D, to_sk: Transform3D, side: String, target_ch: Vector3, pole_ch: Vector3) -> void:
	var a: int = _b["upperarm_" + side]
	var b: int = _b["lowerarm_" + side]
	var c: int = _b["hand_" + side]
	if a < 0 or b < 0 or c < 0:
		return
	var ga := sk.get_bone_global_pose(a)
	var gb := sk.get_bone_global_pose(b)
	var gc := sk.get_bone_global_pose(c)
	var pa := ga.origin
	var pb := gb.origin
	var pc := gc.origin
	var l1 := pa.distance_to(pb)
	var l2 := pb.distance_to(pc)
	var target: Vector3 = to_sk * target_ch
	var pole: Vector3 = to_sk * pole_ch
	var to := target - pa
	var d := clampf(to.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var dir := to.normalized()
	var ca := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var pp := pole - pa
	var perp := pp - dir * pp.dot(dir)
	if perp.length_squared() < 1e-8:
		perp = dir.cross(Vector3.UP)
	perp = perp.normalized()
	var elbow := pa + dir * l1 * ca + perp * l1 * sqrt(1.0 - ca * ca)
	var wrist := pa + dir * d
	var q1 := Quaternion((pb - pa).normalized(), (elbow - pa).normalized())
	ga.basis = Basis(q1) * ga.basis
	sk.set_bone_global_pose(a, ga)
	var forearm_old: Vector3 = (Basis(q1) * (pc - pb)).normalized()
	var q2 := Quaternion(forearm_old, (wrist - elbow).normalized())
	var gb2 := Transform3D(Basis(q2) * Basis(q1) * gb.basis, elbow)
	sk.set_bone_global_pose(b, gb2)
	# mão alinhada com o antebraço
	var gc2 := Transform3D(Basis(q2) * Basis(q1) * gc.basis, wrist)
	sk.set_bone_global_pose(c, gc2)
