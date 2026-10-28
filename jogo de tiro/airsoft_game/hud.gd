extends CanvasLayer
## HUD: apenas APRESENTA o estado. Todos os textos são atualizados por SINAIS da arma,
## do jogo e do jogador (nada de procurar nós na cena a cada frame).

signal start_pressed
signal restart_pressed

const MPS_TO_FPS := 3.280839895

const MENU_TEXT := "OBJETIVO: acerte todos os alvos de cada etapa antes que o tempo acabe. São 3 etapas; a cada uma os alvos ficam menores, mais distantes, o tempo diminui e, no final, os alvos passam a se mover.\n\nCONTROLES\nWASD: andar   |   Mouse: mirar   |   Botão esquerdo: atirar\nF: alternar SEMI / AUTO   |   Roda do mouse: Hop-up\nE: pegar carregador (perto dele)   |   Z / X: mola menos / mais forte\nEsc: pausar\n\nCarregadores têm tipo (só o do tipo da sua arma serve), capacidade e massa de BB diferentes."

var _weapon_label: Label
var _ammo_label: Label
var _mass_label: Label
var _mode_label: Label
var _hop_label: Label
var _stats_label: Label
var _stage_label: Label
var _time_label: Label
var _targets_label: Label
var _score_label: Label
var _message_label: Label
var _prompt_label: Label
var _pause_label: Label
var _overlay: ColorRect
var _overlay_title: Label
var _overlay_body: Label
var _overlay_button: Button
var _msg_timer: Timer
var _overlay_mode := "menu"


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# --- painel esquerdo (arma) ---
	var left := VBoxContainer.new()
	left.position = Vector2(16, 12)
	root.add_child(left)
	_weapon_label = _label(left, 16)
	_ammo_label = _label(left, 28, Color(1, 0.9, 0.4))
	_mass_label = _label(left, 20)
	_mode_label = _label(left, 20)
	_hop_label = _label(left, 20)
	_stats_label = _label(left, 14, Color(0.85, 0.85, 0.85))

	# --- painel direito (jogo) ---
	var right := VBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -420.0
	right.offset_right = -16.0
	right.offset_top = 12.0
	root.add_child(right)
	_stage_label = _label(right, 20)
	_time_label = _label(right, 28, Color(1, 0.9, 0.4))
	_targets_label = _label(right, 22)
	_score_label = _label(right, 22)
	for l in [_stage_label, _time_label, _targets_label, _score_label]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# --- mira ---
	var cross := _label(root, 28)
	cross.text = "+"
	cross.anchor_left = 0.5
	cross.anchor_right = 0.5
	cross.anchor_top = 0.5
	cross.anchor_bottom = 0.5
	cross.offset_left = -15.0
	cross.offset_right = 15.0
	cross.offset_top = -20.0
	cross.offset_bottom = 20.0
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# --- mensagem temporária e dica de interação ---
	_message_label = _label(root, 24)
	_message_label.anchor_right = 1.0
	_message_label.anchor_top = 0.2
	_message_label.anchor_bottom = 0.2
	_message_label.offset_bottom = 40.0
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.visible = false

	_prompt_label = _label(root, 22, Color(0.6, 1, 0.8))
	_prompt_label.anchor_right = 1.0
	_prompt_label.anchor_top = 0.78
	_prompt_label.anchor_bottom = 0.78
	_prompt_label.offset_bottom = 40.0
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_pause_label = _label(root, 40)
	_pause_label.text = "PAUSADO - Esc para continuar"
	_pause_label.anchor_right = 1.0
	_pause_label.anchor_top = 0.4
	_pause_label.anchor_bottom = 0.4
	_pause_label.offset_bottom = 60.0
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.visible = false

	_msg_timer = Timer.new()
	_msg_timer.one_shot = true
	_msg_timer.timeout.connect(func(): _message_label.visible = false)
	add_child(_msg_timer)

	# --- tela de menu / resultado ---
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.78)
	root.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(720, 0)
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	_overlay_title = _label(box, 36, Color(1, 0.9, 0.4))
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_body = _label(box, 18)
	_overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_button = Button.new()
	_overlay_button.add_theme_font_size_override("font_size", 24)
	_overlay_button.pressed.connect(_on_overlay_button)
	box.add_child(_overlay_button)

	_reset_texts()


