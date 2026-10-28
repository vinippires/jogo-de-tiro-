extends Node3D
## BB de Airsoft (física da Atividade 1): esfera de 3 mm, gravidade + arrasto quadrático
## + sustentação do backspin (Magnus simplificado: sqrt(v) * BackspinDrag).
## A BB continua responsável pela PRÓPRIA física depois de instanciada.

const AIR_DENSITY := 1.225        # kg/m³
const DRAG_COEFFICIENT := 0.47    # esfera lisa
const GRAVITY := 9.81
const HOP_SCALE := 0.0001         # N por sqrt(m/s) quando BackspinDrag = 1 (nossa escala)
const MAX_LIFETIME := 10.0
const OUT_OF_AREA := 300.0        # m: além disso a BB é removida
const TRAIL_EVERY_N_STEPS := 4
const VISUAL_SCALE := 4.0         # só o visual é ampliado; a física usa o raio real

@export var mass: float = 0.0002          # kg (definida pela massa do carregador)
@export var radius: float = 0.003         # m
@export var backspin_drag: float = 2.0    # BackspinDrag (Hop-up aplicado)
@export var debug_log: bool = false

var velocity := Vector3.ZERO
var _stopped := false
var _age := 0.0
var _rest_time := 0.0
var _start_pos := Vector3.ZERO
var _steps := 0
var _points := PackedVector3Array()
var _im := ImmediateMesh.new()


func _ready() -> void:
	add_to_group("bbs")

	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	mi.mesh = sphere
	mi.scale = Vector3.ONE * VISUAL_SCALE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1)
	mi.material_override = mat
	add_child(mi)

	var trail := MeshInstance3D.new()
	trail.mesh = _im
	trail.top_level = true
	var tmat := StandardMaterial3D.new()
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.albedo_color = Color(1.0, 0.45, 0.1)
	trail.material_override = tmat
	add_child(trail)


func launch(initial_velocity: Vector3) -> void:
	velocity = initial_velocity
	_start_pos = global_position
	_points.append(global_position)


func _physics_process(delta: float) -> void:
	if _stopped:
		_rest_time += delta
		if _rest_time > 6.0:
			queue_free()
		return

	_age += delta
	if _age > MAX_LIFETIME:
		_stop("tempo máximo")
		return

	var speed := velocity.length()

	# 1) Arrasto: F = ½·ρ·Cd·A·v²
	var area := PI * radius * radius
	var f_drag := Vector3.ZERO
	if speed > 0.0001:
		f_drag = -velocity / speed * (0.5 * AIR_DENSITY * DRAG_COEFFICIENT * area * speed * speed)
	# 2) Gravidade
	var f_gravity := Vector3(0.0, -mass * GRAVITY, 0.0)
	# 3) Sustentação do backspin
	var f_lift := _lift_force(speed)

	velocity += (f_drag + f_gravity + f_lift) / mass * delta

	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1      # chão e alvos (o jogador fica na camada 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	_steps += 1
	if hit:
		global_position = hit["position"]
		_points.append(global_position)
		var collider = hit["collider"]
		if collider != null and collider.has_method("on_bb_hit"):
			collider.on_bb_hit(global_position, self)
			_rest_time = 5.6          # some logo depois de acertar um alvo
		_stop("colisão")
		return

	global_position = to
	if global_position.length() > OUT_OF_AREA:
		queue_free()                  # BB fora da área: removida
		return
	if _steps % TRAIL_EVERY_N_STEPS == 0:
		_points.append(global_position)
		_rebuild_trail()


## Força de sustentação: sqrt(velocidade) * BackspinDrag, perpendicular à direção da BB.
func _lift_force(speed: float) -> Vector3:
	if speed < 0.01 or backspin_drag <= 0.0:
		return Vector3.ZERO
	var dir := velocity / speed
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.001:
		return Vector3.ZERO
	var lift_dir := side.normalized().cross(dir).normalized()
	return lift_dir * sqrt(speed) * backspin_drag * HOP_SCALE


func _stop(reason: String) -> void:
	_stopped = true
	_rebuild_trail()
	if debug_log:
		var flat := Vector3(global_position.x - _start_pos.x, 0.0, global_position.z - _start_pos.z)
		print("   BB parou (%s) | alcance=%.1f m | tempo=%.2f s | v final=%.1f m/s"
			% [reason, flat.length(), _age, velocity.length()])


func _rebuild_trail() -> void:
	_im.clear_surfaces()
	if _points.size() < 2:
		return
	_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in _points:
		_im.surface_add_vertex(p)
	_im.surface_end()
