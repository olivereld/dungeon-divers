extends SceneTree

func _init() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(100, 100)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.position = Vector3(0, 5, 0)
	cam.look_at_from_position(Vector3(0, 5, 0), Vector3(0, 0, 0), Vector3.FORWARD)

	# Triangle 1: with order (0, 1, 2)
	# p0 = (-1, 0, -1), p1 = (1, 0, -1), p2 = (-1, 0, 1)
	var mesh_a := ArrayMesh.new()
	var arr_a := []
	arr_a.resize(Mesh.ARRAY_MAX)
	arr_a[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1)])
	arr_a[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	arr_a[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	mesh_a.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr_a)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.RED
	mat.cull_mode = BaseMaterial3D.CULL_BACK

	var mi_a := MeshInstance3D.new()
	mi_a.mesh = mesh_a
	mi_a.material_override = mat
	vp.add_child(mi_a)

	await process_frame
	await process_frame
	await process_frame

	var img := vp.get_texture().get_image()
	var red_pixels := 0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).r > 0.8:
				red_pixels += 1

	print("With order (0, 1, 2) and CULL_BACK: red pixels = %d" % red_pixels)

	# Now change order to (0, 2, 1)
	var arr_b := []
	arr_b.resize(Mesh.ARRAY_MAX)
	arr_b[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1)])
	arr_b[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	arr_b[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1])
	var mesh_b := ArrayMesh.new()
	mesh_b.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr_b)
	mi_a.mesh = mesh_b

	await process_frame
	await process_frame
	await process_frame

	var img_b := vp.get_texture().get_image()
	var red_pixels_b := 0
	for y in range(img_b.get_height()):
		for x in range(img_b.get_width()):
			if img_b.get_pixel(x, y).r > 0.8:
				red_pixels_b += 1

	print("With order (0, 2, 1) and CULL_BACK: red pixels = %d" % red_pixels_b)
	quit()
