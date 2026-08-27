extends SceneTree

func _init() -> void:
	print("==================================================================")
	print("--- Inspecting skull_pile.glb ---")
	print("==================================================================")
	var glb_path := "res://assets/models/props/skull_pile.glb"
	var res = load(glb_path)
	if res == null:
		print("FAIL: Could not load ", glb_path)
		quit(1)
		return

	var instance = res.instantiate()
	_print_tree(instance, "")
	instance.free()
	quit(0)

func _print_tree(n: Node, indent: String) -> void:
	var extra := ""
	if n is Node3D:
		extra += " pos=" + str(n.position) + " rot=" + str(n.rotation) + " scale=" + str(n.scale)
	if n is VisualInstance3D:
		extra += " aabb=" + str((n as VisualInstance3D).get_aabb())
	if n is MeshInstance3D:
		var mi = n as MeshInstance3D
		if mi.mesh != null:
			extra += " mesh_aabb=" + str(mi.mesh.get_aabb())
	print(indent + "- " + n.name + " (" + n.get_class() + ")" + extra)
	for c in n.get_children():
		_print_tree(c, indent + "  ")
