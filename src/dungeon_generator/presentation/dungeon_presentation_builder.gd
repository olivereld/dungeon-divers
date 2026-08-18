class_name DungeonPresentationBuilder
extends RefCounted

## Coordinador central de Materialización 3D (Fase 8, 9 y 10).
## Flujo Atómico: Staging Desacoplado -> Mapeo Grid -> Muros Continuos -> Puertas -> Escaleras -> Atomic Swap.
## Inmunidad total a reemplazos silenciosos y 0 mutaciones en CellGrid.

const _GridMapMapperScript = preload("res://src/dungeon_generator/presentation/gridmap_mapper.gd")
const _DungeonEntitySpawnerScript = preload("res://src/dungeon_generator/presentation/dungeon_entity_spawner.gd")
const _DungeonPresentationResultScript = preload("res://src/dungeon_generator/presentation/presentation_result.gd")
const _PlaceholderFactoryScript = preload("res://src/dungeon_generator/render/placeholder_factory.gd")
const _ContinuousWallMeshBuilderScript = preload("res://src/wall_mesh_generator/core/continuous_wall_mesh_builder.gd")
const _WallMeshConfigScript = preload("res://src/wall_mesh_generator/config/wall_mesh_config.gd")
const _DoorManifestFactoryScript = preload("res://src/dungeon_generator/core/data/door_manifest_factory.gd")
const _DungeonDoorSpawnerScript = preload("res://src/dungeon_generator/presentation/dungeon_door_spawner.gd")
const _DungeonStairSpawnerScript = preload("res://src/dungeon_generator/presentation/dungeon_stair_spawner.gd")
const _GridToWorldScript = preload("res://src/dungeon_generator/presentation/grid_to_world.gd")
const _DungeonFloorDataScript = preload("res://src/dungeon_generator/core/data/dungeon_floor_data.gd")
const _CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")

var _gridmap_mapper := _GridMapMapperScript.new()
var _entity_spawner := _DungeonEntitySpawnerScript.new()
var _door_spawner := _DungeonDoorSpawnerScript.new()
var _stair_spawner := _DungeonStairSpawnerScript.new()
var _placeholder_factory := _PlaceholderFactoryScript.new()

