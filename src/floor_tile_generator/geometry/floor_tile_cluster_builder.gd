class_name FloorTileClusterBuilder
extends RefCounted

## Ensambla la malla 3D, colisiones físicas y metadatos de una región de suelo en un GeneratedFloorCluster.

const _FloorTileMeshBuilderScript = preload("res://src/floor_tile_generator/geometry/floor_tile_mesh_builder.gd")
const _FloorCollisionBuilderScript = preload("res://src/floor_tile_generator/collision/floor_collision_builder.gd")
const _GeneratedFloorClusterScript = preload("res://src/floor_tile_generator/data/generated_floor_cluster.gd")
const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")

var _mesh_builder := _FloorTileMeshBuilderScript.new()
var _collision_builder := _FloorCollisionBuilderScript.new()

## Construye un cluster completo de suelo para una región dada
func build_cluster(
	cluster_id: int,
	cells: Array,
	config = null,
	seed_val: int = 1337
):
	var cluster := _GeneratedFloorClusterScript.new(cluster_id)
	if cells.is_empty():
		return cluster

	if config == null:
		config = _FloorTileConfigScript.new()

	for c in cells:
		var v: Vector2i = c if c is Vector2i else Vector2i(c.x, c.y)
		cluster.cells.append(v)

	# 1. Construir ArrayMesh
	cluster.mesh = _mesh_builder.build_region_mesh(cluster.cells, config, seed_val)
	if cluster.mesh != null:
		cluster.aabb = cluster.mesh.get_aabb()

	# 2. Construir colisión física
	_collision_builder.build_collision_for_cluster(cluster, cluster.cells, config)

	# 3. Metadatos
	cluster.metadata["cell_count"] = cluster.cells.size()
	cluster.metadata["seed"] = seed_val

	return cluster
