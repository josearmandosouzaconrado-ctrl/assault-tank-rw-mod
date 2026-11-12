class_name Structures
extends RefCounted
## Construções feitas por procedimento, no estilo das cidades coloniais do Caribe (Havana, Nassau, Willemstad):
## paredes grossas rebocadas e pintadas, cunhais de pedra, telhado de telha capa-canal com beiral e caibros à mostra,
## janelas com venezianas, sacadas e varandas de madeira, terraços (azoteias); o píer de madeira sobre estacas;
## e o forte abaluartado (como El Morro) com guaritas nos baluartes, canhoneiras, torre de menagem e morteiros.
## Tudo vai numa única malha com o material shaders/building.gdshader (alfa da cor = tipo de superfície).

const PLAIN := 1.0
const STUCCO := 0.8
const TILE := 0.6
const WOOD := 0.4
const STONE := 0.2
const DARK := 0.0

static var _mat: ShaderMaterial
static var _shader: Shader

const FH := 3.1   # altura de um andar

## Paletas (paredes, venezianas, telhado) por nação, conforme as cidades históricas.
const PALETTES := {
	0: {"walls": ["f2ede0", "e8dcc0", "dfe6e8", "c9d6c0", "eadfcf", "b5654a"], "shut": ["2f4a35", "1f2a33", "3f5f3a"], "roof": ["7a6a5a", "8c4a32", "6e5f52"], "gable": true},
	1: {"walls": ["e8c27a", "e9a9a0", "f2e3b3", "9fc5d8", "f0efe6", "d98e5a", "c9d9a7"], "shut": ["2e5e3e", "2f4f7f", "6b3e26", "7a2a22"], "roof": ["a5532f", "b5653a", "96492a"], "gable": false},
	2: {"walls": ["f1e6c8", "efd9a0", "f4f1e8", "e3c9a8", "d7e0e6"], "shut": ["4d6b85", "5f7d5a", "8a8f96"], "roof": ["a5532f", "5c6670", "9a4f30"], "gable": false},
	3: {"walls": ["e0784a", "f2c14e", "8fb9d6", "e86f6f", "f5f0e6", "9fcf9a"], "shut": ["f5f3ee", "2f4f3a", "8a2a22"], "roof": ["c0603a", "a5532f"], "gable": true},
	4: {"walls": ["f4f1e8", "f2d98a", "e9b8a8", "b9d3e6", "e8c27a"], "shut": ["2a4f8a", "2e5e3e", "6b3e26"], "roof": ["a5532f", "b5653a"], "gable": false},
	5: {"walls": ["e8dcc0", "c9b79a", "a9b8a0", "d6c6a8", "b9a68a"], "shut": ["4a3020", "2f3a2a", "5a4632"], "roof": ["6a5a48", "7a6a5a", "8c4a32"], "gable": true},
}


static func material() -> ShaderMaterial:
	if _mat == null:
		if _shader == null:
			_shader = load("res://shaders/building.gdshader")
		_mat = ShaderMaterial.new()
		_mat.shader = _shader
	return _mat


static func hexc(h: String) -> Color:
	return Color.html(h)


# ------------------------------------------------------------------ primitivas
## Quadrilátero a-b-c-d (a→b = u, a→d = v) com a normal dada; UV em metros a partir de a.
static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color, kind: float, uv0 := Vector2.ZERO) -> void:
	var lc := col.srgb_to_linear()
	st.set_color(Color(lc.r, lc.g, lc.b, kind))
	st.set_normal(n)
	var ud := (b - a)
	var lu := ud.length()
	ud = ud / maxf(lu, 0.0001)
	var vd := d - a
	vd = vd - ud * vd.dot(ud)
	var lv := vd.length()
	vd = vd / maxf(lv, 0.0001)
	var pts := [a, b, c, d]
	var uvs := []
	for p in pts:
		uvs.append(uv0 + Vector2((p - a).dot(ud), (p - a).dot(vd)))
	# o Godot considera frente o sentido horário: ordena para a face da frente ficar do lado da normal
	var order := [0, 2, 1, 0, 3, 2] if (b - a).cross(c - a).dot(n) > 0.0 else [0, 1, 2, 0, 2, 3]
	for k in order:
		st.set_uv(uvs[k])
		st.add_vertex(pts[k])


static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color, kind: float) -> void:
	var lc := col.srgb_to_linear()
	st.set_color(Color(lc.r, lc.g, lc.b, kind))
	st.set_normal(n)
	var ud := (b - a).normalized()
	var vd := (c - a) - ud * (c - a).dot(ud)
	vd = vd.normalized()
	var pts := [a, c, b] if (b - a).cross(c - a).dot(n) > 0.0 else [a, b, c]
	for p in pts:
		st.set_uv(Vector2((p - a).dot(ud), (p - a).dot(vd)))
		st.add_vertex(p)


## Caixa orientada por xf (centro na origem de xf), UV em metros em todas as faces.
static func box(st: SurfaceTool, xf: Transform3D, size: Vector3, col: Color, kind: float, skip_bottom := true) -> void:
	var h := size * 0.5
	var bx := xf.basis.x.normalized()
	var by := xf.basis.y.normalized()
	var bz := xf.basis.z.normalized()
	var o := xf.origin
	var X := bx * h.x
	var Y := by * h.y
	var Z := bz * h.z
	var lo := o - Y
	# frente (+Z), trás (-Z), direita (+X), esquerda (-X): v para cima
	quad(st, lo - X + Z, lo + X + Z, o + X + Z + Y, o - X + Z + Y, bz, col, kind)
	quad(st, lo + X - Z, lo - X - Z, o - X - Z + Y, o + X - Z + Y, -bz, col, kind)
	quad(st, lo + X + Z, lo + X - Z, o + X - Z + Y, o + X + Z + Y, bx, col, kind)
	quad(st, lo - X - Z, lo - X + Z, o - X + Z + Y, o - X - Z + Y, -bx, col, kind)
	quad(st, o - X + Z + Y, o + X + Z + Y, o + X - Z + Y, o - X - Z + Y, by, col, kind)
	if not skip_bottom:
		quad(st, lo - X - Z, lo + X - Z, lo + X + Z, lo - X + Z, -by, col, kind)


## Viga (caixa) de a até b, com seção w × t.
static func beam(st: SurfaceTool, a: Vector3, b: Vector3, w: float, t: float, col: Color, kind: float) -> void:
	var y := b - a
	var L := y.length()
	if L < 0.001:
		return
	y /= L
	var x := Vector3.UP.cross(y)
	if x.length() < 0.1:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	box(st, Transform3D(Basis(x, y, z), (a + b) * 0.5), Vector3(w, L, t), col, kind, false)