## Construye la presentación 3D de un piso semántico individual.
func build_presentation(
	semantic_result: DungeonSemanticResult,
	parent_node: Node3D,
	biome: BiomeProfile,
	config: DungeonConfig = null,
	active_presentation: Node3D = null,
	use_placeholders_if_needed: bool = true
) -> DungeonPresentationResult:
	var result: DungeonPresentationResult = _DungeonPresentationResultScript.new()

	# 1. Validación Previa de Entrada
	if not _validate_input(semantic_result, biome, result):
		_handle_failure_preservation(result, active_presentation)
		return result

	if config == null:
		config = DungeonConfig.new()

	var tile_size: float = config.cell_size

	# 2. Crear StagingRoot 100% Desacoplado del árbol de escena activo
	var staging_root := Node3D.new()
	staging_root.name = "DungeonPresentationStaging"

	# 3. Configurar MeshLibrary y Capas GridMap en Staging
	var mesh_lib: MeshLibrary = null
	if biome.has_custom_assets():
		mesh_lib = biome.mesh_library
	elif use_placeholders_if_needed:
		mesh_lib = _placeholder_factory.create_placeholder_library(biome, tile_size)
	else:
		result.add_diagnostic("MISSING_MESH_LIBRARY", "FATAL", "presentation_builder",
			"No MeshLibrary provided and placeholder fallback is disabled.")
		staging_root.free()
		_handle_failure_preservation(result, active_presentation)
		return result

	var floor_grid_map := GridMap.new()
	floor_grid_map.name = "FloorGridMap"
	floor_grid_map.cell_size = Vector3(tile_size, 0.02, tile_size)
	floor_grid_map.mesh_library = mesh_lib
	staging_root.add_child(floor_grid_map)

	var wall_grid_map := GridMap.new()
	wall_grid_map.name = "WallGridMap"
	wall_grid_map.cell_size = Vector3(tile_size, tile_size, tile_size)
	wall_grid_map.mesh_library = mesh_lib
	staging_root.add_child(wall_grid_map)

	# 4. Mapear CellGrid -> GridMap en Staging
	var map_res: Dictionary = _gridmap_mapper.map_grid(
		semantic_result.grid, biome, floor_grid_map, wall_grid_map, config
	)
	result.total_tiles_rendered = int(map_res.get("total_tiles", 0))
	for diag in map_res.get("diagnostics", []):
		result.diagnostics.append(diag)

	# 4.1 Generar Malla Continua Unificada de Paredes (sin cortes ni solapamientos)
	if biome.wall_scene == null:
		var wall_builder := _ContinuousWallMeshBuilderScript.new()
		var wall_config := _WallMeshConfigScript.new()
		wall_config.cube_size = tile_size
		wall_config.cubes_high = maxi(1, config.wall_height if config != null else 2)
		wall_config.seed = config.seed if config != null else 1337

		var opening_manifest = null
		if semantic_result != null and semantic_result.door_pairs != null:
			opening_manifest = _DoorManifestFactoryScript.create_wall_opening_manifest(semantic_result.door_pairs)

		var wall_mesh: ArrayMesh = wall_builder.build_dungeon_wall_mesh(
			semantic_result.grid, wall_config, 0, opening_manifest
		)
		if wall_mesh.get_surface_count() > 0:
			var wall_inst := MeshInstance3D.new()
			wall_inst.name = "ContinuousWalls"
			wall_inst.mesh = wall_mesh
			wall_inst.create_trimesh_collision()
			staging_root.add_child(wall_inst)

	# 5. Spawning de Puertas y Portales en Staging (Fase 9)
	if semantic_result != null and semantic_result.door_pairs != null:
		var door_manifests = _DoorManifestFactoryScript.create_door_manifests(semantic_result.door_pairs)
		var door_res: Dictionary = _door_spawner.spawn_doors(
			door_manifests, staging_root, biome, tile_size,
			config.wall_height if config != null else 2,
			config.seed if config != null else 1337,
			semantic_result.grid
		)
		for d_node in door_res.get("spawned_doors", []):
			result.spawned_entities.append(d_node)

	# 6. Spawning de Entidades (Marcadores, Llaves, Cerraduras) en Staging
	var spawn_res: Dictionary = _entity_spawner.spawn_entities(
		semantic_result, staging_root, biome, config
	)
	for ent in spawn_res.get("spawned_entities", []):
		result.spawned_entities.append(ent)
	for diag in spawn_res.get("diagnostics", []):
		result.diagnostics.append(diag)

	# 7. Validación de Severidad y Decisión de Commit / Rollback
	if result.has_blocking_errors():
		staging_root.free()
		_handle_failure_preservation(result, active_presentation)
		return result

	# 8. Atomic Swap: Promover StagingRoot a ActiveRoot
	if active_presentation != null:
		if active_presentation.get_parent() != null:
			active_presentation.get_parent().remove_child(active_presentation)
		active_presentation.queue_free()

	staging_root.name = "DungeonPresentation"
	if parent_node != null:
		parent_node.add_child(staging_root)

	result.presentation_root = staging_root
	result.staging_committed = true
	result.previous_presentation_preserved = false
	result.success = true

	return result

