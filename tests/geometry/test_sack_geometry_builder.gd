extends SceneTree

const SackGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/sack_geometry_builder.gd")
const SackGeometryConfigScript = preload("res://src/geometry_generator/config/sack_geometry_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_sack_geometry_builder ---")
	print("==================================================================")

	var builder = SackGeometryBuilderScript.new()
	var cfg = SackGeometryConfigScript.new()
	var sack_asset = builder.build_sack_fixture(cfg)

	assert(sack_asset != null, "FAIL: Sack asset must not be null")
	assert(sack_asset.has_slot(&"sack_fabric"), "FAIL: Must have sack_fabric slot")
	assert(sack_asset.has_slot(&"sack_rope"), "FAIL: Must have sack_rope slot")

	var g_fab = sack_asset.get_mesh(&"sack_fabric")
	var g_rope = sack_asset.get_mesh(&"sack_rope")

	assert(g_fab != null and g_fab.mesh != null, "FAIL: Fabric mesh must not be null")
	assert(g_rope != null and g_rope.mesh != null, "FAIL: Rope mesh must not be null")

	var sack_node = sack_asset.to_node3d("BurlapSack")
	assert(sack_node.get_child_count() >= 2, "FAIL: BurlapSack Node3D must contain mesh components")
	sack_node.free()

	print("  [OK] Burlap Sack slots verified: sack_fabric, sack_rope")
	print("[PASS] test_sack_geometry_builder completed successfully.")
	quit(0)
