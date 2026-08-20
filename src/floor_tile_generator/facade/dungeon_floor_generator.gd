class_name DungeonFloorGenerator
extends RefCounted

## Fachada central de datos puros para la generación de superficies y baldosas de suelo (Fases M1, M2 y M7).
## Orquesta: FloorRegionExtractor -> FloorTilePattern -> FloorSurfaceMeshBuilder -> FloorCollisionBuilder.
## 0 creación de nodos 3D (responsabilidad delegada a DungeonFloorSpawner).

const _FloorRegionExtractorScript = preload("res://src/floor_tile_generator/extraction/floor_region_extractor.gd")
const _FloorTilePatternScript = preload("res://src/floor_tile_generator/patterns/floor_tile_pattern.gd")
const _FloorSurfaceMeshBuilderScript = preload("res://src/floor_tile_generator/geometry/floor_surface_mesh_builder.gd")
const _FloorCollisionBuilderScript = preload("res://src/floor_tile_generator/collision/floor_collision_builder.gd")
const _FloorSurfaceClusterScript = preload("res://src/floor_tile_generator/data/floor_surface_cluster.gd")
const _FloorSurfaceResultScript = preload("res://src/floor_tile_generator/data/floor_surface_result.gd")
const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")

var _region_extractor := _FloorRegionExtractorScript.new()
var _pattern_gen := _FloorTilePatternScript.new()
var _mesh_builder := _FloorSurfaceMeshBuilderScript.new()
var _collision_builder := _FloorCollisionBuilderScript.new()

## Genera la superficie completa de suelo en modo de datos puros (FloorSurfaceResult)
func generate_floor_surface(
	grid,
	config = null,
	seed_val: int = 1337
):
	var result = _FloorSurfaceResultScript.new()
	if grid == null:
		result.add_diagnostic("NULL_GRID", "FATAL", "Grid provided to DungeonFloorGenerator is null")
		return result

	if config == null:
		config = _FloorTileConfigScript.new()

	# M1: Extracción de superficies conexas
	var regions: Array = _region_extractor.extract_regions(grid)
	result.total_regions_count = regions.size()

	if regions.is_empty():
		return result

	# M2 & M3: Generación de clusters y descriptores de patrón
	var cluster_id: int = 0
	for region in regions:
		var cluster = _FloorSurfaceClusterScript.new(cluster_id)
		cluster.cells = region

		for cell in region:
			var cell_pos: Vector2i = cell if cell is Vector2i else Vector2i(cell.x, cell.y)
			var descs: Array = _pattern_gen.generate_descriptors_for_cell(
				cell_pos, config, seed_val + cluster_id
			)
			cluster.descriptors.append_array(descs)

		# M4: Construcción de malla ArrayMesh
		cluster.mesh = _mesh_builder.build_cluster_mesh(cluster, config)
		if cluster.mesh != null:
			cluster.aabb = cluster.mesh.get_aabb()

		# M5: Construcción de colisiones físicas
		_collision_builder.build_collision_for_cluster(cluster, cluster.cells, config)

		result.clusters.append(cluster)
		result.total_tiles_generated += region.size()
		result.total_descriptors_count += cluster.descriptors.size()
		cluster_id += 1

	return result
