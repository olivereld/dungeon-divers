extends SceneTree

func _init() -> void:
	var path := "res://assets/texture/world/cliff/cliff_02.jpg"
	var exists := ResourceLoader.exists(path)
	print("Exists: %s" % str(exists))
	if exists:
		var tex = load(path)
		print("Loaded tex: %s, size: %s" % [str(tex), str(tex.get_size() if tex != null else "null")])
	quit()
