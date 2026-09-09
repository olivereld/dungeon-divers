# targetable.gd
# Responde: "¿Puede esta entidad ser considerada un objetivo?"
# NO responde "quién debería atacarla" — eso es de sistemas futuros
# (Combat, AI, Interaction, Ability targeting...). Evitamos deliberadamente
# llamarla "CombatTarget": seleccionar un barril no implica entrar en combate.
class_name Targetable
extends RefCounted

enum Category {
	ANY,
	LIVING,
	OBJECT,
	DESTRUCTIBLE,
}

var _can_be_targeted: bool
var _category: Category

func _init(p_can_be_targeted: bool = true, p_category: Category = Category.ANY) -> void:
	_can_be_targeted = p_can_be_targeted
	_category = p_category

var category: Category:
	get: return _category

var target_category: Category:
	get: return _category

func is_targetable() -> bool:
	return _can_be_targeted

func set_targetable(value: bool) -> void:
	_can_be_targeted = value