static func cyl(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, col: Color, kind: float, seg := 8, cap := true) -> void:
	var ax := b - a
	var L := ax.length()
	if L < 0.001:
		return
	var d := ax / L
	var u := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
	var v := d.cross(u).normalized()
	var circ := TAU * maxf(r0, r1)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var n0 := u * cos(a0) + v * sin(a0)
		var n1 := u * cos(a1) + v * sin(a1)
		var nm := (n0 + n1).normalized()
		quad(st, a + n0 * r0, a + n1 * r0, b + n1 * r1, b + n0 * r1, nm, col, kind, Vector2(circ * i / seg, 0))
	if cap:
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			tri(st, b, b + (u * cos(a0) + v * sin(a0)) * r1, b + (u * cos(a1) + v * sin(a1)) * r1, d, col, kind)


static func dome(st: SurfaceTool, c: Vector3, r: float, h: float, col: Color, kind: float, seg := 10, rings := 4) -> void:
	for j in rings:
		var p0 := PI * 0.5 * j / rings
		var p1 := PI * 0.5 * (j + 1) / rings
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			var q := []
			for pr in [[a0, p0], [a1, p0], [a1, p1], [a0, p1]]:
				q.append(c + Vector3(cos(pr[0]) * cos(pr[1]) * r, sin(pr[1]) * h, sin(pr[0]) * cos(pr[1]) * r))
			var n: Vector3 = ((q[0] + q[2]) * 0.5 - c).normalized()
			quad(st, q[0], q[1], q[2], q[3], n, col, kind)


# ------------------------------------------------------------------ casas
## Janela com moldura, peitoril, vidraça escura e venezianas abertas, na parede de normal n (em xf local).
static func window(st: SurfaceTool, xf: Transform3D, p: Vector3, n: Vector3, w: float, h: float, trim: Color, shut: Color, tall := false) -> void:
	var right := Vector3.UP.cross(n).normalized()
	var B := xf.basis
	var c := p + n * 0.02
	var hw := w * 0.5
	var hh := h * 0.5
	quad(st, xf * (c - right * hw - Vector3.UP * hh), xf * (c + right * hw - Vector3.UP * hh), xf * (c + right * hw + Vector3.UP * hh), xf * (c - right * hw + Vector3.UP * hh), B * n, Color(0.07, 0.08, 0.1), DARK)
	# moldura
	var fr := 0.12
	box(st, Transform3D(B * Basis(right, Vector3.UP, n), xf * (p + Vector3.UP * (hh + fr * 0.5) + n * 0.05)), Vector3(w + fr * 2.4, fr * 1.3, 0.1), trim, PLAIN)
	box(st, Transform3D(B * Basis(right, Vector3.UP, n), xf * (p - Vector3.UP * (hh + 0.05) + n * 0.08)), Vector3(w + fr * 2.0, 0.1, 0.18), trim, PLAIN)
	for s in [-1.0, 1.0]:
		box(st, Transform3D(B * Basis(right, Vector3.UP, n), xf * (p + right * s * (hw + fr * 0.5) + n * 0.04)), Vector3(fr, h, 0.08), trim, PLAIN)
	# caixilho em cruz
	box(st, Transform3D(B * Basis(right, Vector3.UP, n), xf * (p + n * 0.035)), Vector3(0.05, h, 0.03), trim, PLAIN)
	if not tall:
		box(st, Transform3D(B * Basis(right, Vector3.UP, n), xf * (p + n * 0.035 + Vector3.UP * hh * 0.2)), Vector3(w, 0.05, 0.03), trim, PLAIN)
	# venezianas abertas, quase encostadas na parede
	for s in [-1.0, 1.0]:
		var hinge: Vector3 = p + right * s * (hw + fr) + n * 0.06
		var out: Vector3 = (right * s * cos(0.25) + n * sin(0.25)).normalized()
		var sc := hinge + out * hw * 0.5
		var sb := Basis(out * s, Vector3.UP, out.cross(Vector3.UP).normalized() * -s)
		box(st, Transform3D(B * sb, xf * sc), Vector3(hw, h, 0.04), shut, WOOD)


static func door(st: SurfaceTool, xf: Transform3D, p: Vector3, n: Vector3, w: float, h: float, trim: Color, wood: Color, arch := false) -> void:
	var right := Vector3.UP.cross(n).normalized()
	var B := xf.basis
	var bb := B * Basis(right, Vector3.UP, n)
	box(st, Transform3D(bb, xf * (p + Vector3.UP * h * 0.5 + n * 0.03)), Vector3(w, h, 0.06), wood, WOOD)
	# almofadas da porta e maçaneta
	for s in [-1.0, 1.0]:
		box(st, Transform3D(bb, xf * (p + right * s * w * 0.22 + Vector3.UP * h * 0.62 + n * 0.065)), Vector3(w * 0.3, h * 0.45, 0.02), wood.darkened(0.15), WOOD)
	box(st, Transform3D(bb, xf * (p + right * w * 0.32 + Vector3.UP * h * 0.48 + n * 0.08)), Vector3(0.05, 0.05, 0.04), Color(0.75, 0.6, 0.25), PLAIN)
	# moldura de cantaria e degrau
	var fr := 0.22
	box(st, Transform3D(bb, xf * (p + Vector3.UP * (h + fr * 0.5) + n * 0.06)), Vector3(w + fr * 2.0, fr, 0.14), trim, STONE if arch else PLAIN)
	if arch:
		box(st, Transform3D(bb, xf * (p + Vector3.UP * (h + fr + 0.12) + n * 0.07)), Vector3(0.3, 0.28, 0.12), trim, STONE)
	for s in [-1.0, 1.0]:
		box(st, Transform3D(bb, xf * (p + right * s * (w * 0.5 + fr * 0.5) + Vector3.UP * h * 0.5 + n * 0.06)), Vector3(fr, h, 0.14), trim, STONE if arch else PLAIN)
	box(st, Transform3D(bb, xf * (p + Vector3.UP * 0.08 + n * 0.3)), Vector3(w + 0.6, 0.16, 0.55), Color(0.62, 0.58, 0.52), STONE)


