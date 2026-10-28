extends Node3D
## Cena principal: monta o cenário e LIGA os sistemas (jogador, arma, jogo, HUD).

const HUD_SCRIPT := preload("res://hud.gd")
const GAME_SCRIPT := preload("res://game_manager.gd")

var hud
var game
var player
var weapon


func _ready() -> void:
	_build_world()
	player = $Player
	weapon = $Player/Camera3D/Weapon

	hud = HUD_SCRIPT.new()
	add_child(hud)
	game = GAME_SCRIPT.new()
	add_child(game)

	game.setup(player, weapon, self)
	hud.bind(weapon, game, player)
	hud.start_pressed.connect(_on_start)
	hud.restart_pressed.connect(func(): get_tree().reload_current_scene())

	weapon.enabled = false
	player.set_active(false)
	weapon.refresh_all()
	hud.show_menu()


func _on_start() -> void:
	hud.hide_overlay()
	player.set_active(true)
	game.start_game()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.78, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)

	# chão com colisão (camada 1)
	var ground := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(400, 1, 400)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	ground.add_child(cs)
	var gm := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = shape.size
	gm.mesh = bm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.35, 0.5, 0.3)
	gm.material_override = gmat
	ground.add_child(gm)
	ground.position = Vector3(0, -0.5, -100)
	add_child(ground)

	# marcadores de distância a cada 10 m (ajudam a calibrar o Hop-up)
	for i in range(1, 6):
		var z := -10.0 * i
		for side in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.1, 3.0, 0.1)
			post.mesh = pm
			post.position = Vector3(18.0 * side, 1.5, z)
			var pmat := StandardMaterial3D.new()
			pmat.albedo_color = Color(0.9, 0.2, 0.2)
			post.material_override = pmat
			add_child(post)
		var label := Label3D.new()
		label.text = "%d m" % (i * 10)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.02
		label.font_size = 48
		label.modulate = Color.BLACK
		label.position = Vector3(-18.0, 3.8, z)
		add_child(label)
