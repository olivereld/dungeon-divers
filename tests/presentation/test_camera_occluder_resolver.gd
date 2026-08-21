extends SceneTree

const OccluderResolverScript = preload("res://src/presentation/camera/occluder_resolver.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_camera_occluder_resolver ---")
	print("==================================================================")

	var root := Node3D.new()
	root.name = "ResolverTestWorld"
	get_root().add_child(root)

	var resolver = OccluderResolverScript.new()
	assert(resolver != null, "FAIL: OccluderResolver should instantiate")

	# 1. Jerarquía de Muro: MeshInstance3D (camera_occluder) -> StaticBody3D (camera_occluder) -> CollisionShape3D
	var wall_mesh := MeshInstance3D.new()
	wall_mesh.name = "ContinuousWalls"
	wall_mesh.add_to_group(OccluderResolverScript.CAMERA_OCCLUDER_GROUP, true)
	root.add_child(wall_mesh)

	var wall_body := StaticBody3D.new()
	wall_body.name = "WallStaticBody"
	wall_body.add_to_group(OccluderResolverScript.CAMERA_OCCLUDER_GROUP, true)
	wall_mesh.add_child(wall_body)

	var wall_col := CollisionShape3D.new()
	wall_body.add_child(wall_col)

	# 2. Objeto no oclusor (Suelo)
	var floor_body := StaticBody3D.new()
	floor_body.name = "FloorStaticBody"
	root.add_child(floor_body)

	await process_frame

	# 3. Resolución de candidato desde el cuerpo de colisión hijo hacia la malla visual
	var resolved_mesh = resolver.resolve_candidate(wall_body)
	assert(resolved_mesh == wall_mesh, "FAIL: resolve_candidate from static body should resolve to parent MeshInstance3D")

	# 4. Resolución de array con duplicados y no oclusores
	var candidates: Array[Node3D] = [wall_body, wall_mesh, floor_body]
	var resolved_list: Array[Node3D] = resolver.resolve(candidates)

	assert(resolved_list.size() == 1, "FAIL: resolve should filter out non-occluders and deduplicate")
	assert(resolved_list[0] == wall_mesh, "FAIL: resolve list should only contain wall_mesh")

	# 5. Objeto no oclusor devuelve null
	assert(resolver.resolve_candidate(floor_body) == null, "FAIL: Non-occluder should resolve to null")

	root.free()

	print("[PASS] test_camera_occluder_resolver completed successfully.")
	quit(0)
