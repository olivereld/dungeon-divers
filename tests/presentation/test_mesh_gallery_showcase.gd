extends SceneTree

const ShowcaseScene = preload("res://scenes/showcase/mesh_gallery_showcase.tscn")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_mesh_gallery_showcase ---")
	print("==================================================================")

	var root := Node3D.new()
	root.name = "ShowcaseTestWorld"
	get_root().add_child(root)

	var showcase = ShowcaseScene.instantiate()
	root.add_child(showcase)

	await process_frame

	var categories = showcase._catalog.get_categories()
	assert(categories.size() >= 5, "FAIL: Should have at least 5 categories configured")

	# Probar cambio de categorías y renderizado
	for i in range(categories.size()):
		showcase._select_category(i)
		await process_frame
		assert(showcase.prop_anchor.get_child_count() > 0, "FAIL: Prop should be spawned for category %d" % i)

	# Probar exportación GLB interactiva
	showcase._select_category(0)
	await process_frame
	var export_path = showcase.export_current_model_to_glb()
	assert(export_path != "", "FAIL: Export path must not be empty")
	assert(FileAccess.file_exists(export_path), "FAIL: Exported GLB file must exist on filesystem")
	print("  [OK] Exported GLB from showcase UI successfully to: %s" % export_path)

	root.free()

	print("[PASS] test_mesh_gallery_showcase completed successfully.")
	quit(0)

