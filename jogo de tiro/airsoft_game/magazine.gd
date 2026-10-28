extends RefCounted
## Carregador: objeto independente (dados + regras próprias).
## Guarda tipo, capacidade, munição atual e massa das BBs (SEMPRE em kg).

const Types := preload("res://types.gd")

var type: int
var capacity: int
var current_ammo: int
var bb_mass_kg: float


func _init(p_type: int = 1, p_capacity: int = 30, p_ammo: int = -1, p_mass_kg: float = 0.0002) -> void:
	type = p_type
	capacity = maxi(1, p_capacity)                      # capacidade deve ser > 0
	if p_ammo < 0:
		p_ammo = capacity
	current_ammo = clampi(p_ammo, 0, capacity)          # sempre entre 0 e a capacidade
	bb_mass_kg = p_mass_kg


func has_ammo() -> bool:
	return current_ammo > 0


## Consome exatamente uma BB. Retorna false (sem alterar nada) se estiver vazio.
func consume() -> bool:
	if current_ammo <= 0:
		return false
	current_ammo -= 1
	return true


## Conversão para gramas SÓ para exibição.
func mass_text() -> String:
	return ("%.2f g" % (bb_mass_kg * 1000.0)).replace(".", ",")


func describe() -> String:
	return "%s - %s - %d/%d" % [Types.type_name(type), mass_text(), current_ammo, capacity]
