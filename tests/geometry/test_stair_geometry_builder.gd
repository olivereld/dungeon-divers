extends SceneTree

const StairGeometryBuilderScript = preload("res://src/geometry_generator/geometry/stair_geometry_builder.gd")
const StairGeometryConfigScript = preload("res://src/geometry_generator/config/stair_geometry_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_stair_geometry_builder ---")
	print("==================================================================")

	var builder = StairGeometryBuilderScript.new()

	# 1. Escalera Ascendente (UP)
	var cfg_up = StairGeometryConfigScript.new()
	cfg_up.tile_size = 2.0
	cfg_up.stair_rise = 1.8
	cfg_up.num_steps = 8
	cfg_up.is_downward = false

	var g_up = builder.build_stair_mesh(cfg_up)
	assert(g_up != null and g_up.mesh != null, "FAIL: Upward stair mesh must not be null")
	assert(g_up.mesh.get_surface_count() >= 2, "FAIL: Stair must have StairSteps and StairStringers surfaces")
	assert(g_up.collision_shapes.size() == 8, "FAIL: Upward stair must generate 8 step collision boxes")

	# 2. Escalera Descendente (DOWN)
	var cfg_down = StairGeometryConfigScript.new()
	cfg_down.tile_size = 2.0
	cfg_down.stair_rise = 1.8
	cfg_down.num_steps = 8
	cfg_down.is_downward = true

	var g_down = builder.build_stair_mesh(cfg_down)
	assert(g_down != null and g_down.mesh != null, "FAIL: Downward stair mesh must not be null")
	assert(g_down.mesh.get_surface_count() >= 2, "FAIL: Downward stair must have StairSteps and StairStringers")
	assert(g_down.collision_shapes.size() == 8, "FAIL: Downward stair must generate 8 step collision boxes")

	print("  [OK] Stair UP Surfaces: %d | Collision Steps: %d" % [
		g_up.mesh.get_surface_count(),
		g_up.collision_shapes.size()
	])
	print("  [OK] Stair DOWN Surfaces: %d | Collision Steps: %d" % [
		g_down.mesh.get_surface_count(),
		g_down.collision_shapes.size()
	])

	print("[PASS] test_stair_geometry_builder completed successfully.")
	quit(0)
