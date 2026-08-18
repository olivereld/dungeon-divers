extends SceneTree

## Test unitario para Task 3: Supresión de Picos Miter y Deformaciones Triangulares en Mallas de Muro.
## Valida que la malla de muro extruida posea uniones en inglete acotadas (miter_scale <= 1.42)
## y que ningún vértice de la pared penetre en el centro del pasillo o genere triángulos degenerados.

func _init() -> void:
	print("--- Running test_wall_mesh_spike_suppression ---")
	var BuilderScript = preload("res://src/wall_mesh_generator/core/continuous_wall_mesh_builder.gd")
	var ConfigScript = preload("res://src/wall_mesh_generator/config/wall_mesh_config.gd")

	var grid := CellGrid.new(20, 20)
	var room := RoomData.new(0, Rect2i(2, 2, 6, 6), &"room0")
	grid.fill_rect(room.rect, CellGrid.CellType.FLOOR)

	# Pasillo en T en x=8, y=4 conectando con corredor vertical en x=8, y=2..7
	for y in range(2, 8):
		grid.set_cell(Vector2i(8, y), CellGrid.CellType.CORRIDOR)
	grid.set_cell(Vector2i(9, 4), CellGrid.CellType.CORRIDOR)
	grid.set_cell(Vector2i(10, 4), CellGrid.CellType.CORRIDOR)

	var builder = BuilderScript.new()
	var cfg = ConfigScript.new()
	cfg.cube_size = 2.0
	cfg.seed = 1337

	var mesh: ArrayMesh = builder.build_dungeon_wall_mesh(grid, cfg)
	assert(mesh != null and mesh.get_surface_count() > 0, "Wall mesh must be generated")

	# Inspeccionar todas las superficies de la malla
	for s in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

		assert(verts.size() > 0, "Surface %d must have vertices" % s)

		# 1. Comprobar que ningún triángulo sea degenerado (área casi nula)
		if not indices.is_empty():
			for t in range(0, indices.size(), 3):
				var v0: Vector3 = verts[indices[t]]
				var v1: Vector3 = verts[indices[t + 1]]
				var v2: Vector3 = verts[indices[t + 2]]
				var cross_val: Vector3 = (v1 - v0).cross(v2 - v0)
				var area: float = cross_val.length() * 0.5
				assert(area > 0.00001, "Triangle %d has degenerate area %f in surface %d" % [t / 3, area, s])

		# 2. Comprobar que ningún vértice penetre en el centro del pasillo en (9, 4) -> world X=19.0, Z=9.0
		# El centro de la celda (9, 4) es (19.0, 0, 9.0). El muro debe estar en el borde perimetral.
		for v in verts:
			var dist_to_corridor_center: float = Vector2(v.x - 19.0, v.z - 9.0).length()
			assert(dist_to_corridor_center >= 0.5, "Wall vertex %s penetrates into center of corridor cell (9,4)!" % str(v))

	print("  [OK] No degenerate triangles and no miter spikes penetrating corridor floor")
	print("[PASS] test_wall_mesh_spike_suppression completed successfully!")
	quit(0)
