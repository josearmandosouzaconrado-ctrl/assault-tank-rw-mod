class_name PortUI
extends CanvasLayer
## Tela do porto: mercado, estaleiro, taverna, quadro de missões e governo/almirantado.

signal closed

var port := 0
var content: VBoxContainer
var header: Label
var info: Label
var tab := "mercado"
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open(p: int) -> void:
	port = p
	visible = true
	_rng.randomize()
	_build()
	_show_tab("mercado")
	Sfx.play("bell", -6.0)


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel())
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = 16
	panel.offset_bottom = -16
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	vb.add_child(top)
	var owner: int = Game.port_owner[port]
	top.add_child(UiStyle.flag_rect(Game.NATIONS[owner]["flag"], Vector2(66, 44)))
	header = UiStyle.title("", 30)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(header)
	info = UiStyle.label("", 16)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	vb.add_child(tabs)
	for t in [["mercado", "Mercado"], ["estaleiro", "Estaleiro"], ["taverna", "Taverna"], ["missoes", "Missões"], ["governo", "Governo"]]:
		var b := UiStyle.button(t[1], 50, 18)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = t[0]
		b.pressed.connect(func(): _show_tab(id))
		tabs.add_child(b)
	var sail_b := UiStyle.button("⚓ Zarpar", 50, 18)
	sail_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sail_b.pressed.connect(_close)
	tabs.add_child(sail_b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)


func _refresh_header() -> void:
	var owner: int = Game.port_owner[port]
	header.text = "%s  —  %s" % [Game.PORTS_DEF[port]["name"], Game.NATIONS[owner]["name"]]
	info.text = "Ouro: %d   Tripulação: %d/%d   Carga: %d/%d\nCasco: %d/%d   Dia %d" % [Game.gold, Game.crew, Game.max_crew(),
		Game.cargo_used(), Game.cargo_capacity(), int(Game.hull_hp), int(Game.max_hull()), Game.day]


func _show_tab(id: String) -> void:
	tab = id
	for c in content.get_children():
		c.queue_free()
	_refresh_header()
	match id:
		"mercado": _market()
		"estaleiro": _shipyard()
		"taverna": _tavern()
		"missoes": _missions()
		"governo": _government()


