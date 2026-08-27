extends SceneTree

const CameraOcclusionDetectorScript = preload("res://src/presentation/camera/camera_occlusion_detector.gd")
const OccluderResolverScript = preload("res://src/presentation/camera/occluder_resolver.gd")

var _started_occluders: Array[Node3D] = []
var _ended_occluders: Array[Node3D] = []

func _on_occlusion_started(occs: Array[Node3D]) -> void:
	_started_occluders = occs

func _on_occlusion_ended(occs: Array[Node3D]) -> void:
	_ended_occluders = occs

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_multi_wall_occlusion_physics ---")
	print("==================================================================")

	var root := Node3D.new()
	root.name = "PhysicsTestWorld"
	get_root().add_child(root)

	# 1. Cámara y Player
	var camera := Camera3D.new()
	camera.position = Vector3(20.0, 20.0, 20.0)
	root.add_child(camera)

	var player := CharacterBody3D.new()
	player.position = Vector3(0.0, 0.0, 0.0)
	var player_col := CollisionShape3D.new()
	var player_shape := CapsuleShape3D.new()
	player_col.shape = player_shape
	player.add_child(player_col)
	root.add_child(player)

	# 2. Pared 1 (Externa, cerca de la cámara en 12, 12, 12)
	var wall1_mesh := MeshInstance3D.new()
	wall1_mesh.name = "Wall_Outer_1"
	wall1_mesh.position = Vector3(12.0, 12.0, 12.0)
	wall1_mesh.add_to_group(OccluderResolverScript.CAMERA_OCCLUDER_GROUP, true)
	root.add_child(wall1_mesh)

	var wall1_body := StaticBody3D.new()
	wall1_body.add_to_group(OccluderResolverScript.CAMERA_OCCLUDER_GROUP, true)
	var wall1_col := CollisionShape3D.new()
	var box1 := BoxShape3D.new()
	box1.size = Vector3(3.0, 3.0, 3.0)
	wall1_col.shape = box1
	wall1_body.add_child(wall1_col)
	wall1_mesh.add_child(wall1_body)

	# 3. Pared 2 (Interna, entre Pared 1 y Player en 6, 6, 6)
	var wall2_mesh := MeshInstance3D.new()
	wall2_mesh.name = "Wall_Inner_2"
	wall2_mesh.position = Vector3(6.0, 6.0, 6.0)
	wall2_mesh.add_to_group(OccluderResolverScript.CAMERA_OCCLUDER_GROUP, true)
	root.add_child(wall2_mesh)

	var wall2_body := StaticBody3D.new()
	wall2_body.add_to_group(OccluderResolverScript.CAMERA_OCCLUDER_GROUP, true)
	var wall2_col := CollisionShape3D.new()
	var box2 := BoxShape3D.new()
	box2.size = Vector3(3.0, 3.0, 3.0)
	wall2_col.shape = box2
	wall2_body.add_child(wall2_col)
	wall2_mesh.add_child(wall2_body)

	# 4. Detector de oclusión
	var detector = CameraOcclusionDetectorScript.new()
	root.add_child(detector)
	detector.occlusion_started.connect(_on_occlusion_started)
	detector.occlusion_ended.connect(_on_occlusion_ended)

	await process_frame

	var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
	assert(space != null, "FAIL: DirectSpaceState3D must be available")

	# Chequeo 1: Ambas paredes deben ser detectadas simultáneamente por el raycast perforante
	detector.perform_occlusion_check(camera, player, space)

	assert(detector.is_target_occluded(), "FAIL: Target must be detected as occluded")
	var active_occluders = detector.get_active_occluders()
	print("  Active occluders detected: ", active_occluders.map(func(n): return n.name))

	assert(active_occluders.has(wall1_mesh), "FAIL: Outer wall 1 must be occluded")
	assert(active_occluders.has(wall2_mesh), "FAIL: Inner wall 2 must ALSO be occluded simultaneously!")

	print("  [OK] Both outer and inner walls were detected and faded simultaneously!")

	# Chequeo 2: Mover pared externa -> la interna sigue ocluida
	wall1_mesh.position = Vector3(100.0, 100.0, 100.0)
	await process_frame
	detector.perform_occlusion_check(camera, player, space)

	active_occluders = detector.get_active_occluders()
	print("  Active occluders after moving outer wall: ", active_occluders.map(func(n): return n.name))
	assert(not active_occluders.has(wall1_mesh), "FAIL: Wall 1 should no longer be active")
	assert(active_occluders.has(wall2_mesh), "FAIL: Wall 2 must still remain occluded")

	# Chequeo 3: Mover pared interna -> ninguna ocluida
	wall2_mesh.position = Vector3(100.0, 100.0, 100.0)
	await process_frame
	detector.perform_occlusion_check(camera, player, space)

	assert(not detector.is_target_occluded(), "FAIL: No walls should be occluded")
	assert(detector.get_active_occluders().is_empty(), "FAIL: Active occluders list must be empty")

	root.free()

	print("==================================================================")
	print("[PASS] test_multi_wall_occlusion_physics passed successfully!")
	print("==================================================================")
	quit(0)
