class_name WallLightCandidateFinder
extends RefCounted

## Evaluador de candidatos para anclaje de antorchas y luces en muros de mazmorras.
## Detecta celdas perimetrales adyacentes a muros sólidos y descarta puertas y esquinas estrechas.

const _LightPlacementScript = preload("res://src/dungeon_lighting/data/light_placement.gd")
const _CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")
const _RoomDataScript = preload("res://src/dungeon_generator/core/data/room_data.gd")
const _DoorPairScript = preload("res://src/dungeon_generator/core/data/door_pair.gd")
const _CorridorPathScript = preload("res://src/dungeon_generator/core/data/corridor_path.gd")

const DIRS: Array[Vector2i] = [
	Vector2i(0, -1), # NORTH = 0
	Vector2i(0, 1),  # SOUTH = 1
	Vector2i(1, 0),  # EAST = 2
	Vector2i(-1, 0)  # WEST = 3
]

## Encuentra candidatos de colocación de luz en los muros interiores de una habitación.
func find_room_wall_candidates(
	room: RoomData,
	grid: CellGrid,
	door_pairs: Array = [],
	door_avoidance_margin: int = 1,
	avoid_corners: bool = true
) -> Array[LightPlacement]:
	var candidates: Array[LightPlacement] = []
	if room == null or grid == null:
		return candidates

	# 1. Recopilar celdas de puertas para exclusión
	var forbidden_cells: Dictionary = {}
	for dp in door_pairs:
		if dp == null:
			continue
		var door_positions: Array[Vector2i] = []
		if "door_a" in dp and dp.door_a != null:
			door_positions.append(dp.door_a.position)
		if "door_b" in dp and dp.door_b != null:
			door_positions.append(dp.door_b.position)
		if "door_cell" in dp:
			door_positions.append(dp.door_cell)
		if "position" in dp:
			door_positions.append(dp.position)

		for dpos in door_positions:
			for dy in range(-door_avoidance_margin, door_avoidance_margin + 1):
				for dx in range(-door_avoidance_margin, door_avoidance_margin + 1):
					forbidden_cells[dpos + Vector2i(dx, dy)] = true

	var r: Rect2i = room.rect
	var next_id: int = 1

	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var cell := Vector2i(x, y)
			if not grid.is_walkable(cell):
				continue
			if forbidden_cells.has(cell):
				continue

			# Evaluar las 4 direcciones para detectar muro adyacente
			for side_idx in range(DIRS.size()):
				var dir = DIRS[side_idx]
				var neighbor = cell + dir

				# Si el vecino no es caminable (es void o muro sólido)
				if not grid.is_walkable(neighbor):
					# Descartar si está en esquina diagonal cerrada (opcional)
					if avoid_corners:
						var is_corner_pinch: bool = false
						# Revisar si hay muros a ambos lados perpendiculares
						if side_idx <= 1: # NORTH o SOUTH
							if not grid.is_walkable(cell + Vector2i(1, 0)) and not grid.is_walkable(cell + Vector2i(-1, 0)):
								is_corner_pinch = true
						else: # EAST o WEST
							if not grid.is_walkable(cell + Vector2i(0, 1)) and not grid.is_walkable(cell + Vector2i(0, -1)):
								is_corner_pinch = true
						if is_corner_pinch:
							continue

					var placement := _LightPlacementScript.new()
					placement.light_id = next_id
					next_id += 1
					placement.cell = cell
					placement.wall_side = side_idx as _LightPlacementScript.WallSide
					placement.room_id = room.id
					placement.corridor_id = ""
					placement.kind = &"torch"
					placement.priority = 1.0
					candidates.append(placement)

	return candidates

## Encuentra candidatos de colocación de luz en las paredes laterales de un pasillo.
func find_corridor_wall_candidates(
	corridor: CorridorPath,
	grid: CellGrid,
	avoid_corners: bool = false
) -> Array[LightPlacement]:
	var candidates: Array[LightPlacement] = []
	if corridor == null or grid == null:
		return candidates

	var next_id: int = 1000

	for cell in corridor.carved_cells:
		if grid.get_cell(cell) != _CellGridScript.CellType.CORRIDOR and not grid.is_walkable(cell):
			continue

		for side_idx in range(DIRS.size()):
			var dir = DIRS[side_idx]
			var neighbor = cell + dir

			if not grid.is_walkable(neighbor):
				var placement := _LightPlacementScript.new()
				placement.light_id = next_id
				next_id += 1
				placement.cell = cell
				placement.wall_side = side_idx as _LightPlacementScript.WallSide
				placement.room_id = -1
				placement.corridor_id = str(corridor.connection_id)
				placement.kind = &"torch"
				placement.priority = 1.0
				candidates.append(placement)

	return candidates
