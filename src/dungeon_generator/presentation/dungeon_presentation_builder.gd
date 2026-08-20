class_name DungeonPresentationBuilder
extends RefCounted

## Coordinador central de Materialización 3D (Fase 8, 9 y 10).
## Flujo Atómico: Staging Desacoplado -> Mapeo Grid -> Muros Continuos (Geometry Generator M6) -> Puertas -> Escaleras -> Atomic Swap.
## Inmunidad total a reemplazos silenciosos y 0 mutaciones en CellGrid.

const _GridMapMapperScript = preload("res://src/dungeon_generator/presentation/gridmap_mapper.gd")
const _DungeonEntitySpawnerScript = preload("res://src/dungeon_generator/presentation/dungeon_entity_spawner.gd")
const _DungeonPresentationResultScript = preload("res://src/dungeon_generator/presentation/presentation_result.gd")
const _PlaceholderFactoryScript = preload("res://src/dungeon_generator/render/placeholder_factory.gd")
const _DungeonGeometryGeneratorScript = preload("res://src/geometry_generator/facade/dungeon_geometry_generator.gd")
const _DungeonFloorGeneratorScript = preload("res://src/floor_tile_generator/facade/dungeon_floor_generator.gd")
const _DungeonFloorSpawnerScript = preload("res://src/dungeon_generator/presentation/dungeon_floor_spawner.gd")
const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const _CollisionConfigScript = preload("res://src/geometry_generator/config/collision_config.gd")
const _DecorationConfigScript = preload("res://src/geometry_generator/config/decoration_config.gd")
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
var _geometry_generator := _DungeonGeometryGeneratorScript.new()
var _floor_generator := _DungeonFloorGeneratorScript.new()
var _floor_spawner := _DungeonFloorSpawnerScript.new()

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

	# 4.0 Generar y materializar Geometría Procedural de Suelo (Fases M1-M8)
	if biome.dungeon_floor_scene == null and biome.floor_scene == null and semantic_result.grid != null:
		var floor_cfg: _FloorTileConfigScript = config.floor_tile_config if (config != null and "floor_tile_config" in config and config.floor_tile_config != null) else _FloorTileConfigScript.new()
		floor_cfg.tile_size = tile_size
		floor_cfg.seed = config.seed if config != null else 1337

		var floor_res = _floor_generator.generate_floor_surface(
			semantic_result.grid, floor_cfg, config.seed if config != null else 1337
		)
		_floor_spawner.spawn_floor(floor_res, staging_root, biome)
		floor_grid_map.visible = false

	# 4.1 Generar Malla Continua de Paredes a través de DungeonGeometryGenerator (Fase M6)
	if biome.wall_scene == null:
		var wall_config := _WallGeometryConfigScript.new()
		wall_config.cube_size = tile_size
		wall_config.cubes_high = maxi(1, config.wall_height if config != null else 2)
		wall_config.seed = config.seed if config != null else 1337

		var col_config := _CollisionConfigScript.new()
		col_config.mode = _CollisionConfigScript.CollisionMode.COMPOUND_BOX

		var dec_config := _DecorationConfigScript.new()
		dec_config.enabled = true
		dec_config.seed = config.seed if config != null else 1337

		var opening_manifest = null
		if semantic_result != null and semantic_result.door_pairs != null:
			opening_manifest = _DoorManifestFactoryScript.create_wall_opening_manifest(semantic_result.door_pairs)

		var geom_res = _geometry_generator.generate_wall_clusters(
			semantic_result.grid, opening_manifest, wall_config, col_config, dec_config, 0
		)

		if not geom_res.generated_meshes.is_empty():
			var wall_inst := MeshInstance3D.new()
			wall_inst.name = "ContinuousWalls"
			wall_inst.mesh = geom_res.get_unified_mesh()

			var static_body := StaticBody3D.new()
			static_body.name = "WallStaticBody"
			for g_mesh in geom_res.generated_meshes:
				for i in range(g_mesh.collision_shapes.size()):
					var col_shape := CollisionShape3D.new()
					col_shape.shape = g_mesh.collision_shapes[i]
					col_shape.transform = g_mesh.collision_transforms[i]
					static_body.add_child(col_shape)
			wall_inst.add_child(static_body)
			staging_root.add_child(wall_inst)
			wall_grid_map.visible = false

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

		# 1.1 Floor Surface & Tile Spawner (Fases M1-M8)
		if biome.dungeon_floor_scene == null and biome.floor_scene == null and f_data.grid != null:
			var floor_cfg: _FloorTileConfigScript = config.floor_tile_config if (config != null and "floor_tile_config" in config and config.floor_tile_config != null) else _FloorTileConfigScript.new()
			floor_cfg.tile_size = tile_size
			floor_cfg.seed = f_data.seed_used

			var floor_res = _floor_generator.generate_floor_surface(
				f_data.grid, floor_cfg, f_data.seed_used
			)
			_floor_spawner.spawn_floor(floor_res, floor_container, biome)
			floor_grid_map.visible = false

		# 2. ContinuousWalls a través de DungeonGeometryGenerator
		var wall_config := _WallGeometryConfigScript.new()
		wall_config.cube_size = tile_size
		wall_config.cubes_high = maxi(1, config.wall_height)
		wall_config.seed = f_data.seed_used

		var col_config := _CollisionConfigScript.new()
		col_config.mode = _CollisionConfigScript.CollisionMode.COMPOUND_BOX

		var dec_config := _DecorationConfigScript.new()
		dec_config.enabled = true
		dec_config.seed = f_data.seed_used

		var opening_manifest = null
		if f_data.door_pairs != null:
			opening_manifest = _DoorManifestFactoryScript.create_wall_opening_manifest(f_data.door_pairs)

		var geom_res = _geometry_generator.generate_wall_clusters(
			f_data.grid, opening_manifest, wall_config, col_config, dec_config, 0
		)

		if not geom_res.generated_meshes.is_empty():
			var wall_inst := MeshInstance3D.new()
			wall_inst.name = "ContinuousWalls"
			wall_inst.mesh = geom_res.get_unified_mesh()

			var static_body := StaticBody3D.new()
			static_body.name = "WallStaticBody"
			for g_mesh in geom_res.generated_meshes:
				for i in range(g_mesh.collision_shapes.size()):
					var col_shape := CollisionShape3D.new()
					col_shape.shape = g_mesh.collision_shapes[i]
					col_shape.transform = g_mesh.collision_transforms[i]
					static_body.add_child(col_shape)
			wall_inst.add_child(static_body)
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

