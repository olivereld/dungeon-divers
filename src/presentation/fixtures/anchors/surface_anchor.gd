class_name SurfaceAnchor
extends "res://src/presentation/fixtures/fixture_anchor.gd"

## Anclaje en superficie horizontal de apoyo (suelo, tablero, peana, altar).
## Provisionalmente derivado de celdas de suelo libre hasta la integración de Room Props (Mesas, Altares, etc.).

var surface_type: StringName = &"floor_surface"

func _init(
	p_cell: Vector2i = Vector2i.ZERO,
	p_pos: Vector3 = Vector3.ZERO,
	p_rot_y: float = 0.0,
	p_surface_type: StringName = &"floor_surface"
) -> void:
	mode = _FixturePlacementModeScript.Mode.SURFACE
	cell = p_cell
	position = p_pos
	rotation_y = p_rot_y
	normal = Vector3.UP
	surface_type = p_surface_type
