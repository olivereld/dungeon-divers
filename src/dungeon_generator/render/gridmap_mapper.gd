class_name GridMapMapper
extends Node

## Traduce los datos abstractos de un CellGrid a nodos GridMap de Godot en 3D.
## Soporta capas independientes de suelo (FloorGridMap) y muros (WallGridMap) para
## garantizar base continua bajo las paredes y orientación limpia de muros y esquinas.

@export var floor_grid_map: GridMap
@export var wall_grid_map: GridMap
@export var grid_map: GridMap # Fallback de compatibilidad

var _placeholder_factory: RefCounted = PlaceholderFactory.new()
var _current_mesh_lib: MeshLibrary = null
var _last_cell_size: float = -1.0
var _last_biome: BiomeProfile = null

func apply(grid: CellGrid, config: DungeonConfig = null, rooms: Array[RoomData] = []) -> void:
	var target_floor_map: GridMap = floor_grid_map
	var target_wall_map: GridMap = wall_grid_map
	if target_wall_map == null:
		target_wall_map = grid_map
	if target_floor_map == null:
		target_floor_map = grid_map

	if target_wall_map == null and target_floor_map == null:
		push_error("GridMapMapper: No se ha asignado ningún nodo GridMap.")
		return

	if config == null:
		config = DungeonConfig.new()

	var biome: BiomeProfile = config.biome_profile
	if biome == null:
		biome = BiomeProfile.new()

	# 1. Configurar o reutilizar librería de mallas
	var mesh_lib: MeshLibrary = null
	if biome.has_custom_assets():
		mesh_lib = biome.mesh_library
	else:
		if _current_mesh_lib == null or _last_cell_size != config.cell_size or _last_biome != biome:
			_current_mesh_lib = _placeholder_factory.create_placeholder_library(biome, config.cell_size)
			_last_cell_size = config.cell_size
			_last_biome = biome
		mesh_lib = _current_mesh_lib

	# 2. Limpiar y configurar GridMaps
	var maps_to_init: Array[GridMap] = []
	if target_floor_map != null and not maps_to_init.has(target_floor_map):
		maps_to_init.append(target_floor_map)
	if target_wall_map != null and not maps_to_init.has(target_wall_map):
		maps_to_init.append(target_wall_map)

	for gmap in maps_to_init:
		gmap.clear()
		gmap.cell_size = Vector3(config.cell_size, config.cell_size, config.cell_size)
		if gmap.mesh_library != mesh_lib:
			gmap.mesh_library = mesh_lib

	var wall_h: int = maxi(1, config.wall_height)
	var dungeon_floor_idx: int = biome.dungeon_floor_index if biome.dungeon_floor_index >= 0 else biome.floor_index

	# 3. Rellenar celdas en FloorGridMap y WallGridMap
	for y in range(grid.height):
		for x in range(grid.width):
			var cell_pos := Vector2i(x, y)
			var cell_type: CellGrid.CellType = grid.get_cell(cell_pos)

			# --- CAPA DE SUELOS (FloorGridMap) ---
			if target_floor_map != null:
				match cell_type:
					CellGrid.CellType.FLOOR:
						target_floor_map.set_cell_item(Vector3i(x, 0, y), biome.floor_index, 0)

					CellGrid.CellType.CORRIDOR:
						var c_idx: int = biome.corridor_index if biome.corridor_index >= 0 else dungeon_floor_idx
						target_floor_map.set_cell_item(Vector3i(x, 0, y), c_idx, 0)

					CellGrid.CellType.DOOR, CellGrid.CellType.LOCKED_DOOR, \
					CellGrid.CellType.SPAWN, CellGrid.CellType.OBJECTIVE, \
					CellGrid.CellType.STAIRS_DOWN, CellGrid.CellType.STAIRS_UP:
						target_floor_map.set_cell_item(Vector3i(x, 0, y), biome.floor_index, 0)

					CellGrid.CellType.WALL:
						# Suelo bajo muros perimetrales visibles para evitar huecos negros
						if grid.count_walkable_neighbors(cell_pos, true) > 0:
							target_floor_map.set_cell_item(Vector3i(x, 0, y), dungeon_floor_idx, 0)

			# --- CAPA DE MUROS Y PROPS (WallGridMap) ---
			if target_wall_map != null:
				match cell_type:
					CellGrid.CellType.WALL:
						if grid.count_walkable_neighbors(cell_pos, true) > 0:
							var wall_info: Dictionary = _get_wall_tile_and_orientation(grid, cell_pos, biome)
							var w_idx: int = wall_info["index"]
							var w_orient: int = wall_info["orientation"]
							if w_idx >= 0:
								if biome.wall_scene != null or biome.wall_corner_small_scene != null or biome.wall_corner_scene != null:
									target_wall_map.set_cell_item(Vector3i(x, 0, y), w_idx, w_orient)
								else:
									for wy in range(wall_h):
										target_wall_map.set_cell_item(Vector3i(x, wy, y), w_idx, w_orient)

					CellGrid.CellType.DOOR, CellGrid.CellType.LOCKED_DOOR:
						var door_idx: int = biome.door_index if cell_type == CellGrid.CellType.DOOR else biome.locked_door_index
						var door_orient: int = _get_door_orientation(grid, cell_pos)
						# Si usamos mapa único colocamos en y=1, si usamos mapas separados a nivel y=0
						var door_y: int = 1 if (target_wall_map == target_floor_map) else 0
						target_wall_map.set_cell_item(Vector3i(x, door_y, y), door_idx, door_orient)

					CellGrid.CellType.SPAWN:
						if biome.spawn_marker_index >= 0:
							var marker_y: int = 1 if (target_wall_map == target_floor_map) else 0
							target_wall_map.set_cell_item(Vector3i(x, marker_y, y), biome.spawn_marker_index, 0)

					CellGrid.CellType.OBJECTIVE:
						if biome.objective_marker_index >= 0:
							var marker_y: int = 1 if (target_wall_map == target_floor_map) else 0
							target_wall_map.set_cell_item(Vector3i(x, marker_y, y), biome.objective_marker_index, 0)

					CellGrid.CellType.STAIRS_DOWN:
						if target_wall_map != target_floor_map and biome.stairs_down_index >= 0:
							target_wall_map.set_cell_item(Vector3i(x, 0, y), biome.stairs_down_index, 0)

					CellGrid.CellType.STAIRS_UP:
						if target_wall_map != target_floor_map and biome.stairs_up_index >= 0:
							target_wall_map.set_cell_item(Vector3i(x, 0, y), biome.stairs_up_index, 0)

	# 4. Colocación de Columnas Arquitectónicas en salas espaciosas (>= 7x7)
	if target_wall_map != null and biome.column_index >= 0:
		_place_room_columns(grid, target_wall_map, rooms, biome)