## Telhado de quatro águas (ou duas águas com empena) sobre um retângulo w × d na altura y, com beiral.
static func roof(st: SurfaceTool, xf: Transform3D, w: float, d: float, y: float, pitch: float, col: Color, gable: bool, wall: Color, along_z := false) -> void:
	var o := 0.5
	var hw := w * 0.5 + o
	var hd := d * 0.5 + o
	if along_z:
		var t := hw
		hw = hd
		hd = t
	var rh := (minf(hw, hd)) * pitch
	var B := xf.basis
	var rot := Basis(Vector3.UP, PI * 0.5) if along_z else Basis()
	var P := func(v: Vector3) -> Vector3: return xf * (rot * v)
	var N := func(v: Vector3) -> Vector3: return (B * (rot * v)).normalized()
	var ridge_x := hw - hd if not gable else hw
	ridge_x = maxf(ridge_x, 0.0)
	var r0: Vector3 = Vector3(-ridge_x, y + rh, 0)
	var r1: Vector3 = Vector3(ridge_x, y + rh, 0)
	# águas da frente e de trás (UV: u ao longo do beiral, v descendo do cume)
	var e_f0 := Vector3(-hw, y, hd)
	var e_f1 := Vector3(hw, y, hd)
	var e_b0 := Vector3(hw, y, -hd)
	var e_b1 := Vector3(-hw, y, -hd)
	var nf: Vector3 = N.call(Vector3(0, hd, rh))
	var nb: Vector3 = N.call(Vector3(0, hd, -rh))
	quad(st, P.call(r0), P.call(r1), P.call(e_f1), P.call(e_f0), nf, col, TILE)
	quad(st, P.call(r1), P.call(r0), P.call(e_b1), P.call(e_b0), nb, col, TILE)
	if gable:
		# empenas de parede
		var gw := w * 0.5 if not along_z else d * 0.5
		var gd := d * 0.5 if not along_z else w * 0.5
		var grh := gd / hd * rh
		for s in [-1.0, 1.0]:
			tri(st, P.call(Vector3(s * gw, y, gd)), P.call(Vector3(s * gw, y, -gd)), P.call(Vector3(s * gw, y + grh, 0)), N.call(Vector3(s, 0, 0)), wall, STUCCO)
			# telhado avança sobre a empena: borda
			beam(st, P.call(Vector3(s * hw, y, hd)), P.call(Vector3(s * hw, y + rh, 0)), 0.12, 0.2, col.darkened(0.3), PLAIN)
			beam(st, P.call(Vector3(s * hw, y, -hd)), P.call(Vector3(s * hw, y + rh, 0)), 0.12, 0.2, col.darkened(0.3), PLAIN)
	else:
		var nl: Vector3 = N.call(Vector3(-hd, rh, 0))
		var nr: Vector3 = N.call(Vector3(hd, rh, 0))
		tri(st, P.call(e_b1), P.call(e_f0), P.call(r0), nl, col, TILE)
		tri(st, P.call(e_f1), P.call(e_b0), P.call(r1), nr, col, TILE)
	# cumeeira
	if ridge_x > 0.05:
		cyl(st, P.call(r0 + Vector3(-0.05, 0.03, 0)), P.call(r1 + Vector3(0.05, 0.03, 0)), 0.13, 0.13, col.darkened(0.15), PLAIN, 6, false)
	# caibros à mostra sob o beiral (frente e fundo)
	var n_raf := int(hw * 2.0 / 0.7)
	for i in n_raf + 1:
		var x := -hw + 0.2 + i * (hw * 2.0 - 0.4) / maxf(n_raf, 1)
		for s in [-1.0, 1.0]:
			beam(st, P.call(Vector3(x, y - 0.12, s * (hd - o - 0.05))), P.call(Vector3(x, y - 0.02, s * (hd - 0.05))), 0.08, 0.12, Color(0.32, 0.22, 0.14), WOOD)
	# testeira (tábua do beiral)
	beam(st, P.call(Vector3(-hw, y - 0.05, hd)), P.call(Vector3(hw, y - 0.05, hd)), 0.06, 0.2, col.darkened(0.35), PLAIN)
	beam(st, P.call(Vector3(-hw, y - 0.05, -hd)), P.call(Vector3(hw, y - 0.05, -hd)), 0.06, 0.2, col.darkened(0.35), PLAIN)


