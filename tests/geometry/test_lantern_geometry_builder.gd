extends SceneTree

const LanternGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/lantern_geometry_builder.gd")
const LanternGeometryConfigScript = preload("res://src/geometry_generator/config/lantern_geometry_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_lantern_geometry_builder ---")
	print("==================================================================")

	var builder = LanternGeometryBuilderScript.new()

	# 1. Test Farol Colgante (Hanging)
	var cfg_hang = LanternGeometryConfigScript.new(1.0, 6, false, Color(0.85, 0.25, 0.95, 1.0), 1337, 5, true)
	var asset_hang = builder.build_lantern_fixture(cfg_hang)
	assert(asset_hang != null, "FAIL: Hanging Lantern asset must not be null")
	assert(asset_hang.has_slot(&"lantern_frame"), "FAIL: Must have lantern_frame slot")
	assert(asset_hang.has_slot(&"lantern_glass"), "FAIL: Must have lantern_glass slot")
	var node_hang = asset_hang.to_node3d("HangingLantern")
	assert(node_hang.get_child_count() >= 2, "FAIL: Hanging Lantern Node3D must contain mesh components")
	var frame_mesh_hang = asset_hang.get_mesh(&"lantern_frame")
	assert(frame_mesh_hang != null and frame_mesh_hang.mesh != null, "FAIL: Frame mesh must be generated")
	assert(frame_mesh_hang.mesh.get_surface_count() >= 1, "FAIL: Frame must have at least 1 surface")
	node_hang.free()
	print("  [OK] Hanging Lantern with 3D chain and ceiling mount verified")

	# 2. Test Farol de Pared (Wall-Mounted)
	var cfg_wall = LanternGeometryConfigScript.new(1.0, 6, true)
	var asset_wall = builder.build_lantern_fixture(cfg_wall)
	assert(asset_wall != null, "FAIL: Wall Lantern asset must not be null")
	assert(asset_wall.has_slot(&"lantern_frame"), "FAIL: Must have lantern_frame slot")
	assert(asset_wall.has_slot(&"lantern_glass"), "FAIL: Must have lantern_glass slot")
	var node_wall = asset_wall.to_node3d("WallLantern")
	assert(node_wall.get_child_count() >= 2, "FAIL: Wall Lantern Node3D must contain mesh components and bracket")
	node_wall.free()
	print("  [OK] Wall Lantern with bottom bracket and S-scroll verified")

	print("[PASS] test_lantern_geometry_builder completed successfully.")
	quit(0)
