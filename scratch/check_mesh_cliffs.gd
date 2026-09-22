extends SceneTree

func _init() -> void:
	var pipeline := WorldPipeline.new()
	var profile := TaigaWorldProfile.new()
	var result: WorldResult = pipeline.generate(12345, profile)
	var mesh: ArrayMesh = TerrainMeshBuilder.build_mesh(result, profile.cell_size, profile)

	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	var tri_count := indices.size() / 3
	var cliff_tris := 0
	var cliff_inverted := 0

	for t in range(tri_count):
		var i0 := indices[t * 3]
		var i1 := indices[t * 3 + 1]
		var i2 := indices[t * 3 + 2]
		var n0 := norms[i0]

		if n0.distance_to(Vector3.UP) > 0.1:
			cliff_tris += 1
			var v0 := verts[i0]
			var v1 := verts[i1]
			var v2 := verts[i2]
			var calc_n := (v1 - v0).cross(v2 - v0).normalized()
			var dot: float = calc_n.dot(n0)
			if dot < 0.5:
				cliff_inverted += 1
				if cliff_inverted <= 5:
					print("Cliff tri %d inverted! decl=%s, calc=%s, v0=%s, v1=%s, v2=%s" % [t, str(n0), str(calc_n), str(v0), str(v1), str(v2)])
			else:
				if cliff_tris <= 5:
					print("Cliff tri %d OK! norm=%s, v0=%s, v1=%s, v2=%s" % [t, str(n0), str(v0), str(v1), str(v2)])

	print("Total cliff triangles found: %d (Inverted: %d)" % [cliff_tris, cliff_inverted])
	quit()