func _place_room_columns(grid: CellGrid, wall_map: GridMap, rooms: Array[RoomData], biome: BiomeProfile) -> void:
	if rooms.is_empty() or biome.column_index < 0:
		return

	for room in rooms:
		# Solo en salas con suficiente amplitud para que no obstruya el paso
		if room.rect.size.x >= 7 and room.rect.size.y >= 7:
			var candidate_offsets: Array[Vector2i] = [
				Vector2i(room.rect.position.x + 2, room.rect.position.y + 2),
				Vector2i(room.rect.end.x - 3, room.rect.position.y + 2),
				Vector2i(room.rect.position.x + 2, room.rect.end.y - 3),
				Vector2i(room.rect.end.x - 3, room.rect.end.y - 3)
			]

			for pos in candidate_offsets:
				if not grid.is_in_bounds(pos):
					continue
				if grid.get_cell(pos) != CellGrid.CellType.FLOOR:
					continue

				# Evitar colocar pegado a marcadores o puertas
				var near_critical := false
				for n in grid.get_neighbors_4(pos):
					var nt := grid.get_cell(n)
					if nt == CellGrid.CellType.DOOR or nt == CellGrid.CellType.LOCKED_DOOR \
						or nt == CellGrid.CellType.SPAWN or nt == CellGrid.CellType.OBJECTIVE \
						or nt == CellGrid.CellType.STAIRS_DOWN or nt == CellGrid.CellType.STAIRS_UP:
						near_critical = true
						break

				if not near_critical:
					wall_map.set_cell_item(Vector3i(pos.x, 0, pos.y), biome.column_index, 0)

