class_name BoundaryExtractor
extends RefCounted

## Extractor topológico formal de aristas de frontera a partir de un CellGrid.
## Convierte las transiciones entre celdas transitables y sólidas en un WallBoundaryGraph explícito.

const _WallBoundaryGraphScript = preload("res://src/geometry_generator/data/wall_boundary_graph.gd")
const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")
const _WallOpeningManifestScript = preload("res://src/dungeon_generator/core/data/wall_opening_manifest.gd")

enum EdgeDir {
	NORTH = 0, # Arista de (x, y) a (x+1, y)
	EAST = 1,  # Arista de (x+1, y) a (x+1, y+1)
	SOUTH = 2, # Arista de (x+1, y+1) a (x, y+1)
	WEST = 3   # Arista de (x, y+1) a (x, y)
}

func extract_graph(grid: CellGrid, opening_manifest: WallOpeningManifest = null) -> WallBoundaryGraph:
	var graph := _WallBoundaryGraphScript.new()
	if grid == null:
		return graph

	var w: int = grid.width
	var h: int = grid.height

	for y in range(h):
		for x in range(w):
			var cell := Vector2i(x, y)
			if not grid.is_walkable(cell):
				continue

			# 1. Frontera Norte
			if _is_boundary(grid, cell, cell + Vector2i(0, -1), _RoomEntranceScript.NORTH, opening_manifest):
				graph.add_directed_edge(
					Vector2i(x, y),
					Vector2i(x + 1, y),
					{"dir": EdgeDir.NORTH, "cell": cell, "side": _RoomEntranceScript.NORTH}
				)

			# 2. Frontera Este
			if _is_boundary(grid, cell, cell + Vector2i(1, 0), _RoomEntranceScript.EAST, opening_manifest):
				graph.add_directed_edge(
					Vector2i(x + 1, y),
					Vector2i(x + 1, y + 1),
					{"dir": EdgeDir.EAST, "cell": cell, "side": _RoomEntranceScript.EAST}
				)

			# 3. Frontera Sur
			if _is_boundary(grid, cell, cell + Vector2i(0, 1), _RoomEntranceScript.SOUTH, opening_manifest):
				graph.add_directed_edge(
					Vector2i(x + 1, y + 1),
					Vector2i(x, y + 1),
					{"dir": EdgeDir.SOUTH, "cell": cell, "side": _RoomEntranceScript.SOUTH}
				)

			# 4. Frontera Oeste
			if _is_boundary(grid, cell, cell + Vector2i(-1, 0), _RoomEntranceScript.WEST, opening_manifest):
				graph.add_directed_edge(
					Vector2i(x, y + 1),
					Vector2i(x, y),
					{"dir": EdgeDir.WEST, "cell": cell, "side": _RoomEntranceScript.WEST}
				)

	return graph

func _is_boundary(
	grid: CellGrid,
	cell: Vector2i,
	neighbor: Vector2i,
	side: int,
	opening_manifest: WallOpeningManifest
) -> bool:
	if not grid.is_in_bounds(neighbor):
		return true

	if not grid.is_walkable(neighbor):
		if opening_manifest != null and opening_manifest.has_opening(cell, side):
			return false
		return true

	return false