## Construye la presentación 3D consumiendo directamente un DungeonResult inmutable (Fase 16).
## Desacoplado 100% en modo Read-Only: 0 mutaciones en el modelo lógico.
func build_from_dungeon_result(
	dungeon_result: DungeonResult,
	parent_node: Node3D,
	biome: BiomeProfile = null,
	config: DungeonConfig = null,
	active_presentation: Node3D = null,
	use_placeholders_if_needed: bool = true
) -> DungeonPresentationResult:
	var result: DungeonPresentationResult = _DungeonPresentationResultScript.new()

	if dungeon_result == null or dungeon_result.grid == null:
		result.add_diagnostic("INVALID_DUNGEON_RESULT", "FATAL", "presentation_builder",
			"DungeonResult or its CellGrid is null.")
		_handle_failure_preservation(result, active_presentation)
		return result

	if biome == null:
		biome = BiomeProfile.new()

	if config == null:
		config = DungeonConfig.new()

	var tile_size: float = config.cell_size

	# 1. Staging Root desacoplado
	var staging_root := Node3D.new()
	staging_root.name = "DungeonPresentationStaging"

	# 2. Configurar MeshLibrary y Capas GridMap en Staging
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

	# 3. Mapear CellGrid -> GridMap en Staging
	var map_res: Dictionary = _gridmap_mapper.map_grid(
		dungeon_result.grid, biome, floor_grid_map, wall_grid_map, config
	)
	result.total_tiles_rendered = int(map_res.get("total_tiles", 0))

	# 3.1 Floor Surface & Tile Spawner (Fases M1-M8)
	if biome.dungeon_floor_scene == null and biome.floor_scene == null and dungeon_result.grid != null:
		var floor_cfg: _FloorTileConfigScript = config.floor_tile_config if (config != null and "floor_tile_config" in config and config.floor_tile_config != null) else _FloorTileConfigScript.new()
		floor_cfg.tile_size = tile_size
		floor_cfg.seed = config.seed if config != null else 1337

		var floor_res = _floor_generator.generate_floor_surface(
			dungeon_result.grid, floor_cfg, config.seed if config != null else 1337
		)
		_floor_spawner.spawn_floor(floor_res, staging_root, biome)
		floor_grid_map.visible = false

	# 4. Generar Malla Continua de Paredes a través de DungeonGeometryGenerator
	if biome.wall_scene == null:
		var wall_config := _WallGeometryConfigScript.new()
		wall_config.cube_size = tile_size
		wall_config.cubes_high = maxi(1, config.wall_height if config != null else 2)
		wall_config.seed = config.seed if config != null else 1337

		var col_config := _CollisionConfigScript.new()
		col_config.mode = _CollisionConfigScript.CollisionMode.COMPOUND_BOX

		var dec_config := _DecorationConfigScript.new()
		dec_config.enabled = true
		dec_config.seed = config.seed if config != null else 1337

		var opening_manifest = null
		if dungeon_result.door_pairs != null and not dungeon_result.door_pairs.is_empty():
			opening_manifest = _DoorManifestFactoryScript.create_wall_opening_manifest(dungeon_result.door_pairs)

		var geom_res = _geometry_generator.generate_wall_clusters(
			dungeon_result.grid, opening_manifest, wall_config, col_config, dec_config, 0
		)

		if not geom_res.generated_meshes.is_empty():
			var wall_inst := MeshInstance3D.new()
			wall_inst.name = "ContinuousWalls"
			wall_inst.mesh = geom_res.get_unified_mesh()

			var static_body := StaticBody3D.new()
			static_body.name = "WallStaticBody"
			for g_mesh in geom_res.generated_meshes:
				for i in range(g_mesh.collision_shapes.size()):
					var col_shape := CollisionShape3D.new()
					col_shape.shape = g_mesh.collision_shapes[i]
					col_shape.transform = g_mesh.collision_transforms[i]
					static_body.add_child(col_shape)
			wall_inst.add_child(static_body)
			staging_root.add_child(wall_inst)

	# 5. Spawning de Puertas
	if dungeon_result.door_pairs != null and not dungeon_result.door_pairs.is_empty():
		var door_manifests = _DoorManifestFactoryScript.create_door_manifests(dungeon_result.door_pairs)
		var door_res: Dictionary = _door_spawner.spawn_doors(
			door_manifests, staging_root, biome, tile_size,
			config.wall_height if config != null else 2,
			config.seed if config != null else 1337,
			dungeon_result.grid
		)
		for d_node in door_res.get("spawned_doors", []):
			result.spawned_entities.append(d_node)

	# 6. Spawning de Iluminación Focal (Fase 16: <= 12 OmniLights sin sombras)
	_spawn_lighting(dungeon_result, staging_root, config)

	# 7. Atomic Swap: Promover StagingRoot a ActiveRoot
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