func _get_wall_tile_and_orientation(grid: CellGrid, pos: Vector2i, biome: BiomeProfile) -> Dictionary:
	var n_type: CellGrid.CellType = grid.get_cell(pos + Vector2i(0, -1))
	var s_type: CellGrid.CellType = grid.get_cell(pos + Vector2i(0, 1))
	var w_type: CellGrid.CellType = grid.get_cell(pos + Vector2i(-1, 0))
	var e_type: CellGrid.CellType = grid.get_cell(pos + Vector2i(1, 0))

	var n: bool = grid.is_walkable(pos + Vector2i(0, -1))
	var s: bool = grid.is_walkable(pos + Vector2i(0, 1))
	var w: bool = grid.is_walkable(pos + Vector2i(-1, 0))
	var e: bool = grid.is_walkable(pos + Vector2i(1, 0))

	var nw: bool = grid.is_walkable(pos + Vector2i(-1, -1))
	var ne: bool = grid.is_walkable(pos + Vector2i(1, -1))
	var sw: bool = grid.is_walkable(pos + Vector2i(-1, 1))
	var se: bool = grid.is_walkable(pos + Vector2i(1, 1))

	var rot_0: int = 0
	var rot_90: int = 16
	var rot_180: int = 10
	var rot_270: int = 22

	var corner_idx: int = biome.wall_corner_small_index if (biome.wall_corner_small_scene != null or (biome.has_custom_assets() and biome.wall_corner_small_index >= 0)) else biome.wall_corner_index
	if corner_idx < 0:
		corner_idx = biome.wall_corner_index

	var has_corner: bool = (corner_idx >= 0 and (biome.wall_corner_small_scene != null or biome.wall_corner_scene != null or not biome.has_custom_assets()))
	var tsplit_idx: int = biome.wall_tsplit_index
	var has_tsplit: bool = (tsplit_idx >= 0 and (biome.wall_tsplit_scene != null or not biome.has_custom_assets()))

	# 1. Puertas adyacentes: mantener alineación de muro recto continuo
	var n_door: bool = (n_type == CellGrid.CellType.DOOR or n_type == CellGrid.CellType.LOCKED_DOOR)
	var s_door: bool = (s_type == CellGrid.CellType.DOOR or s_type == CellGrid.CellType.LOCKED_DOOR)
	var w_door: bool = (w_type == CellGrid.CellType.DOOR or w_type == CellGrid.CellType.LOCKED_DOOR)
	var e_door: bool = (e_type == CellGrid.CellType.DOOR or e_type == CellGrid.CellType.LOCKED_DOOR)

	if (s or n) and (w_door or e_door):
		return {"index": biome.wall_index, "orientation": rot_0}
	if (w or e) and (n_door or s_door):
		return {"index": biome.wall_index, "orientation": rot_90}

	# 2. Bitmask de 4 bits para vecinos transitables cardinales: N=8, S=4, W=2, E=1
	var mask: int = (8 if n else 0) | (4 if s else 0) | (2 if w else 0) | (1 if e else 0)

	match mask:
		0:
			# Esquinas exteriores de vértice (ningún vecino cardinal es transitable)
			if has_corner:
				if se and not sw and not ne and not nw:
					var e_faces_s: bool = grid.is_walkable(pos + Vector2i(1, 1))
					var s_faces_e: bool = grid.is_walkable(pos + Vector2i(1, 1))
					if e_faces_s and s_faces_e:
						return {"index": corner_idx, "orientation": rot_90}

				if sw and not se and not ne and not nw:
					var w_faces_s: bool = grid.is_walkable(pos + Vector2i(-1, 1))
					var s_faces_w: bool = grid.is_walkable(pos + Vector2i(-1, 1))
					if w_faces_s and s_faces_w:
						return {"index": corner_idx, "orientation": rot_0}

				if ne and not nw and not se and not sw:
					var e_faces_n: bool = grid.is_walkable(pos + Vector2i(1, -1))
					var n_faces_e: bool = grid.is_walkable(pos + Vector2i(1, -1))
					if e_faces_n and n_faces_e:
						return {"index": corner_idx, "orientation": rot_180}

				if nw and not ne and not se and not sw:
					var w_faces_n: bool = grid.is_walkable(pos + Vector2i(-1, -1))
					var n_faces_w: bool = grid.is_walkable(pos + Vector2i(-1, -1))
					if w_faces_n and n_faces_w:
						return {"index": corner_idx, "orientation": rot_270}

			return {"index": -1, "orientation": 0}

		# Muros rectos (1 vecino cardinal transitable)
		8, 4:
			return {"index": biome.wall_index, "orientation": rot_0}
		2, 1:
			return {"index": biome.wall_index, "orientation": rot_90}

		# Muros separadores delgados (2 transitables opuestos)
		12: # N + S
			return {"index": biome.wall_index, "orientation": rot_0}
		3:  # W + E
			return {"index": biome.wall_index, "orientation": rot_90}

		# Esquinas interiores (2 transitables adyacentes formando L)
		5:  # S + E
			var w_idx: int = corner_idx if has_corner else biome.wall_index
			return {"index": w_idx, "orientation": rot_270}
		9:  # N + E
			var w_idx: int = corner_idx if has_corner else biome.wall_index
			return {"index": w_idx, "orientation": rot_0}
		10: # N + W
			var w_idx: int = corner_idx if has_corner else biome.wall_index
			return {"index": w_idx, "orientation": rot_90}
		6:  # S + W
			var w_idx: int = corner_idx if has_corner else biome.wall_index
			return {"index": w_idx, "orientation": rot_180}

		# Muros en T (3 vecinos transitables -> 1 solo vecino de muro sólido que conecta)
		11: # N + W + E transitables (Muro sólido al Sur)
			if has_tsplit:
				return {"index": tsplit_idx, "orientation": rot_0}
			return {"index": biome.wall_index, "orientation": rot_0}
		7:  # S + W + E transitables (Muro sólido al Norte)
			if has_tsplit:
				return {"index": tsplit_idx, "orientation": rot_180}
			return {"index": biome.wall_index, "orientation": rot_0}
		14: # N + S + W transitables (Muro sólido al Este)
			if has_tsplit:
				return {"index": tsplit_idx, "orientation": rot_90}
			return {"index": biome.wall_index, "orientation": rot_90}
		13: # N + S + E transitables (Muro sólido al Oeste)
			if has_tsplit:
				return {"index": tsplit_idx, "orientation": rot_270}
			return {"index": biome.wall_index, "orientation": rot_90}

		# 15: Todos los lados transitables (pilar o columna aislada)
		15:
			var col_idx: int = biome.column_index if biome.column_index >= 0 else (biome.wall_endcap_index if biome.wall_endcap_index >= 0 else biome.wall_index)
			return {"index": col_idx, "orientation": rot_0}

	return {"index": biome.wall_index, "orientation": rot_0}

