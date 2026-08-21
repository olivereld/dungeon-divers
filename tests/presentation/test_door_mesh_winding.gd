extends SceneTree

const WallMeshBuilderScript = preload("res://src/wall_mesh_generator/core/wall_mesh_builder.gd")
const WallMeshConfigScript = preload("res://src/wall_mesh_generator/config/wall_mesh_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_door_mesh_winding ---")
	print("==================================================================")

	var builder = WallMeshBuilderScript.new()

	# 1. Validar mallas de puerta (DOOR)
	var door_cfg = WallMeshConfigScript.new()
	door_cfg.piece_type = WallMeshConfigScript.PieceType.DOOR
	door_cfg.centered_origin = true
	door_cfg.door_width = 1.06
	door_cfg.door_height = 2.49
	door_cfg.seed = 1337

	var door_mesh: ArrayMesh = builder.build_wall_mesh(door_cfg)
	assert(door_mesh != null and door_mesh.get_surface_count() >= 2, "FAIL: Door must have Wood and Iron surfaces")

	# Comprobar normales en superficie de madera (superficie 0)
	var wood_arrays = door_mesh.surface_get_arrays(0)
	var wood_verts = wood_arrays[Mesh.ARRAY_VERTEX]
	var wood_normals = wood_arrays[Mesh.ARRAY_NORMAL]

	var has_front_normal: bool = false
	var has_back_normal: bool = false

	for i in range(wood_verts.size()):
		var norm: Vector3 = wood_normals[i]
		if norm.z > 0.7:
			has_front_normal = true
		elif norm.z < -0.7:
			has_back_normal = true

	assert(has_front_normal, "FAIL: Door wood mesh must contain front (+Z) facing normals")
	assert(has_back_normal, "FAIL: Door wood mesh must contain back (-Z) facing normals")
	print("  [OK] door_wood_leaf: Normales frontales (+Z) y traseras (-Z) orientadas correctamente.")

	# 2. Validar mallas de arco (ARCH)
	var arch_cfg = WallMeshConfigScript.new()
	arch_cfg.piece_type = WallMeshConfigScript.PieceType.ARCH
	arch_cfg.centered_origin = true
	arch_cfg.cube_size = 2.0
	arch_cfg.cubes_high = 2
	arch_cfg.seed = 1337

	var arch_mesh: ArrayMesh = builder.build_wall_mesh(arch_cfg)
	assert(arch_mesh != null and arch_mesh.get_surface_count() >= 2, "FAIL: Arch must have at least Trims and WallPanel surfaces")

	var panel_arrays = arch_mesh.surface_get_arrays(1)
	var panel_verts = panel_arrays[Mesh.ARRAY_VERTEX]
	var panel_normals = panel_arrays[Mesh.ARRAY_NORMAL]

	var arch_front: bool = false
	var arch_back: bool = false
	for i in range(panel_verts.size()):
		var norm: Vector3 = panel_normals[i]
		if norm.z > 0.7:
			arch_front = true
		elif norm.z < -0.7:
			arch_back = true

	assert(arch_front, "FAIL: Arch panel must contain front (+Z) facing normals")
	assert(arch_back, "FAIL: Arch panel must contain back (-Z) facing normals")
	print("  [OK] door_arch_stone: Normales de panel frontal (+Z) y trasero (-Z) verificadas.")

	print("[PASS] test_door_mesh_winding completed successfully.")
	quit(0)
