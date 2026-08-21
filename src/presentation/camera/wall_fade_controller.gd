class_name WallFadeController
extends Node

## Controlador de Transparencia y Desvanecimiento Suave de Muros Oclusores.
## Administra de forma individualizada el estado de transparencia de cada muro mediante
## GeometryInstance3D.transparency y decaimiento exponencial continuo (sin instanciar tweens repetitivos).

@export_range(0.0, 1.0, 0.05) var occluded_transparency: float = 0.75
@export_range(0.1, 30.0, 0.5) var fade_speed: float = 12.0
@export var enabled: bool = true

# Mapa de seguimiento individual: Dictionary[Node3D, float (target_transparency)]
var _target_transparencies: Dictionary = {}

func fade_out(walls: Array[Node3D]) -> void:
	if not enabled:
		return
	for wall in walls:
		if wall != null and is_instance_valid(wall):
			_target_transparencies[wall] = occluded_transparency

func fade_in(walls: Array[Node3D]) -> void:
	for wall in walls:
		if wall != null and is_instance_valid(wall):
			_target_transparencies[wall] = 0.0

func clear_all() -> void:
	for wall in _target_transparencies.keys():
		if wall != null and is_instance_valid(wall):
			_apply_transparency(wall, 0.0)
	_target_transparencies.clear()

func _process(delta: float) -> void:
	process_fade_step(delta)

func process_fade_step(delta: float) -> void:
	if _target_transparencies.is_empty():
		return

	var weight: float = 1.0 - exp(-fade_speed * delta)
	var keys_to_remove: Array[Node3D] = []

	for wall in _target_transparencies.keys():
		if wall == null or not is_instance_valid(wall):
			keys_to_remove.append(wall)
			continue

		var target_t: float = _target_transparencies[wall]
		var current_t: float = _get_transparency(wall)

		var new_t: float = lerpf(current_t, target_t, weight)
		if absf(new_t - target_t) < 0.01:
			new_t = target_t

		_apply_transparency(wall, new_t)

		# Si ya convergió a opaco total (0.0), dejar de trackear para ahorrar procesamiento
		if is_equal_approx(new_t, 0.0) and is_equal_approx(target_t, 0.0):
			keys_to_remove.append(wall)

	for dead_key in keys_to_remove:
		_target_transparencies.erase(dead_key)

func _get_transparency(node: Node3D) -> float:
	if node is GeometryInstance3D:
		return (node as GeometryInstance3D).transparency
	for child in node.get_children():
		if child is GeometryInstance3D:
			return (child as GeometryInstance3D).transparency
	return 0.0

func _apply_transparency(node: Node3D, val: float) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).transparency = val
	for child in node.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).transparency = val

func get_tracked_walls_count() -> int:
	return _target_transparencies.size()
