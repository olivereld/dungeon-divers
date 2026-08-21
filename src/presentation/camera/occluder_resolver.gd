class_name OccluderResolver
extends RefCounted

## Resolutor de Oclusores Semánticos.
## Recibe los colliders físicos crudos detectados por los raycasts y navega la jerarquía
## hacia arriba hasta encontrar el nodo raíz visual que pertenece al grupo 'camera_occluder'.

const CAMERA_OCCLUDER_GROUP: StringName = &"camera_occluder"

func resolve_candidate(candidate: Node3D) -> Node3D:
	if candidate == null or not is_instance_valid(candidate):
		return null

	var current: Node = candidate
	var visual_occluder: Node3D = null

	while current != null:
		if current is Node3D and current.is_in_group(CAMERA_OCCLUDER_GROUP):
			visual_occluder = current as Node3D
			# Si encontramos un MeshInstance3D o GeometryInstance3D que posee la geometría, es el objetivo prioritario
			if current is GeometryInstance3D:
				return current as Node3D
		current = current.get_parent()

	return visual_occluder

func resolve(candidates: Array[Node3D]) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for candidate in candidates:
		var resolved = resolve_candidate(candidate)
		if resolved != null and not result.has(resolved):
			result.append(resolved)
	return result