func _label(parent: Node, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	return l


func _reset_texts() -> void:
	_weapon_label.text = "Arma: -"
	_ammo_label.text = "Munição: - / -"
	_mass_label.text = "BB: -"
	_mode_label.text = "Modo: SEMI"
	_hop_label.text = "Hop-up: -"
	_stats_label.text = ""
	_stage_label.text = ""
	_time_label.text = ""
	_targets_label.text = ""
	_score_label.text = "Pontos: 0"
	_prompt_label.text = ""


# ---------- ligação com os sistemas (somente leitura) ----------
func bind(weapon, game, player) -> void:
	weapon.weapon_info.connect(_on_weapon_info)
	weapon.magazine_changed.connect(_on_magazine_changed)
	weapon.mode_changed.connect(_on_mode_changed)
	weapon.hop_changed.connect(_on_hop_changed)
	weapon.stats_changed.connect(_on_stats_changed)
	weapon.message.connect(show_message)

	game.stage_started.connect(_on_stage_started)
	game.time_changed.connect(_on_time_changed)
	game.targets_changed.connect(_on_targets_changed)
	game.score_changed.connect(_on_score_changed)
	game.message.connect(show_message)
	game.game_ended.connect(_on_game_ended)

	player.prompt_changed.connect(func(t: String): _prompt_label.text = t)
	player.paused_changed.connect(func(p: bool): _pause_label.visible = p)


func _on_weapon_info(model: String, type_name: String) -> void:
	_weapon_label.text = "Arma: %s  (carregador %s)" % [model, type_name]


func _on_magazine_changed(current: int, capacity: int, mass_kg: float, has_mag: bool) -> void:
	if not has_mag:
		_ammo_label.text = "Munição: SEM CARREGADOR"
		_mass_label.text = "BB: -"
		return
	_ammo_label.text = "Munição: %d / %d" % [current, capacity]
	_ammo_label.add_theme_color_override("font_color",
		Color(1, 0.4, 0.4) if current == 0 else Color(1, 0.9, 0.4))
	_mass_label.text = "BB: %s g" % ("%.2f" % (mass_kg * 1000.0)).replace(".", ",")


func _on_mode_changed(is_auto: bool) -> void:
	_mode_label.text = "Modo: %s" % ("AUTO" if is_auto else "SEMI")


func _on_hop_changed(value: float, min_v: float, max_v: float) -> void:
	_hop_label.text = "Hop-up: %.2f  [%.0f - %.0f]" % [value, min_v, max_v]


func _on_stats_changed(rof: float, interval: float, energy: float, v0: float, x_mm: float) -> void:
	_stats_label.text = "Mola x=%.1f mm | E=%.2f J | v0=%.1f m/s (%.0f fps) | ROF=%.2f BB/s (%.3f s)" % [
		x_mm, energy, v0, v0 * MPS_TO_FPS, rof, interval]


func _on_stage_started(index: int, total: int, title: String, _hint: String, _time_limit: float) -> void:
	_stage_label.text = "Etapa %d/%d - %s" % [index, total, title]


func _on_time_changed(remaining: float) -> void:
	_time_label.text = "Tempo: %.1f s" % remaining
	_time_label.add_theme_color_override("font_color",
		Color(1, 0.4, 0.4) if remaining < 10.0 else Color(1, 0.9, 0.4))


func _on_targets_changed(remaining: int, total: int) -> void:
	_targets_label.text = "Alvos: %d / %d" % [remaining, total]


func _on_score_changed(score: int) -> void:
	_score_label.text = "Pontos: %d" % score


# ---------- mensagens e telas ----------
func show_message(text: String, kind: String = "info", duration: float = 2.5) -> void:
	var colors := {
		"info": Color(1, 1, 1), "ok": Color(0.5, 1, 0.5),
		"warn": Color(1, 0.85, 0.3), "error": Color(1, 0.4, 0.4),
	}
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", colors.get(kind, Color.WHITE))
	_message_label.visible = true
	_msg_timer.start(duration)


func show_menu() -> void:
	_overlay_mode = "menu"
	_overlay_title.text = "Airsoft - Circuito de Precisão"
	_overlay_body.text = MENU_TEXT
	_overlay_button.text = "Iniciar"
	_overlay.visible = true


func hide_overlay() -> void:
	_overlay.visible = false


func _on_game_ended(won: bool, title: String, detail: String) -> void:
	_overlay_mode = "result"
	_overlay_title.text = title
	_overlay_title.add_theme_color_override("font_color",
		Color(0.5, 1, 0.5) if won else Color(1, 0.4, 0.4))
	_overlay_body.text = detail
	_overlay_button.text = "Jogar novamente"
	_prompt_label.text = ""
	_overlay.visible = true


func _on_overlay_button() -> void:
	if _overlay_mode == "menu":
		start_pressed.emit()
	else:
		restart_pressed.emit()
