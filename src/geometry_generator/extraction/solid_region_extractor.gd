class_name SolidRegionExtractor
extends RefCounted

## Extractor de regiones de masa sólida a partir de un CellGrid.
## Agrupa celdas contiguas de muro en SolidRegions e identifica sus caras exteriores
## orientadas hacia espacios transitables o límites del mapa, verificando openings.

const _SolidRegionScript = preload("res://src/geometry_generator/data/solid_region.gd")
const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")
const _WallOpeningManifestScript = preload("res://src/dungeon_generator/core/data/wall_opening_manifest.gd")

const SIDES: Array[Dictionary] = [
	{"side": _RoomEntranceScript.NORTH, "offset": Vector2i(0, -1), "opp": _RoomEntranceScript.SOUTH},
	{"side": _RoomEntranceScript.SOUTH, "offset": Vector2i(0, 1), "opp": _RoomEntranceScript.NORTH},
	{"side": _RoomEntranceScript.WEST, "offset": Vector2i(-1, 0), "opp": _RoomEntranceScript.EAST},
	{"side": _RoomEntranceScript.EAST, "offset": Vector2i(1, 0), "opp": _RoomEntranceScript.WEST}
]

## Extrae todas las regiones sólidas de celdas WALL del grid.
func extract_regions(
	grid: CellGrid,
	opening_manifest: WallOpeningManifest = null
) -> Array: # Array[SolidRegion]
	var regions: Array = []
	if grid == null:
		return regions

	var w: int = grid.width
	var h: int = grid.height
	var visited: Dictionary = {} # Vector2i -> true
	var region_id: int = 0

	for y in range(h):
		for x in range(w):
			var pos := Vector2i(x, y)
			if visited.has(pos):
				continue
			if not _is_wall_cell(grid, pos):
				continue

			# Iniciar flood fill BFS para agrupar celdas contiguas WALL
			var region := _SolidRegionScript.new(region_id)
			region_id += 1

			var queue: Array[Vector2i] = [pos]
			visited[pos] = true

			while not queue.is_empty():
				var curr: Vector2i = queue.pop_front()
				region.add_cell(curr)

				for s in SIDES:
					var n_pos: Vector2i = curr + (s["offset"] as Vector2i)
					if grid.is_in_bounds(n_pos) and _is_wall_cell(grid, n_pos):
						if not visited.has(n_pos):
							visited[n_pos] = true
							queue.append(n_pos)

			# Extraer caras exteriores para la región encontrada
			_extract_exterior_faces(region, grid, opening_manifest)
			regions.append(region)

	return regions

func _is_wall_cell(grid: CellGrid, pos: Vector2i) -> bool:
	if not grid.is_in_bounds(pos):
		return false
	var t = grid.get_cell(pos)
	return t == CellGrid.CellType.WALL or t == CellGrid.CellType.COLUMN

func _extract_exterior_faces(
	region: _SolidRegionScript,
	grid: CellGrid,
	opening_manifest: WallOpeningManifest
) -> void:
	for cell in region.cells:
		for s in SIDES:
			var side: int = s["side"]
			var offset: Vector2i = s["offset"]
			var opp_side: int = s["opp"]
			var neighbor: Vector2i = cell + offset

			var is_ext: bool = false
			var room_owner: int = -1
			var is_opening: bool = false

			if not grid.is_in_bounds(neighbor):
				is_ext = true
			elif not _is_wall_cell(grid, neighbor):
				is_ext = true
				if grid.is_walkable(neighbor):
					room_owner = grid.get_room_owner(neighbor)
					if opening_manifest != null:
						if opening_manifest.has_opening(neighbor, opp_side) or opening_manifest.has_opening(cell, side):
							is_opening = true

			if is_ext:
				region.add_exterior_face(cell, side, neighbor, is_opening, room_owner)
