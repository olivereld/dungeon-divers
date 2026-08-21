extends SceneTree

const RubbleGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/rubble_geometry_builder.gd")
const RubbleGeometryConfigScript = preload("res://src/geometry_generator/config/rubble_geometry_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_rubble_geometry_builder ---")
	print("==================================================================")

	var builder = RubbleGeometryBuilderScript.new()
	var cfg = RubbleGeometryConfigScript.new(RubbleGeometryConfigScript.RubbleSize.MEDIUM)
	var rubble_asset = builder.build_rubble_fixture(cfg)

	assert(rubble_asset != null, "FAIL: Rubble asset must not be null")
	assert(rubble_asset.has_slot(&"rubble_gravel"), "FAIL: Must have rubble_gravel slot")
	assert(rubble_asset.has_slot(&"rubble_stone_primary"), "FAIL: Must have rubble_stone_primary slot")
	assert(rubble_asset.has_slot(&"rubble_stone_secondary"), "FAIL: Must have rubble_stone_secondary slot")
	assert(rubble_asset.has_slot(&"rubble_pebbles"), "FAIL: Must have rubble_pebbles slot")

	var g_gravel = rubble_asset.get_mesh(&"rubble_gravel")
	var g_pri = rubble_asset.get_mesh(&"rubble_stone_primary")
	var g_sec = rubble_asset.get_mesh(&"rubble_stone_secondary")
	var g_peb = rubble_asset.get_mesh(&"rubble_pebbles")

	assert(g_gravel != null and g_gravel.mesh != null, "FAIL: Gravel mesh must not be null")
	assert(g_pri != null and g_pri.mesh != null, "FAIL: Primary stone mesh must not be null")
	assert(g_sec != null and g_sec.mesh != null, "FAIL: Secondary stone mesh must not be null")
	assert(g_peb != null and g_peb.mesh != null, "FAIL: Pebbles mesh must not be null")

	var rubble_node = rubble_asset.to_node3d("DungeonRubble")
	assert(rubble_node.get_child_count() >= 4, "FAIL: Rubble Node3D must contain mesh components")
	rubble_node.free()

	print("  [OK] Rubble slots verified: rubble_gravel, rubble_stone_primary, rubble_stone_secondary, rubble_pebbles")
	print("[PASS] test_rubble_geometry_builder completed successfully.")
	quit(0)
