extends SceneTree

func _init() -> void:
	var pipeline := WorldPipeline.new()
	var profile := TaigaWorldProfile.new()
	var result: WorldResult = pipeline.generate(12345, profile)
	var mesh: ArrayMesh = TerrainMeshBuilder.build_mesh(result, profile.cell_size, profile)

	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	var space := PhysicsServer3D.space_create()
	PhysicsServer3D.space_set_active(space, true)

	var body := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_space(body, space)
	PhysicsServer3D.body_add_shape(body, shape.get_rid())

	var space_state := PhysicsServer3D.space_get_direct_state(space)

	# Find a cliff edge: cell A (higher) and cell B (lower)
	var found_cliffs := 0
	for pos in result.cells:
		var c: WorldCell = result.cells[pos]
		var neighbors := {
			"W": pos + Vector2i(-1, 0),
			"E": pos + Vector2i(1, 0),
			"N": pos + Vector2i(0, -1),
			"S": pos + Vector2i(0, 1),
		}
		for dir in neighbors:
			var n_pos: Vector2i = neighbors[dir]
			if result.cells.has(n_pos):
				var nc: WorldCell = result.cells[n_pos]
				if c.elevation_level > nc.elevation_level:
					# c is higher than nc. There should be a cliff wall facing nc!
					# Raycast from nc towards c at height (c.height + nc.height) / 2
					var mid_y: float = (c.height + nc.height) * 0.5
					var from_pt := Vector3(float(n_pos.x) + 0.5, mid_y, float(n_pos.y) + 0.5)
					var to_pt := Vector3(float(pos.x) + 0.5, mid_y, float(pos.y) + 0.5)
					var query := PhysicsRayQueryParameters3D.create(from_pt, to_pt)
					var hit := space_state.intersect_ray(query)
					if hit.is_empty():
						print("ERROR: Missing or backfacing cliff collision between %s (h=%.1f) and %s (h=%.1f) in dir %s!" % [str(pos), c.height, str(n_pos), nc.height, dir])
					else:
						found_cliffs += 1

	print("Tested cliffs. Successfully collided with %d cliff walls from lower ground." % found_cliffs)
	quit()
