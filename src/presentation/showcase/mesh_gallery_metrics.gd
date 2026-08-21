class_name MeshGalleryMetrics
extends RefCounted

## Calculador de métricas y estadísticas geométricas para el Mesh Generation Lab.
## Extrae con precisión: mallas, superficies, vértices, triángulos, AABB bounds y formas de colisión.

class MetricsData:
	var mesh_count: int = 0
	var surface_count: int = 0
	var vertex_count: int = 0
	var triangle_count: int = 0
	var cluster_count: int = 0
	var collision_shape_count: int = 0
	var bounds: AABB = AABB()

	func to_summary_string() -> String:
		return "Mallas: %d | Superficies: %d | Vértices: %d | Triángulos: %d" % [
			mesh_count, surface_count, vertex_count, triangle_count
		]

	func to_bounds_string() -> String:
		return "Dimensiones: %.2f × %.2f × %.2f m" % [
			bounds.size.x, bounds.size.y, bounds.size.z
		]

## Extrae métricas completas desde un nodo Node3D instanciado.
static func calculate_node_metrics(root: Node3D) -> MetricsData:
	var data := MetricsData.new()
	if root == null:
		return data

	var mesh_instances = root.find_children("*", "MeshInstance3D", true, false)
	var collision_shapes = root.find_children("*", "CollisionShape3D", true, false)
	data.collision_shape_count = collision_shapes.size()

	var first_point := true
	var global_aabb := AABB()

	for mi in mesh_instances:
		# Ignorar base o helpers de debug
		if mi.name == "Base" or mi.name == "DebugBounds" or mi.name == "DebugGrid":
			continue

		if mi.mesh != null:
			data.mesh_count += 1
			data.surface_count += mi.mesh.get_surface_count()

			var mesh_aabb: AABB = mi.mesh.get_aabb()
			var xformed_aabb: AABB = mi.transform * mesh_aabb
			if first_point:
				global_aabb = xformed_aabb
				first_point = false
			else:
				global_aabb = global_aabb.merge(xformed_aabb)

			for s in range(mi.mesh.get_surface_count()):
				var arrays = mi.mesh.surface_get_arrays(s)
				if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
					data.vertex_count += arrays[Mesh.ARRAY_VERTEX].size()
				if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
					data.triangle_count += arrays[Mesh.ARRAY_INDEX].size() / 3

	data.bounds = global_aabb
	return data
