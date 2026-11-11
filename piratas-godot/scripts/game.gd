extends Node
## Estado global do jogo: nações, navios, mercadorias, portos, carreira e save.

signal message(text: String, color: Color)
signal state_changed

const SAVE_PATH := "user://mares_save.json"
const WORLD_HALF := 8200.0

# ---------------------------------------------------------------- Nações
enum { ENG, ESP, FRA, HOL, POR, PIR }

const NATIONS := [
	{"name": "Grã-Bretanha", "navy": "Marinha Real Britânica", "adj": "britânico",
		"color": Color(0.80, 0.12, 0.15), "hull": Color(0.2, 0.16, 0.12), "stripe": Color(0.85, 0.66, 0.25),
		"sail": Color(0.93, 0.91, 0.84), "flag": 0, "alliance": 0},
	{"name": "Espanha", "navy": "Armada Espanhola", "adj": "espanhol",
		"color": Color(0.85, 0.65, 0.10), "hull": Color(0.5, 0.33, 0.19), "stripe": Color(0.62, 0.10, 0.08),
		"sail": Color(0.92, 0.88, 0.78), "flag": 1, "alliance": 1},
	{"name": "França", "navy": "Marine Royale", "adj": "francês",
		"color": Color(0.20, 0.35, 0.85), "hull": Color(0.46, 0.31, 0.18), "stripe": Color(0.14, 0.22, 0.52),
		"sail": Color(0.94, 0.92, 0.86), "flag": 2, "alliance": 1},
	{"name": "Holanda", "navy": "Marinha Holandesa", "adj": "holandês",
		"color": Color(0.95, 0.50, 0.10), "hull": Color(0.48, 0.32, 0.18), "stripe": Color(0.25, 0.42, 0.25),
		"sail": Color(0.90, 0.86, 0.76), "flag": 3, "alliance": 0},
	{"name": "Portugal", "navy": "Armada Portuguesa", "adj": "português",
		"color": Color(0.10, 0.60, 0.25), "hull": Color(0.5, 0.34, 0.2), "stripe": Color(0.75, 0.12, 0.10),
		"sail": Color(0.93, 0.90, 0.82), "flag": 4, "alliance": 0},
	{"name": "Piratas", "navy": "Irmandade da Costa", "adj": "pirata",
		"color": Color(0.15, 0.15, 0.15), "hull": Color(0.34, 0.24, 0.15), "stripe": Color(0.42, 0.08, 0.06),
		"sail": Color(0.3, 0.28, 0.26), "flag": 5, "alliance": 2},
]

const NAVY_RANKS := ["Aspirante", "Tenente", "Capitão de Fragata", "Capitão de Mar e Guerra", "Comodoro", "Almirante"]
const PIRATE_RANKS := ["Marujo Rebelde", "Corsário", "Capitão Pirata", "Terror dos Mares", "Lorde Pirata", "Rei dos Piratas"]
const RANK_MERIT := [0, 150, 450, 1000, 2000, 3600]

# ---------------------------------------------------------------- Navios
# speed em m/s (escala de jogo), turn em rad/s
const SHIPS := [
	{"id": "saveiro", "name": "Saveiro", "len": 16.0, "beam": 4.6, "masts": 1, "rig": "fore", "guns": 4, "hp": 320,
		"crew": 40, "cargo": 40, "speed": 11.0, "turn": 0.42, "price": 2500, "castle": 0.0, "rank": 0},
	{"id": "escuna", "name": "Escuna", "len": 21.0, "beam": 5.4, "masts": 2, "rig": "fore", "guns": 6, "hp": 480,
		"crew": 60, "cargo": 70, "speed": 10.5, "turn": 0.37, "price": 6500, "castle": 0.6, "rank": 0},
	{"id": "brigue", "name": "Brigue", "len": 27.0, "beam": 7.0, "masts": 2, "rig": "square", "guns": 9, "hp": 760,
		"crew": 100, "cargo": 120, "speed": 10.0, "turn": 0.31, "price": 14000, "castle": 1.0, "rank": 1},
	{"id": "fragata", "name": "Fragata", "len": 37.0, "beam": 9.0, "masts": 3, "rig": "square", "guns": 14, "hp": 1300,
		"crew": 220, "cargo": 200, "speed": 9.5, "turn": 0.26, "price": 32000, "castle": 1.6, "rank": 2},
	{"id": "galeao", "name": "Galeão", "len": 41.0, "beam": 11.0, "masts": 3, "rig": "square", "guns": 16, "hp": 1750,
		"crew": 260, "cargo": 420, "speed": 8.0, "turn": 0.21, "price": 46000, "castle": 3.2, "rank": 2},
	{"id": "nau", "name": "Nau de Linha", "len": 52.0, "beam": 13.0, "masts": 3, "rig": "square", "guns": 26, "hp": 2800,
		"crew": 420, "cargo": 260, "speed": 7.5, "turn": 0.18, "price": 95000, "castle": 2.6, "rank": 4},
]

