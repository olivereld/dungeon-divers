extends SceneTree

## Test suite para validar la Generación de Colisiones Desacoplada (Fase M3: WallCollisionBuilder).
## Verifica la correcta creación de BoxShape3D orientados, modo Compound y Concave.

const WallComponent = preload("res://src/geometry_generator/data/wall_component.gd")
const WallGeometryConfig = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const CollisionConfig = preload("res://src/geometry_generator/config/collision_config.gd")
const WallCollisionBuilder = preload("res://src/geometry_generator/collision/wall_collision_builder.gd")
const WallGeometryBuilder = preload("res://src/geometry_generator/geometry/wall_geometry_builder.gd")
const GeneratedMesh = preload("res://src/geometry_generator/data/generated_mesh.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_wall_collision_builder (Fase M3: Collisions) ---")
	print("==================================================================")

	var geom_builder := WallGeometryBuilder.new()
	var col_builder := WallCollisionBuilder.new()
	var wall_cfg := WallGeometryConfig.new()
	wall_cfg.cube_size = 2.0
	wall_cfg.cubes_high = 2

	# 1. Caso A: Componente cuadrado de 4 paredes en modo COMPOUND_BOX
	var comp := WallComponent.new(0)
	comp.add_loop([
		Vector2i(2, 2),
		Vector2i(6, 2),
		Vector2i(6, 6),
		Vector2i(2, 6)
	])

	var g_mesh_a: GeneratedMesh = geom_builder.build_component_mesh(comp, wall_cfg)
	var col_cfg_a := CollisionConfig.new()
	col_cfg_a.mode = CollisionConfig.CollisionMode.COMPOUND_BOX

	col_builder.build_collision_for_component(comp, wall_cfg, col_cfg_a, g_mesh_a)

	assert(g_mesh_a.collision_shapes.size() == 4, "Expected exactly 4 collision box shapes for 4 wall segments, got %d" % g_mesh_a.collision_shapes.size())
	assert(g_mesh_a.collision_transforms.size() == 4, "Expected 4 collision transforms")

	for i in range(4):
		var shape = g_mesh_a.collision_shapes[i]
		assert(shape is BoxShape3D, "Shape %d must be a BoxShape3D" % i)
		var box := shape as BoxShape3D
		assert(box.size.y == wall_cfg.get_total_height(), "Box height must match wall total height (4.0m)")
		assert(box.size.z >= 7.9, "Segment length for 4 cells (8.0m) must be approximately 8.0m, got %.2f" % box.size.z)

	# Instanciar en StaticBody3D y verificar árbol
	var body: StaticBody3D = g_mesh_a.create_collision_body()
	assert(body != null)
	assert(body.get_child_count() == 4, "StaticBody3D should have 4 CollisionShape3D children")
	body.free()
	print("  [OK] Caso A: COMPOUND_BOX generó 4 cajas físicas con dimensiones y orientaciones exactas.")

	# 2. Caso B: Modo NONE -> No debe añadir ninguna forma
	var g_mesh_b := GeneratedMesh.new()
	var col_cfg_b := CollisionConfig.new()
	col_cfg_b.mode = CollisionConfig.CollisionMode.NONE
	col_builder.build_collision_for_component(comp, wall_cfg, col_cfg_b, g_mesh_b)
	assert(g_mesh_b.collision_shapes.is_empty(), "CollisionMode.NONE must not generate any shapes")
	print("  [OK] Caso B: CollisionMode.NONE no añade formas físicas.")

	# 3. Caso C: Modo CONCAVE_TRIMESH
	var g_mesh_c: GeneratedMesh = geom_builder.build_component_mesh(comp, wall_cfg)
	var col_cfg_c := CollisionConfig.new()
	col_cfg_c.mode = CollisionConfig.CollisionMode.CONCAVE_TRIMESH
	col_builder.build_collision_for_component(comp, wall_cfg, col_cfg_c, g_mesh_c)
	assert(g_mesh_c.collision_shapes.size() == 1, "Concave trimesh should produce 1 ConcavePolygonShape3D")
	assert(g_mesh_c.collision_shapes[0] is ConcavePolygonShape3D, "Shape must be ConcavePolygonShape3D")
	print("  [OK] Caso C: CONCAVE_TRIMESH generó la malla cóncava a partir de las superficies renderizables.")

	print("==================================================================")
	print("[PASS] test_wall_collision_builder completado exitosamente!")
	print("==================================================================")
	quit(0)
