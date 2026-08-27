extends SceneTree

func _init() -> void:
	print("==================================================================")
	var chest_sc: PackedScene = load("res://assets/scenes/props/chest.tscn")
	var pillar_sc: PackedScene = load("res://assets/scenes/props/pillar_stone.tscn")

	var chest = chest_sc.instantiate()
	var pillar = pillar_sc.instantiate()

	var c_aabb = _get_combined_aabb(chest)
	var p_aabb = _get_combined_aabb(pillar)

	print("Raw chest.tscn AABB size: ", c_aabb.size)
	print("Raw pillar_stone.tscn AABB size: ", p_aabb.size)

	chest.scale = Vector3(0.1, 0.1, 0.1)
	pillar.scale = Vector3(3.0, 3.0, 3.0)

	print("Scaled chest (scale=0.1) effective size: ", c_aabb.size * 0.1)
	print("Scaled pillar (scale=3.0) effective size: ", p_aabb.size * 3.0)

	chest.scale = Vector3(0.4, 0.4, 0.4)
	print("Scaled chest (scale=0.4) effective size: ", c_aabb.size * 0.4)

	chest.free()
	pillar.free()
	quit(0)

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
