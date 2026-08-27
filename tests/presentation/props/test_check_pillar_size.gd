extends SceneTree

func _init() -> void:
	var sc = load("res://assets/scenes/props/pillar_stone.tscn") as PackedScene
	var inst = sc.instantiate() as Node3D

	print("Pillar scene children: ", inst.get_child_count())
	var mi = inst.find_child("Model", true, false)
	if mi is MeshInstance3D:
		var aabb: AABB = mi.get_aabb()
		print("Model Mesh AABB: ", aabb)
		print("Model Mesh Size: ", aabb.size)
	elif mi is Node3D:
		for c in mi.get_children():
			if c is MeshInstance3D:
				print("Child Mesh AABB: ", c.get_aabb())
				print("Child Mesh Size: ", c.get_aabb().size)

	quit(0)