func _spawn_lighting(
	dungeon_result: DungeonResult,
	staging_root: Node3D,
	config: DungeonConfig
) -> void:
	if dungeon_result == null or staging_root == null:
		return

	var lights_root := Node3D.new()
	lights_root.name = "Lighting"
	staging_root.add_child(lights_root)

	var tile_size: float = config.cell_size if config != null else 2.0
	var max_lights: int = 12
	var spawned_count: int = 0

	# 1. Punto clave: Spawn
	var spawn_pos: Vector2i = Vector2i.ZERO
	var spawn_cells = dungeon_result.grid.find_cells_of_type(CellGrid.CellType.SPAWN)
	if not spawn_cells.is_empty():
		spawn_pos = spawn_cells[0]
		_create_omni_light(lights_root, spawn_pos, tile_size, Color(0.3, 0.7, 1.0), 8.0, 1.5)
		spawned_count += 1

	# 2. Puntos clave: Habitaciones según rol semántico
	for r in dungeon_result.rooms:
		if spawned_count >= max_lights:
			break
		if r == null:
			continue

		var center: Vector2i = r.get_center()
		if center == spawn_pos:
			continue

		var color := Color(1.0, 0.85, 0.6) # Antorcha cálida por defecto
		var energy := 1.2
		var range_val := float(maxi(r.rect.size.x, r.rect.size.y)) * tile_size * 0.8

		match r.room_type:
			&"boss":
				color = Color(1.0, 0.25, 0.2) # Rojo intenso
				energy = 2.0
			&"shrine", &"puzzle":
				color = Color(0.4, 0.9, 0.6) # Verde místico
				energy = 1.6
			&"treasure":
				color = Color(1.0, 0.85, 0.2) # Dorado brillante
				energy = 1.8

		_create_omni_light(lights_root, center, tile_size, color, range_val, energy)
		spawned_count += 1

func _create_omni_light(parent: Node3D, grid_pos: Vector2i, tile_size: float, color: Color, range_val: float, energy: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "OmniLight_%d_%d" % [grid_pos.x, grid_pos.y]
	light.position = Vector3(
		(float(grid_pos.x) + 0.5) * tile_size,
		tile_size * 0.8,
		(float(grid_pos.y) + 0.5) * tile_size
	)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_val
	light.shadow_enabled = false # Estricto: sin sombras para rendimiento máximo
	parent.add_child(light)
	return light
