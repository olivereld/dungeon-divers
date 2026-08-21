class_name CameraOcclusionDetector
extends Node

## Subsistema de Detección de Oclusión Desacoplado para Cámara Isométrica.
## Realiza queries de rayos múltiples (centro, superior, inferior) entre la cámara y el objetivo,
## resuelve los colliders a través de OccluderResolver y emite eventos delta de borde.

signal occlusion_started(occluders: Array[Node3D])
signal occlusion_ended(occluders: Array[Node3D])

const _OccluderResolverScript = preload("res://src/presentation/camera/occluder_resolver.gd")

@export var enabled: bool = true
@export_flags_3d_physics var collision_mask: int = 1
@export var sample_offsets: Array[Vector3] = [
	Vector3(0.0, 0.0, 0.0),   # Centro del objetivo
	Vector3(0.0, 0.6, 0.0),   # Torso / Cabeza
	Vector3(0.0, -0.5, 0.0)   # Base / Pies
]
@export_range(0.1, 1.0, 0.1) var occlusion_threshold: float = 0.5 # Proporción de rayos requerida

var _is_occluded: bool = false
var _active_occluders: Array[Node3D] = []
var _resolver: _OccluderResolverScript = _OccluderResolverScript.new()

func is_target_occluded() -> bool:
	return _is_occluded

func get_active_occluders() -> Array[Node3D]:
	return _active_occluders

func perform_occlusion_check(camera: Camera3D, target: Node3D, space_state: PhysicsDirectSpaceState3D) -> void:
	if not enabled or camera == null or target == null or space_state == null:
		if not _active_occluders.is_empty():
			_update_occlusion_state([])
		return

	var cam_pos: Vector3 = camera.global_position
	var target_base: Vector3 = target.global_position
	var raw_colliders: Array[Node3D] = []
	var hits: int = 0

	for offset in sample_offsets:
		var target_point: Vector3 = target_base + offset
		var query := PhysicsRayQueryParameters3D.create(cam_pos, target_point, collision_mask)
		if target is CollisionObject3D:
			query.exclude = [target.get_rid()]

		var result := space_state.intersect_ray(query)
		if not result.is_empty():
			hits += 1
			var collider = result.get("collider")
			if collider is Node3D and not raw_colliders.has(collider):
				raw_colliders.append(collider)

	var hit_ratio: float = float(hits) / float(maxi(1, sample_offsets.size()))
	if hit_ratio >= occlusion_threshold and not raw_colliders.is_empty():
		var valid_occluders: Array[Node3D] = _resolver.resolve(raw_colliders)
		_update_occlusion_state(valid_occluders)
	else:
		_update_occlusion_state([])

func _update_occlusion_state(new_occluders: Array[Node3D]) -> void:
	var added: Array[Node3D] = []
	var removed: Array[Node3D] = []

	# Calcular elementos añadidos
	for occ in new_occluders:
		if not _active_occluders.has(occ):
			added.append(occ)

	# Calcular elementos liberados
	for prev in _active_occluders:
		if not new_occluders.has(prev):
			removed.append(prev)

	_active_occluders = new_occluders.duplicate()
	_is_occluded = not _active_occluders.is_empty()

	if not added.is_empty():
		occlusion_started.emit(added)
	if not removed.is_empty():
		occlusion_ended.emit(removed)
