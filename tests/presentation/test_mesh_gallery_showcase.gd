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

	root.free()

	print("[PASS] test_mesh_gallery_showcase completed successfully.")
	quit(0)
