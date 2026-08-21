extends SceneTree

const BarrelGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/barrel_geometry_builder.gd")
const BarrelGeometryConfigScript = preload("res://src/geometry_generator/config/barrel_geometry_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_barrel_geometry_builder ---")
	print("==================================================================")

	var builder = BarrelGeometryBuilderScript.new()
	var cfg = BarrelGeometryConfigScript.new()
	var barrel_asset = builder.build_barrel_fixture(cfg)

	assert(barrel_asset != null, "FAIL: Barrel asset must not be null")
	assert(barrel_asset.has_slot(&"barrel_wood"), "FAIL: Must have barrel_wood slot")
	assert(barrel_asset.has_slot(&"barrel_iron"), "FAIL: Must have barrel_iron slot")

	var g_wood = barrel_asset.get_mesh(&"barrel_wood")
	var g_iron = barrel_asset.get_mesh(&"barrel_iron")

	assert(g_wood != null and g_wood.mesh != null, "FAIL: Wood mesh must not be null")
	assert(g_iron != null and g_iron.mesh != null, "FAIL: Iron mesh must not be null")

	var barrel_node = barrel_asset.to_node3d("WoodenBarrel")
	assert(barrel_node.get_child_count() >= 2, "FAIL: WoodenBarrel Node3D must contain mesh components")
	barrel_node.free()

	print("  [OK] Wooden Barrel slots verified: barrel_wood, barrel_iron")
	print("[PASS] test_barrel_geometry_builder completed successfully.")
	quit(0)
