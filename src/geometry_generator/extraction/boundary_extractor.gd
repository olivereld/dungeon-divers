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

enum BoundaryType {
	NONE = 0,
	SOLID_BOUNDARY = 1,
	ROOM_CORRIDOR_BOUNDARY = 2
}

func _is_boundary(
	grid: CellGrid,
	cell: Vector2i,
	neighbor: Vector2i,
	side: int,
	opening_manifest: WallOpeningManifest
) -> bool:
	var b_type := _classify_boundary(grid, cell, neighbor, side, opening_manifest)
	return b_type != BoundaryType.NONE

func _classify_boundary(
	grid: CellGrid,
	cell: Vector2i,
	neighbor: Vector2i,
	side: int,
	opening_manifest: WallOpeningManifest
) -> BoundaryType:
	# 1. Límite fuera del mapa o celda no transitable (roca sólida)
	if not grid.is_in_bounds(neighbor) or not grid.is_walkable(neighbor):
		if opening_manifest != null and opening_manifest.has_opening(cell, side):
			return BoundaryType.NONE
		return BoundaryType.SOLID_BOUNDARY

	# 2. Frontera arquitectónica entre ROOM y CORRIDOR (o entre distintas habitaciones)
	if _is_room_corridor_boundary(grid, cell, neighbor):
		var opposite_side := _opposite_side(side)

		if opening_manifest != null:
			if opening_manifest.has_opening(cell, side):
				return BoundaryType.NONE
			if opening_manifest.has_opening(neighbor, opposite_side):
				return BoundaryType.NONE

		# Regla de unicidad para evitar doble pared superpuesta:
		# a) Entre ROOM y CORRIDOR: solo la habitación emite la arista
		if _is_room_cell(grid, cell) and _is_corridor_cell(grid, neighbor):
			return BoundaryType.ROOM_CORRIDOR_BOUNDARY
		# b) Entre dos habitaciones distintas: solo la sala con menor room_owner emite la arista
		if _is_room_cell(grid, cell) and _is_room_cell(grid, neighbor):
			var owner_c: int = grid.get_room_owner(cell)
			var owner_n: int = grid.get_room_owner(neighbor)
			if owner_c < owner_n:
				return BoundaryType.ROOM_CORRIDOR_BOUNDARY

		return BoundaryType.NONE

	return BoundaryType.NONE

func _is_room_corridor_boundary(
	grid: CellGrid,
	cell: Vector2i,
	neighbor: Vector2i
) -> bool:
	var cell_is_room := _is_room_cell(grid, cell)
	var neighbor_is_room := _is_room_cell(grid, neighbor)

	var cell_is_corridor := _is_corridor_cell(grid, cell)
	var neighbor_is_corridor := _is_corridor_cell(grid, neighbor)

	return (cell_is_room and neighbor_is_corridor) \
		or (cell_is_corridor and neighbor_is_room) \
		or (cell_is_room and neighbor_is_room and grid.get_room_owner(cell) != grid.get_room_owner(neighbor))

func _is_room_cell(grid: CellGrid, pos: Vector2i) -> bool:
	if not grid.is_walkable(pos):
		return false
	return grid.get_room_owner(pos) != -1

func _is_corridor_cell(grid: CellGrid, pos: Vector2i) -> bool:
	return grid.is_walkable(pos) \
		and grid.get_cell(pos) == CellGrid.CellType.CORRIDOR

func _opposite_side(side: int) -> int:
	match side:
		_RoomEntranceScript.NORTH:
			return _RoomEntranceScript.SOUTH
		_RoomEntranceScript.SOUTH:
			return _RoomEntranceScript.NORTH
		_RoomEntranceScript.EAST:
			return _RoomEntranceScript.WEST
		_RoomEntranceScript.WEST:
			return _RoomEntranceScript.EAST
	return side
