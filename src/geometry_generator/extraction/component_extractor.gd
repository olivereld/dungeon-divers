class_name ComponentExtractor
extends RefCounted

## Descompone un WallBoundaryGraph en un conjunto de WallComponents independientes.
## Extrae bucles cerrados y cadenas abiertas ordenadas, simplificando vértices colineales.

const _WallComponentScript = preload("res://src/geometry_generator/data/wall_component.gd")
const _WallBoundaryGraphScript = preload("res://src/geometry_generator/data/wall_boundary_graph.gd")

func extract_components(graph: WallBoundaryGraph) -> Array[WallComponent]:
	var components: Array[WallComponent] = []
	if graph == null or graph.get_edge_count() == 0:
		return components

	# 1. Identificar componentes conexas
	var visited_edges: Dictionary = {} # Vector4i -> bool
	var all_edges: Array[Dictionary] = graph.get_all_edges()

	# Mapa de salida dirigida: Vector2i -> Array[Vector2i]
	var outgoing_map: Dictionary = {}
	for e in all_edges:
		var u: Vector2i = e["start"]
		var v: Vector2i = e["end"]
		if not outgoing_map.has(u):
			var arr: Array[Vector2i] = []
			outgoing_map[u] = arr
		(outgoing_map[u] as Array[Vector2i]).append(v)

	var component_counter: int = 0

	for e in all_edges:
		var edge_k := Vector4i(e["start"].x, e["start"].y, e["end"].x, e["end"].y)
		if visited_edges.has(edge_k):
			continue

		# Rastrear ciclo cerrado o cadena a partir de este punto
		var comp := _WallComponentScript.new(component_counter)
		var loop_points: Array[Vector2i] = []
		var curr_pt: Vector2i = e["start"]
		var start_pt: Vector2i = curr_pt

		var max_steps: int = all_edges.size() + 10
		var step: int = 0
		var closed: bool = false

		while step < max_steps:
			step += 1
			loop_points.append(curr_pt)

			# Buscar aristas no visitadas salientes desde curr_pt
			var next_candidates: Array = outgoing_map.get(curr_pt, [])
			var chosen_next: Vector2i = Vector2i(-999999, -999999)

			for cand_item in next_candidates:
				var cand: Vector2i = cand_item as Vector2i
				var cand_k := Vector4i(curr_pt.x, curr_pt.y, cand.x, cand.y)
				if not visited_edges.has(cand_k):
					chosen_next = cand
					visited_edges[cand_k] = true
					break

			if chosen_next == Vector2i(-999999, -999999):
				# No hay más aristas salientes no visitadas
				break

			if chosen_next == start_pt:
				# Se cerró el ciclo completamente
				closed = true
				break

			curr_pt = chosen_next

		if loop_points.size() >= 3:
			var simplified: Array[Vector2i] = simplify_polygon(loop_points)
			if simplified.size() >= 3:
				if closed:
					comp.add_loop(simplified)
				else:
					comp.add_chain(simplified)

		if not comp.is_empty():
			components.append(comp)
			component_counter += 1

	return components

## Simplifica vértices colineales consecutivos en un polígono cerrado ortogonal.
static func simplify_polygon(pts: Array[Vector2i]) -> Array[Vector2i]:
	var n: int = pts.size()
	if n < 3:
		return pts

	var result: Array[Vector2i] = []
	for i in range(n):
		var prev: Vector2i = pts[(i - 1 + n) % n]
		var curr: Vector2i = pts[i]
		var next: Vector2i = pts[(i + 1) % n]

		var dir1: Vector2i = curr - prev
		var dir2: Vector2i = next - curr

		# Si cambian de dirección ortogonal, conservamos el vértice de esquina
		var cross_prod: int = dir1.x * dir2.y - dir1.y * dir2.x
		var dot_prod: int = dir1.x * dir2.x + dir1.y * dir2.y
		if cross_prod != 0 or dot_prod <= 0:
			result.append(curr)

	return result
