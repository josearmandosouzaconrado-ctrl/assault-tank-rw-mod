class_name MusketRig
extends SkeletonModifier3D
## Posiciona o mosquete conforme a ordem de armas do início do século XVIII e
## dobra os braços (cinemática inversa de dois ossos) para segurá-lo de verdade:
##   CARRY  "ombro-armas": coronha na mão esquerda, cano apoiado no ombro esquerdo
##   ORDER  "descansar": coronha no chão ao lado do pé direito, mão direita no cano
##   AIM    "apontar/fogo": coronha no ombro direito, mão direita no punho, mão esquerda sob o cano

enum { NONE, CARRY, ORDER, AIM }

var mode := CARRY
var root: Node3D            # nó raiz do personagem (espaço do personagem: frente = -Z, direita = +X)
var musket: MeshInstance3D  # filho de root
var kick := 0.0             # recuo após o disparo
var _b := {}


func setup(person_root: Node3D, sk: Skeleton3D) -> void:
	root = person_root
	for n in ["UpperArm.L", "LowerArm.L", "Palm.L", "UpperArm.R", "LowerArm.R", "Palm.R", "Torso"]:
		_b[n] = sk.find_bone(n)
	musket = MeshInstance3D.new()
	musket.mesh = Assets.musket_mesh()
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
	var sh_l: Vector3 = to_ch * sk.get_bone_global_pose(_b["UpperArm.L"]).origin
	var sh_r: Vector3 = to_ch * sk.get_bone_global_pose(_b["UpperArm.R"]).origin
	var butt := Vector3.ZERO
	var dir := Vector3.UP
	match mode:
		CARRY:
			butt = sh_l + Vector3(0.03, -0.5, -0.13)
			dir = Vector3(0.0, 1.0, 0.24).normalized()
		ORDER:
			butt = Vector3(sh_r.x + 0.1, 0.03, sh_r.z - 0.08)
			dir = Vector3(0.02, 1.0, 0.03).normalized()
		AIM:
			dir = Vector3(-0.05, 0.03, -1.0).normalized()
			butt = sh_r + Vector3(-0.04, -0.04, 0.04) - dir * (0.12 * kick)
	# o mosquete: eixo Y do modelo = da coronha para a boca; a coronha fica a 0,9 m da origem do modelo
	var x := Vector3.RIGHT if absf(dir.x) < 0.9 else Vector3.FORWARD
	x = (x - dir * x.dot(dir)).normalized()
	var z := x.cross(dir)
	musket.transform = Transform3D(Basis(x, dir, z), butt + dir * 0.9)
	# braços
	match mode:
		CARRY:
			_ik(sk, to_sk, "L", butt + dir * 0.06 + Vector3(-0.02, 0, 0), sh_l + Vector3(-0.25, -0.3, 0.25))
		ORDER:
			_ik(sk, to_sk, "R", butt + dir * 0.9 + Vector3(0.03, 0, 0.02), sh_r + Vector3(0.3, -0.25, 0.3))
		AIM:
			_ik(sk, to_sk, "R", butt + dir * 0.3 + Vector3(0.0, -0.05, 0), sh_r + Vector3(0.35, -0.35, 0.15))
			_ik(sk, to_sk, "L", butt + dir * 0.78 + Vector3(0.0, -0.04, 0), sh_l + Vector3(0.05, -0.5, -0.2))


## IK analítico de dois ossos (braço e antebraço) no espaço do esqueleto.
func _ik(sk: Skeleton3D, to_sk: Transform3D, side: String, target_ch: Vector3, pole_ch: Vector3) -> void:
	var a: int = _b["UpperArm." + side]
	var b: int = _b["LowerArm." + side]
	var c: int = _b["Palm." + side]
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