const UPGRADES := [
	{"id": "casco", "name": "Casco reforçado", "desc": "+20% de resistência do casco por nível", "price": 2500},
	{"id": "velas", "name": "Velas de lona fina", "desc": "+6% de velocidade por nível", "price": 2200},
	{"id": "canhoes", "name": "Canhões de bronze", "desc": "+15% de dano por nível", "price": 3000},
	{"id": "artilheiros", "name": "Artilheiros treinados", "desc": "-12% no tempo de recarga por nível", "price": 2800},
]

const AMMO := ["Bala redonda", "Bala corrente", "Metralha"]

# ---------------------------------------------------------------- Mercadorias
const GOODS := [
	{"id": "rum", "name": "Rum", "base": 32},
	{"id": "acucar", "name": "Açúcar", "base": 22},
	{"id": "tabaco", "name": "Tabaco", "base": 40},
	{"id": "especiarias", "name": "Especiarias", "base": 75},
	{"id": "tecidos", "name": "Tecidos", "base": 48},
	{"id": "polvora", "name": "Pólvora", "base": 55},
	{"id": "madeira", "name": "Madeira", "base": 14},
	{"id": "cafe", "name": "Café", "base": 36},
]

# ---------------------------------------------------------------- Portos
# pos = (x, z) no mundo; -Z = norte. produz = barato; precisa = caro
const PORTS_DEF := [
	{"name": "Charles Town", "nation": ENG, "pos": Vector2(-6100, -7000), "r": 620, "prod": ["madeira", "tabaco"], "need": ["tecidos", "rum"]},
	{"name": "Nassau", "nation": PIR, "pos": Vector2(-2400, -6300), "r": 520, "prod": ["rum", "polvora"], "need": ["especiarias", "tecidos"]},
	{"name": "Havana", "nation": ESP, "pos": Vector2(-5400, -4200), "r": 820, "prod": ["tabaco", "acucar"], "need": ["tecidos", "polvora"]},
	{"name": "Tortuga", "nation": PIR, "pos": Vector2(300, -4600), "r": 480, "prod": ["rum", "madeira"], "need": ["polvora", "especiarias"]},
	{"name": "Port Royal", "nation": ENG, "pos": Vector2(-2600, -1500), "r": 760, "prod": ["rum", "acucar"], "need": ["especiarias", "madeira"]},
	{"name": "Petit-Goâve", "nation": FRA, "pos": Vector2(700, -2300), "r": 560, "prod": ["cafe", "acucar"], "need": ["polvora", "tecidos"]},
	{"name": "Santo Domingo", "nation": ESP, "pos": Vector2(3000, -2700), "r": 700, "prod": ["acucar", "cafe"], "need": ["tecidos", "rum"]},
	{"name": "San Juan", "nation": ESP, "pos": Vector2(5600, -3300), "r": 620, "prod": ["acucar", "madeira"], "need": ["especiarias", "polvora"]},
	{"name": "Sint Eustatius", "nation": HOL, "pos": Vector2(7100, -1600), "r": 460, "prod": ["tecidos", "polvora"], "need": ["acucar", "tabaco"]},
	{"name": "Fort-Royal", "nation": FRA, "pos": Vector2(7300, 600), "r": 620, "prod": ["cafe", "rum"], "need": ["madeira", "tecidos"]},
	{"name": "Bridgetown", "nation": ENG, "pos": Vector2(6200, 2400), "r": 560, "prod": ["acucar", "rum"], "need": ["madeira", "cafe"]},
	{"name": "Willemstad", "nation": HOL, "pos": Vector2(2200, 2600), "r": 640, "prod": ["tecidos", "especiarias"], "need": ["tabaco", "madeira"]},
	{"name": "Cartagena", "nation": ESP, "pos": Vector2(-1900, 4700), "r": 820, "prod": ["especiarias", "tabaco"], "need": ["rum", "tecidos"]},
	{"name": "Olinda", "nation": POR, "pos": Vector2(6900, 5600), "r": 600, "prod": ["acucar", "madeira"], "need": ["tecidos", "polvora"]},
	{"name": "Salvador", "nation": POR, "pos": Vector2(4400, 7000), "r": 760, "prod": ["acucar", "tabaco"], "need": ["especiarias", "rum"]},
]

