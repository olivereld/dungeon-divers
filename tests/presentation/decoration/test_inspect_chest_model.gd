extends SceneTree

func _init() -> void:
	var sc: PackedScene = load("res://assets/models/props/chest.glb")
	if sc == null:
		print("FAIL: Cannot load chest.glb")
		quit(1)
		return

	var inst = sc.instantiate()
	print("Chest instance structure:")
	_print_tree(inst, "  ")

	var aabb = _get_combined_aabb(inst)
	print("Combined AABB: position=", aabb.position, " size=", aabb.size)
	inst.free()
	quit(0)

func _print_tree(node: Node, indent: String) -> void:
	print("%s- %s (%s)" % [indent, node.name, node.get_class()])
	for child in node.get_children():
		_print_tree(child, indent + "  ")

func _get_combined_aabb(node: Node) -> AABB:
	var total_aabb := AABB()
	var has_aabb := false

	if node is VisualInstance3D:
		total_aabb = (node as VisualInstance3D).get_aabb()
		has_aabb = true

	for child in node.get_children():
		var child_aabb = _get_combined_aabb(child)
		if child_aabb.size != Vector3.ZERO:
			if not has_aabb:
				total_aabb = child_aabb
				has_aabb = true
			else:
				total_aabb = total_aabb.merge(child_aabb)

	return total_aabb