## Casa colonial. xf: chão no centro, frente para +Z. style: walls, trim, shut, roof (Color), floors, gable,
## balcony, porch, flat, quoins, wood (paredes de tábuas), arch (porta em arco de cantaria).
static func house(st: SurfaceTool, xf: Transform3D, w: float, d: float, style: Dictionary, rng: RandomNumberGenerator) -> void:
	var floors: int = style.get("floors", 2)
	var H := floors * FH
	var wall: Color = style["walls"]
	var trim: Color = style.get("trim", Color(0.95, 0.94, 0.9))
	var shut: Color = style["shut"]
	var roofc: Color = style["roof"]
	var kind := WOOD if style.get("wood", false) else STUCCO
	var B := xf.basis
	# embasamento de pedra e paredes
	box(st, Transform3D(B, xf * Vector3(0, -0.3, 0)), Vector3(w + 0.16, 1.4, d + 0.16), Color(0.6, 0.56, 0.5), STONE)
	var faces := [[Vector3(0, 0, 1), w, d], [Vector3(0, 0, -1), w, d], [Vector3(1, 0, 0), d, w], [Vector3(-1, 0, 0), d, w]]
	for f in faces:
		var n: Vector3 = f[0]
		var r := Vector3.UP.cross(n).normalized()
		var hl: float = f[1] * 0.5
		var off: float = f[2] * 0.5
		var a := n * off - r * hl + Vector3(0, 0.4, 0)
		var b := n * off + r * hl + Vector3(0, 0.4, 0)
		quad(st, xf * a, xf * b, xf * (b + Vector3(0, H - 0.4, 0)), xf * (a + Vector3(0, H - 0.4, 0)), B * n, wall, kind)
	# cunhais de pedra nas quinas
	if style.get("quoins", false):
		var qc := wall.lerp(Color(0.85, 0.82, 0.75), 0.6)
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				var k := 0
				var yy := 0.5
				while yy < H - 0.3:
					var big := k % 2 == 0
					var sx := 0.5 if big else 0.3
					var sz := 0.3 if big else 0.5
					box(st, Transform3D(B, xf * Vector3(cx * (w * 0.5 - sx * 0.5 + 0.03), yy + 0.17, cz * (d * 0.5 - sz * 0.5 + 0.03))), Vector3(sx, 0.34, sz), qc, STONE)
					yy += 0.4
					k += 1
	# frisos entre os andares e cornija
	for f in range(1, floors):
		box(st, Transform3D(B, xf * Vector3(0, f * FH, 0)), Vector3(w + 0.12, 0.16, d + 0.12), trim, PLAIN)
	box(st, Transform3D(B, xf * Vector3(0, H - 0.1, 0)), Vector3(w + 0.26, 0.22, d + 0.26), trim, PLAIN)
	# janelas e porta
	var balcony: bool = style.get("balcony", false) and floors > 1
	if style.get("church", false):
		# nave de igreja: janelas altas só nas laterais e portal grande
		door(st, xf, Vector3(0, 0.4, d * 0.5), Vector3(0, 0, 1), 2.0, 3.8, trim, Color(0.3, 0.18, 0.1), true)
		for fi in [2, 3]:
			var n: Vector3 = faces[fi][0]
			var r := Vector3.UP.cross(n).normalized()
			var nw := int(d / 4.5)
			for i in nw:
				var x := (float(i) - (nw - 1) * 0.5) * (d / nw)
				window(st, xf, n * (w * 0.5) + r * x + Vector3(0, H * 0.55, 0), n, 1.1, 3.0, trim, wall.darkened(0.2), true)
		floors = 0
	for f in floors:
		var y0 := f * FH
		for fi in faces.size():
			var n: Vector3 = faces[fi][0]
			var r := Vector3.UP.cross(n).normalized()
			var len: float = faces[fi][1]
			var off: float = faces[fi][2] * 0.5
			var nwin := maxi(1, int(len / 2.5))
			if fi >= 2:
				nwin = maxi(1, int(len / 3.2))
			if fi == 1 and rng.randf() < 0.4:
				continue
			for i in nwin:
				var x := (float(i) - (nwin - 1) * 0.5) * (len / nwin)
				var p := n * off + r * x
				if f == 0 and fi == 0 and absf(x) < len / nwin * 0.6:
					door(st, xf, p + Vector3(0, 0.4, 0), n, 1.25, 2.3, trim, Color(0.35, 0.2, 0.12) if rng.randf() < 0.5 else shut.darkened(0.2), style.get("arch", false))
					continue
				var tall := f > 0 and fi == 0 and balcony
				var wh := 2.1 if tall else 1.45
				var wy := y0 + (0.25 + wh * 0.5 + 0.15 if tall else 1.75)
				window(st, xf, p + Vector3(0, wy, 0), n, 0.95, wh, trim, shut, tall)
	# sacada de madeira no primeiro andar (frente)
	if balcony:
		var bw := w * (0.92 if rng.randf() < 0.5 else 0.6)
		var bd := 0.95
		var wood := shut.darkened(0.15) if rng.randf() < 0.6 else Color(0.36, 0.24, 0.15)
		var by := FH + 0.1
		box(st, Transform3D(B, xf * Vector3(0, by, d * 0.5 + bd * 0.5)), Vector3(bw, 0.12, bd), wood, WOOD)
		for i in 4:
			var x := (float(i) / 3.0 - 0.5) * (bw - 0.2)
			beam(st, xf * Vector3(x, by - 0.75, d * 0.5 + 0.02), xf * Vector3(x, by - 0.06, d * 0.5 + bd * 0.85), 0.1, 0.1, wood, WOOD)
		var rail_y := by + 1.0
		var front := d * 0.5 + bd - 0.05
		var nb := int(bw / 0.16)
		for i in nb + 1:
			var x := -bw * 0.5 + 0.05 + i * (bw - 0.1) / nb
			box(st, Transform3D(B, xf * Vector3(x, by + 0.5, front)), Vector3(0.05, 0.9, 0.05), wood, PLAIN)
		for s in [-1.0, 1.0]:
			for i in 5:
				var z := d * 0.5 + 0.1 + i * (bd - 0.15) / 4.0
				box(st, Transform3D(B, xf * Vector3(s * (bw * 0.5 - 0.05), by + 0.5, z)), Vector3(0.05, 0.9, 0.05), wood, PLAIN)
		box(st, Transform3D(B, xf * Vector3(0, rail_y, front)), Vector3(bw, 0.08, 0.1), wood, WOOD)
		for s in [-1.0, 1.0]:
			box(st, Transform3D(B, xf * Vector3(s * (bw * 0.5 - 0.05), rail_y, d * 0.5 + bd * 0.5)), Vector3(0.1, 0.08, bd), wood, WOOD)
	# varanda coberta no térreo (casas inglesas e holandesas)
	if style.get("porch", false):
		var pd := 2.2
		var wood2 := Color(0.85, 0.83, 0.78) if rng.randf() < 0.6 else shut
		box(st, Transform3D(B, xf * Vector3(0, 0.3, d * 0.5 + pd * 0.5)), Vector3(w, 0.2, pd), Color(0.45, 0.33, 0.22), WOOD)
		var npost := maxi(2, int(w / 2.2) + 1)
		for i in npost:
			var x := -w * 0.5 + 0.15 + i * (w - 0.3) / (npost - 1)
			box(st, Transform3D(B, xf * Vector3(x, 0.4 + (FH - 0.5) * 0.5, d * 0.5 + pd - 0.15)), Vector3(0.16, FH - 0.5, 0.16), wood2, PLAIN)
		box(st, Transform3D(B, xf * Vector3(0, FH - 0.05, d * 0.5 + pd - 0.15)), Vector3(w + 0.1, 0.2, 0.2), wood2, PLAIN)
		var e0 := Vector3(-w * 0.5 - 0.2, FH + 0.05, d * 0.5 + pd + 0.3)
		var e1 := Vector3(w * 0.5 + 0.2, FH + 0.05, d * 0.5 + pd + 0.3)
		var t1 := Vector3(w * 0.5 + 0.2, FH + 0.7, d * 0.5)
		var t0 := Vector3(-w * 0.5 - 0.2, FH + 0.7, d * 0.5)
		quad(st, xf * t1, xf * t0, xf * e0, xf * e1, B * Vector3(0, 1, 0.3).normalized(), roofc, TILE)
		# guarda-corpo da varanda
		box(st, Transform3D(B, xf * Vector3(0, 1.2, d * 0.5 + pd - 0.15)), Vector3(w, 0.07, 0.08), wood2, PLAIN)
	# telhado: telha, terraço com platibanda ou empena virada para a rua (holandesa)
	if style.get("flat", false):
		box(st, Transform3D(B, xf * Vector3(0, H + 0.05, 0)), Vector3(w + 0.2, 0.12, d + 0.2), Color(0.66, 0.6, 0.52), STONE)
		for f in faces:
			var n: Vector3 = f[0]
			var r := Vector3.UP.cross(n).normalized()
			box(st, Transform3D(B * Basis(r, Vector3.UP, n), xf * (n * (f[2] * 0.5 + 0.05) + Vector3(0, H + 0.5, 0))), Vector3(f[1] + 0.3, 0.9, 0.22), wall, kind)
			box(st, Transform3D(B * Basis(r, Vector3.UP, n), xf * (n * (f[2] * 0.5 + 0.05) + Vector3(0, H + 1.0, 0))), Vector3(f[1] + 0.42, 0.12, 0.34), trim, PLAIN)
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				box(st, Transform3D(B, xf * Vector3(cx * (w * 0.5 + 0.05), H + 1.25, cz * (d * 0.5 + 0.05))), Vector3(0.32, 0.4, 0.32), trim, PLAIN)
	elif style.get("dutch", false):
		roof(st, xf, w, d, H, 1.3, roofc, true, wall, true)
		# frontão curvo (gable holandês) na fachada
		var gy := H
		var gh := w * 0.5 * 1.2
		var steps := [[0.5, 0.0], [0.5, 0.25], [0.3, 0.35], [0.3, 0.7], [0.17, 0.8], [0.17, 1.0]]
		for i in steps.size() - 1:
			var hw0: float = steps[i][0] * w
			var hw1: float = steps[i + 1][0] * w
			var y0: float = gy + steps[i][1] * gh
			var y1: float = gy + steps[i + 1][1] * gh
			quad(st, xf * Vector3(-hw0, y0, d * 0.5 + 0.12), xf * Vector3(hw0, y0, d * 0.5 + 0.12), xf * Vector3(hw1, y1, d * 0.5 + 0.12), xf * Vector3(-hw1, y1, d * 0.5 + 0.12), B * Vector3(0, 0, 1), wall, kind)
		box(st, Transform3D(B, xf * Vector3(0, gy + gh + 0.08, d * 0.5 + 0.12)), Vector3(w * 0.4, 0.16, 0.3), trim, PLAIN)
		window(st, xf, Vector3(0, gy + gh * 0.45, d * 0.5 + 0.12), Vector3(0, 0, 1), 0.8, 1.0, trim, shut)
	else:
		roof(st, xf, w, d, H, 0.55 if style.get("gable", false) else 0.48, roofc, style.get("gable", false), wall)
		if rng.randf() < 0.45:
			var cx := (rng.randf() - 0.5) * w * 0.6
			box(st, Transform3D(B, xf * Vector3(cx, H + 1.4, -d * 0.2)), Vector3(0.6, 2.0, 0.6), wall, kind)
			box(st, Transform3D(B, xf * Vector3(cx, H + 2.45, -d * 0.2)), Vector3(0.8, 0.12, 0.8), trim, PLAIN)


