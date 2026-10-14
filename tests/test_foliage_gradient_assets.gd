extends SceneTree

func _init() -> void:
	print("Running test_foliage_gradient_assets...")
	var expected_files = [
		"res://assets/texture/foliage/flowers/flower_gradient_lavender.png",
		"res://assets/texture/foliage/flowers/flower_gradient_poppy.png",
		"res://assets/texture/foliage/flowers/flower_gradient_daisy.png",
		"res://assets/texture/foliage/mushrooms/mushroom_gradient_amanita.png",
		"res://assets/texture/foliage/mushrooms/mushroom_gradient_boletus.png",
		"res://assets/texture/foliage/mushrooms/mushroom_gradient_chanterelle.png"
	]
	for path in expected_files:
		var global_path = ProjectSettings.globalize_path(path)
		assert(FileAccess.file_exists(global_path), "Missing gradient asset: %s" % path)
		var img = Image.load_from_file(global_path)
		assert(img != null, "Failed to load image: %s" % path)
		assert(img.get_width() >= 256 and img.get_height() >= 256, "Invalid resolution for %s" % path)
		# Verify vertical color differential: top (y=0) must be distinctly different from bottom (y=h-1)
		var top_px: Color = img.get_pixel(img.get_width() / 2, 5)
		var bottom_px: Color = img.get_pixel(img.get_width() / 2, img.get_height() - 5)
		var diff: float = absf(top_px.r - bottom_px.r) + absf(top_px.g - bottom_px.g) + absf(top_px.b - bottom_px.b)
		assert(diff > 0.15, "Gradient must exhibit vertical color variation in %s (diff=%f)" % [path, diff])

	print("[PASS] test_foliage_gradient_assets")
	quit(0)
