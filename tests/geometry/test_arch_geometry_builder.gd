extends SceneTree

const ArchGeometryBuilderScript = preload("res://src/geometry_generator/geometry/arch_geometry_builder.gd")
const ArchGeometryConfigScript = preload("res://src/geometry_generator/config/arch_geometry_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_arch_geometry_builder ---")
	print("==================================================================")

	var builder = ArchGeometryBuilderScript.new()
	var cfg = ArchGeometryConfigScript.new()
	cfg.width = 2.0
	cfg.height = 4.0
	cfg.opening_width = 1.06
	cfg.opening_height = 2.50
	cfg.seed = 1337

	var g_mesh = builder.build_arch_mesh(cfg)
	assert(g_mesh != null, "FAIL: g_mesh must not be null")
	assert(g_mesh.mesh != null, "FAIL: Arch mesh must not be null")
	assert(g_mesh.mesh.get_surface_count() >= 2, "FAIL: Arch must have at least Trims and WallPanel surfaces")
	assert(g_mesh.collision_shapes.size() >= 2, "FAIL: Arch must generate collision shapes for pillars")

	# Validar superficies y normales en panel central
	var panel_arrays = g_mesh.mesh.surface_get_arrays(1)
	var verts = panel_arrays[Mesh.ARRAY_VERTEX]
	var normals = panel_arrays[Mesh.ARRAY_NORMAL]
	assert(verts.size() > 0, "FAIL: Arch panel must contain vertices")

	var has_front_normal: bool = false
	var has_back_normal: bool = false
	for n in normals:
		if n.z > 0.7:
			has_front_normal = true
		elif n.z < -0.7:
			has_back_normal = true

	assert(has_front_normal, "FAIL: Arch must have front (+Z) facing normals")
	assert(has_back_normal, "FAIL: Arch must have back (-Z) facing normals")

	print("  [OK] Arch surfaces: %d | Verts: %d | Collisions: %d" % [
		g_mesh.mesh.get_surface_count(),
		verts.size(),
		g_mesh.collision_shapes.size()
	])

	print("[PASS] test_arch_geometry_builder completed successfully.")
	quit(0)
