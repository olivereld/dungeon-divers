extends SceneTree

func _init() -> void:
	print("--- Checking floor_wood_small.gltf load ---")
	var res = load("res://models/dungeon/floor_wood_small/floor_wood_small.gltf")
	print("Loaded resource: ", res)
	if res is PackedScene:
		var inst = res.instantiate()
		print("Instantiated scene root: ", inst.get_class(), " name: ", inst.name)
		for child in inst.get_children():
			print("Child: ", child.get_class(), " name: ", child.name)
			if child is MeshInstance3D:
				print("Found Mesh: ", child.mesh, " AABB: ", child.mesh.get_aabb())
				if child.mesh.get_surface_count() > 0:
					print("Surface material: ", child.get_active_material(0))
	quit(0)