# ---------------------------------------------------------------- Estado
var captain_name := "Capitão"
var career := PIR            # nação a que o jogador serve (PIR = pirata)
var gold := 1500
var ship_type := 0
var hull_hp := 320.0
var sail_hp := 100.0
var crew := 30
var cargo := {}              # id -> quantidade
var upgrades := {"casco": 0, "velas": 0, "canhoes": 0, "artilheiros": 0}
var ammo := 0
var rep := [0, 0, 0, 0, 0, 0]  # -100..100 por nação
var merit := 0               # mérito (marinha) ou infâmia (pirata)
var bounty := 0
var day := 1
var time_of_day := 0.30      # 0..1 (0.25 = nascer do sol)
var port_owner: Array = []
var port_fort_hp: Array = []
var mission := {}
var treasure := {}           # {"pos": Vector2, "island": int}
var player_pos := Vector2(-2350, -1950)
var player_yaw := 0.0
var stats := {"sunk": 0, "captured": 0, "ports": 0, "treasures": 0}
var has_save := false
var quality := 1             # 0 baixa, 1 média, 2 alta
var false_flag := -1         # bandeira falsa hasteada (-1 = a verdadeira)

var _price_noise := {}


func _ready() -> void:
	reset_ports()
	has_save = FileAccess.file_exists(SAVE_PATH)
	_load_settings.call_deferred()


func reset_ports() -> void:
	port_owner.clear()
	port_fort_hp.clear()
	for p in PORTS_DEF:
		port_owner.append(p["nation"])
		port_fort_hp.append(fort_max_hp())


func fort_max_hp() -> float:
	return 2400.0


# ---------------------------------------------------------------- Carreira
func new_game(chosen_career: int, cname: String) -> void:
	captain_name = cname if cname.strip_edges() != "" else "Capitão"
	career = chosen_career
	reset_ports()
	rep = [0, 0, 0, 0, 0, 0]
	cargo = {}
	upgrades = {"casco": 0, "velas": 0, "canhoes": 0, "artilheiros": 0}
	merit = 0
	bounty = 0
	day = 1
	time_of_day = 0.29
	mission = {}
	treasure = {}
	stats = {"sunk": 0, "captured": 0, "ports": 0, "treasures": 0}
	false_flag = -1
	ammo = 0
	var start_port := 4
	if career == PIR:
		ship_type = 0
		gold = 1200
		start_port = 1
		for n in 5:
			rep[n] = -25
		rep[PIR] = 30
		cargo = {"rum": 10}
	else:
		ship_type = 2 if career == ENG else 1
		gold = 2500
		rep[career] = 40
		start_port = home_port(career)
		for n in 5:
			if n != career and are_enemies(n, career):
				rep[n] = -20
		rep[PIR] = -40
	hull_hp = max_hull()
	sail_hp = 100.0
	crew = int(SHIPS[ship_type]["crew"] * 0.8)
	var sp: Vector2 = PORTS_DEF[start_port]["pos"]
	var d := dock_offset(start_port)
	player_pos = sp + d * (PORTS_DEF[start_port]["r"] * 1.25 + 120.0)
	player_yaw = atan2(-d.x, -d.y) + PI * 0.5
	has_save = true
	save_game()


func home_port(nation: int) -> int:
	var pref := {ENG: 4, ESP: 2, FRA: 5, HOL: 8, POR: 13, PIR: 1}
	var i: int = pref.get(nation, 4)
	if port_owner.size() > i and port_owner[i] == nation:
		return i
	for k in PORTS_DEF.size():
		if port_owner.size() > k and port_owner[k] == nation:
			return k
	return i


func dock_offset(port_idx: int) -> Vector2:
	# Direção (do centro da ilha) em que fica o cais: de frente para o mar aberto.
	var p: Vector2 = PORTS_DEF[port_idx]["pos"]
	var ang := float(hash(PORTS_DEF[port_idx]["name"]) % 628) / 100.0
	var away := p.normalized() if p.length() > 1.0 else Vector2(0, 1)
	return Vector2(cos(ang), sin(ang)).lerp(away, 0.55).normalized()


func is_navy() -> bool:
	return career != PIR


func rank_index() -> int:
	var r := 0
	for i in RANK_MERIT.size():
		if merit >= RANK_MERIT[i]:
			r = i
	return r


func rank_name() -> String:
	return (NAVY_RANKS if is_navy() else PIRATE_RANKS)[rank_index()]


