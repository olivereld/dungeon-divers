class_name WorldNavigationCell
extends RefCounted

## Objeto inmutable de transporte para consultas puntuales de datos de navegación.

var cell: Vector2i = Vector2i.ZERO
var height: float = 0.0
var elevation_level: int = 0
var walkable: bool = true

func _init(p_cell: Vector2i = Vector2i.ZERO, p_height: float = 0.0, p_elevation: int = 0, p_walkable: bool = true) -> void:
	cell = p_cell
	height = p_height
	elevation_level = p_elevation
	walkable = p_walkable
