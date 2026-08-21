extends SceneTree

const BookshelfGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/bookshelf_geometry_builder.gd")
const BookshelfGeometryConfigScript = preload("res://src/geometry_generator/config/bookshelf_geometry_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_bookshelf_geometry_builder ---")
	print("==================================================================")

	var builder = BookshelfGeometryBuilderScript.new()

	for style_val in [
		BookshelfGeometryConfigScript.BookshelfStyle.STANDARD_EMPTY,
		BookshelfGeometryConfigScript.BookshelfStyle.STANDARD_FILLED,
		BookshelfGeometryConfigScript.BookshelfStyle.GOTHIC_ARCHED
	]:
		var cfg = BookshelfGeometryConfigScript.new(style_val)
		var shelf_asset = builder.build_bookshelf_fixture(cfg)

		assert(shelf_asset != null, "FAIL: Bookshelf asset must not be null")
		assert(shelf_asset.has_slot(&"bookshelf_wood"), "FAIL: Must have bookshelf_wood slot")

		var g_wood = shelf_asset.get_mesh(&"bookshelf_wood")
		assert(g_wood != null and g_wood.mesh != null, "FAIL: Wood mesh must not be null")

		var shelf_node = shelf_asset.to_node3d("Bookshelf")
		assert(shelf_node.get_child_count() >= 1, "FAIL: Bookshelf Node3D must contain mesh components")
		shelf_node.free()

	print("  [OK] Bookshelf styles verified: Empty, Filled with Books, Gothic Arched")
	print("[PASS] test_bookshelf_geometry_builder completed successfully.")
	quit(0)
