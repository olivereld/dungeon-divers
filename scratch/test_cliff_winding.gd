extends SceneTree

func _init() -> void:
	var space := PhysicsServer3D.space_create()
	PhysicsServer3D.space_set_active(space, true)

	# Test Borde Oeste (-X).
	# High cell at x=1, low cell at x=0.
	# Wall is at x=1, facing -X (towards x=0).
	# Quad vertices:
	# 0: (1, 2, 1) top front
	# 1: (1, 2, 0) top back
	# 2: (1, 0, 1) bottom front
	# 3: (1, 0, 0) bottom back
	var v0 := Vector3(1, 2, 1)
	var v1 := Vector3(1, 2, 0)
	var v2 := Vector3(1, 0, 1)
	var v3 := Vector3(1, 0, 0)

	# Current order in terrain_mesh_builder: (0, 1, 2) and (1, 3, 2)
	var faces_orig := PackedVector3Array([v0, v1, v2,  v1, v3, v2])
	var shape_orig := PhysicsServer3D.concave_polygon_shape_create()
	PhysicsServer3D.shape_set_data(shape_orig, {"faces": faces_orig, "backface_collision": false})

	var body := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_space(body, space)
	PhysicsServer3D.body_add_shape(body, shape_orig)

	var space_state := PhysicsServer3D.space_get_direct_state(space)
	# Ray from lower ground (x=0, y=1, z=0.5) to high ground (x=2, y=1, z=0.5)
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 1, 0.5), Vector3(2, 1, 0.5))
	var hit_orig := space_state.intersect_ray(query)
	print("Raycast hit with current order (0, 1, 2): %s" % str(hit_orig))

	# Now inverted order: (0, 2, 1) and (1, 2, 3)
	var faces_inv := PackedVector3Array([v0, v2, v1,  v1, v2, v3])
	PhysicsServer3D.shape_set_data(shape_orig, {"faces": faces_inv, "backface_collision": false})
	var hit_inv := space_state.intersect_ray(query)
	print("Raycast hit with inverted order (0, 2, 1): %s" % str(hit_inv))

	quit()
