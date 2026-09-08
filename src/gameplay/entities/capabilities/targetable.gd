# targetable.gd
# Responde: "¿Puede esta entidad ser considerada un objetivo?"
# NO responde "quién debería atacarla" — eso es de sistemas futuros
# (Combat, AI, Interaction, Ability targeting...). Evitamos deliberadamente
# llamarla "CombatTarget": seleccionar un barril no implica entrar en combate.
class_name Targetable
extends RefCounted

var _can_be_targeted: bool
var _target_category: String

func _init(p_can_be_targeted: bool = true, p_target_category: String = "") -> void:
	_can_be_targeted = p_can_be_targeted
	_target_category = p_target_category

var target_category: String:
	get: return _target_category

func is_targetable() -> bool:
	return _can_be_targeted

func set_targetable(value: bool) -> void:
	_can_be_targeted = value
