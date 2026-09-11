extends SceneTree

const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")

func _init() -> void:
	print("--- Test WaterSurfaceData ---")
	var data = _WaterSurfaceDataScript.new()
	assert(data != null, "WaterSurfaceData must instantiate")

	# Add a simple triangle
	var i0 := data.add_vertex(Vector3(0, 1, 0), Vector3.UP, Vector2(0, 0), Vector2(1, 0), Color.BLUE)
	var i1 := data.add_vertex(Vector3(1, 1, 0), Vector3.UP, Vector2(1, 0), Vector2(1, 0), Color.BLUE)
	var i2 := data.add_vertex(Vector3(0, 1, 1), Vector3.UP, Vector2(0, 1), Vector2(1, 0), Color.BLUE)
	data.add_triangle(i0, i1, i2)

	assert(data.vertices.size() == 3, "Must have 3 vertices")
	assert(data.indices.size() == 3, "Must have 3 indices")
	assert(data.uv2_flow.size() == 3, "Must have 3 flow vectors")

	var mesh: ArrayMesh = data.to_array_mesh()
	assert(mesh != null, "ArrayMesh must be created")
	assert(mesh.get_surface_count() == 1, "Must contain 1 surface")
	print("Test WaterSurfaceData: PASSED")
	quit(0)
