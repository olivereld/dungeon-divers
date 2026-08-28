extends SceneTree

func _init() -> void:
	print("--- Checking VFX Textures ---")
	var t1 = load("res://assets/texture/vfx/particles/alpha/dirt_01_a.png") as Texture2D
	print("dirt_01_a: ", t1, " | size: ", t1.get_size() if t1 else Vector2.ZERO)

	var t2 = load("res://assets/texture/vfx/particles/alpha/smoke_04_a.png") as Texture2D
	print("smoke_04_a: ", t2, " | size: ", t2.get_size() if t2 else Vector2.ZERO)

	var t3 = load("res://assets/texture/vfx/particles/alpha/circle_05_a.png") as Texture2D
	print("circle_05_a: ", t3, " | size: ", t3.get_size() if t3 else Vector2.ZERO)

	# Check image data
	if t1:
		var img = t1.get_image()
		print("dirt_01_a image format: ", img.get_format() if img else "null")
		if img:
			var c = img.get_pixel(img.get_width() / 2, img.get_height() / 2)
			print("dirt_01_a center pixel: ", c)

	quit(0)
