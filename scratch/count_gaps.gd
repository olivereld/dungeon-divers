extends SceneTree

func _init() -> void:
	var pipeline := WorldPipeline.new()
	var profile := TaigaWorldProfile.new()
	var result: WorldResult = pipeline.generate(12345, profile)

	var mesh: ArrayMesh = TerrainMeshBuilder.build_mesh(result, 1.0, profile)
	print("Mesh built successfully with %d surfaces, surface 0 vertex count: %d" % [mesh.get_surface_count(), mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()])

	var unclosed_with_new_rule := 0
	for pos in result.cells:
		var c: WorldCell = result.cells[pos]
		for offset in [Vector2i(1, 0), Vector2i(0, 1)]:
			var n_pos: Vector2i = pos + offset
			if result.cells.has(n_pos):
				var nc: WorldCell = result.cells[n_pos]
				if not is_equal_approx(c.height, nc.height):
					var has_wall := (c.height - nc.height > 0.00001) or (nc.height - c.height > 0.00001)
					if not has_wall:
						unclosed_with_new_rule += 1
						print("Diff was: %e, c.height=%f, nc.height=%f" % [absf(c.height - nc.height), c.height, nc.height])

	print("Unclosed vertical gaps with new rule: %d!" % unclosed_with_new_rule)
	quit()
