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
	print("--- Running test_camera_occlusion_physics ---")
	print("==================================================================")

	var root := Node3D.new()
	root.name = "PhysicsTestWorld"
	get_root().add_child(root)

	# 1. Cámara y Player
	var camera := Camera3D.new()
	camera.position = Vector3(10.0, 10.0, 10.0)
	root.add_child(camera)

	var player := CharacterBody3D.new()
	player.position = Vector3(0.0, 0.0, 0.0)
	var player_col := CollisionShape3D.new()
	var player_shape := CapsuleShape3D.new()
	player_col.shape = player_shape
	player.add_child(player_col)
	root.add_child(player)

	# 2. Muro con colisión intermedia (en 5, 5, 5)
	var wall_mesh := MeshInstance3D.new()
	wall_mesh.name = "Wall_Occluder"
	wall_mesh.position = Vector3(5.0, 5.0, 5.0)
	wall_mesh.add_to_group(OccluderResolverScript.CAMERA_OCCLUDER_GROUP, true)
	root.add_child(wall_mesh)

	var wall_body := StaticBody3D.new()
	wall_body.add_to_group(OccluderResolverScript.CAMERA_OCCLUDER_GROUP, true)
	var wall_col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(3.0, 3.0, 3.0)
	wall_col.shape = box_shape
	wall_body.add_child(wall_col)
	wall_mesh.add_child(wall_body)

	# 3. Detector de oclusión
	var detector = CameraOcclusionDetectorScript.new()
	root.add_child(detector)
	detector.occlusion_started.connect(_on_occlusion_started)
	detector.occlusion_ended.connect(_on_occlusion_ended)

	await process_frame

	var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
	assert(space != null, "FAIL: DirectSpaceState3D must be available")

	# 4. Chequeo de Oclusión Físico con muro bloqueando
	detector.perform_occlusion_check(camera, player, space)

	assert(detector.is_target_occluded(), "FAIL: Target should be detected as occluded by physics raycast")
	assert(_started_occluders.has(wall_mesh), "FAIL: occlusion_started should receive resolved wall_mesh")

	# 5. Mover muro fuera de la línea de visión
	wall_mesh.position = Vector3(50.0, 50.0, 50.0)
	await process_frame

	detector.perform_occlusion_check(camera, player, space)

	assert(not detector.is_target_occluded(), "FAIL: Target should no longer be occluded")
	assert(_ended_occluders.has(wall_mesh), "FAIL: occlusion_ended should receive wall_mesh")

	root.free()

	print("[PASS] test_camera_occlusion_physics completed successfully.")
	quit(0)
