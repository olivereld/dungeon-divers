extends SceneTree

const _CatalogScript = preload("res://src/presentation/showcase/mesh_gallery_catalog.gd")
const _RendererScript = preload("res://src/presentation/showcase/mesh_gallery_renderer.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_glb_export ---")
	var catalog := _CatalogScript.new()
	var renderer := _RendererScript.new()

	var entry = catalog.get_entry(&"sarcophagus_stone_closed")
	assert(entry != null, "FAIL: Entry must exist")

	var node: Node3D = renderer.render_entry(entry, 1337)
	assert(node != null, "FAIL: Node must render")

	var gltf_doc := GLTFDocument.new()
	var gltf_state := GLTFState.new()

	var append_err = gltf_doc.append_from_scene(node, gltf_state)
	assert(append_err == OK, "FAIL: append_from_scene failed with error %d" % append_err)

	var export_dir = "user://test_exports"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(export_dir))
	var export_path = ProjectSettings.globalize_path(export_dir.path_join("test_sarcophagus.glb"))

	var write_err = gltf_doc.write_to_filesystem(gltf_state, export_path)
	assert(write_err == OK, "FAIL: write_to_filesystem failed with error %d" % write_err)

	assert(FileAccess.file_exists(export_path), "FAIL: Exported GLB file must exist")
	print("  [OK] Successfully exported GLB to: %s" % export_path)
	print("[PASS] test_glb_export completed successfully!")
	quit(0)
