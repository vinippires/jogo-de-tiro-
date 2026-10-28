extends AnimatableBody3D
## Alvo circular virado para +Z. Aro central vale mais. Pode se mover lateralmente.

signal destroyed(points: int, target: Node)

var radius := 0.5
var move_speed := 0.0          # m/s (0 = parado)
var move_amplitude := 3.0      # m

var _x0 := 0.0
var _t := 0.0
var _dead := false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = 0.1
	cs.shape = sh
	cs.rotation_degrees = Vector3(90, 0, 0)
	add_child(cs)

	_add_disc(radius, Color(0.85, 0.15, 0.15), 0.0)
	_add_disc(radius * 0.6, Color(1, 1, 1), 0.01)
	_add_disc(radius * 0.25, Color(0.85, 0.15, 0.15), 0.02)

	_x0 = position.x
	_t = randf() * TAU


func _physics_process(delta: float) -> void:
	if _dead or move_speed <= 0.0:
		return
	_t += delta * move_speed / move_amplitude
	position.x = _x0 + sin(_t) * move_amplitude


func _add_disc(r: float, color: Color, z: float) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.05
	mi.mesh = cyl
	mi.rotation_degrees = Vector3(90, 0, 0)
	mi.position.z = z
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	add_child(mi)


## Chamado pela BB ao colidir.
func on_bb_hit(hit_position: Vector3, _bb) -> void:
	if _dead:
		return
	_dead = true
	var local := to_local(hit_position)
	var ratio := clampf(Vector2(local.x, local.y).length() / radius, 0.0, 1.0)
	var points := 50
	if ratio < 0.25:
		points = 100
	elif ratio < 0.6:
		points = 75
	collision_layer = 0
	destroyed.emit(points, self)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.05, 0.2)
	tw.tween_callback(queue_free)
