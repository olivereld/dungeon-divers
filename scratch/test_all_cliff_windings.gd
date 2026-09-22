extends SceneTree

func _init() -> void:
	var space := PhysicsServer3D.space_create()
	PhysicsServer3D.space_set_active(space, true)

	var cell_size := 1.0
	var x := 5
	var y := 5
	var x0 := float(x) * cell_size
	var x1 := float(x + 1) * cell_size
	var z0 := float(y) * cell_size
	var z1 := float(y + 1) * cell_size
	var h_hi := 4.0
	var h_lo := 2.0

	# West (-X)
	var w_v0 := Vector3(x0, h_hi, z1)
	var w_v1 := Vector3(x0, h_hi, z0)
	var w_v2 := Vector3(x0, h_lo, z1)
	var w_v3 := Vector3(x0, h_lo, z0)
	var w_faces := PackedVector3Array([w_v0, w_v2, w_v1,  w_v1, w_v2, w_v3])

	# East (+X)
	var e_v0 := Vector3(x1, h_hi, z0)
	var e_v1 := Vector3(x1, h_hi, z1)
	var e_v2 := Vector3(x1, h_lo, z0)
	var e_v3 := Vector3(x1, h_lo, z1)
	var e_faces := PackedVector3Array([e_v0, e_v2, e_v1,  e_v1, e_v2, e_v3])

	# North (-Z)
	var n_v0 := Vector3(x0, h_hi, z0)
	var n_v1 := Vector3(x1, h_hi, z0)
	var n_v2 := Vector3(x0, h_lo, z0)
	var n_v3 := Vector3(x1, h_lo, z0)
	var n_faces := PackedVector3Array([n_v0, n_v2, n_v1,  n_v1, n_v2, n_v3])

	# South (+Z)
	var s_v0 := Vector3(x1, h_hi, z1)
	var s_v1 := Vector3(x0, h_hi, z1)
	var s_v2 := Vector3(x1, h_lo, z1)
	var s_v3 := Vector3(x0, h_lo, z1)
	var s_faces := PackedVector3Array([s_v0, s_v2, s_v1,  s_v1, s_v2, s_v3])

	var all_faces := PackedVector3Array()
	all_faces.append_array(w_faces)
	all_faces.append_array(e_faces)
	all_faces.append_array(n_faces)
	all_faces.append_array(s_faces)

	var shape := PhysicsServer3D.concave_polygon_shape_create()
	PhysicsServer3D.shape_set_data(shape, {"faces": all_faces, "backface_collision": false})

	var body := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_space(body, space)
	PhysicsServer3D.body_add_shape(body, shape)

	var space_state := PhysicsServer3D.space_get_direct_state(space)

	# Raycast West wall from outside (x=4 -> x=5.5)
	var hit_w := space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(4.0, 3.0, 5.5), Vector3(5.5, 3.0, 5.5)))
	print("Hit West: norm=%s (expected Vector3.LEFT)" % str(hit_w.get("normal")))

	# Raycast East wall from outside (x=7 -> x=5.5)
	var hit_e := space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(7.0, 3.0, 5.5), Vector3(5.5, 3.0, 5.5)))
	print("Hit East: norm=%s (expected Vector3.RIGHT)" % str(hit_e.get("normal")))

	# Raycast North wall from outside (z=4 -> z=5.5)
	var hit_n := space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(5.5, 3.0, 4.0), Vector3(5.5, 3.0, 5.5)))
	print("Hit North: norm=%s (expected Vector3.FORWARD)" % str(hit_n.get("normal")))

	# Raycast South wall from outside (z=7 -> z=5.5)
	var hit_s := space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(5.5, 3.0, 7.0), Vector3(5.5, 3.0, 5.5)))
	print("Hit South: norm=%s (expected Vector3.BACK)" % str(hit_s.get("normal")))

	quit()