## Estilo aleatório de casa para a nação dada.
static func house_style(nation: int, rng: RandomNumberGenerator) -> Dictionary:
	var pal: Dictionary = PALETTES.get(nation, PALETTES[1])
	var walls: Array = pal["walls"]
	var st := {
		"walls": hexc(walls[rng.randi() % walls.size()]),
		"shut": hexc(pal["shut"][rng.randi() % pal["shut"].size()]),
		"roof": hexc(pal["roof"][rng.randi() % pal["roof"].size()]),
		"floors": 2 if rng.randf() < 0.7 else 1,
		"gable": pal["gable"],
		"quoins": rng.randf() < 0.5,
		"arch": rng.randf() < 0.4,
	}
	match nation:
		1, 4:
			st["balcony"] = rng.randf() < 0.65
			st["flat"] = rng.randf() < 0.25
		2:
			st["balcony"] = rng.randf() < 0.5
		0, 5:
			st["porch"] = rng.randf() < 0.5
			st["wood"] = rng.randf() < 0.35
			st["balcony"] = not st["porch"] and rng.randf() < 0.3
		3:
			st["dutch"] = rng.randf() < 0.6
			st["porch"] = not st["dutch"] and rng.randf() < 0.4
	if st.get("wood", false):
		st["quoins"] = false
	return st


## Igreja barroca: nave, frontão com volutas, torre sineira com cúpula e cruz.
static func church(st: SurfaceTool, xf: Transform3D, nation: int, rng: RandomNumberGenerator) -> void:
	var wall := Color(0.93, 0.88, 0.76) if nation != 0 else Color(0.9, 0.9, 0.86)
	var trim := Color(0.8, 0.74, 0.62)
	var B := xf.basis
	var w := 10.0
	var d := 20.0
	var H := 9.0
	house(st, xf * Transform3D(Basis(), Vector3(0, 0, -2.0)), w, d, {"walls": wall, "trim": trim, "shut": Color(0.3, 0.22, 0.15),
		"roof": Color(0.66, 0.33, 0.2), "floors": 3, "gable": true, "quoins": true, "arch": true, "church": true}, rng)
	# frontão sobre a fachada
	var fz := 8.0 + 0.1
	var steps := [[0.5, 0.0], [0.5, 0.3], [0.32, 0.45], [0.25, 1.0]]
	for i in steps.size() - 1:
		quad(st, xf * Vector3(-steps[i][0] * w, H + steps[i][1] * 3.5, fz), xf * Vector3(steps[i][0] * w, H + steps[i][1] * 3.5, fz),
			xf * Vector3(steps[i + 1][0] * w, H + steps[i + 1][1] * 3.5, fz), xf * Vector3(-steps[i + 1][0] * w, H + steps[i + 1][1] * 3.5, fz), B * Vector3(0, 0, 1), wall, STUCCO)
	box(st, Transform3D(B, xf * Vector3(0, H + 3.6, fz)), Vector3(w * 0.55, 0.25, 0.4), trim, PLAIN)
	cyl(st, xf * Vector3(0, H + 3.7, fz), xf * Vector3(0, H + 5.3, fz), 0.08, 0.08, Color(0.2, 0.2, 0.2), PLAIN, 4)
	box(st, Transform3D(B, xf * Vector3(0, H + 4.9, fz)), Vector3(0.8, 0.1, 0.1), Color(0.2, 0.2, 0.2), PLAIN)
	# óculo
	dome(st, xf * Vector3(0, H + 1.2, fz + 0.02), 0.8, 0.01, Color(0.1, 0.1, 0.12), DARK, 10, 1)
	# pilastras na fachada
	for x in [-4.6, -1.6, 1.6, 4.6]:
		box(st, Transform3D(B, xf * Vector3(x, H * 0.5, fz)), Vector3(0.5, H, 0.25), trim, PLAIN)
	# torre sineira ao lado
	var tx := w * 0.5 + 2.5
	var tz := 5.5
	var th := 17.0
	box(st, Transform3D(B, xf * Vector3(tx, th * 0.5 - 0.5, tz)), Vector3(4.6, th + 1.0, 4.6), wall, STUCCO)
	for y in [6.0, 11.0]:
		box(st, Transform3D(B, xf * Vector3(tx, y, tz)), Vector3(4.8, 0.2, 4.8), trim, PLAIN)
	# campanário aberto
	for n in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		window(st, xf, Vector3(tx, th - 2.5, tz) + n * 2.3, n, 1.4, 2.6, trim, wall.darkened(0.3), true)
	box(st, Transform3D(B, xf * Vector3(tx, th + 0.1, tz)), Vector3(5.0, 0.3, 5.0), trim, PLAIN)
	dome(st, xf * Vector3(tx, th + 0.25, tz), 2.1, 2.6, Color(0.62, 0.35, 0.22), TILE, 12, 4)
	cyl(st, xf * Vector3(tx, th + 2.8, tz), xf * Vector3(tx, th + 4.6, tz), 0.07, 0.07, Color(0.2, 0.2, 0.2), PLAIN, 4)
	box(st, Transform3D(B, xf * Vector3(tx, th + 4.1, tz)), Vector3(0.8, 0.09, 0.09), Color(0.2, 0.2, 0.2), PLAIN)


