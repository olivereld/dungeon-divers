class_name DestructionHit
extends RefCounted

## Contrato inmutable que encapsula los datos de un impacto físico o elemental sobre un objeto.

var damage: float = 0.0
var damage_type: StringName = &"physical"
var impact_position: Vector3 = Vector3.ZERO
var impact_direction: Vector3 = Vector3.FORWARD
var source: Object = null

func _init(
	p_damage: float = 0.0,
	p_type: StringName = &"physical",
	p_pos: Vector3 = Vector3.ZERO,
	p_dir: Vector3 = Vector3.FORWARD,
	p_source: Object = null
) -> void:
	damage = p_damage
	damage_type = p_type
	impact_position = p_pos
	impact_direction = p_dir
	source = p_source
