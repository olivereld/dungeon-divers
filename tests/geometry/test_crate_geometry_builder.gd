extends SceneTree

const CrateGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/crate_geometry_builder.gd")
const CrateGeometryConfigScript = preload("res://src/geometry_generator/config/crate_geometry_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_crate_geometry_builder ---")
	print("==================================================================")

	var builder = CrateGeometryBuilderScript.new()
	var cfg = CrateGeometryConfigScript.new()
	var crate_asset = builder.build_crate_fixture(cfg)

	assert(crate_asset != null, "FAIL: Crate asset must not be null")
	assert(crate_asset.has_slot(&"crate_panels"), "FAIL: Must have crate_panels slot")
	assert(crate_asset.has_slot(&"crate_frame"), "FAIL: Must have crate_frame slot")
	assert(crate_asset.has_slot(&"crate_iron"), "FAIL: Must have crate_iron slot")

	var g_panels = crate_asset.get_mesh(&"crate_panels")
	var g_frame = crate_asset.get_mesh(&"crate_frame")
	var g_iron = crate_asset.get_mesh(&"crate_iron")

	assert(g_panels != null and g_panels.mesh != null, "FAIL: Panels mesh must not be null")
	assert(g_frame != null and g_frame.mesh != null, "FAIL: Frame mesh must not be null")
	assert(g_iron != null and g_iron.mesh != null, "FAIL: Iron mesh must not be null")

	var crate_node = crate_asset.to_node3d("WoodenCrate")
	assert(crate_node.get_child_count() >= 3, "FAIL: WoodenCrate Node3D must contain mesh components")
	crate_node.free()

	print("  [OK] Wooden Crate 3 slots verified: crate_panels (dark wood), crate_frame (light wood), crate_iron (iron corners)")
	print("[PASS] test_crate_geometry_builder completed successfully.")
	quit(0)
