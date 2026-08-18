class_name CorridorAnalyzer
extends RefCounted

## Analizador geométrico de corredores para la toma inteligente de decisiones de puertas (Fase Reforced).

const _CorridorInfoScript = preload("res://src/dungeon_generator/core/data/corridor_info.gd")
const _CorridorPathScript = preload("res://src/dungeon_generator/core/data/corridor_path.gd")

## Extrae las métricas estructurales de un corredor individual.
static func analyze_corridor(grid: CellGrid, path: _CorridorPathScript, rooms: Array) -> _CorridorInfoScript:
	var info := _CorridorInfoScript.new()
	if path == null:
		return info

	info.connection_id = path.connection_id
	info.length = path.centerline_cells.size()
	info.is_short = (info.length <= 3)

	if not path.centerline_cells.is_empty():
		info.endpoints.append(path.centerline_cells[0])
		if path.centerline_cells.size() > 1:
			info.endpoints.append(path.centerline_cells[-1])
		else:
			info.endpoints.append(path.centerline_cells[0])

	return info

## Extrae las métricas para una lista completa de corredores.
static func analyze_all_corridors(grid: CellGrid, paths: Array, rooms: Array) -> Dictionary:
	var results: Dictionary = {} # conn_id -> CorridorInfo
	for p in paths:
		if p != null:
			var info := analyze_corridor(grid, p, rooms)
			results[info.connection_id] = info
	return results
