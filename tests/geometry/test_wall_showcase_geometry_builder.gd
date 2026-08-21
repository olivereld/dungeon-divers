extends SceneTree

const WallShowcaseGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/wall_showcase_geometry_builder.gd")
const WallShowcaseGeometryConfigScript = preload("res://src/geometry_generator/config/wall_showcase_geometry_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_wall_showcase_geometry_builder ---")
	print("==================================================================")

	var builder = WallShowcaseGeometryBuilderScript.new()

	for var_val in [
		WallShowcaseGeometryConfigScript.WallVariant.BARRED_WINDOW,
		WallShowcaseGeometryConfigScript.WallVariant.CENTER_PILASTER,
		WallShowcaseGeometryConfigScript.WallVariant.FISSURE_BRICKS
	]:
		var cfg = WallShowcaseGeometryConfigScript.new(var_val)
		var wall_asset = builder.build_wall_showcase_fixture(cfg)

		assert(wall_asset != null, "FAIL: Wall asset must not be null")
		assert(wall_asset.has_slot(&"wall_stone"), "FAIL: Must have wall_stone slot")

		var g_stone = wall_asset.get_mesh(&"wall_stone")
		assert(g_stone != null and g_stone.mesh != null, "FAIL: Stone mesh must not be null")

		var wall_node = wall_asset.to_node3d("WallShowcase3x2")
		assert(wall_node.get_child_count() >= 1, "FAIL: Wall Node3D must contain mesh components")
		wall_node.free()

	print("  [OK] Wall showcase variants verified: Barred Window, Center Pilaster, Fissure & Foliage")
	print("[PASS] test_wall_showcase_geometry_builder completed successfully.")
	quit(0)
