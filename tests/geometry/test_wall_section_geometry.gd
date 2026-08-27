extends SceneTree

const _WallSectionScript = preload("res://src/geometry_generator/data/wall_section.gd")
const _WallGeometryBuilderScript = preload("res://src/geometry_generator/geometry/wall_geometry_builder.gd")
const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_wall_section_geometry ---")
	print("==================================================================")

	var builder := _WallGeometryBuilderScript.new()
	var config := _WallGeometryConfigScript.new()
	config.cube_size = 2.0
	config.cubes_high = 2

	# 1. Tramo abierto
	var open_pts: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(3, 0),
		Vector2i(5, 0)
	]
	var open_sec := _WallSectionScript.new(1, 10, open_pts, 3, &"normal", false)
	var g_mesh_open = builder.build_section_mesh(open_sec, config)

	assert(g_mesh_open != null, "FAIL: g_mesh_open should not be null")
	assert(g_mesh_open.mesh != null, "FAIL: g_mesh_open.mesh should not be null")
	assert(g_mesh_open.mesh.get_surface_count() == 2, "FAIL: Should have Trims and WallPanel surfaces (got %d)" % g_mesh_open.mesh.get_surface_count())
	assert(g_mesh_open.section_id == 1, "FAIL: section_id metadata")
	assert(g_mesh_open.component_id == 10, "FAIL: component_id metadata")
	assert(g_mesh_open.room_id == 3, "FAIL: room_id metadata")
	assert(g_mesh_open.bounds.size.x > 0.0, "FAIL: bounds width")

	# 2. Tramo cerrado (bucle)
	var loop_pts: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(4, 0),
		Vector2i(4, 4),
		Vector2i(0, 4),
		Vector2i(0, 0)
	]
	var loop_sec := _WallSectionScript.new(2, 10, loop_pts, 3, &"cracked", true)
	var g_mesh_loop = builder.build_section_mesh(loop_sec, config)

	assert(g_mesh_loop != null and g_mesh_loop.mesh != null, "FAIL: g_mesh_loop should be valid")
	assert(g_mesh_loop.mesh.get_surface_count() == 2, "FAIL: Loop mesh surfaces count")
	assert(g_mesh_loop.variant_id == &"cracked", "FAIL: variant_id metadata")

	print("  [OK] WallGeometryBuilder builds section meshes for open and closed sections with proper metadata.")
	print("==================================================================")
	print("[PASS] test_wall_section_geometry passed successfully!")
	print("==================================================================")
	quit(0)
