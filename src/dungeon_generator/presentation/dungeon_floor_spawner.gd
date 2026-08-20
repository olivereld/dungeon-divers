class_name DungeonFloorSpawner
extends RefCounted

## Spawner especializado de nodos 3D para superficies y baldosas de suelo en la capa de Presentación (Fase M6).
## Desacopla la instanciación de nodos del DungeonPresentationBuilder, evitando que se convierta en un God Object.

const _FloorSurfaceResultScript = preload("res://src/floor_tile_generator/data/floor_surface_result.gd")
const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")

## Materializa los clusters de suelo en el árbol de escena bajo el nodo de staging dado
func spawn_floor(
	floor_result,
	parent_staging_node: Node3D,
	biome: BiomeProfile = null
) -> Dictionary:
	var output: Dictionary = {
		"spawned_nodes": [],
		"floor_container": null
	}

	if floor_result == null or floor_result.clusters.is_empty() or parent_staging_node == null:
		return output

	var floor_tiles_root := Node3D.new()
	floor_tiles_root.name = "FloorTiles"

	var spawned_nodes: Array = []

	for cluster in floor_result.clusters:
		var c_inst: MeshInstance3D = cluster.to_mesh_instance("FloorCluster")
		c_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# Agregar StaticBody3D si el cluster tiene colisiones configuradas
		if not cluster.collision_shapes.is_empty():
			var c_body: StaticBody3D = cluster.create_collision_body("FloorStaticBody")
			c_inst.add_child(c_body)

		floor_tiles_root.add_child(c_inst)
		spawned_nodes.append(c_inst)

	parent_staging_node.add_child(floor_tiles_root)

	output["spawned_nodes"] = spawned_nodes
	output["floor_container"] = floor_tiles_root
	return output
