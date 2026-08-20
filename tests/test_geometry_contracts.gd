extends SceneTree

## Test suite para validar los contratos de datos y configuraciones de src/geometry_generator (Fase M0).

const GeneratedMesh = preload("res://src/geometry_generator/data/generated_mesh.gd")
const WallBoundaryGraph = preload("res://src/geometry_generator/data/wall_boundary_graph.gd")
const WallComponent = preload("res://src/geometry_generator/data/wall_component.gd")
const GeometryRequest = preload("res://src/geometry_generator/data/geometry_request.gd")
const GeometryResult = preload("res://src/geometry_generator/data/geometry_result.gd")
const WallGeometryConfig = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const CollisionConfig = preload("res://src/geometry_generator/config/collision_config.gd")
const DecorationConfig = preload("res://src/geometry_generator/config/decoration_config.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_geometry_contracts (Fase M0: Data & Configs) ---")
	print("==================================================================")

	# 1. Validar GeneratedMesh
	var g_mesh := GeneratedMesh.new()
	assert(g_mesh.mesh == null, "Initial mesh must be null")
	assert(g_mesh.collision_shapes.is_empty(), "Initial collision shapes must be empty")
	assert(g_mesh.component_id == 0, "Default component_id is 0")
	var box := BoxShape3D.new()
	g_mesh.add_collision_shape(box, Transform3D.IDENTITY)
	assert(g_mesh.collision_shapes.size() == 1, "add_collision_shape should register shape")
	print("  [OK] GeneratedMesh contract validated.")

	# 2. Validar WallBoundaryGraph
	var graph := WallBoundaryGraph.new()
	assert(graph.get_edge_count() == 0, "Initial graph should have 0 edges")
	graph.add_directed_edge(Vector2i(0, 0), Vector2i(1, 0), {"side": "north"})
	graph.add_directed_edge(Vector2i(1, 0), Vector2i(1, 1))
	assert(graph.get_edge_count() == 2, "Graph must have 2 edges")
	assert(graph.has_edge(Vector2i(0, 0), Vector2i(1, 0)) == true, "Must contain edge (0,0)->(1,0)")
	assert(graph.has_edge(Vector2i(1, 0), Vector2i(0, 0)) == false, "Directed graph should not have reverse edge unless added")
	var out_nbrs = graph.get_outgoing_neighbors(Vector2i(0, 0))
	assert(out_nbrs.size() == 1 and out_nbrs[0] == Vector2i(1, 0), "Outgoing neighbors correct")
	print("  [OK] WallBoundaryGraph contract validated.")

	# 3. Validar WallComponent
	var comp := WallComponent.new(42)
	assert(comp.id == 42, "Component ID should match constructor argument")
	assert(comp.is_empty() == true, "New component is empty")
	comp.add_loop([Vector2i(0, 0), Vector2i(4, 0), Vector2i(4, 4), Vector2i(0, 4)])
	assert(comp.is_empty() == false, "Component is not empty after loop added")
	assert(comp.loops.size() == 1, "Should have 1 loop")
	assert(comp.bounds.size.x >= 4 and comp.bounds.size.y >= 4, "Bounds expanded correctly")
	print("  [OK] WallComponent contract validated.")

	# 4. Validar DTOs y Configs
	var req := GeometryRequest.new()
	assert(req.type == GeometryRequest.GeometryType.WALL)

	var res := GeometryResult.new()
	assert(res.success == true)
	assert(not res.has_errors())
	res.add_diagnostic("TEST_WARN", "INFO", "Informational note")
	assert(res.success == true)

	var wall_cfg := WallGeometryConfig.new()
	assert(wall_cfg.cube_size == 2.0)
	assert(wall_cfg.get_total_height() == 4.0)
	assert(wall_cfg.get_wall_panel_height() > 0.0)

	var col_cfg := CollisionConfig.new()
	assert(col_cfg.mode == CollisionConfig.CollisionMode.COMPOUND_BOX)

	var dec_cfg := DecorationConfig.new()
	assert(dec_cfg.style == DecorationConfig.DecorationStyle.STYLIZED_CLUSTERS)

	print("  [OK] GeometryRequest, GeometryResult, and Config resources validated.")
	print("==================================================================")
	print("[PASS] test_geometry_contracts completed successfully!")
	print("==================================================================")
	quit(0)