func _get_door_orientation(grid: CellGrid, pos: Vector2i) -> int:
	var rot_90: int = 16

	var left_type: CellGrid.CellType = grid.get_cell(pos + Vector2i(-1, 0))
	var right_type: CellGrid.CellType = grid.get_cell(pos + Vector2i(1, 0))
	var up_type: CellGrid.CellType = grid.get_cell(pos + Vector2i(0, -1))
	var down_type: CellGrid.CellType = grid.get_cell(pos + Vector2i(0, 1))

	var left_wall: bool = (left_type == CellGrid.CellType.WALL or not grid.is_in_bounds(pos + Vector2i(-1, 0)))
	var right_wall: bool = (right_type == CellGrid.CellType.WALL or not grid.is_in_bounds(pos + Vector2i(1, 0)))
	var up_wall: bool = (up_type == CellGrid.CellType.WALL or not grid.is_in_bounds(pos + Vector2i(0, -1)))
	var down_wall: bool = (down_type == CellGrid.CellType.WALL or not grid.is_in_bounds(pos + Vector2i(0, 1)))

	# 1. Si hay muros a izquierda y derecha, la puerta está en un muro horizontal -> rot_0
	if left_wall and right_wall:
		return 0

	# 2. Si hay muros arriba y abajo, la puerta está en un muro vertical -> rot_90
	if up_wall and down_wall:
		return rot_90

	# 3. Si la habitación (FLOOR) está a la izquierda o derecha: el tránsito es horizontal (E/W) -> rot_90
	if left_type == CellGrid.CellType.FLOOR or right_type == CellGrid.CellType.FLOOR:
		return rot_90

	# 4. Si la habitación (FLOOR) está arriba o abajo: el tránsito es vertical (N/S) -> 0
	if up_type == CellGrid.CellType.FLOOR or down_type == CellGrid.CellType.FLOOR:
		return 0

	# 5. Fallback por análisis de muros laterales parciales
	if left_wall or right_wall:
		return 0

	return rot_90

func _get_tile_index(type: CellGrid.CellType, biome: BiomeProfile) -> int:
	match type:
		CellGrid.CellType.WALL:
			return biome.wall_index
		CellGrid.CellType.FLOOR:
			return biome.floor_index
		CellGrid.CellType.CORRIDOR:
			return biome.corridor_index if biome.corridor_index >= 0 else (biome.dungeon_floor_index if biome.dungeon_floor_index >= 0 else biome.floor_index)
		CellGrid.CellType.DOOR:
			return biome.door_index
		CellGrid.CellType.LOCKED_DOOR:
			return biome.locked_door_index
		CellGrid.CellType.STAIRS_DOWN:
			return biome.stairs_down_index
		CellGrid.CellType.STAIRS_UP:
			return biome.stairs_up_index
		CellGrid.CellType.SPAWN:
			return biome.floor_index
		CellGrid.CellType.OBJECTIVE:
			return biome.floor_index
		_:
			return -1
