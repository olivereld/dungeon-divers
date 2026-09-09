# health.gd
# Estado de vida de una LivingEntity. Vive en el dominio de Entities, no en
# Combat, para que cualquier fuente de daño (una trampa, un ambiente
# ambiental...) pueda afectar a una LivingEntity sin depender de Combat.
#
# Invariantes:
#   max_hp > 0
#   0 <= current_hp <= max_hp
class_name Health
extends RefCounted

var _max_hp: float
var _current_hp: float

func _init(p_max_hp: float) -> void:
	assert(p_max_hp > 0.0, "Health: max_hp debe ser mayor que 0")
	_max_hp = p_max_hp
	_current_hp = p_max_hp

var max_hp: float:
	get: return _max_hp

var current_hp: float:
	get: return _current_hp

# Devuelve la cantidad REALMENTE absorbida por HP (nunca negativa,
# nunca lleva current_hp por debajo de 0).
func apply_damage(amount: float) -> float:
	var clamped_amount: float = max(0.0, amount)
	var before: float = _current_hp
	_current_hp = clamp(_current_hp - clamped_amount, 0.0, _max_hp)
	return before - _current_hp

# Devuelve la cantidad REALMENTE recuperada (nunca negativa,
# nunca lleva current_hp por encima de max_hp).
func heal(amount: float) -> float:
	var clamped_amount: float = max(0.0, amount)
	var before: float = _current_hp
	_current_hp = clamp(_current_hp + clamped_amount, 0.0, _max_hp)
	return _current_hp - before

func is_alive() -> bool:
	return _current_hp > 0.0

func is_dead() -> bool:
	return not is_alive()

func get_health_ratio() -> float:
	return _current_hp / _max_hp
