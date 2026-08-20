class_name DungeonFloorTileGenerator
extends RefCounted

## Fachada central de alto nivel para la generación procedural de suelo 3D (Presentation Layer).
## Orquesta: FloorRegionExtractor -> FloorTileClusterBuilder (Mesh + Collision) -> FloorTileResult.
## 0 mutaciones sobre CellGrid, garantizando arquitectura desacoplada y determinista.

const _FloorRegionExtractorScript = preload("res://src/floor_tile_generator/extraction/floor_region_extractor.gd")
const _FloorTileClusterBuilderScript = preload("res://src/floor_tile_generator/geometry/floor_tile_cluster_builder.gd")
const _FloorTileResultScript = preload("res://src/floor_tile_generator/data/floor_tile_result.gd")
const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const _GeneratedFloorClusterScript = preload("res://src/floor_tile_generator/data/generated_floor_cluster.gd")

var _region_extractor := _FloorRegionExtractorScript.new()
var _cluster_builder := _FloorTileClusterBuilderScript.new()

## Genera los clusters de geometría y colisión de suelo para un CellGrid y los retorna en un FloorTileResult.
func generate_floor_clusters(
	grid,
	config = null,
	seed_val: int = 1337
):
	var result = _FloorTileResultScript.new()
	if grid == null:
		result.add_diagnostic("NULL_GRID", "FATAL", "Grid provided to DungeonFloorTileGenerator is null")
		return result

	if config == null:
		config = _FloorTileConfigScript.new()

	# 1. Extracción de regiones conexas transitables
	var regions: Array = _region_extractor.extract_regions(grid)
	result.total_regions_extracted = regions.size()

	if regions.is_empty():
		return result

	# 2. Generación de mallas y colisiones por cluster
	var cluster_id: int = 0
	for region in regions:
		var cluster_seed: int = seed_val + cluster_id
		var cluster = _cluster_builder.build_cluster(
			cluster_id, region, config, cluster_seed
		)
		if cluster != null and cluster.mesh != null:
			result.generated_clusters.append(cluster)
			result.total_tiles_generated += region.size()
		cluster_id += 1

	return result

## Genera y añade directamente los nodos 3D (MeshInstance3D + StaticBody3D) a un nodo padre.
func generate_and_attach_floor_nodes(
	grid,
	parent_node: Node3D,
	config = null,
	seed_val: int = 1337
) -> Array[MeshInstance3D]:
	var created_nodes: Array[MeshInstance3D] = []

	if config == null:
		config = _FloorTileConfigScript.new()

	var res = generate_floor_clusters(grid, config, seed_val)

	for cluster in res.generated_clusters:
		var inst: MeshInstance3D = cluster.to_mesh_instance("FloorCluster")
		if config.collision_mode != _FloorTileConfigScript.CollisionMode.NONE:
			var static_body = cluster.create_collision_body("FloorStaticBody")
			inst.add_child(static_body)

		if parent_node != null:
			parent_node.add_child(inst)
		created_nodes.append(inst)

	return created_nodes
