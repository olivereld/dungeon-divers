extends SceneTree

func _init() -> void:
	# Let's test RayCast3D hitting a ConcavePolygonShape3D from above
	var space := PhysicsServer3D.space_create()
	PhysicsServer3D.space_set_active(space, true)

	# Shape A: (0, 2, 1) and (1, 2, 3)
	var shape_a := PhysicsServer3D.concave_polygon_shape_create()
	var p0 := Vector3(0, 5, 0)
	var p1 := Vector3(1, 5, 0)
	var p2 := Vector3(0, 5, 1)
	var p3 := Vector3(1, 5, 1)

	# Order A: 0, 2, 1 and 1, 2, 3
	var faces_a := PackedVector3Array([p0, p2, p1,  p1, p2, p3])
	PhysicsServer3D.shape_set_data(shape_a, {"faces": faces_a, "backface_collision": false})

	var body_a := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_space(body_a, space)
	PhysicsServer3D.body_add_shape(body_a, shape_a)

	# Raycast from (0.5, 10, 0.5) to (0.5, 0, 0.5)
	var space_state := PhysicsServer3D.space_get_direct_state(space)
	var query := PhysicsRayQueryParameters3D.create(Vector3(0.5, 10, 0.5), Vector3(0.5, 0, 0.5))
	var hit_a := space_state.intersect_ray(query)
	print("Raycast hit with (0, 2, 1): %s" % str(hit_a))

	# Now test (0, 1, 2)
	PhysicsServer3D.body_clear_shapes(body_a)
	var shape_b := PhysicsServer3D.concave_polygon_shape_create()
	var faces_b := PackedVector3Array([p0, p1, p2,  p1, p3, p2])
	PhysicsServer3D.shape_set_data(shape_b, {"faces": faces_b, "backface_collision": false})
	PhysicsServer3D.body_add_shape(body_a, shape_b)

	var hit_b := space_state.intersect_ray(query)
	print("Raycast hit with (0, 1, 2): %s" % str(hit_b))

	quit()
