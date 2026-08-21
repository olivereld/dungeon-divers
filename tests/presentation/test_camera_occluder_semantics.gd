extends SceneTree

const DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const PlayerTestScript = preload("res://src/character_test/player_test.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_camera_occluder_semantics ---")
	print("==================================================================")

	var root := Node3D.new()
	root.name = "SemanticTestWorld"
	get_root().add_child(root)

	var group_name: StringName = DungeonPresentationBuilderScript.CAMERA_OCCLUDER_GROUP
	assert(group_name == &"camera_occluder", "FAIL: CAMERA_OCCLUDER_GROUP must equal 'camera_occluder'")

	# 1. Simular muro continuo generado y su cuerpo de colisión
	var mock_wall_mesh := MeshInstance3D.new()
	mock_wall_mesh.name = "ContinuousWalls"
	mock_wall_mesh.add_to_group(group_name, true)
	root.add_child(mock_wall_mesh)

	var mock_wall_body := StaticBody3D.new()
	mock_wall_body.name = "WallStaticBody"
	mock_wall_body.add_to_group(group_name, true)
	mock_wall_mesh.add_child(mock_wall_body)

	# 2. Simular suelo, jugador y props
	var mock_floor := MeshInstance3D.new()
	mock_floor.name = "FloorMeshInstance"
	root.add_child(mock_floor)

	var player = PlayerTestScript.new()
	player.name = "Player"
	root.add_child(player)

	var mock_prop := Node3D.new()
	mock_prop.name = "TorchProp"
	root.add_child(mock_prop)

	await process_frame

	# 3. Comprobar semántica de grupos
	assert(mock_wall_mesh.is_in_group(group_name), "FAIL: Wall mesh must be in camera_occluder group")
	assert(mock_wall_body.is_in_group(group_name), "FAIL: Wall static body must be in camera_occluder group")

	assert(not mock_floor.is_in_group(group_name), "FAIL: Floor must NOT be in camera_occluder group")
	assert(not player.is_in_group(group_name), "FAIL: Player must NOT be in camera_occluder group")
	assert(not mock_prop.is_in_group(group_name), "FAIL: Props must NOT be in camera_occluder group")

	root.free()

	print("[PASS] test_camera_occluder_semantics completed successfully.")
	quit(0)
