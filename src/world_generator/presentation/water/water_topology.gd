class_name WaterTopology
extends RefCounted

## Topología hidráulica formal y resolución de conectividad (BLOQUE 6).
## Analiza y estructura `water_cells` en componentes conexos, clasifica aristas
## (interior vs borde de agua) y garantiza superficies continuas y cerradas.
##
## Invariantes:
## 1. agua -> agua     = interior (sin caras internas ni costuras)
## 2. agua -> tierra   = borde de agua (shoreline)
## 3. agua -> exterior = borde de agua (borde de grilla)
## 4. No distinguir río/lago; la conectividad D8 define los cuerpos de agua contiguos.

enum EdgeType {
	INTERIOR,  ## Agua con agua: el agua fluye continuamente
	SHORELINE, ## Agua con tierra: margen de ribera
	EXTERIOR   ## Agua con límite del mundo
}

# Direcciones cardinales para las 4 aristas de cada celda:
# 0: Norte (dy = -1)
# 1: Este  (dx = +1)
# 2: Sur   (dy = +1)
# 3: Oeste (dx = -1)
const D4_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0)
]

const D8_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)
]

## Mapa de aristas por celda: Vector2i -> Array[int] (tamaño 4, valores EdgeType)
var cell_edges: Dictionary = {}

## Lista de componentes conexos hidráulicos (cuerpos de agua contiguos D8)
## Cada componente es un Dictionary: { "id": int, "cells": Array[Vector2i], "boundary_edges": Array[Dictionary] }
var components: Array[Dictionary] = []

## Mapa de pertenencia: Vector2i -> int (component_id)
var cell_component_map: Dictionary = {}

## Aristas de borde globales (shoreline loops)
var boundary_edge_count: int = 0
var interior_edge_count: int = 0

static func analyze(water_cells: Dictionary, grid_width: int, grid_height: int) -> WaterTopology:
	var topo := WaterTopology.new()
	topo._build(water_cells, grid_width, grid_height)
	return topo

func _build(water_cells: Dictionary, grid_width: int, grid_height: int) -> void:
	cell_edges.clear()
	components.clear()
	cell_component_map.clear()
	boundary_edge_count = 0
	interior_edge_count = 0

	if water_cells.is_empty():
		return

	# 1. Clasificación de aristas para cada celda de agua
	for pos in water_cells.keys():
		var edges: Array[int] = [EdgeType.EXTERIOR, EdgeType.EXTERIOR, EdgeType.EXTERIOR, EdgeType.EXTERIOR]

		for dir_idx in range(4):
			var neighbor_pos: Vector2i = pos + D4_OFFSETS[dir_idx]

			if neighbor_pos.x < 0 or neighbor_pos.x >= grid_width or neighbor_pos.y < 0 or neighbor_pos.y >= grid_height:
				edges[dir_idx] = EdgeType.EXTERIOR
				boundary_edge_count += 1
			elif water_cells.has(neighbor_pos):
				edges[dir_idx] = EdgeType.INTERIOR
				interior_edge_count += 1
			else:
				edges[dir_idx] = EdgeType.SHORELINE
				boundary_edge_count += 1

		cell_edges[pos] = edges

	# 2. Segmentación en componentes conexos (D8: ríos, lagos, confluencias, desembocaduras continuas)
	var visited: Dictionary = {}
	var component_id: int = 0

	for start_pos in water_cells.keys():
		if visited.has(start_pos):
			continue

		var comp_cells: Array[Vector2i] = []
		var queue: Array[Vector2i] = [start_pos]
		visited[start_pos] = true

		var head: int = 0
		while head < queue.size():
			var curr: Vector2i = queue[head]
			head += 1
			comp_cells.append(curr)
			cell_component_map[curr] = component_id

			# Explorar vecinos D8 para mantener conectividad hidráulica diagonal
			for off in D8_OFFSETS:
				var next_pos: Vector2i = curr + off
				if water_cells.has(next_pos) and not visited.has(next_pos):
					visited[next_pos] = true
					queue.append(next_pos)

		# Extraer aristas de borde de este componente
		var comp_boundary: Array[Dictionary] = []
		for pos in comp_cells:
			var edges: Array = cell_edges[pos]
			for dir_idx in range(4):
				if edges[dir_idx] != EdgeType.INTERIOR:
					comp_boundary.append({
						"cell": pos,
						"direction": dir_idx,
						"type": edges[dir_idx]
					})

		components.append({
			"id": component_id,
			"cells": comp_cells,
			"boundary_edges": comp_boundary
		})
		component_id += 1

