# stat_modifier.gd
# Un modificador individual aplicado a un atributo o a un stat derivado.
# source_id identifica la fuente concreta (ej: "item_ring_of_ogre_power",
# "buff_bless") para poder remover justo ese modificador más tarde sin
# afectar a los demás que compartan source/type.
class_name StatModifier
extends RefCounted

var type: StatModifierType.Type
var value: float
var source: StatModifierSource.Source
var source_id: String

func _init(
	p_type: StatModifierType.Type,
	p_value: float,
	p_source: StatModifierSource.Source = StatModifierSource.Source.OTHER,
	p_source_id: String = ""
) -> void:
	type = p_type
	value = p_value
	source = p_source
	source_id = p_source_id