## Armazém de madeira com portões largos.
static func warehouse(st: SurfaceTool, xf: Transform3D, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var wood := Color(0.5, 0.38, 0.26).lerp(Color(0.62, 0.55, 0.45), rng.randf())
	house(st, xf, w, d, {"walls": wood, "trim": Color(0.3, 0.2, 0.12), "shut": Color(0.3, 0.22, 0.15), "roof": Color(0.5, 0.45, 0.4),
		"floors": 1, "gable": true, "wood": true}, rng)
	var B := xf.basis
	for i in 2:
		var x := (i - 0.5) * w * 0.5
		box(st, Transform3D(B, xf * Vector3(x, 1.7, d * 0.5 + 0.05)), Vector3(2.6, 2.9, 0.1), Color(0.3, 0.2, 0.12), WOOD)
		beam(st, xf * Vector3(x - 1.3, 0.4, d * 0.5 + 0.12), xf * Vector3(x + 1.3, 3.0, d * 0.5 + 0.12), 0.12, 0.05, Color(0.25, 0.16, 0.1), WOOD)


## Praça calçada com lajes de pedra que acompanham o terreno (raio r em volta de c).
static func plaza(st: SurfaceTool, w: World, c: Vector3, r: float) -> void:
	var cell := 2.0
	var n := int(r * 2.0 / cell)
	var col := Color(0.72, 0.68, 0.6)
	for i in n:
		for j in n:
			var x0 := c.x - r + i * cell
			var z0 := c.z - r + j * cell
			var mid := Vector2(x0 + cell * 0.5, z0 + cell * 0.5)
			if mid.distance_to(Vector2(c.x, c.z)) > r:
				continue
			var ps := []
			for q in [Vector2(0, 0), Vector2(cell, 0), Vector2(cell, cell), Vector2(0, cell)]:
				var px: float = x0 + q.x
				var pz: float = z0 + q.y
				ps.append(Vector3(px, w.terrain_height(px, pz) + 0.4, pz))
			quad(st, ps[0], ps[1], ps[2], ps[3], Vector3.UP, col, STONE, Vector2(x0, z0))
	# meio-fio em volta
	for k in 48:
		var a0 := TAU * k / 48.0
		var a1 := TAU * (k + 1) / 48.0
		var p0 := c + Vector3(cos(a0), 0, sin(a0)) * r
		var p1 := c + Vector3(cos(a1), 0, sin(a1)) * r
		p0.y = w.terrain_height(p0.x, p0.z) + 0.35
		p1.y = w.terrain_height(p1.x, p1.z) + 0.35
		beam(st, p0, p1, 0.35, 0.2, Color(0.6, 0.57, 0.5), STONE)


# ------------------------------------------------------------------ píer
## Píer de madeira sobre estacas (frente para +Z, piso a 1,65 m): passarela de 7,2 m × 72 m e cabeço em T de 22 m.
## glow recebe as lâmpadas dos lampiões.
static func pier(st: SurfaceTool, glow: SurfaceTool, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	var deck := 1.65
	var B := xf.basis
	var plank_c := [Color(0.66, 0.56, 0.44), Color(0.6, 0.52, 0.42), Color(0.7, 0.6, 0.47), Color(0.58, 0.53, 0.47)]
	var pile_c := Color(0.45, 0.36, 0.27)
	var wet := Color(0.2, 0.22, 0.16)
	# tábuas atravessadas (passarela) e do cabeço
	var z := -10.0
	while z < 61.4:
		var c: Color = plank_c[rng.randi() % plank_c.size()]
		box(st, Transform3D(B, xf * Vector3(rng.randf_range(-0.04, 0.04), deck - 0.04, z + 0.15)), Vector3(7.2, 0.08, 0.3), c, WOOD)
		z += 0.33
	z = 61.5
	while z < 70.5:
		for seg in [-1.0, 0.0, 1.0]:
			var c: Color = plank_c[rng.randi() % plank_c.size()]
			box(st, Transform3D(B, xf * Vector3(seg * 7.45, deck - 0.04, z + 0.15)), Vector3(7.4, 0.08, 0.3), c, WOOD)
		z += 0.33
	# longarinas e travessas
	for x in [-3.3, -1.1, 1.1, 3.3]:
		box(st, Transform3D(B, xf * Vector3(x, deck - 0.22, 25.75)), Vector3(0.22, 0.28, 71.5), pile_c, WOOD)
	for x in [-10.8, -7.2, -3.6, 0.0, 3.6, 7.2, 10.8]:
		box(st, Transform3D(B, xf * Vector3(x, deck - 0.22, 66.0)), Vector3(0.22, 0.28, 9.0), pile_c, WOOD)
	# fileiras de estacas com contraventamento em X
	var rows := []
	var zz := -6.0
	while zz <= 60.0:
		rows.append(zz)
		zz += 3.6
	for rz in rows:
		var pz: float = rz
		box(st, Transform3D(B, xf * Vector3(0, deck - 0.45, pz)), Vector3(7.8, 0.26, 0.3), pile_c, WOOD)
		for x in [-3.5, 0.0, 3.5]:
			cyl(st, xf * Vector3(x, -5.0, pz), xf * Vector3(x, 0.4, pz), 0.2, 0.19, wet, WOOD, 7, false)
			cyl(st, xf * Vector3(x, 0.4, pz), xf * Vector3(x, deck - 0.3, pz), 0.19, 0.18, pile_c, WOOD, 7, false)
		beam(st, xf * Vector3(-3.5, deck - 0.6, pz + 0.22), xf * Vector3(3.5, -0.6, pz + 0.22), 0.16, 0.08, pile_c, WOOD)
		beam(st, xf * Vector3(3.5, deck - 0.6, pz - 0.22), xf * Vector3(-3.5, -0.6, pz - 0.22), 0.16, 0.08, pile_c, WOOD)
	for pz in [62.5, 66.0, 69.5]:
		box(st, Transform3D(B, xf * Vector3(0, deck - 0.45, pz)), Vector3(22.6, 0.26, 0.3), pile_c, WOOD)
		for x in [-10.8, -7.2, -3.6, 0.0, 3.6, 7.2, 10.8]:
			cyl(st, xf * Vector3(x, -5.0, pz), xf * Vector3(x, 0.4, pz), 0.2, 0.19, wet, WOOD, 7, false)
			cyl(st, xf * Vector3(x, 0.4, pz), xf * Vector3(x, deck - 0.3, pz), 0.19, 0.18, pile_c, WOOD, 7, false)
	# defensas verticais na frente do cabeço (onde o navio encosta)
	var fx := -10.5
	while fx <= 10.6:
		cyl(st, xf * Vector3(fx, -1.5, 70.75), xf * Vector3(fx, deck + 0.35, 70.75), 0.17, 0.17, pile_c.darkened(0.1), WOOD, 6)
		fx += 1.5
	box(st, Transform3D(B, xf * Vector3(0, deck + 0.1, 70.6)), Vector3(22.4, 0.22, 0.25), pile_c, WOOD)
	# cabeços de amarração (com tampa de ferro) e rolos de corda
	var bollards := [Vector3(-10.4, 0, 70.0), Vector3(-3.6, 0, 70.0), Vector3(3.6, 0, 70.0), Vector3(10.4, 0, 70.0),
		Vector3(-10.6, 0, 62.2), Vector3(10.6, 0, 62.2)]
	var bz := 8.0
	while bz < 58.0:
		bollards.append(Vector3(-3.3, 0, bz))
		bollards.append(Vector3(3.3, 0, bz + 5.0))
		bz += 12.0
	for bp in bollards:
		var b0: Vector3 = bp + Vector3(0, deck, 0)
		cyl(st, xf * b0, xf * (b0 + Vector3(0, 0.55, 0)), 0.2, 0.17, Color(0.3, 0.24, 0.18), WOOD, 8)
		cyl(st, xf * (b0 + Vector3(0, 0.55, 0)), xf * (b0 + Vector3(0, 0.65, 0)), 0.22, 0.22, Color(0.15, 0.15, 0.16), PLAIN, 8)
		if rng.randf() < 0.6:
			var rc: Vector3 = b0 + Vector3(0.7 * signf(-bp.x + 0.01), 0.08, 0.6)
			for i in 10:
				var a0 := TAU * i / 10.0
				var a1 := TAU * (i + 1) / 10.0
				cyl(st, xf * (rc + Vector3(cos(a0), 0, sin(a0)) * 0.32), xf * (rc + Vector3(cos(a1), 0, sin(a1)) * 0.32), 0.07, 0.07, Color(0.72, 0.62, 0.42), PLAIN, 5, false)
	# escadas de marinheiro descendo até a água
	for sx in [-1.0, 1.0]:
		var lx: float = sx * 5.5
		for r in [-0.25, 0.25]:
			beam(st, xf * Vector3(lx + r, -1.2, 70.9), xf * Vector3(lx + r, deck + 0.6, 70.9), 0.08, 0.08, pile_c, WOOD)
		var ry := -1.0
		while ry < deck:
			box(st, Transform3D(B, xf * Vector3(lx, ry, 70.92)), Vector3(0.5, 0.05, 0.06), pile_c, WOOD)
			ry += 0.35
	# lampiões em postes
	for lp in [Vector3(-3.4, 0, 18.0), Vector3(3.4, 0, 40.0), Vector3(-10.8, 0, 70.2), Vector3(10.8, 0, 70.2)]:
		var p0: Vector3 = lp + Vector3(0, deck, 0)
		beam(st, xf * p0, xf * (p0 + Vector3(0, 3.4, 0)), 0.14, 0.14, Color(0.25, 0.18, 0.12), WOOD)
		var arm: Vector3 = p0 + Vector3(-signf(lp.x) * 0.6, 3.2, 0)
		beam(st, xf * (p0 + Vector3(0, 3.2, 0)), xf * arm, 0.06, 0.06, Color(0.15, 0.15, 0.16), PLAIN)
		box(st, Transform3D(B, xf * (arm + Vector3(0, -0.35, 0))), Vector3(0.3, 0.42, 0.3), Color(0.12, 0.12, 0.13), PLAIN)
		ShipBuilder._box(glow, Transform3D(B, xf * (arm + Vector3(0, -0.35, 0))), Vector3(0.24, 0.32, 0.24), Color(1, 1, 1))


# ------------------------------------------------------------------ forte
## Forte abaluartado (planta em estrela com 4 baluartes), com centro na origem de xf e terrapleno a H.
## Devolve as posições (no espaço do mundo) e direções das canhoneiras para os canhões.
static func fort(st: SurfaceTool, xf: Transform3D, rng: RandomNumberGenerator) -> Array:
	var a := 15.0
	var H := 7.5
	var sq := [Vector2(a, a), Vector2(-a, a), Vector2(-a, -a), Vector2(a, -a)]
	var poly := PackedVector2Array()
	for i in 4:
		var v: Vector2 = sq[i]
		var vp: Vector2 = sq[(i + 3) % 4]
		var vn: Vector2 = sq[(i + 1) % 4]
		var e_in := (v - vp).normalized()
		var e_out := (vn - v).normalized()
		var n_in := Vector2(e_in.y, -e_in.x)
		var n_out := Vector2(e_out.y, -e_out.x)
		if n_in.dot(v) < 0.0:
			n_in = -n_in
		if n_out.dot(v) < 0.0:
			n_out = -n_out
		var p1 := v - e_in * 6.5
		poly.append(p1)
		poly.append(p1 + n_in * 3.5)
		poly.append(v + v.normalized() * 10.0)
		poly.append(v + e_out * 6.5 + n_out * 3.5)
		poly.append(v + e_out * 6.5)
	var B := xf.basis
	var stone := Color(0.78, 0.72, 0.6)
	var stone2 := Color(0.7, 0.64, 0.53)
	var n := poly.size()
	var guns := []
	var y0 := -3.0
	var top := PackedVector2Array()
	for i in n:
		top.append(poly[i] * (1.0 - 1.1 / poly[i].length()))
	var dist := 0.0
	for i in n:
		var p0 := poly[i]
		var p1 := poly[(i + 1) % n]
		var t0 := top[i]
		var t1 := top[(i + 1) % n]
		var seg_len := p0.distance_to(p1)
		var out := Vector2((p1 - p0).y, -(p1 - p0).x).normalized()
		if out.dot((p0 + p1) * 0.5) < 0.0:
			out = -out
		var n3 := B * Vector3(out.x, 0.15, out.y).normalized()
		# escarpa inclinada (talude) em cantaria
		quad(st, xf * Vector3(p0.x, y0, p0.y), xf * Vector3(p1.x, y0, p1.y), xf * Vector3(t1.x, H - 1.0, t1.y), xf * Vector3(t0.x, H - 1.0, t0.y), n3, stone, STONE, Vector2(dist, 0))
		# cordão (moldura redonda) e parapeito reto
		var c0 := t0 + out * 0.15
		var c1 := t1 + out * 0.15
		cyl(st, xf * Vector3(c0.x, H - 0.95, c0.y), xf * Vector3(c1.x, H - 0.95, c1.y), 0.22, 0.22, stone2, STONE, 6, false)
		quad(st, xf * Vector3(t0.x, H - 1.0, t0.y), xf * Vector3(t1.x, H - 1.0, t1.y), xf * Vector3(t1.x, H + 1.5, t1.y), xf * Vector3(t0.x, H + 1.5, t0.y), B * Vector3(out.x, 0, out.y), stone, STONE, Vector2(dist, H - 1.0 - y0))
		# topo do parapeito com canhoneiras abertas (merlões entre elas)
		var inner0 := t0 - out * 2.4
		var inner1 := t1 - out * 2.4
		var segs := maxi(1, int(seg_len / 3.2))
		for k in segs:
			var u0 := float(k) / segs
			var u1 := float(k + 1) / segs
			var m0 := t0.lerp(t1, u0)
			var m1 := t0.lerp(t1, u1)
			var i0 := inner0.lerp(inner1, u0)
			var i1 := inner0.lerp(inner1, u1)
			var mid := (m0 + m1) * 0.5
			var gap := 0.75 / maxf(m0.distance_to(m1), 0.1)
			var is_gun := k % 2 == 1 and seg_len > 5.0
			var mtop := H + 1.5
			if is_gun:
				# canhoneira: duas metades de merlão e o vão no meio
				for half in [[0.0, 0.5 - gap], [0.5 + gap, 1.0]]:
					var ma := m0.lerp(m1, half[0])
					var mb := m0.lerp(m1, half[1])
					var ia := i0.lerp(i1, half[0])
					var ib := i0.lerp(i1, half[1])
					quad(st, xf * Vector3(ma.x, mtop, ma.y), xf * Vector3(mb.x, mtop, mb.y), xf * Vector3(ib.x, mtop, ib.y), xf * Vector3(ia.x, mtop, ia.y), B * Vector3.UP, stone2, STONE)
					quad(st, xf * Vector3(ib.x, H, ib.y), xf * Vector3(ia.x, H, ia.y), xf * Vector3(ia.x, mtop, ia.y), xf * Vector3(ib.x, mtop, ib.y), B * Vector3(-out.x, 0, -out.y), stone2, STONE)
				var ga := m0.lerp(m1, 0.5 - gap)
				var gb := m0.lerp(m1, 0.5 + gap)
				var iga := i0.lerp(i1, 0.5 - gap)
				var igb := i0.lerp(i1, 0.5 + gap)
				quad(st, xf * Vector3(ga.x, H + 0.6, ga.y), xf * Vector3(gb.x, H + 0.6, gb.y), xf * Vector3(igb.x, H + 0.6, igb.y), xf * Vector3(iga.x, H + 0.6, iga.y), B * Vector3.UP, stone2, STONE)
				for side in [[ga, iga, 1.0], [gb, igb, -1.0]]:
					var e: Vector2 = (m1 - m0).normalized() * side[2]
					quad(st, xf * Vector3(side[0].x, H + 0.6, side[0].y), xf * Vector3(side[1].x, H + 0.6, side[1].y), xf * Vector3(side[1].x, mtop, side[1].y), xf * Vector3(side[0].x, mtop, side[0].y), B * Vector3(e.x, 0, e.y), stone2, STONE)
				var gp := mid - out * 2.2
				guns.append([xf * Vector3(gp.x, H, gp.y), B * Vector3(out.x, 0, out.y)])
			else:
				quad(st, xf * Vector3(m0.x, mtop, m0.y), xf * Vector3(m1.x, mtop, m1.y), xf * Vector3(i1.x, mtop, i1.y), xf * Vector3(i0.x, mtop, i0.y), B * Vector3.UP, stone2, STONE)
				quad(st, xf * Vector3(i1.x, H, i1.y), xf * Vector3(i0.x, H, i0.y), xf * Vector3(i0.x, mtop, i0.y), xf * Vector3(i1.x, mtop, i1.y), B * Vector3(-out.x, 0, -out.y), stone2, STONE)
		dist += seg_len
	# piso do terrapleno
	var tri_idx := Geometry2D.triangulate_polygon(top)
	for k in range(0, tri_idx.size(), 3):
		var pa := top[tri_idx[k]]
		var pb := top[tri_idx[k + 1]]
		var pc := top[tri_idx[k + 2]]
		tri(st, xf * Vector3(pa.x, H, pa.y), xf * Vector3(pb.x, H, pb.y), xf * Vector3(pc.x, H, pc.y), B * Vector3.UP, Color(0.62, 0.57, 0.48), STONE)
	# guaritas (sentinelas) nas pontas dos baluartes
	for i in range(2, n, 5):
		var tip := top[i]
		var g := tip - tip.normalized() * 1.2
		var gb := xf * Vector3(g.x, H + 1.5, g.y)
		var up := B * Vector3.UP
		cyl(st, gb - up * 1.4, gb, 0.3, 1.0, stone2, STONE, 10, false)
		cyl(st, gb, gb + up * 2.2, 0.95, 0.95, stone, STONE, 10, false)
		cyl(st, gb + up * 2.2, gb + up * 2.4, 1.1, 1.1, stone2, STONE, 10, true)
		dome(st, gb + up * 2.4, 1.0, 0.9, stone, STONE, 10, 3)
		cyl(st, gb + up * 3.25, gb + up * 3.7, 0.12, 0.05, stone2, STONE, 6)
		var od := B * Vector3(tip.normalized().x, 0, tip.normalized().y)
		var r := up.cross(od).normalized()
		for s in [-0.6, 0.0, 0.6]:
			var dir: Vector3 = (od + r * s).normalized()
			quad(st, gb + dir * 0.97 + up * 1.0 - r.rotated(up, s) * 0.08, gb + dir * 0.97 + up * 1.0 + r.rotated(up, s) * 0.08, gb + dir * 0.97 + up * 1.6 + r.rotated(up, s) * 0.08, gb + dir * 0.97 + up * 1.6 - r.rotated(up, s) * 0.08, dir, Color(0.05, 0.05, 0.05), DARK)
	# torre de menagem com ameias (onde fica a bandeira)
	var tw := 7.0
	var th := 8.0
	var tpos := Vector3(0, H, -6.0)
	box(st, Transform3D(B, xf * (tpos + Vector3(0, th * 0.5, 0))), Vector3(tw, th, tw), stone, STONE)
	box(st, Transform3D(B, xf * (tpos + Vector3(0, th + 0.15, 0))), Vector3(tw + 0.5, 0.3, tw + 0.5), stone2, STONE)
	for f in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var r := Vector3.UP.cross(f)
		for k in 4:
			var x := (k - 1.5) * 1.75
			box(st, Transform3D(B, xf * (tpos + f * (tw * 0.5 + 0.05) + r * x + Vector3(0, th + 0.8, 0))), Vector3(1.0 if absf(f.x) < 0.5 else 0.6, 1.0, 0.6 if absf(f.x) < 0.5 else 1.0), stone2, STONE)
		window(st, xf, tpos + f * (tw * 0.5) + Vector3(0, th * 0.62, 0), f, 0.7, 1.1, stone2, Color(0.3, 0.2, 0.12))
	door(st, xf, tpos + Vector3(0, 0, tw * 0.5), Vector3(0, 0, 1), 1.6, 2.6, stone2, Color(0.3, 0.2, 0.12), true)
	# quartel de dois andares com telhado
	house(st, xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-7.5, H, 4.0)), 12.0, 6.0, {"walls": Color(0.85, 0.8, 0.68), "trim": stone2,
		"shut": Color(0.35, 0.25, 0.15), "roof": Color(0.62, 0.33, 0.2), "floors": 1, "gable": false, "quoins": true}, rng)
	# paiol abobadado
	var pm := Vector3(8.0, H, 5.0)
	box(st, Transform3D(B, xf * (pm + Vector3(0, 1.2, 0))), Vector3(5.0, 2.4, 4.0), stone, STONE)
	cyl(st, xf * (pm + Vector3(-2.5, 2.4, 0)), xf * (pm + Vector3(2.5, 2.4, 0)), 2.0, 2.0, stone2, STONE, 10, true)
	# portão de entrada (do lado da cidade) em arco de cantaria
	var gpt := (poly[14] + poly[15]) * 0.5
	var gout := Vector2((poly[15] - poly[14]).y, -(poly[15] - poly[14]).x).normalized()
	if gout.dot(gpt) < 0.0:
		gout = -gout
	var gn := Vector3(gout.x, 0, gout.y)
	var g3 := Vector3(gpt.x, 0, gpt.y) + gn * 0.2
	door(st, xf, g3 + Vector3(0, -0.4, 0), gn, 3.0, 3.8, stone2, Color(0.28, 0.18, 0.1), true)
	box(st, Transform3D(B * Basis(Vector3.UP.cross(gn).normalized(), Vector3.UP, gn), xf * (g3 + Vector3(0, 4.6, 0.0) + gn * 0.15)), Vector3(2.2, 1.6, 0.25), stone2, STONE)
	return guns
