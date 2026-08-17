class_name DungeonPresentationBuilder
extends RefCounted

## Coordinador central de la Fase 8: Materialización 3D de la Dungeon.
## Flujo Atómico: Staging Desacoplado -> Mapeo Grid -> Spawner Entidades -> Validación -> Atomic Swap.
## Inmunidad total a reemplazos silenciosos y 0 mutaciones en CellGrid.

const _GridMapMapperScript = preload("res://src/dungeon_generator/presentation/gridmap_mapper.gd")
const _DungeonEntitySpawnerScript = preload("res://src/dungeon_generator/presentation/dungeon_entity_spawner.gd")
const _DungeonPresentationResultScript = preload("res://src/dungeon_generator/presentation/presentation_result.gd")
const _PlaceholderFactoryScript = preload("res://src/dungeon_generator/render/placeholder_factory.gd")

var _gridmap_mapper := _GridMapMapperScript.new()
var _entity_spawner := _DungeonEntitySpawnerScript.new()
var _placeholder_factory := _PlaceholderFactoryScript.new()

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
	floor_grid_map.cell_size = Vector3(tile_size, tile_size, tile_size)
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

	# 5. Spawning de Entidades en Staging
	var spawn_res: Dictionary = _entity_spawner.spawn_entities(
		semantic_result, staging_root, biome, config
	)
	result.spawned_entities = spawn_res.get("spawned_entities", [])
	for diag in spawn_res.get("diagnostics", []):
		result.diagnostics.append(diag)

	# 6. Validación de Severidad y Decisión de Commit / Rollback
	if result.has_blocking_errors():
		# Rollback inmediato: destruir staging desacoplado
		staging_root.free()
		_handle_failure_preservation(result, active_presentation)
		return result

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
