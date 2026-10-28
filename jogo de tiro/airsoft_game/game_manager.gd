extends Node
## Regras do jogo: etapas, alvos, tempo, pontuação, vitória/derrota.
## Não desenha nada: emite sinais para o HUD.
##
## OBJETIVO: acertar todos os alvos de cada etapa antes do tempo acabar (3 etapas).
## PROGRESSÃO REAL (muda a cada etapa): alvos menores, mais distantes, tempo menor e,
## na etapa 3, alvos que se movem. Carregadores com massas diferentes ajudam em cada situação.

const Types := preload("res://types.gd")
const Magazine := preload("res://magazine.gd")
const TARGET_SCENE := preload("res://target.tscn")
const PICKUP_SCENE := preload("res://magazine_pickup.tscn")

signal stage_started(index: int, total: int, title: String, hint: String, time_limit: float)
signal time_changed(remaining: float)
signal targets_changed(remaining: int, total: int)
signal score_changed(score: int)
signal message(text: String, kind: String, duration: float)
signal game_ended(won: bool, title: String, detail: String)

enum State { MENU, PLAYING, BETWEEN, ENDED }

var state: State = State.MENU
var player
var weapon
var world: Node3D

var stage_index := -1
var score := 0
var shots := 0
var hits := 0
var stages_cleared := 0
var time_left := 0.0

var _targets_left := 0
var _targets_total := 0
var _accum := 0.0
var _stage_targets: Array = []

# compat=true  -> carregador do tipo da arma;  compat=false -> outro tipo (other = deslocamento no enum)
var stages: Array = [
	{
		"title": "Aquecimento",
		"hint": "Alvos grandes e parados. Aprenda os controles e pegue carregadores com E.",
		"time": 60.0, "count": 5, "radius": 0.5, "dmin": 10.0, "dmax": 16.0,
		"spread": 6.0, "speed": 0.0, "amp": 0.0,
		"pickups": [
			{"compat": true, "other": 0, "cap": 20, "ammo": 20, "g": 0.25, "pos": Vector3(-4, 0, -1.5)},
			{"compat": true, "other": 0, "cap": 30, "ammo": 30, "g": 0.20, "pos": Vector3(6, 0, 4)},
			{"compat": false, "other": 1, "cap": 8, "ammo": 8, "g": 0.20, "pos": Vector3(0, 0, 9)},
			{"compat": false, "other": 2, "cap": 6, "ammo": 6, "g": 0.30, "pos": Vector3(-8, 0, 3)},
		],
	},
	{
		"title": "Precisão",
		"hint": "Alvos menores e mais distantes. Use a roda do mouse (Hop-up) para compensar a queda da BB.",
		"time": 55.0, "count": 6, "radius": 0.25, "dmin": 18.0, "dmax": 35.0,
		"spread": 9.0, "speed": 0.0, "amp": 0.0,
		"pickups": [
			{"compat": true, "other": 0, "cap": 18, "ammo": 18, "g": 0.32, "pos": Vector3(-5, 0, 5)},
			{"compat": true, "other": 0, "cap": 30, "ammo": 30, "g": 0.20, "pos": Vector3(7, 0, 7)},
			{"compat": true, "other": 0, "cap": 25, "ammo": 25, "g": 0.25, "pos": Vector3(2, 0, 11)},
			{"compat": false, "other": 3, "cap": 17, "ammo": 17, "g": 0.20, "pos": Vector3(-9, 0, 0)},
		],
	},
	{
		"title": "Alvos móveis",
		"hint": "Alvos em movimento! Antecipe o deslocamento. BBs mais pesadas mantêm mais velocidade a longa distância.",
		"time": 50.0, "count": 6, "radius": 0.35, "dmin": 15.0, "dmax": 30.0,
		"spread": 7.0, "speed": 1.5, "amp": 3.0,
		"pickups": [
			{"compat": true, "other": 0, "cap": 30, "ammo": 30, "g": 0.20, "pos": Vector3(-6, 0, 4)},
			{"compat": true, "other": 0, "cap": 25, "ammo": 25, "g": 0.32, "pos": Vector3(6, 0, 8)},
			{"compat": true, "other": 0, "cap": 25, "ammo": 25, "g": 0.25, "pos": Vector3(0, 0, 12)},
			{"compat": false, "other": 1, "cap": 6, "ammo": 6, "g": 0.30, "pos": Vector3(9, 0, 1)},
		],
	},
]


func setup(p_player, p_weapon, p_world: Node3D) -> void:
	player = p_player
	weapon = p_weapon
	world = p_world
	weapon.shot_fired.connect(_on_shot_fired)
	weapon.magazine_changed.connect(_on_magazine_changed)


func start_game() -> void:
	score = 0
	shots = 0
	hits = 0
	stages_cleared = 0
	stage_index = -1
	weapon.enabled = true
	weapon.equip_magazine(Magazine.new(weapon.mag_type, 20, 20, 0.0002), true)
	score_changed.emit(score)
	_next_stage()


