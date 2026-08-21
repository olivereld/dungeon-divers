extends SceneTree

const CatalogScript = preload("res://src/presentation/showcase/mesh_gallery_catalog.gd")
const EntryScript = preload("res://src/presentation/showcase/mesh_gallery_entry.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_mesh_gallery_catalog ---")
	print("==================================================================")

	var catalog = CatalogScript.new()
	assert(catalog != null, "FAIL: Catalog should instantiate")

	var categories = catalog.get_categories()
	assert(categories.size() >= 5, "FAIL: Catalog should have at least 5 categories (walls, floors, doors, stairs, lighting)")
	print("[OK] Registered categories count: %d" % categories.size())

	var total_entries = catalog.get_total_entry_count()
	assert(total_entries >= 10, "FAIL: Catalog should have at least 10 entries registered")
	print("[OK] Total registered entries: %d" % total_entries)

	for cat in categories:
		assert(not str(cat.id).is_empty(), "FAIL: Category ID must not be empty")
		assert(not str(cat.name).is_empty(), "FAIL: Category Name must not be empty")
		var entries = catalog.get_entries_for_category(cat.id)
		assert(entries.size() > 0, "FAIL: Category '%s' must have at least one entry" % cat.name)

		for entry in entries:
			assert(entry is EntryScript, "FAIL: Entry must be of type MeshGalleryEntry")
			assert(entry.is_valid(), "FAIL: Entry '%s' must be valid" % entry.id)
			assert(not entry.name.is_empty(), "FAIL: Entry '%s' must have a name" % entry.id)
			assert(not entry.script_path.is_empty(), "FAIL: Entry '%s' must have a script path" % entry.id)

	# Probar recuperación por ID único
	var wall_entry = catalog.get_entry(&"wall_continuous_straight")
	assert(wall_entry != null, "FAIL: wall_continuous_straight should be retrievable by ID")
	assert(wall_entry.generator_id == &"wall_continuous", "FAIL: Generator ID must match")

	print("[PASS] test_mesh_gallery_catalog completed successfully.")
	quit(0)
