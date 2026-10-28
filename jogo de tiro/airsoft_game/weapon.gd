extends Node3D
## ARMA: controla o disparo, mas OBTÉM quantidade e massa das BBs do carregador equipado.
## Não conhece HUD nem alvos: apenas emite sinais (eventos).
##
## MODELO DE MOLA ESCOLHIDO: MODELO FÍSICO  ->  E = ½ · k · x²
##   k = constante elástica (N/m), x = compressão (m, ajustável com Z/X).
##   Velocidade da BB recalculada a cada tiro: v = sqrt(2E/m)  (m = massa do carregador).
## CADÊNCIA:  ROF = RPM / (60 · N)   [BB/s]   e   intervalo = 1 / ROF
##   N = rotações do motor necessárias para completar um disparo.

const Types := preload("res://types.gd")
const BB_SCENE := preload("res://bb.tscn")

const MPS_TO_FPS := 3.280839895
const REFERENCE_MASS_KG := 0.0002
const HOP_MIN := 0.0
const HOP_MAX := 6.0
const HOP_STEP := 0.25
const SPRING_MIN := 0.030      # m
const SPRING_MAX := 0.045      # m
const SPRING_STEP := 0.0005    # m
const MAX_BBS_IN_SCENE := 60

signal weapon_info(model: String, type_name: String)
signal magazine_changed(current: int, capacity: int, mass_kg: float, has_magazine: bool)
signal mode_changed(is_auto: bool)
signal hop_changed(value: float, min_value: float, max_value: float)
signal stats_changed(rof: float, interval: float, energy: float, v0: float, compression_mm: float)
signal message(text: String, kind: String)
signal shot_fired
signal dry_fire

@export_enum("Shotgun", "Rifle", "Pistol1911", "PistolGlock") var mag_type: int = 1   # = Types.MagType
@export var model_name: String = "AEG M4-A1"
@export var spring_k: float = 2000.0              # N/m
@export var spring_compression: float = 0.0386    # m  (E ≈ 1,49 J)
@export var motor_rpm: float = 9000.0
@export var rotations_per_shot: float = 30.0      # 9000 / (60*30) = 5 BB/s
@export var hop_level: float = 2.0                # valor enviado ao BackspinDrag das BBs
@export var auto_mode: bool = false               # false = SEMI, true = AUTO

var magazine = null          # carregador equipado (objeto Magazine) ou null
var enabled := true

var _next_shot_time := 0.0

@onready var muzzle: Marker3D = $Muzzle


func _ready() -> void:
	_build_visuals()
	print("ARMA %s | carregador=%s | E=%.3f J | ROF=%.2f BB/s (intervalo %.3f s)"
		% [model_name, Types.type_name(mag_type), current_energy(), current_rof(), fire_interval()])


# ---------- grandezas físicas ----------
func current_energy() -> float:
	return 0.5 * spring_k * spring_compression * spring_compression


func current_rof() -> float:
	return motor_rpm / (60.0 * maxf(rotations_per_shot, 0.001))


func fire_interval() -> float:
	return 1.0 / maxf(current_rof(), 0.0001)


func speed_for_mass(mass_kg: float) -> float:
	return sqrt(2.0 * current_energy() / mass_kg)


func has_ammo() -> bool:
	return magazine != null and magazine.has_ammo()


# ---------- carregador ----------
## Tenta equipar. Retorna {"ok": bool, "previous": carregador anterior ou null}.
func equip_magazine(mag, silent := false) -> Dictionary:
	if mag == null:
		return {"ok": false, "previous": null}
	if mag.type != mag_type:
		message.emit("Incompatível: esta arma usa carregador %s, mas este é %s."
			% [Types.type_name(mag_type), Types.type_name(mag.type)], "error")
		return {"ok": false, "previous": null}
	var previous = magazine
	magazine = mag
	_emit_magazine()
	_emit_stats()
	if not silent:
		message.emit("Carregador equipado: %s" % mag.describe(), "ok")
	return {"ok": true, "previous": previous}


# ---------- modo de tiro / hop-up / mola ----------
## Alternar o modo NÃO recarrega, NÃO reinicia o carregador e NÃO mexe no intervalo de tiro.
func toggle_fire_mode() -> void:
	auto_mode = not auto_mode
	mode_changed.emit(auto_mode)
	message.emit("Modo de tiro: %s" % ("AUTO" if auto_mode else "SEMI"), "info")


