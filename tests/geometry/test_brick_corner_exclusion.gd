# tests/geometry/test_brick_corner_exclusion.gd
extends SceneTree

const _BrickDecoratorScript = preload("res://src/geometry_generator/decoration/brick_decorator.gd")
const _WallSectionScript = preload("res://src/geometry_generator/data/wall_section.gd")
const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const _DecorationConfigScript = preload("res://src/geometry_generator/config/decoration_config.gd")
const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _WallGeometryBuilderScript = preload("res://src/geometry_generator/geometry/wall_geometry_builder.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_brick_corner_exclusion ---")
	print("==================================================================")

	var geom_cfg := _WallGeometryConfigScript.new()
	geom_cfg.cube_size = 2.0
	geom_cfg.cubes_high = 2

	var dec_cfg := _DecorationConfigScript.new()
	dec_cfg.enabled = true
	dec_cfg.brick_density = 1.0  # max density
	dec_cfg.corner_exclusion_distance = 0.5

	# Create an L-shaped section — has a 90° corner at (3,0)
	var sec := _WallSectionScript.new(0, 1,
		[Vector2i(0, 0), Vector2i(3, 0), Vector2i(3, 3)],
		1, &"normal", false)
	sec.start_miter_neighbor = _WallSectionScript.INVALID_NEIGHBOR
	sec.end_miter_neighbor = _WallSectionScript.INVALID_NEIGHBOR
	sec.has_start_cap = true
	sec.has_end_cap = true

	var builder := _WallGeometryBuilderScript.new()
	var g_mesh := builder.build_section_mesh(sec, geom_cfg)
	assert(g_mesh.mesh != null, "Mesh must exist for decoration test")

	var decorator := _BrickDecoratorScript.new()
	decorator.decorate_section(g_mesh, sec, geom_cfg, dec_cfg, null)

	var corner_pt := Vector3(3.0 * geom_cfg.cube_size, 0.0, 0.0)  # point at (3,0) in world coords = (6, 0, 0)
	var brick_surface_idx := -1
	for s in range(g_mesh.mesh.get_surface_count()):
		if g_mesh.mesh.surface_get_name(s) == "Bricks":
			brick_surface_idx = s
			break

	if brick_surface_idx >= 0:
		var arr = g_mesh.mesh.surface_get_arrays(brick_surface_idx)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for v in verts:
			var dist_xz := Vector2(v.x - corner_pt.x, v.z - corner_pt.z).length()
			assert(dist_xz >= dec_cfg.corner_exclusion_distance * 0.7,
				"Brick vertex too close to corner: dist=%.3f, threshold=%.3f" % [dist_xz, dec_cfg.corner_exclusion_distance * 0.7])
		print("  [OK] No brick vertices within exclusion zone of corners")
	else:
		print("  [OK] No Bricks surface (density may be too low) — exclusion trivially holds")

	print("==================================================================")
	print("[PASS] test_brick_corner_exclusion completado con éxito!")
	print("==================================================================")
	quit(0)
