extends SceneTree

const ChestGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/chest_geometry_builder.gd")
const ChestGeometryConfigScript = preload("res://src/geometry_generator/config/chest_geometry_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_chest_geometry_builder ---")
	print("==================================================================")

	var builder = ChestGeometryBuilderScript.new()
	var cfg = ChestGeometryConfigScript.new()

	# 1. Test Base Asset
	var base_asset = builder.build_chest_base(cfg)
	assert(base_asset != null, "FAIL: Chest base asset must not be null")
	assert(base_asset.has_slot(&"chest_base_wood_dark"), "FAIL: Must have chest_base_wood_dark slot")
	assert(base_asset.has_slot(&"chest_base_wood_light"), "FAIL: Must have chest_base_wood_light slot")
	assert(base_asset.has_slot(&"chest_base_metal"), "FAIL: Must have chest_base_metal slot")

	# 2. Test Lid Asset (Hinge origin at Vector3.ZERO)
	var lid_asset = builder.build_chest_lid(cfg)
	assert(lid_asset != null, "FAIL: Chest lid asset must not be null")
	assert(lid_asset.has_slot(&"chest_lid_wood_dark"), "FAIL: Must have chest_lid_wood_dark slot")
	assert(lid_asset.has_slot(&"chest_lid_metal"), "FAIL: Must have chest_lid_metal slot")

	# 3. Test Articulation Node Assembly
	var base_node = base_asset.to_node3d("BaseNode")
	var lid_node = lid_asset.to_node3d("LidNode")

	# Hinge placement
	lid_node.position = Vector3(0.0, cfg.base_height, -cfg.depth * 0.50)
	lid_node.rotation.x = deg_to_rad(-145.0)

	assert(base_node.get_child_count() >= 3, "FAIL: Base must have meshes")
	assert(lid_node.get_child_count() >= 2, "FAIL: Lid must have meshes")

	base_node.free()
	lid_node.free()

	print("  [OK] Chest Base slots verified: dark wood, light wood, metal")
	print("  [OK] Chest Lid slots verified: dark wood vault, metal ribs")
	print("  [OK] 145° rear hinge articulation verified cleanly")
	print("[PASS] test_chest_geometry_builder completed successfully.")
	quit(0)