## Construye la presentación 3D de una mazmorra completa multinivel (Fase 10).
func build_multi_floor_presentation(
	multi_result: DungeonMultiFloorResult,
	parent_node: Node3D,
	biome: BiomeProfile,
	config: DungeonConfig = null,
	active_presentation: Node3D = null
) -> DungeonPresentationResult:
	var result: DungeonPresentationResult = _DungeonPresentationResultScript.new()

	if multi_result == null or not multi_result.is_valid:
		result.add_diagnostic("INVALID_MULTI_RESULT", "FATAL", "presentation_builder",
			"DungeonMultiFloorResult is null or invalid.")
		_handle_failure_preservation(result, active_presentation)
		return result

	if config == null:
		config = DungeonConfig.new()

	var tile_size: float = config.cell_size
	var floor_h: float = config.floor_height

	var staging_root := Node3D.new()
	staging_root.name = "MultiFloorPresentationStaging"

	var mesh_lib: MeshLibrary = _placeholder_factory.create_placeholder_library(biome, tile_size)

	# Materializar cada piso en su contenedor con elevación Y
	for f_num in multi_result.get_floor_numbers():
		var f_data: DungeonFloorData = multi_result.get_floor(f_num)
		if f_data == null:
			continue

		var floor_container := Node3D.new()
		floor_container.name = "Floor_%d" % f_num
		floor_container.position.y = _GridToWorldScript.floor_to_world_y(f_num, floor_h)
		staging_root.add_child(floor_container)

		# 1. FloorGridMap
		var floor_grid_map := GridMap.new()
		floor_grid_map.name = "FloorGridMap"
		floor_grid_map.cell_size = Vector3(tile_size, 0.02, tile_size)
		floor_grid_map.mesh_library = mesh_lib
		floor_container.add_child(floor_grid_map)

		if f_data.grid != null:
			var grid = f_data.grid
			for y in range(grid.height):
				for x in range(grid.width):
					if grid.is_walkable(Vector2i(x, y)):
						floor_grid_map.set_cell_item(Vector3i(x, 0, y), biome.floor_index if biome != null else 0, 0)
						result.total_tiles_rendered += 1

		# 2. ContinuousWallMesh
		var wall_builder := _ContinuousWallMeshBuilderScript.new()
		var wall_config := _WallMeshConfigScript.new()
		wall_config.cube_size = tile_size
		wall_config.cubes_high = maxi(1, config.wall_height)
		wall_config.seed = f_data.seed_used

		var opening_manifest = null
		if f_data.door_pairs != null:
			opening_manifest = _DoorManifestFactoryScript.create_wall_opening_manifest(f_data.door_pairs)

		var wall_mesh: ArrayMesh = wall_builder.build_dungeon_wall_mesh(
			f_data.grid, wall_config, 0, opening_manifest
		)
		if wall_mesh.get_surface_count() > 0:
			var wall_inst := MeshInstance3D.new()
			wall_inst.name = "ContinuousWalls"
			wall_inst.mesh = wall_mesh
			wall_inst.create_trimesh_collision()
			floor_container.add_child(wall_inst)

		# 3. Puertas
		if f_data.door_pairs != null:
			var door_manifests = _DoorManifestFactoryScript.create_door_manifests(f_data.door_pairs)
			var door_res: Dictionary = _door_spawner.spawn_doors(
				door_manifests, floor_container, biome, tile_size, config.wall_height, f_data.seed_used, f_data.grid
			)
			for d in door_res.get("spawned_doors", []):
				result.spawned_entities.append(d)

		# 4. Escaleras del piso
		if f_data.has_stairs():
			var stair_res: Dictionary = _stair_spawner.spawn_stairs(
				f_data.stairs, floor_container, biome, tile_size, floor_h, f_data.seed_used
			)
			for st_node in stair_res.get("spawned_stairs", []):
				result.spawned_entities.append(st_node)

	# Atomic Swap
	if active_presentation != null:
		if active_presentation.get_parent() != null:
			active_presentation.get_parent().remove_child(active_presentation)
		active_presentation.queue_free()

	staging_root.name = "DungeonPresentation"
	if parent_node != null:
		parent_node.add_child(staging_root)

	result.presentation_root = staging_root
	result.staging_committed = true
	result.previous_presentation_preserved = false
	result.success = true

	return result

func _validate_input(
	semantic_result: DungeonSemanticResult,
	biome: BiomeProfile,
	result: DungeonPresentationResult
) -> bool:
	if semantic_result == null:
		result.add_diagnostic("INVALID_SEMANTIC_RESULT", "FATAL", "presentation_builder",
			"DungeonSemanticResult is null.")
		return false

	if not semantic_result.gameplay_valid:
		result.add_diagnostic("GAMEPLAY_INVALID", "FATAL", "presentation_builder",
			"DungeonSemanticResult is flagged as gameplay_valid == false.")
		return false

	if semantic_result.grid == null:
		result.add_diagnostic("NULL_GRID", "FATAL", "presentation_builder",
			"DungeonSemanticResult grid is null.")
		return false

	if biome == null:
		result.add_diagnostic("MISSING_BIOME_PROFILE", "FATAL", "presentation_builder",
			"BiomeProfile is null.")
		return false

	return true

func _handle_failure_preservation(
	result: DungeonPresentationResult,
	active_presentation: Node3D
) -> void:
	result.staging_committed = false
	result.success = false
	if active_presentation != null:
		result.presentation_root = active_presentation
		result.previous_presentation_preserved = true
	else:
		result.presentation_root = null
		result.previous_presentation_preserved = false