func _row(cols: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for c in cols:
		h.add_child(c)
	content.add_child(h)
	return h


func _lbl(t: String, w := 0.0, size := 18, col := Color(0.95, 0.92, 0.85)) -> Label:
	var l := UiStyle.label(t, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	if w > 0:
		l.custom_minimum_size = Vector2(w, 0)
	else:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _btn(t: String, cb: Callable, enabled := true, w := 0.0) -> Button:
	var b := UiStyle.button(t, 48, 16)
	b.disabled = not enabled
	if w > 0:
		b.custom_minimum_size.x = w
	b.pressed.connect(func():
		cb.call()
		_show_tab(tab))
	return b


# ---------------------------------------------------------------- mercado
func _market() -> void:
	content.add_child(UiStyle.label("Compre barato onde se produz e venda caro onde falta. Produz aqui: %s. Procura: %s." % [
		", ".join(Game.PORTS_DEF[port]["prod"].map(func(x): return Game.good_name(x))),
		", ".join(Game.PORTS_DEF[port]["need"].map(func(x): return Game.good_name(x)))], 16, Color(0.85, 0.8, 0.65)))
	_row([_lbl("Mercadoria", 170, 16, UiStyle.GOLD), _lbl("No porão", 90, 16, UiStyle.GOLD), _lbl("Compra", 80, 16, UiStyle.GOLD), _lbl("Venda", 80, 16, UiStyle.GOLD), _lbl("", 0)])
	for g in Game.GOODS:
		var id: String = g["id"]
		var have := int(Game.cargo.get(id, 0))
		var bp := Game.price(port, id, true)
		var sp := Game.price(port, id, false)
		var free := Game.cargo_capacity() - Game.cargo_used()
		var tag := ""
		if id in Game.PORTS_DEF[port]["prod"]:
			tag = " ▼"
		elif id in Game.PORTS_DEF[port]["need"]:
			tag = " ▲"
		_row([
			_lbl(g["name"] + tag, 170), _lbl(str(have), 90), _lbl(str(bp), 80), _lbl(str(sp), 80),
			_btn("+1", func(): _buy(id, 1), Game.gold >= bp and free > 0, 70),
			_btn("+10", func(): _buy(id, 10), Game.gold >= bp * 10 and free >= 10, 80),
			_btn("-1", func(): _sell(id, 1), have > 0, 70),
			_btn("Vender tudo", func(): _sell(id, have), have > 0, 150),
		])


func _buy(id: String, n: int) -> void:
	var p := Game.price(port, id, true)
	n = mini(n, Game.gold / p)
	var got := Game.add_cargo(id, n)
	Game.gold -= got * p
	if got > 0:
		Sfx.play("coin", -6.0)


func _sell(id: String, n: int) -> void:
	var have := int(Game.cargo.get(id, 0))
	n = mini(n, have)
	if n <= 0:
		return
	var reserved := 0
	if Game.mission.get("type", "") == "deliver" and Game.mission.get("good", "") == id:
		reserved = int(Game.mission["qty"])
	n = mini(n, have - reserved)
	if n <= 0:
		Game.notify("Essa carga é de uma missão de entrega.", Color(1, 0.7, 0.4))
		return
	Game.gold += n * Game.price(port, id, false)
	Game.cargo[id] = have - n
	if Game.cargo[id] <= 0:
		Game.cargo.erase(id)
	Sfx.play("coin", -4.0)


# ---------------------------------------------------------------- estaleiro
func _shipyard() -> void:
	var d := Game.ship_def()
	var dmg := Game.max_hull() - Game.hull_hp
	var hull_cost := int(dmg * (1.2 + d["guns"] * 0.06))
	var sail_cost := int((100.0 - Game.sail_hp) * (4 + d["masts"] * 3))
	content.add_child(UiStyle.label("Seu navio: %s — %d canhões por bordo, velocidade %.1f nós, porão %d." % [d["name"], d["guns"], d["speed"] * 1.94 * 0.6, d["cargo"]], 18, UiStyle.GOLD))
	_row([_lbl("Reparar o casco (%d/%d)" % [int(Game.hull_hp), int(Game.max_hull())]), _btn("%d moedas" % hull_cost, func(): _repair_hull(hull_cost), dmg > 1 and Game.gold >= hull_cost, 200)])
	_row([_lbl("Remendar as velas (%d%%)" % int(Game.sail_hp)), _btn("%d moedas" % sail_cost, func(): _repair_sail(sail_cost), Game.sail_hp < 99.5 and Game.gold >= sail_cost, 200)])
	content.add_child(UiStyle.label("Melhorias (máximo 3 níveis cada)", 20, UiStyle.GOLD))
	for u in Game.UPGRADES:
		var id: String = u["id"]
		var lvl: int = Game.upgrades[id]
		var cost: int = u["price"] * (lvl + 1) * (1 + Game.ship_type / 2)
		_row([_lbl("%s  [%d/3]  — %s" % [u["name"], lvl, u["desc"]], 0, 16), _btn("%d moedas" % cost if lvl < 3 else "Máximo", func(): _upgrade(id, cost), lvl < 3 and Game.gold >= cost, 200)])
	content.add_child(UiStyle.label("Navios à venda (seu navio atual entra como parte do pagamento)", 20, UiStyle.GOLD))
	var trade_in := int(Game.SHIPS[Game.ship_type]["price"] * 0.5 * clampf(Game.hull_hp / Game.max_hull(), 0.3, 1.0))
	for i in Game.SHIPS.size():
		var s: Dictionary = Game.SHIPS[i]
		if i == Game.ship_type:
			continue
		var cost: int = maxi(0, int(s["price"]) - trade_in)
		var restricted := i == 5 and not (Game.is_navy() and Game.rank_index() >= 4)
		var txt := "%s — %d canhões/bordo, casco %d, %d tripulantes, porão %d" % [s["name"], s["guns"], s["hp"], s["crew"], s["cargo"]]
		if restricted:
			txt += "  (só para Comodoros da Marinha)"
		_row([_lbl(txt, 0, 16), _btn("%d moedas" % cost, func(): _buy_ship(i, cost), not restricted and Game.gold >= cost, 200)])


func _repair_hull(c: int) -> void:
	Game.gold -= c
	Game.hull_hp = Game.max_hull()
	World.I.player.apply_player_stats()


func _repair_sail(c: int) -> void:
	Game.gold -= c
	Game.sail_hp = 100.0
	World.I.player.apply_player_stats()


func _upgrade(id: String, c: int) -> void:
	Game.gold -= c
	Game.upgrades[id] += 1
	if id == "casco":
		Game.hull_hp = Game.max_hull()
	World.I.player.apply_player_stats()
	Sfx.play("bell", -10.0)


func _buy_ship(i: int, c: int) -> void:
	Game.gold -= c
	var keep := Game.cargo.duplicate()
	World.I.change_player_ship(i)
	Game.cargo = keep
	var over := Game.cargo_used() - Game.cargo_capacity()
	if over > 0:
		Game.notify("O porão é menor: %d unidades de carga ficaram no cais." % over, Color(1, 0.7, 0.4))
		for k in Game.cargo.keys():
			var take := mini(over, int(Game.cargo[k]))
			Game.cargo[k] -= take
			over -= take
			if Game.cargo[k] <= 0:
				Game.cargo.erase(k)
	Game.notify("Você comprou um(a) %s!" % Game.SHIPS[i]["name"], Color(0.5, 1, 0.5))
	Sfx.play("bell")


# ---------------------------------------------------------------- taverna
const RUMORS := [
	"Dizem que um galeão espanhol carregado de prata navega perto de Havana.",
	"Navios mercantes se rendem quando o casco está em pedaços — aborde-os em vez de afundá-los!",
	"Bala corrente rasga velas; um navio sem velas não foge de ninguém.",
	"Metralha limpa o convés. Menos marujos inimigos, abordagem mais fácil.",
	"Com uma bandeira falsa você entra em portos inimigos... até disparar o primeiro tiro.",
	"Fortes atiram longe. Silencie os canhões antes de invadir uma cidade.",
	"Ventos de popa e de través dão mais velocidade; contra o vento, nem o melhor navio anda.",
	"Os ingleses, holandeses e portugueses estão aliados contra a Espanha e a França nesta guerra.",
	"Tempestades chegam sem aviso. Recolha um pouco as velas e aguente firme.",
	"Mapas de tesouro levam a ilhas desertas. Desembarque e cave no X!",
]


func _tavern() -> void:
	var need := Game.max_crew() - Game.crew
	var cost := 18 + Game.ship_type * 3
	content.add_child(UiStyle.label("A taverna está cheia de marujos procurando trabalho.", 18, UiStyle.GOLD))
	_row([_lbl("Contratar 10 marujos (%d cada)" % cost), _btn("%d moedas" % (cost * mini(10, need)), func(): _hire(mini(10, need), cost), need > 0 and Game.gold >= cost * mini(10, need), 200)])
	_row([_lbl("Completar a tripulação (%d vagas)" % need), _btn("%d moedas" % (cost * need), func(): _hire(need, cost), need > 0 and Game.gold >= cost * need, 200)])
	var tp := 1200
	if Game.treasure.has("pos"):
		content.add_child(UiStyle.label("Você já tem um mapa: o tesouro está em %s (marcado com X no mapa)." % Game.treasure.get("island", "?"), 17))
	else:
		_row([_lbl("Um velho bucaneiro vende um mapa do tesouro"), _btn("%d moedas" % tp, func(): _buy_map(tp), Game.gold >= tp, 200)])
	content.add_child(UiStyle.label("Rumor: \"%s\"" % RUMORS[(port * 7 + Game.day) % RUMORS.size()], 17, Color(0.85, 0.8, 0.65)))


func _hire(n: int, c: int) -> void:
	Game.gold -= n * c
	Game.crew += n
	World.I.player.apply_player_stats()


func _buy_map(c: int) -> void:
	Game.gold -= c
	Game.treasure = World.I.make_treasure_map()
	Game.notify("Mapa do tesouro: %s. Navegue até lá, desembarque e cave no X!" % Game.treasure["island"], Color(1, 0.85, 0.3))


# ---------------------------------------------------------------- missões
func _mission_offers() -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = port * 1000 + Game.day * 13 + Game.stats["sunk"]
	var owner: int = Game.port_owner[port]
	var offers := []
	var rank := Game.rank_index()
	var w := World.I
	var sea := func() -> Vector2:
		var base: Vector2 = w.port_islands[port].dock_point
		for k in 30:
			var q := base + Vector2.from_angle(r.randf() * TAU) * r.randf_range(1800.0, 4200.0)
			if absf(q.x) < 7500 and absf(q.y) < 7500 and w.terrain_height(q.x, q.y) < -12.0:
				return q
		return base + Vector2(1500, 0)
	if owner != Game.PIR:
		var t := clampi(rank + r.randi_range(0, 1), 0, 3)
		offers.append({"type": "hunt", "nation": Game.PIR, "ship": t, "pos": sea.call(), "reward": 1400 + rank * 900 + t * 500,
			"merit": 60 + t * 30, "giver": owner, "desc": "Caçar o pirata \"%s\" (%s)" % [["Barba Ruiva", "Mão de Ferro", "Olho de Vidro", "Dente de Ouro", "Capitão Sem-Nome"][r.randi() % 5], Game.SHIPS[t]["name"]]})
	var enemies: Array = []
	for n in 5:
		if Game.are_enemies(n, owner) and n != owner:
			enemies.append(n)
	if not enemies.is_empty() and (owner == Game.career or owner == Game.PIR or not Game.are_enemies(owner, Game.career)):
		var en: int = enemies[r.randi() % enemies.size()]
		var t := clampi(rank + r.randi_range(0, 2), 1, 4)
		var verb := "Saquear o mercante" if owner == Game.PIR else "Afundar o navio de guerra"
		offers.append({"type": "hunt", "nation": en, "ship": t, "pos": sea.call(), "reward": 2000 + rank * 1100 + t * 700,
			"merit": 90 + t * 35, "giver": owner, "role": "merchant" if owner == Game.PIR else "patrol", "desc": "%s %s %s" % [verb, Game.NATIONS[en]["adj"], Game.SHIPS[t]["name"]]})
	# entrega
	var dests: Array = []
	for i in Game.PORTS_DEF.size():
		if i != port and Game.can_dock(i) and Game.PORTS_DEF[i]["pos"].distance_to(Game.PORTS_DEF[port]["pos"]) > 3000.0:
			dests.append(i)
	if not dests.is_empty():
		var di: int = dests[r.randi() % dests.size()]
		var g: Dictionary = Game.GOODS[r.randi() % Game.GOODS.size()]
		var qty := r.randi_range(10, 30)
		var dist: float = Game.PORTS_DEF[di]["pos"].distance_to(Game.PORTS_DEF[port]["pos"])
		offers.append({"type": "deliver", "good": g["id"], "qty": qty, "port": di, "reward": int(qty * g["base"] * 0.6 + dist * 0.35),
			"merit": 30, "giver": owner, "desc": "Entregar %d %s em %s" % [qty, g["name"], Game.PORTS_DEF[di]["name"]]})
	# conquista
	if Game.is_navy() and owner == Game.career and rank >= 2:
		var targets: Array = []
		for i in Game.PORTS_DEF.size():
			if Game.are_enemies(Game.port_owner[i], Game.career):
				targets.append(i)
		if not targets.is_empty():
			var ti: int = targets[r.randi() % targets.size()]
			offers.append({"type": "capture", "port": ti, "reward": 15000 + rank * 3000, "merit": 400, "giver": owner,
				"desc": "Conquistar %s para a Coroa" % Game.PORTS_DEF[ti]["name"]})
	elif not Game.is_navy() and owner == Game.PIR and rank >= 2:
		var ti := r.randi() % Game.PORTS_DEF.size()
		if Game.port_owner[ti] != Game.PIR:
			offers.append({"type": "capture", "port": ti, "reward": 12000, "merit": 400, "giver": owner,
				"desc": "Tomar %s para a Irmandade" % Game.PORTS_DEF[ti]["name"]})
	return offers


func _missions() -> void:
	if not Game.mission.is_empty():
		content.add_child(UiStyle.label("Missão atual: %s  —  recompensa %d moedas" % [Game.mission.get("desc", "?"), Game.mission.get("reward", 0)], 19, UiStyle.GOLD))
		if Game.mission.get("type", "") == "deliver" and int(Game.mission["port"]) == port:
			var g: String = Game.mission["good"]
			var have := int(Game.cargo.get(g, 0))
			_row([_lbl("Entregar a carga aqui"), _btn("Entregar", _deliver, have >= int(Game.mission["qty"]), 200)])
		_row([_lbl("Desistir da missão (perde reputação)"), _btn("Desistir", _abandon, true, 200)])
		return
	content.add_child(UiStyle.label("Quadro de avisos — escolha uma missão:", 19, UiStyle.GOLD))
	for o in _mission_offers():
		var od: Dictionary = o
		_row([_lbl("%s — %d moedas" % [od["desc"], od["reward"]], 0, 17), _btn("Aceitar", func(): _accept(od), true, 160)])
	content.add_child(UiStyle.label("O alvo aparece no mapa e no minimapa (marcador vermelho).", 15, Color(0.8, 0.75, 0.6)))


func _accept(o: Dictionary) -> void:
	if o["type"] == "deliver":
		var free := Game.cargo_capacity() - Game.cargo_used()
		if free < int(o["qty"]):
			Game.notify("Sem espaço no porão para essa entrega.", Color(1, 0.6, 0.4))
			return
		Game.add_cargo(o["good"], int(o["qty"]))
	Game.mission = o.duplicate()
	Game.mission["spawned"] = false
	Game.notify("Missão aceita: %s" % o["desc"], Color(0.6, 1, 0.6))


func _deliver() -> void:
	var g: String = Game.mission["good"]
	Game.cargo[g] = int(Game.cargo.get(g, 0)) - int(Game.mission["qty"])
	if Game.cargo[g] <= 0:
		Game.cargo.erase(g)
	Game.gold += int(Game.mission["reward"])
	Game.add_merit(int(Game.mission.get("merit", 30)))
	Game.change_rep(Game.port_owner[port], 5)
	Game.notify("Entrega concluída! +%d moedas." % int(Game.mission["reward"]), Color(0.5, 1, 0.5))
	Game.mission = {}
	Sfx.play("coin")


func _abandon() -> void:
	var giver := int(Game.mission.get("giver", -1))
	if giver >= 0:
		Game.change_rep(giver, -5)
	if Game.mission.get("type", "") == "hunt":
		for s in World.I.ships:
			s.mission_target = false
	Game.mission = {}


# ---------------------------------------------------------------- governo
func _government() -> void:
	var owner: int = Game.port_owner[port]
	var rep_txt := ""
	for n in 6:
		rep_txt += "%s: %d   " % [Game.NATIONS[n]["name"], Game.rep[n]]
	content.add_child(UiStyle.label("Reputação — " + rep_txt, 16, Color(0.85, 0.8, 0.65)))
	content.add_child(UiStyle.label("Sua carreira: %s.  %s: %d%s" % [Game.career_title(), "Mérito" if Game.is_navy() else "Infâmia", Game.merit,
		("   Recompensa pela sua cabeça: %d" % Game.bounty) if Game.bounty > 0 else ""], 18, UiStyle.GOLD))
	var ri := Game.rank_index()
	if ri < Game.RANK_MERIT.size() - 1:
		content.add_child(UiStyle.label("Próximo posto (%s) com %d pontos." % [(Game.NAVY_RANKS if Game.is_navy() else Game.PIRATE_RANKS)[ri + 1], Game.RANK_MERIT[ri + 1]], 16))
	if owner == Game.PIR:
		content.add_child(UiStyle.label("Esta é uma cidade da Irmandade da Costa. Aqui não há reis nem almirantes.", 18))
		if Game.is_navy():
			_row([_lbl("Rasgar a comissão e virar pirata"), _btn("Virar pirata", _go_pirate, true, 220)])
		return
	var navy: String = Game.NATIONS[owner]["navy"]
	if Game.career == owner:
		content.add_child(UiStyle.label("Almirantado da %s." % navy, 20, UiStyle.GOLD))
		var tier := 2 if ri < 2 else (3 if ri < 4 else 5)
		if Game.ship_type < tier and Game.SHIPS[tier]["rank"] <= ri:
			_row([_lbl("A Coroa oferece um(a) %s ao seu posto" % Game.SHIPS[tier]["name"]), _btn("Aceitar navio", func(): _crown_ship(tier), true, 220)])
		_row([_lbl("Desertar e virar pirata (vão caçá-lo!)"), _btn("Desertar", _go_pirate, true, 220)])
		return
	if Game.career == Game.PIR:
		var pardon := 2500 + Game.bounty
		_row([_lbl("Comprar a anistia do governador (%s)" % Game.NATIONS[owner]["name"]), _btn("%d moedas" % pardon, func(): _pardon(owner, pardon), Game.gold >= pardon and Game.rep[owner] < 20, 220)])
	if Game.rep[owner] >= 0:
		_row([_lbl("Alistar-se na %s" % navy), _btn("Alistar-se", func(): _enlist(owner), true, 220)])
	else:
		content.add_child(UiStyle.label("A %s não aceita você (reputação %d)." % [navy, Game.rep[owner]], 17, Color(1, 0.6, 0.5)))


func _go_pirate() -> void:
	Game.turn_pirate()
	World.I.player.flag_nation = Game.PIR
	World.I.player.set_flag(Game.NATIONS[Game.PIR]["flag"])
	_build()


func _crown_ship(t: int) -> void:
	World.I.change_player_ship(t)
	Game.notify("A Coroa lhe concede um(a) %s!" % Game.SHIPS[t]["name"], Color(1, 0.85, 0.3))


func _pardon(n: int, c: int) -> void:
	Game.gold -= c
	Game.bounty = 0
	Game.rep[n] = maxi(Game.rep[n], 20)
	Game.notify("Anistia concedida pela %s." % Game.NATIONS[n]["name"], Color(0.6, 1, 0.6))


func _enlist(n: int) -> void:
	Game.enlist(n)
	World.I.change_player_ship(maxi(Game.ship_type, 1))
	_build()


func _close() -> void:
	visible = false
	Game.save_game()
	closed.emit()