func _next_stage() -> void:
	if state == State.ENDED:
		return
	stage_index += 1
	if stage_index >= stages.size():
		_end(true, "VITÓRIA!")
		return
	var cfg: Dictionary = stages[stage_index]
	_clear_stage_nodes()
	_spawn_targets(cfg)
	_spawn_pickups(cfg)
	time_left = cfg["time"]
	_accum = 0.0
	state = State.PLAYING
	stage_started.emit(stage_index + 1, stages.size(), cfg["title"], cfg["hint"], time_left)
	targets_changed.emit(_targets_left, _targets_total)
	time_changed.emit(time_left)
	message.emit(cfg["hint"], "info", 5.0)


func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	time_left -= delta
	_accum += delta
	if _accum >= 0.1:
		_accum = 0.0
		time_changed.emit(maxf(time_left, 0.0))
	if time_left <= 0.0:
		time_changed.emit(0.0)
		_end(false, "TEMPO ESGOTADO!")


func _spawn_targets(cfg: Dictionary) -> void:
	var count: int = cfg["count"]
	var spread: float = cfg["spread"]
	var xs: Array = []
	for i in count:
		xs.append(lerpf(-spread, spread, (i + 0.5) / count))
	xs.shuffle()
	_stage_targets.clear()
	for i in count:
		var t = TARGET_SCENE.instantiate()
		t.radius = cfg["radius"]
		t.move_speed = cfg["speed"]
		t.move_amplitude = maxf(cfg["amp"], 0.1)
		var z: float = -randf_range(cfg["dmin"], cfg["dmax"])
		t.position = Vector3(xs[i], randf_range(1.1, 2.3), z)
		world.add_child(t)
		t.destroyed.connect(_on_target_destroyed)
		_stage_targets.append(t)
	_targets_total = count
	_targets_left = count


func _spawn_pickups(cfg: Dictionary) -> void:
	for p in get_tree().get_nodes_in_group("pickups"):
		p.queue_free()
	player.clear_nearby()
	for d in cfg["pickups"]:
		var mtype: int = weapon.mag_type
		if not d["compat"]:
			mtype = (weapon.mag_type + int(d["other"])) % 4
		var mag = Magazine.new(mtype, d["cap"], d["ammo"], float(d["g"]) / 1000.0)
		var pk = PICKUP_SCENE.instantiate()
		pk.magazine = mag
		pk.position = d["pos"]
		world.add_child(pk)


func _clear_stage_nodes() -> void:
	for t in _stage_targets:
		if is_instance_valid(t):
			t.queue_free()
	_stage_targets.clear()


func _on_target_destroyed(points: int, _target: Node) -> void:
	if state != State.PLAYING:
		return
	hits += 1
	score += points
	_targets_left -= 1
	score_changed.emit(score)
	targets_changed.emit(_targets_left, _targets_total)
	message.emit("Acerto! +%d" % points, "ok", 1.0)
	if _targets_left <= 0:
		_stage_cleared()


func _stage_cleared() -> void:
	var bonus := int(time_left * 10.0)
	score += bonus
	stages_cleared += 1
	score_changed.emit(score)
	if stage_index >= stages.size() - 1:
		_end(true, "VITÓRIA!")
		return
	state = State.BETWEEN
	message.emit("Etapa %d concluída! Bônus de tempo: +%d" % [stage_index + 1, bonus], "ok", 2.5)
	get_tree().create_timer(2.5).timeout.connect(_next_stage)


func _on_shot_fired() -> void:
	if state == State.PLAYING:
		shots += 1


func _on_magazine_changed(current: int, _cap: int, _mass: float, has_mag: bool) -> void:
	if state != State.PLAYING:
		return
	if has_mag and current > 0:
		return
	get_tree().create_timer(3.0).timeout.connect(_check_out_of_ammo)


## Sem munição na arma e nenhum carregador compatível utilizável no cenário = derrota.
func _check_out_of_ammo() -> void:
	if state != State.PLAYING or weapon.has_ammo():
		return
	for p in get_tree().get_nodes_in_group("pickups"):
		if is_instance_valid(p) and p.magazine.type == weapon.mag_type and p.magazine.has_ammo():
			return
	_end(false, "SEM MUNIÇÃO!")


func _end(won: bool, title: String) -> void:
	state = State.ENDED
	player.set_active(false)         # interrompe movimento, mira e disparo
	weapon.enabled = false
	var accuracy := 0.0
	if shots > 0:
		accuracy = 100.0 * hits / shots
	var detail := "Pontuação: %d\nEtapas concluídas: %d / %d\nAlvos atingidos: %d  |  Disparos: %d  |  Precisão: %.0f%%" % [
		score, stages_cleared, stages.size(), hits, shots, accuracy]
	game_ended.emit(won, title, detail)
