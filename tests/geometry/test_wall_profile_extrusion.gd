# tests/geometry/test_wall_profile_extrusion.gd
extends SceneTree

const _WallGeometryBuilderScript = preload("res://src/geometry_generator/geometry/wall_geometry_builder.gd")
const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const _WallComponentScript = preload("res://src/geometry_generator/data/wall_component.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_wall_profile_extrusion ---")
	print("==================================================================")

	var builder := _WallGeometryBuilderScript.new()
	var cfg := _WallGeometryConfigScript.new()
	cfg.cube_size = 2.0
	cfg.cubes_high = 2

	# L-shaped room — has both convex and concave corners
	var comp := _WallComponentScript.new(1)
	comp.add_loop([
		Vector2i(0, 0), Vector2i(6, 0), Vector2i(6, 3),
		Vector2i(3, 3), Vector2i(3, 6), Vector2i(0, 6)
	])
	var g = builder.build_component_mesh(comp, cfg)
	assert(g != null and g.mesh != null, "L-mesh must be valid")
	assert(g.mesh.get_surface_count() >= 2, "Must have Trims + Panel surfaces")

	# Validate no degenerate geometry
	for s in range(g.mesh.get_surface_count()):
		var arr = g.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idxs: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		assert(verts.size() > 0, "Surface %d has verts" % s)
		assert(idxs.size() % 3 == 0, "Triangles valid on surface %d" % s)

		for v in verts:
			assert(not is_nan(v.x) and not is_nan(v.y) and not is_nan(v.z), "No NaN verts")
			assert(not is_inf(v.x) and not is_inf(v.y) and not is_inf(v.z), "No INF verts")
		for n in norms:
			assert(not is_nan(n.x) and not is_nan(n.y) and not is_nan(n.z), "No NaN normals")
			assert(n.length_squared() > 0.2 and n.length_squared() < 2.0, "Normals unit length")
		for t in range(0, idxs.size(), 3):
			var v0 = verts[idxs[t]]; var v1 = verts[idxs[t+1]]; var v2 = verts[idxs[t+2]]
			assert((v1 - v0).cross(v2 - v0).length_squared() > 0.0000001, "No zero-area triangles")

	print("  [OK] L-room profile-based extrusion: clean mesh, no degenerates")

	print("==================================================================")
	print("[PASS] test_wall_profile_extrusion completado con éxito!")
	print("==================================================================")
	quit(0)
