class_name Waterway
extends RefCounted

## Abstracción unificada de cuerpo o vía de agua para presentación y renderizado.
## Totalmente desacoplada de la verdad del terreno.

enum Type {
	RIVER,
	LAKE
}

var type: Type = Type.RIVER
var id: int = -1
var geometry: PackedVector3Array = PackedVector3Array()
var cells: Array[Vector2i] = []
var water_height: float = 0.0
var color_gradient: Gradient = null
var order: int = 1
var widths: PackedFloat32Array = PackedFloat32Array()
var depths: PackedFloat32Array = PackedFloat32Array()

func _init(p_type: Type = Type.RIVER, p_id: int = -1) -> void:
	type = p_type
	id = p_id
