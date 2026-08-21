extends SceneTree

const BrazierGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/brazier_geometry_builder.gd")
const BrazierGeometryConfigScript = preload("res://src/geometry_generator/config/brazier_geometry_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_brazier_geometry_builder ---")
	print("==================================================================")

	var builder = BrazierGeometryBuilderScript.new()
	var cfg = BrazierGeometryConfigScript.new()
	var brazier_asset = builder.build_brazier_fixture(cfg)
	assert(brazier_asset != null, "FAIL: Brazier asset must not be null")
	assert(brazier_asset.has_slot(&"stone_pedestal"), "FAIL: Must have stone_pedestal slot")
	assert(brazier_asset.has_slot(&"iron_straps"), "FAIL: Must have iron_straps slot")
	assert(brazier_asset.has_slot(&"glowing_firebed"), "FAIL: Must have glowing_firebed slot")
	assert(brazier_asset.has_slot(&"coal_rocks"), "FAIL: Must have coal_rocks slot")

	var g_stone = brazier_asset.get_mesh(&"stone_pedestal")
	var g_iron = brazier_asset.get_mesh(&"iron_straps")
	var g_fire = brazier_asset.get_mesh(&"glowing_firebed")
	var g_coals = brazier_asset.get_mesh(&"coal_rocks")

	assert(g_stone != null and g_stone.mesh != null, "FAIL: Stone mesh must not be null")
	assert(g_iron != null and g_iron.mesh != null, "FAIL: Iron mesh must not be null")
	assert(g_fire != null and g_fire.mesh != null, "FAIL: Fire mesh must not be null")
	assert(g_coals != null and g_coals.mesh != null, "FAIL: Coals mesh must not be null")

	var brazier_node = brazier_asset.to_node3d("Brazier")
	assert(brazier_node.get_child_count() >= 4, "FAIL: Brazier Node3D must contain mesh components and collision bodies")
	brazier_node.free()

	print("  [OK] Brazier slots verified: stone_pedestal, iron_straps, glowing_firebed, coal_rocks")
	print("[PASS] test_brazier_geometry_builder completed successfully.")
	quit(0)