func adjust_hop(direction: int) -> void:
	var new_value := clampf(snappedf(hop_level + direction * HOP_STEP, 0.05), HOP_MIN, HOP_MAX)
	if is_equal_approx(new_value, hop_level):
		message.emit("Hop-up no limite (%.2f)" % hop_level, "warn")
		return
	hop_level = new_value
	hop_changed.emit(hop_level, HOP_MIN, HOP_MAX)


func adjust_spring(direction: int) -> void:
	var nx := clampf(snappedf(spring_compression + direction * SPRING_STEP, 0.00005), SPRING_MIN, SPRING_MAX)
	if is_equal_approx(nx, spring_compression):
		message.emit("Mola no limite de ajuste", "warn")
		return
	spring_compression = nx
	_emit_stats()
	message.emit("Mola: compressão %.1f mm -> E = %.2f J" % [nx * 1000.0, current_energy()], "info")


# ---------- disparo ----------
func try_fire() -> bool:
	if not enabled:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now < _next_shot_time:
		return false          # cadência: nenhum modo pode ignorar o intervalo

	if magazine == null:
		_next_shot_time = now + fire_interval()
		message.emit("Sem carregador! Pegue um %s (tecla E)." % Types.type_name(mag_type), "error")
		dry_fire.emit()
		return false
	if not magazine.has_ammo():
		_next_shot_time = now + fire_interval()
		message.emit("Carregador vazio! Troque de carregador.", "warn")
		dry_fire.emit()
		return false

	var mass: float = magazine.bb_mass_kg          # massa vem do carregador equipado
	var v0 := speed_for_mass(mass)                 # v = sqrt(2E/m)
	if not magazine.consume():                     # desconta 1 BB somente se o disparo ocorre
		return false

	var existing := get_tree().get_nodes_in_group("bbs")
	if existing.size() >= MAX_BBS_IN_SCENE:
		existing[0].queue_free()

	var bb = BB_SCENE.instantiate()
	bb.mass = mass
	bb.backspin_drag = hop_level
	get_tree().current_scene.add_child(bb)
	bb.global_position = muzzle.global_position
	var dir: Vector3 = -muzzle.global_transform.basis.z
	bb.launch(dir * v0)

	_next_shot_time = now + fire_interval()
	_emit_magazine()
	shot_fired.emit()
	print("DISPARO | %s | massa=%.2f g | v0=%.2f m/s (%.1f fps) | E=%.3f J | hop=%.2f | restam %d/%d"
		% [model_name, mass * 1000.0, v0, v0 * MPS_TO_FPS, 0.5 * mass * v0 * v0, hop_level,
			magazine.current_ammo, magazine.capacity])
	return true


## Reenvia todo o estado atual (usado uma vez, quando o HUD se conecta).
func refresh_all() -> void:
	weapon_info.emit(model_name, Types.type_name(mag_type))
	_emit_magazine()
	mode_changed.emit(auto_mode)
	hop_changed.emit(hop_level, HOP_MIN, HOP_MAX)
	_emit_stats()


func _emit_magazine() -> void:
	if magazine == null:
		magazine_changed.emit(0, 0, 0.0, false)
	else:
		magazine_changed.emit(magazine.current_ammo, magazine.capacity, magazine.bb_mass_kg, true)


func _emit_stats() -> void:
	var m: float = magazine.bb_mass_kg if magazine != null else REFERENCE_MASS_KG
	stats_changed.emit(current_rof(), fire_interval(), current_energy(), speed_for_mass(m),
		spring_compression * 1000.0)
	print("ROF = %.2f BB/s (intervalo %.3f s) | RPM=%.0f | E=%.3f J" %
		[current_rof(), fire_interval(), motor_rpm, current_energy()])


# ---------- visual simples ----------
func _build_visuals() -> void:
	_add_box(Vector3(0.05, 0.10, 0.40), Vector3(0.0, 0.0, 0.0), Color(0.2, 0.2, 0.22))
	_add_box(Vector3(0.04, 0.12, 0.05), Vector3(0.0, -0.10, 0.12), Color(0.15, 0.15, 0.17))
	var barrel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.012
	cyl.height = 0.40
	barrel.mesh = cyl
	barrel.rotation_degrees = Vector3(90, 0, 0)
	barrel.position = Vector3(0.0, 0.03, -0.40)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.1)
	barrel.material_override = mat
	add_child(barrel)


func _add_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	add_child(mi)