func career_title() -> String:
	if is_navy():
		return "%s da %s" % [rank_name(), NATIONS[career]["navy"]]
	return rank_name()


func add_merit(v: int) -> void:
	var before := rank_index()
	merit = max(0, merit + v)
	var after := rank_index()
	if after > before:
		if is_navy():
			notify("PROMOÇÃO! Agora você é %s." % rank_name(), Color(1, 0.85, 0.3))
			Sfx.play("bell")
		else:
			notify("Sua lenda cresce: %s!" % rank_name(), Color(1, 0.4, 0.3))
	state_changed.emit()


# ---------------------------------------------------------------- Diplomacia
func are_enemies(a: int, b: int) -> bool:
	if a == b:
		return false
	if a == PIR or b == PIR:
		return true
	return NATIONS[a]["alliance"] != NATIONS[b]["alliance"]


## A nação `n` é hostil ao jogador?
func nation_hostile_to_player(n: int) -> bool:
	if false_flag == PIR:
		return n != PIR
	if n == PIR:
		return career != PIR and rep[PIR] < 20
	if false_flag >= 0 and not are_enemies(n, false_flag):
		return false
	if career == PIR:
		return rep[n] < 10
	if rep[n] <= -40:
		return true
	return are_enemies(n, career) and rep[n] < 30


func player_flag() -> int:
	return false_flag if false_flag >= 0 else career


func change_rep(n: int, v: int) -> void:
	rep[n] = clampi(rep[n] + v, -100, 100)
	# aliados também se importam
	for o in 5:
		if o != n and NATIONS[o]["alliance"] == NATIONS[n]["alliance"] and n != PIR:
			rep[o] = clampi(rep[o] + int(v * 0.4), -100, 100)
		elif o != n and n != PIR and are_enemies(o, n) and v < 0:
			rep[o] = clampi(rep[o] - int(v * 0.25), -100, 100)
	state_changed.emit()


func can_dock(port_idx: int) -> bool:
	var owner: int = port_owner[port_idx]
	if owner == PIR:
		return career == PIR or rep[PIR] >= 0
	if owner == career:
		return true
	return not nation_hostile_to_player(owner)


func enlist(n: int) -> void:
	if career == PIR:
		bounty = 0
		merit = int(merit * 0.25)
	else:
		merit = int(merit * 0.5)
	career = n
	rep[n] = max(rep[n], 30)
	rep[PIR] = min(rep[PIR], -30)
	false_flag = -1
	notify("Você agora serve à %s." % NATIONS[n]["navy"], NATIONS[n]["color"].lightened(0.3))
	state_changed.emit()


func turn_pirate() -> void:
	if career != PIR:
		change_rep(career, -60)
		bounty += 3000
		notify("Você desertou! A %s põe sua cabeça a prêmio." % NATIONS[career]["navy"], Color(1, 0.3, 0.3))
	career = PIR
	merit = int(merit * 0.4)
	rep[PIR] = max(rep[PIR], 30)
	state_changed.emit()


# ---------------------------------------------------------------- Navio do jogador
func ship_def() -> Dictionary:
	return SHIPS[ship_type]


func max_hull() -> float:
	return SHIPS[ship_type]["hp"] * (1.0 + 0.2 * upgrades["casco"])


func max_crew() -> int:
	return SHIPS[ship_type]["crew"]


func cargo_capacity() -> int:
	return SHIPS[ship_type]["cargo"]


func cargo_used() -> int:
	var t := 0
	for k in cargo:
		t += int(cargo[k])
	return t


func add_cargo(id: String, n: int) -> int:
	var free := cargo_capacity() - cargo_used()
	n = mini(n, free)
	if n <= 0:
		return 0
	cargo[id] = int(cargo.get(id, 0)) + n
	return n


func good_name(id: String) -> String:
	for g in GOODS:
		if g["id"] == id:
			return g["name"]
	return id


func price(port_idx: int, id: String, buying: bool) -> int:
	var base := 30
	for g in GOODS:
		if g["id"] == id:
			base = g["base"]
	var p: Dictionary = PORTS_DEF[port_idx]
	var m := 1.0
	if id in p["prod"]:
		m = 0.6
	elif id in p["need"]:
		m = 1.55
	var key := "%d_%s" % [port_idx, id]
	if not _price_noise.has(key) or int(_price_noise[key].y) != day:
		var r := RandomNumberGenerator.new()
		r.seed = hash(key) + day * 7919
		_price_noise[key] = Vector2(r.randf_range(0.88, 1.14), day)
	m *= _price_noise[key].x
	var v := base * m
	if not buying:
		v *= 0.88
	return max(1, int(round(v)))


