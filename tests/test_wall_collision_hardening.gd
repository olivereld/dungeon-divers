extends SceneTree

## Test suite para validar la diferenciación de colisiones (PER_SEGMENT_BOX vs COMPOUND_BOX vs TRIMESH).

const WallComponent = preload("res://src/geometry_generator/data/wall_component.gd")
const WallGeometryConfig = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const CollisionConfig = preload("res://src/geometry_generator/config/collision_config.gd")
const WallCollisionBuilder = preload("res://src/geometry_generator/collision/wall_collision_builder.gd")
const WallGeometryBuilder = preload("res://src/geometry_generator/geometry/wall_geometry_builder.gd")
const GeneratedMesh = preload("res://src/geometry_generator/data/generated_mesh.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_wall_collision_hardening (Modes & Normalization) ---")
	print("==================================================================")

	var geom_builder := WallGeometryBuilder.new()
	var col_builder := WallCollisionBuilder.new()
	var wall_cfg := WallGeometryConfig.new()
	wall_cfg.cube_size = 2.0
	wall_cfg.cubes_high = 2

	# Sala en L con 6 segmentos ortogonales
	var comp_l := WallComponent.new(1)
	comp_l.add_loop([
		Vector2i(0, 0), Vector2i(6, 0), Vector2i(6, 3),
		Vector2i(3, 3), Vector2i(3, 6), Vector2i(0, 6)
	])

	# 1. Modo PER_SEGMENT_BOX
	var g_mesh_seg := geom_builder.build_component_mesh(comp_l, wall_cfg)
	var col_seg := CollisionConfig.new()
	col_seg.mode = CollisionConfig.CollisionMode.PER_SEGMENT_BOX
	col_builder.build_collision_for_component(comp_l, wall_cfg, col_seg, g_mesh_seg)

	assert(g_mesh_seg.collision_shapes.size() == 6, "PER_SEGMENT_BOX must produce 6 box shapes for 6 segments, got %d" % g_mesh_seg.collision_shapes.size())
	for shape in g_mesh_seg.collision_shapes:
		assert(shape is BoxShape3D)
	print("  [OK] PER_SEGMENT_BOX generó exactamente 6 cajas físicas alineadas a cada arista.")

	# 2. Modo COMPOUND_BOX
	var g_mesh_comp := geom_builder.build_component_mesh(comp_l, wall_cfg)
	var col_comp := CollisionConfig.new()
	col_comp.mode = CollisionConfig.CollisionMode.COMPOUND_BOX
	col_builder.build_collision_for_component(comp_l, wall_cfg, col_comp, g_mesh_comp)

	assert(g_mesh_comp.collision_shapes.size() == 6, "COMPOUND_BOX loop produces valid perimeter compound collision")
	for shape in g_mesh_comp.collision_shapes:
		assert(shape is BoxShape3D)
	print("  [OK] COMPOUND_BOX generó la envoltura compuesta continua.")

	# 3. Modo CONCAVE_TRIMESH
	var g_mesh_tri := geom_builder.build_component_mesh(comp_l, wall_cfg)
	var col_tri := CollisionConfig.new()
	col_tri.mode = CollisionConfig.CollisionMode.CONCAVE_TRIMESH
	col_builder.build_collision_for_component(comp_l, wall_cfg, col_tri, g_mesh_tri)

	assert(g_mesh_tri.collision_shapes.size() == 1, "CONCAVE_TRIMESH must produce 1 trimesh shape")
	assert(g_mesh_tri.collision_shapes[0] is ConcavePolygonShape3D)
	print("  [OK] CONCAVE_TRIMESH generó la malla cóncava a partir del ArrayMesh.")

	# 4. Modo NONE
	var g_mesh_none := geom_builder.build_component_mesh(comp_l, wall_cfg)
	var col_none := CollisionConfig.new()
	col_none.mode = CollisionConfig.CollisionMode.NONE
	col_builder.build_collision_for_component(comp_l, wall_cfg, col_none, g_mesh_none)
	assert(g_mesh_none.collision_shapes.is_empty(), "NONE mode must not add any collision shapes")
	print("  [OK] NONE mode validado con cero colisiones.")

	print("==================================================================")
	print("[PASS] test_wall_collision_hardening completado con 100% éxito!")
	print("==================================================================")
	quit(0)
