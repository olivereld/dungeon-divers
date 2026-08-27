extends SceneTree

func _init() -> void:
	print("==================================================================")
	print("--- Testing skull_pile.tscn ---")
	print("==================================================================")
	var sc: PackedScene = load("res://assets/scenes/props/skull_pile.tscn")
	assert(sc != null, "FAIL: Could not load skull_pile.tscn")
	var node = sc.instantiate() as Node3D
	assert(node != null, "FAIL: Could not instantiate skull_pile.tscn")

	print("Root name: ", node.name)
	for c in node.get_children():
		print("  child: ", c.name, " transform=", (c as Node3D).transform if c is Node3D else "")

	node.free()
	print("[PASS] skull_pile.tscn loaded and verified successfully!")
	print("==================================================================")
	quit(0)
