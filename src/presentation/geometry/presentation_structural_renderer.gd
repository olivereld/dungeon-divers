class_name PresentationStructuralRenderer
extends RefCounted

## Orquestador desacoplado de renderizado estructural (Suelos y Muros 3D).
## Convierte PresentationGeometryPartition + ArchitecturalStyleConfigResolver en mallas 3D,
## colisiones físicas y oclusores en el StagingRoot, sin acoplar la lógica semántica ni mutar CellGrid.

const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const _CollisionConfigScript = preload("res://src/geometry_generator/config/collision_config.gd")
const _DecorationConfigScript = preload("res://src/geometry_generator/config/decoration_config.gd")
const _DoorManifestFactoryScript = preload("res://src/dungeon_generator/core/data/door_manifest_factory.gd")

const _DungeonGeometryGeneratorScript = preload("res://src/geometry_generator/facade/dungeon_geometry_generator.gd")
const _DungeonFloorGeneratorScript = preload("res://src/floor_tile_generator/facade/dungeon_floor_generator.gd")
const _DungeonFloorSpawnerScript = preload("res://src/dungeon_generator/presentation/dungeon_floor_spawner.gd")
const _ArchitecturalStyleConfigResolverScript = preload("res://src/presentation/architecture/architectural_style_config_resolver.gd")

const CAMERA_OCCLUDER_GROUP: StringName = &"camera_occluder"

var _geometry_generator := _DungeonGeometryGeneratorScript.new()
var _floor_generator := _DungeonFloorGeneratorScript.new()
var _floor_spawner := _DungeonFloorSpawnerScript.new()
var _style_config_resolver := _ArchitecturalStyleConfigResolverScript.new()

## Renderiza la estructura física (suelos y muros continuos) en el nodo staging_root.
func render_structure(
	partition: PresentationGeometryPartition,
	semantic_result: DungeonSemanticResult,
	config: DungeonConfig,
	biome: BiomeProfile,
	staging_root: Node3D,
	floor_grid_map: GridMap = null,
	wall_grid_map: GridMap = null
) -> Dictionary:
	var result: Dictionary = {
		"floor_rendered": false,
		"walls_rendered": false,
		"diagnostics": []
	}

	if partition == null or staging_root == null or semantic_result == null:
		return result

	var tile_size: float = config.cell_size if config != null else 2.0
	var master_seed: int = config.seed if config != null else 1337

	# 1. Generación de Suelos Procedurales por Partición
	if biome == null or (biome.dungeon_floor_scene == null and biome.floor_scene == null):
		var base_floor_cfg: _FloorTileConfigScript = config.floor_tile_config if (config != null and "floor_tile_config" in config and config.floor_tile_config != null) else _FloorTileConfigScript.new()
		base_floor_cfg.tile_size = tile_size
		base_floor_cfg.seed = master_seed

		var floor_res = _floor_generator.generate_floor_for_partition(
			partition, _style_config_resolver, base_floor_cfg, master_seed
		)
		_floor_spawner.spawn_floor(floor_res, staging_root, biome)
		if floor_grid_map != null:
			floor_grid_map.visible = false
		result["floor_rendered"] = true

	# 2. Generación de Muros Continuos por Partición
	if biome == null or biome.wall_scene == null:
		var wall_config := _WallGeometryConfigScript.new()
		wall_config.cube_size = tile_size
		wall_config.cubes_high = maxi(1, config.wall_height if config != null else 2)
		wall_config.seed = master_seed

		var col_config := _CollisionConfigScript.new()
		col_config.mode = _CollisionConfigScript.CollisionMode.COMPOUND_BOX

		var base_dec := _DecorationConfigScript.new()
		base_dec.enabled = true
		base_dec.seed = master_seed

		var opening_manifest = null
		if semantic_result.door_pairs != null:
			opening_manifest = _DoorManifestFactoryScript.create_wall_opening_manifest(semantic_result.door_pairs)

		var geom_res = _geometry_generator.generate_wall_clusters_for_partition(
			semantic_result.grid, partition, _style_config_resolver, opening_manifest, wall_config, col_config, base_dec, 0, master_seed
		)

		if not geom_res.generated_meshes.is_empty():
			var wall_inst := MeshInstance3D.new()
			wall_inst.name = "ContinuousWalls"
			wall_inst.mesh = geom_res.get_unified_mesh()
			wall_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

			var static_body := StaticBody3D.new()
			static_body.name = "WallStaticBody"
			for g_mesh in geom_res.generated_meshes:
				for i in range(g_mesh.collision_shapes.size()):
					var col_shape := CollisionShape3D.new()
					col_shape.shape = g_mesh.collision_shapes[i]
					col_shape.transform = g_mesh.collision_transforms[i]
					static_body.add_child(col_shape)
			wall_inst.add_child(static_body)

			wall_inst.add_to_group(CAMERA_OCCLUDER_GROUP, true)
			static_body.add_to_group(CAMERA_OCCLUDER_GROUP, true)

			staging_root.add_child(wall_inst)
			if wall_grid_map != null:
				wall_grid_map.visible = false
			result["walls_rendered"] = true

	return result
