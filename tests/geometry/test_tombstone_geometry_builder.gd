extends SceneTree

const TombstoneGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/tombstone_geometry_builder.gd")
const TombstoneGeometryConfigScript = preload("res://src/geometry_generator/config/tombstone_geometry_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_tombstone_geometry_builder ---")
	print("==================================================================")

	var builder = TombstoneGeometryBuilderScript.new()

	for style_val in [
		TombstoneGeometryConfigScript.TombstoneStyle.CLASSIC_ARCH,
		TombstoneGeometryConfigScript.TombstoneStyle.CELTIC_CROSS,
		TombstoneGeometryConfigScript.TombstoneStyle.BROKEN_SLAB
	]:
		var cfg = TombstoneGeometryConfigScript.new(style_val)
		var tomb_asset = builder.build_tombstone_fixture(cfg)

		assert(tomb_asset != null, "FAIL: Tombstone asset must not be null")
		assert(tomb_asset.has_slot(&"tombstone_stone"), "FAIL: Must have tombstone_stone slot")
		assert(tomb_asset.has_slot(&"tombstone_trim"), "FAIL: Must have tombstone_trim slot")

		var g_stone = tomb_asset.get_mesh(&"tombstone_stone")
		var g_trim = tomb_asset.get_mesh(&"tombstone_trim")

		assert(g_stone != null and g_stone.mesh != null, "FAIL: Stone mesh must not be null")
		assert(g_trim != null and g_trim.mesh != null, "FAIL: Trim mesh must not be null")

		var tomb_node = tomb_asset.to_node3d("Tombstone")
		assert(tomb_node.get_child_count() >= 2, "FAIL: Tombstone Node3D must contain mesh components")
		tomb_node.free()

	print("  [OK] Tombstone styles verified: Classic Arch, Celtic Cross, Broken Slab")
	print("[PASS] test_tombstone_geometry_builder completed successfully.")
	quit(0)
