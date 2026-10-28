extends Area3D
## Carregador coletável no cenário. Guarda um objeto Magazine.
## Na troca, o carregador antigo fica AQUI (melhoria: pode ser recuperado depois).

const Types := preload("res://types.gd")

var magazine = null      # definido ANTES de entrar na cena

var _mesh: MeshInstance3D
var _label: Label3D


func _ready() -> void:
	add_to_group("pickups")
	collision_layer = 0
	collision_mask = 2          # detecta o jogador (camada 2)
	monitorable = false

	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.8
	cs.shape = sh
	cs.position.y = 0.5
	add_child(cs)

	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.32, 0.22)
	_mesh.mesh = bm
	_mesh.position.y = 0.5
	add_child(_mesh)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.pixel_size = 0.006
	_label.outline_size = 10
	_label.position.y = 1.1
	add_child(_label)

	_refresh_visual()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	_mesh.rotate_y(delta * 1.5)


func _refresh_visual() -> void:
	var color := Types.color_of(magazine.type)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	_mesh.material_override = mat
	_label.modulate = color
	_label.text = "%s\n%s\n%d/%d BB" % [Types.type_name(magazine.type), magazine.mass_text(),
		magazine.current_ammo, magazine.capacity]


## Chamado pelo jogador ao interagir (tecla E).
func try_collect(weapon, player) -> void:
	var result: Dictionary = weapon.equip_magazine(magazine)
	if not result["ok"]:
		return                         # incompatível: a arma já avisou o motivo
	var previous = result["previous"]
	if previous != null:
		magazine = previous            # carregador antigo fica no lugar da troca
		_refresh_visual()
	else:
		player.unregister_pickup(self)
		queue_free()
		return
	player.refresh_prompt()


func describe() -> String:
	return magazine.describe()


func _on_body_entered(body: Node) -> void:
	if body.has_method("register_pickup"):
		body.register_pickup(self)


func _on_body_exited(body: Node) -> void:
	if body.has_method("unregister_pickup"):
		body.unregister_pickup(self)
