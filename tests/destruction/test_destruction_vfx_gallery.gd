extends SceneTree

const _GalleryScript = preload("res://scenes/vfx/showcase/destruction_vfx_gallery.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_vfx_gallery ---")
	print("==================================================================")
	var scn = load("res://scenes/vfx/showcase/destruction_vfx_gallery.tscn") as PackedScene
	assert(scn != null, "FAIL: destruction_vfx_gallery.tscn failed to load")

	var gallery = scn.instantiate() as _GalleryScript
	root.add_child(gallery)
	await process_frame

	gallery.selected_effect_id = "small_dust"
	var spawned = gallery.spawn_selected_effect()
	assert(spawned != null, "FAIL: small_dust must be spawned in gallery")
	assert(spawned.name.begins_with("VFX_SmallDust"), "FAIL: unexpected node name")

	# Test clear
	gallery.clear_all()
	await process_frame
	assert(gallery.get_node("VFXContainer").get_child_count() == 0, "FAIL: clear_all must empty container")

	gallery.free()
	print("[PASS] test_destruction_vfx_gallery passed 100%!")
	print("==================================================================")
	quit(0)
