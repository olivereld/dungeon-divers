class_name Health
extends RefCounted


var max_hp: float
var current_hp: float


func _init(p_max_hp: float) -> void:
	assert(p_max_hp > 0.0)

	max_hp = p_max_hp
	current_hp = p_max_hp


func apply_damage(amount: float) -> float:
	var damage := maxf(0.0, amount)

	var previous_hp := current_hp

	current_hp = maxf(
		0.0,
		current_hp - damage
	)

	return previous_hp - current_hp


func heal(amount: float) -> float:
	var healing := maxf(0.0, amount)

	var previous_hp := current_hp

	current_hp = minf(
		max_hp,
		current_hp + healing
	)

	return current_hp - previous_hp


func is_alive() -> bool:
	return current_hp > 0.0


func is_dead() -> bool:
	return not is_alive()


func get_health_ratio() -> float:
	return current_hp / max_hp