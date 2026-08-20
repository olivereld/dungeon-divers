extends SceneTree

## Test suite para validar la Integración Completa de src/geometry_generator (Fase M5).
## Verifica generación de clusters en mazmorras procedurales reales y retrocompatibilidad del adaptador.

const DungeonPipeline = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const DungeonConfig = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonGeometryGenerator = preload("res://src/geometry_generator/facade/dungeon_geometry_generator.gd")
const ContinuousWallMeshBuilder = preload("res://src/wall_mesh_generator/core/continuous_wall_mesh_builder.gd")
const WallMeshConfig = preload("res://src/wall_mesh_generator/config/wall_mesh_config.gd")
const GeometryResult = preload("res://src/geometry_generator/data/geometry_result.gd")
const CollisionConfig = preload("res://src/geometry_generator/config/collision_config.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_geometry_generator_integration (Fase M5) ---")
	print("==================================================================")

	var pipeline := DungeonPipeline.new()
	var generator := DungeonGeometryGenerator.new()
	var legacy_adapter := ContinuousWallMeshBuilder.new()

	var config := DungeonConfig.new()
	config.seed = 450000
	config.use_fixed_seed = true
	config.mission_depth = 5

	var d_res: DungeonResult = pipeline.generate(config)
	assert(d_res != null and d_res.grid != null, "Pipeline generation must succeed")

	# 1. Caso A: Generar clusters con DungeonGeometryGenerator
	var col_cfg := CollisionConfig.new()
	col_cfg.mode = CollisionConfig.CollisionMode.COMPOUND_BOX

	var result: GeometryResult = generator.generate_wall_clusters(
		d_res.grid,
		null,
		null,
		col_cfg,
		null,
		0
	)

	assert(result != null, "GeometryResult must not be null")
	assert(result.success == true, "Generation must succeed")
	assert(result.generated_meshes.size() > 0, "Must generate at least 1 wall cluster, got %d" % result.generated_meshes.size())

	for i in range(result.generated_meshes.size()):
		var g_mesh = result.generated_meshes[i]
		assert(g_mesh.mesh != null, "Cluster %d mesh must not be null" % i)
		assert(g_mesh.mesh.get_surface_count() >= 2, "Cluster %d must have at least Trims and WallPanel" % i)
		assert(not g_mesh.collision_shapes.is_empty(), "Cluster %d must have collision shapes" % i)

	print("  [OK] Caso A: DungeonGeometryGenerator generó %d clusters independientes con colisión y mallas válidas." % result.generated_meshes.size())

	# 2. Caso B: Generar y enlazar nodos 3D en árbol de escena
	var parent_node := Node3D.new()
	root.add_child(parent_node)

	var wall_nodes: Array[MeshInstance3D] = generator.generate_and_attach_wall_nodes(
		d_res.grid,
		parent_node,
		null,
		null,
		col_cfg,
		null,
		0
	)

	assert(wall_nodes.size() == result.generated_meshes.size(), "Node count should match cluster count")
	assert(parent_node.get_child_count() == wall_nodes.size(), "Parent node must have all cluster children")

	for node in wall_nodes:
		assert(node is MeshInstance3D)
		assert(node.mesh != null)
		assert(node.get_child_count() == 1, "Each cluster MeshInstance3D should have 1 StaticBody3D child")
		var body = node.get_child(0)
		assert(body is StaticBody3D)
		assert(body.get_child_count() > 0, "StaticBody3D must contain CollisionShape3D children")

	parent_node.free()
	print("  [OK] Caso B: generate_and_attach_wall_nodes instanció correctamente la jerarquía 3D con colisión.")

	# 3. Caso C: Retrocompatibilidad del adaptador ContinuousWallMeshBuilder
	var wall_mesh_cfg := WallMeshConfig.new()
	wall_mesh_cfg.cube_size = config.cell_size
	wall_mesh_cfg.cubes_high = config.wall_height
	wall_mesh_cfg.seed = config.seed

	var unified_mesh: ArrayMesh = legacy_adapter.build_dungeon_wall_mesh(d_res.grid, wall_mesh_cfg, 0, null)
	assert(unified_mesh != null, "Legacy adapter must return an ArrayMesh")
	assert(unified_mesh.get_surface_count() >= 2, "Unified mesh must have at least Trims and WallPanel surfaces")

	print("  [OK] Caso C: Adaptador ContinuousWallMeshBuilder unificó mallas correctamente para PresentationBuilder.")

	print("==================================================================")
	print("[PASS] test_geometry_generator_integration completado con éxito!")
	print("==================================================================")
	quit(0)
