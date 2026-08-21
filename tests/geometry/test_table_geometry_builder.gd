extends SceneTree

const TableGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/table_geometry_builder.gd")
const TableGeometryConfigScript = preload("res://src/geometry_generator/config/table_geometry_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_table_geometry_builder ---")
	print("==================================================================")

	var builder = TableGeometryBuilderScript.new()

	for style_val in [
		TableGeometryConfigScript.TableStyle.LONG_BANQUET,
		TableGeometryConfigScript.TableStyle.ROUND_TAVERN,
		TableGeometryConfigScript.TableStyle.STOUT_SQUARE
	]:
		var cfg = TableGeometryConfigScript.new(style_val)
		var table_asset = builder.build_table_fixture(cfg)

		assert(table_asset != null, "FAIL: Table asset must not be null")
		assert(table_asset.has_slot(&"table_wood"), "FAIL: Must have table_wood slot")
		assert(table_asset.has_slot(&"table_metal"), "FAIL: Must have table_metal slot")

		var g_wood = table_asset.get_mesh(&"table_wood")
		var g_metal = table_asset.get_mesh(&"table_metal")

		assert(g_wood != null and g_wood.mesh != null, "FAIL: Wood mesh must not be null")
		assert(g_metal != null and g_metal.mesh != null, "FAIL: Metal mesh must not be null")

		var table_node = table_asset.to_node3d("Table")
		assert(table_node.get_child_count() >= 2, "FAIL: Table Node3D must contain mesh components")
		table_node.free()

	print("  [OK] Table styles verified: Long Banquet, Round Tavern, Stout Square")
	print("[PASS] test_table_geometry_builder completed successfully.")
	quit(0)
