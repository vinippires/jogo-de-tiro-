extends CharacterBody3D
## Jogador em 1ª pessoa: traduz ENTRADA em comandos para a arma. Não guarda estado da arma.

signal prompt_changed(text: String)
signal paused_changed(is_paused: bool)

const SPEED := 6.0
const GRAVITY := 20.0
const MOUSE_SENS := 0.0025

@onready var cam: Camera3D = $Camera3D
@onready var weapon = $Camera3D/Weapon

var active := false
var _nearby: Array = []
var _pitch := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # precisa receber Esc durante a pausa
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)


func set_active(value: bool) -> void:
	active = value
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE
	if not value:
		clear_nearby()


func _captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_toggle_pause()
		return
	# O scroll (Hop-up) e os demais comandos só valem com o mouse capturado pelo jogo,
	# nunca durante pausa/menus (outra interface usando o mesmo comando).
	if get_tree().paused or not _captured():
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.4, 1.4)
		cam.rotation.x = _pitch
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if not weapon.auto_mode:
					weapon.try_fire()            # SEMI: 1 disparo por acionamento
			MOUSE_BUTTON_WHEEL_UP:
				weapon.adjust_hop(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				weapon.adjust_hop(-1)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F:
				weapon.toggle_fire_mode()
			KEY_E:
				_interact()
			KEY_Z:
				weapon.adjust_spring(-1)
			KEY_X:
				weapon.adjust_spring(1)


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	var dir := Vector3.ZERO
	if active and _captured():
		var ix := int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A))
		var iz := int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W))
		dir = (global_transform.basis * Vector3(ix, 0, iz)).normalized()
		# AUTO: contínuo enquanto o botão estiver pressionado (a arma impõe a cadência)
		if weapon.auto_mode and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			weapon.try_fire()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()


func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED
	paused_changed.emit(p)


# ---------- carregadores próximos ----------
func register_pickup(p) -> void:
	if not _nearby.has(p):
		_nearby.append(p)
	refresh_prompt()


func unregister_pickup(p) -> void:
	_nearby.erase(p)
	refresh_prompt()


func clear_nearby() -> void:
	_nearby.clear()
	prompt_changed.emit("")


func refresh_prompt() -> void:
	_nearby = _nearby.filter(func(p): return is_instance_valid(p))
	if _nearby.is_empty():
		prompt_changed.emit("")
		return
	prompt_changed.emit("[E] Pegar carregador: %s" % _closest().describe())


func _closest():
	var best = null
	var best_d := INF
	for p in _nearby:
		var d: float = global_position.distance_squared_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


func _interact() -> void:
	_nearby = _nearby.filter(func(p): return is_instance_valid(p))
	if _nearby.is_empty():
		return
	_closest().try_collect(weapon, self)
