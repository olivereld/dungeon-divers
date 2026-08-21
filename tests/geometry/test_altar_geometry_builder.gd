extends SceneTree

const AltarGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/altar_geometry_builder.gd")
const AltarGeometryConfigScript = preload("res://src/geometry_generator/config/altar_geometry_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_altar_geometry_builder ---")
	print("==================================================================")

	var builder = AltarGeometryBuilderScript.new()
	var cfg = AltarGeometryConfigScript.new(AltarGeometryConfigScript.AltarSize.STANDARD)
	var altar_asset = builder.build_altar_fixture(cfg)

	assert(altar_asset != null, "FAIL: Altar asset must not be null")
	assert(altar_asset.has_slot(&"altar_stone_body"), "FAIL: Must have altar_stone_body slot")
	assert(altar_asset.has_slot(&"altar_stone_trim"), "FAIL: Must have altar_stone_trim slot")

	var g_body = altar_asset.get_mesh(&"altar_stone_body")
	var g_trim = altar_asset.get_mesh(&"altar_stone_trim")

	assert(g_body != null and g_body.mesh != null, "FAIL: Body mesh must not be null")
	assert(g_trim != null and g_trim.mesh != null, "FAIL: Trim mesh must not be null")

	var altar_node = altar_asset.to_node3d("StoneAltar")
	assert(altar_node.get_child_count() >= 2, "FAIL: Altar Node3D must contain mesh components")
	altar_node.free()

	print("  [OK] Stone Altar slots verified: altar_stone_body, altar_stone_trim")
	print("[PASS] test_altar_geometry_builder completed successfully.")
	quit(0)
