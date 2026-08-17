class_name GridMapMapper
extends RefCounted

## Traduce los datos de solo lectura de un CellGrid a tiles de GridMap en 3D.
## Soporta capas independientes de suelo (FloorGridMap) y muros (WallGridMap).
## 100% puro: no muta el CellGrid, no genera geometría ni recalcula puertas lógicas.

func map_grid(
	grid: CellGrid,
	biome: BiomeProfile,
	floor_grid_map: GridMap,
	wall_grid_map: GridMap = null,
	config: DungeonConfig = null
) -> Dictionary:
	# Retorna: { "total_tiles": int, "diagnostics": Array[Dictionary] }
	var diagnostics: Array[Dictionary] = []
	var total_tiles: int = 0

	if grid == null:
		diagnostics.append({
			"code": "NULL_GRID",
			"severity": "FATAL",
			"stage": "gridmap_mapper",
			"entity_id": null,
			"message": "CellGrid is null."
		})
		return { "total_tiles": 0, "diagnostics": diagnostics }

	if biome == null:
		diagnostics.append({
			"code": "MISSING_BIOME_PROFILE",
			"severity": "FATAL",
			"stage": "gridmap_mapper",
			"entity_id": null,
			"message": "BiomeProfile is null."
		})
		return { "total_tiles": 0, "diagnostics": diagnostics }

	if floor_grid_map == null and wall_grid_map == null:
		diagnostics.append({
			"code": "NULL_GRIDMAP",
			"severity": "FATAL",
			"stage": "gridmap_mapper",
			"entity_id": null,
			"message": "No GridMap provided for rendering."
		})
		return { "total_tiles": 0, "diagnostics": diagnostics }

	var target_floor_map: GridMap = floor_grid_map if floor_grid_map != null else wall_grid_map
	var target_wall_map: GridMap = wall_grid_map if wall_grid_map != null else floor_grid_map

	var dungeon_floor_idx: int = biome.dungeon_floor_index if biome.dungeon_floor_index >= 0 else biome.floor_index
	var wall_h: int = maxi(1, config.wall_height) if config != null else 1

	for y in range(grid.height):
		for x in range(grid.width):
			var cell_pos := Vector2i(x, y)
			var cell_type: CellGrid.CellType = grid.get_cell(cell_pos)

			match cell_type:
				CellGrid.CellType.VOID:
					# VOID no produce tile en ningún GridMap
					continue

				CellGrid.CellType.FLOOR:
					if biome.floor_index >= 0:
						target_floor_map.set_cell_item(Vector3i(x, 0, y), biome.floor_index, 0)
						total_tiles += 1
					else:
						_record_missing_tile(diagnostics, "floor_index", cell_type, cell_pos)

				CellGrid.CellType.CORRIDOR:
					var c_idx: int = biome.corridor_index if biome.corridor_index >= 0 else dungeon_floor_idx
					if c_idx >= 0:
						target_floor_map.set_cell_item(Vector3i(x, 0, y), c_idx, 0)
						total_tiles += 1
					else:
						_record_missing_tile(diagnostics, "corridor_index", cell_type, cell_pos)

				CellGrid.CellType.DOOR, CellGrid.CellType.LOCKED_DOOR, \
				CellGrid.CellType.SPAWN, CellGrid.CellType.OBJECTIVE, \
				CellGrid.CellType.STAIRS_DOWN, CellGrid.CellType.STAIRS_UP:
					# Capa de suelo base bajo transiciones y marcadores
					if biome.floor_index >= 0:
						target_floor_map.set_cell_item(Vector3i(x, 0, y), biome.floor_index, 0)
						total_tiles += 1

				CellGrid.CellType.WALL:
					# 1. Base continua bajo muros visibles
					if grid.count_walkable_neighbors(cell_pos, true) > 0:
						if dungeon_floor_idx >= 0:
							target_floor_map.set_cell_item(Vector3i(x, 0, y), dungeon_floor_idx, 0)
							total_tiles += 1

						# 2. Muro 3D con orientación visual cosmética
						var wall_info: Dictionary = _get_wall_tile_and_orientation(grid, cell_pos, biome)
						var w_idx: int = wall_info["index"]
						var w_orient: int = wall_info["orientation"]
						if w_idx >= 0:
							if target_wall_map != target_floor_map:
								# Capa separada de muros en Y = 0
								target_wall_map.set_cell_item(Vector3i(x, 0, y), w_idx, w_orient)
							else:
								# GridMap único: apilar muros a partir de Y = 1
								for h in range(1, wall_h + 1):
									target_wall_map.set_cell_item(Vector3i(x, h, y), w_idx, w_orient)
							total_tiles += 1

				CellGrid.CellType.COLUMN:
					if dungeon_floor_idx >= 0:
						target_floor_map.set_cell_item(Vector3i(x, 0, y), dungeon_floor_idx, 0)
						total_tiles += 1
					var col_idx: int = biome.column_index if biome.column_index >= 0 else biome.wall_index
					if col_idx >= 0:
						target_wall_map.set_cell_item(Vector3i(x, 0 if target_wall_map != target_floor_map else 1, y), col_idx, 0)
						total_tiles += 1

				CellGrid.CellType.OBSTACLE:
					if biome.floor_index >= 0:
						target_floor_map.set_cell_item(Vector3i(x, 0, y), biome.floor_index, 0)
						total_tiles += 1
					var obs_idx: int = biome.obstacle_index if biome.obstacle_index >= 0 else biome.wall_index
					if obs_idx >= 0:
						target_wall_map.set_cell_item(Vector3i(x, 0 if target_wall_map != target_floor_map else 1, y), obs_idx, 0)
						total_tiles += 1

	return {
		"total_tiles": total_tiles,
		"diagnostics": diagnostics
	}

func _record_missing_tile(diagnostics: Array[Dictionary], slot_name: String, cell_type: CellGrid.CellType, pos: Vector2i) -> void:
	diagnostics.append({
		"code": "MISSING_TILE_MAPPING",
		"severity": "WARNING",
		"stage": "gridmap_mapper",
		"entity_id": slot_name,
		"message": "Missing tile mapping for slot '%s' at cell %s (type %d)." % [slot_name, str(pos), cell_type]
	})

func _get_wall_tile_and_orientation(grid: CellGrid, pos: Vector2i, biome: BiomeProfile) -> Dictionary:
	var n_w: bool = grid.is_walkable(pos + Vector2i(0, -1))
	var s_w: bool = grid.is_walkable(pos + Vector2i(0, 1))
	var w_w: bool = grid.is_walkable(pos + Vector2i(-1, 0))
	var e_w: bool = grid.is_walkable(pos + Vector2i(1, 0))

	var wall_idx: int = biome.wall_index
	var wall_orient: int = 0

	# Esquinas exteriores
	if biome.wall_corner_small_index >= 0:
		if s_w and e_w and not n_w and not w_w:
			return { "index": biome.wall_corner_small_index, "orientation": 0 }
		elif s_w and w_w and not n_w and not e_w:
			return { "index": biome.wall_corner_small_index, "orientation": 16 }
		elif n_w and e_w and not s_w and not w_w:
			return { "index": biome.wall_corner_small_index, "orientation": 22 }
		elif n_w and w_w and not s_w and not e_w:
			return { "index": biome.wall_corner_small_index, "orientation": 10 }

	# Paredes rectas
	if s_w:
		wall_orient = 0
	elif n_w:
		wall_orient = 10
	elif e_w:
		wall_orient = 22
	elif w_w:
		wall_orient = 16

	return { "index": wall_idx, "orientation": wall_orient }
