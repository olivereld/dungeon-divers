extends SceneTree

const ChairGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/chair_geometry_builder.gd")
const ChairGeometryConfigScript = preload("res://src/geometry_generator/config/chair_geometry_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_chair_geometry_builder ---")
	print("==================================================================")

	var builder = ChairGeometryBuilderScript.new()

	for style_val in [
		ChairGeometryConfigScript.ChairStyle.TAVERN_STOOL,
		ChairGeometryConfigScript.ChairStyle.GOTHIC_HIGHBACK,
		ChairGeometryConfigScript.ChairStyle.TAVERN_ARMCHAIR
	]:
		var cfg = ChairGeometryConfigScript.new(style_val)
		var chair_asset = builder.build_chair_fixture(cfg)

		assert(chair_asset != null, "FAIL: Chair asset must not be null")
		assert(chair_asset.has_slot(&"chair_wood"), "FAIL: Must have chair_wood slot")

		var g_wood = chair_asset.get_mesh(&"chair_wood")
		assert(g_wood != null and g_wood.mesh != null, "FAIL: Wood mesh must not be null")

		var chair_node = chair_asset.to_node3d("Chair")
		assert(chair_node.get_child_count() >= 1, "FAIL: Chair Node3D must contain mesh components")
		chair_node.free()

	print("  [OK] Chair styles verified: Tavern Stool, Gothic High-Back, Tavern Armchair")
	print("[PASS] test_chair_geometry_builder completed successfully.")
	quit(0)