func notify(text: String, color := Color(1, 1, 1)) -> void:
	message.emit(text, color)


# ---------------------------------------------------------------- Tempo
func advance_time(delta: float) -> void:
	# um dia = 12 minutos reais
	time_of_day += delta / 720.0
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		day += 1
		_new_day()


func _new_day() -> void:
	var wages := int(crew * 1.2)
	var txt := "Dia %d. Soldo da tripulação: -%d moedas." % [day, wages]
	if is_navy():
		var salary := 150 + rank_index() * 220
		gold += salary
		txt += " Salário da Coroa: +%d." % salary
	gold -= wages
	if gold < 0:
		gold = 0
		var lost := int(crew * 0.1)
		crew -= lost
		txt += " Sem dinheiro: %d marujos desertaram!" % lost
	notify(txt, Color(0.9, 0.85, 0.6))
	if career == PIR and bounty > 0:
		bounty = int(bounty * 0.97)
	state_changed.emit()


# ---------------------------------------------------------------- Save
func to_dict() -> Dictionary:
	return {
		"v": 1, "captain": captain_name, "career": career, "gold": gold, "ship": ship_type,
		"hull": hull_hp, "sail": sail_hp, "crew": crew, "cargo": cargo, "up": upgrades, "ammo": ammo,
		"rep": rep, "merit": merit, "bounty": bounty, "day": day, "tod": time_of_day,
		"owners": port_owner, "forts": port_fort_hp, "mission": _vec_to_arr(mission), "treasure": _vec_to_arr(treasure),
		"px": player_pos.x, "pz": player_pos.y, "yaw": player_yaw, "stats": stats,
	}


func _vec_to_arr(d: Dictionary) -> Dictionary:
	var o := {}
	for k in d:
		var v = d[k]
		if v is Vector2:
			o[k] = {"__v2": [v.x, v.y]}
		else:
			o[k] = v
	return o


func _arr_to_vec(d: Dictionary) -> Dictionary:
	var o := {}
	for k in d:
		var v = d[k]
		if v is Dictionary and v.has("__v2"):
			o[k] = Vector2(v["__v2"][0], v["__v2"][1])
		else:
			o[k] = v
	return o


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))
		has_save = true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return false
	captain_name = d.get("captain", "Capitão")
	career = int(d.get("career", PIR))
	gold = int(d.get("gold", 1000))
	ship_type = clampi(int(d.get("ship", 0)), 0, SHIPS.size() - 1)
	hull_hp = float(d.get("hull", 300))
	sail_hp = float(d.get("sail", 100))
	crew = int(d.get("crew", 30))
	cargo = {}
	var c: Dictionary = d.get("cargo", {})
	for k in c:
		cargo[k] = int(c[k])
	var u: Dictionary = d.get("up", {})
	for k in upgrades:
		upgrades[k] = int(u.get(k, 0))
	ammo = int(d.get("ammo", 0))
	var r: Array = d.get("rep", [])
	for i in mini(r.size(), 6):
		rep[i] = int(r[i])
	merit = int(d.get("merit", 0))
	bounty = int(d.get("bounty", 0))
	day = int(d.get("day", 1))
	time_of_day = float(d.get("tod", 0.3))
	var ow: Array = d.get("owners", [])
	var fo: Array = d.get("forts", [])
	reset_ports()
	for i in mini(ow.size(), port_owner.size()):
		port_owner[i] = int(ow[i])
	for i in mini(fo.size(), port_fort_hp.size()):
		port_fort_hp[i] = float(fo[i])
	mission = _arr_to_vec(d.get("mission", {}))
	treasure = _arr_to_vec(d.get("treasure", {}))
	player_pos = Vector2(float(d.get("px", 0)), float(d.get("pz", 0)))
	player_yaw = float(d.get("yaw", 0))
	var st: Dictionary = d.get("stats", {})
	for k in stats:
		stats[k] = int(st.get(k, 0))
	false_flag = -1
	return true


func save_settings() -> void:
	var f := FileAccess.open("user://mares_settings.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"quality": quality, "music": Sfx.music_on}))


func _load_settings() -> void:
	if OS.has_feature("mobile"):
		quality = 0
	if not FileAccess.file_exists("user://mares_settings.json"):
		return
	var f := FileAccess.open("user://mares_settings.json", FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) == TYPE_DICTIONARY:
		quality = int(d.get("quality", quality))
		Sfx.music_on = bool(d.get("music", true))