## Consulta si la arista en una dirección específica es frontera con tierra seca (SHORELINE - BLOQUE 9)
func is_shoreline_edge(pos: Vector2i, dir_idx: int) -> bool:
	if not cell_edges.has(pos):
		return false
	var edges: Array = cell_edges[pos]
	return edges[dir_idx] == EdgeType.SHORELINE

## Consulta si la arista en una dirección específica es frontera con el límite exterior (EXTERIOR)
func is_exterior_edge(pos: Vector2i, dir_idx: int) -> bool:
	if not cell_edges.has(pos):
		return false
	var edges: Array = cell_edges[pos]
	return edges[dir_idx] == EdgeType.EXTERIOR

## Consulta si la arista en una dirección específica es de borde (shoreline o exterior)
func is_border_edge(pos: Vector2i, dir_idx: int) -> bool:
	if not cell_edges.has(pos):
		return true
	var edges: Array = cell_edges[pos]
	return edges[dir_idx] != EdgeType.INTERIOR

## Consulta si la arista es puramente interior (agua continua)
func is_interior_edge(pos: Vector2i, dir_idx: int) -> bool:
	if not cell_edges.has(pos):
		return false
	var edges: Array = cell_edges[pos]
	return edges[dir_idx] == EdgeType.INTERIOR

## Retorna el número de componentes conexos de agua
func get_component_count() -> int:
	return components.size()

## Valida los invariantes topológicos requeridos por el BLOQUE 6:
## - Cada componente tiene un contorno cerrado (aristas de borde > 0).
## - No hay celdas de agua huérfanas sin clasificar.
## - Cada arista interior tiene una arista interior correspondiente en la celda vecina.
func validate_invariants(water_cells: Dictionary) -> Dictionary:
	var errors: Array[String] = []

	# Invariante 1: Coincidencia de celdas
	if cell_edges.size() != water_cells.size():
		errors.append("Discrepancia en recuento de celdas: clasificadas %d != water_cells %d" % [cell_edges.size(), water_cells.size()])

	# Invariante 2: Reciprocidad de aristas interiores
	for pos in cell_edges.keys():
		var edges: Array = cell_edges[pos]
		for dir_idx in range(4):
			if edges[dir_idx] == EdgeType.INTERIOR:
				var neighbor_pos: Vector2i = pos + D4_OFFSETS[dir_idx]
				var opposite_dir: int = (dir_idx + 2) % 4
				if not cell_edges.has(neighbor_pos):
					errors.append("Arista interior en %s dir %d apunta a vecina inexistente %s" % [str(pos), dir_idx, str(neighbor_pos)])
				elif cell_edges[neighbor_pos][opposite_dir] != EdgeType.INTERIOR:
					errors.append("Falta reciprocidad interior entre %s y %s" % [str(pos), str(neighbor_pos)])

	# Invariante 3: Cada componente debe tener borde perimétrico
	for comp in components:
		if comp["boundary_edges"].is_empty():
			errors.append("Componente %d no tiene aristas de contorno (superficie no acotada)" % comp["id"])

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"component_count": components.size(),
		"total_water_cells": water_cells.size(),
		"interior_edges": interior_edge_count,
		"boundary_edges": boundary_edge_count
	}
