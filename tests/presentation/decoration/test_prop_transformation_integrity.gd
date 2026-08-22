extends SceneTree

const PropSpawnerScript = preload("res://src/presentation/props/prop_spawner.gd")
const PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
const PropCollisionModeScript = preload("res://src/presentation/props/prop_collision_mode.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_prop_transformation_integrity ---")
	print("==================================================================")

	var spawner := PropSpawnerScript.new()

	var test_pos := Vector3(14.5, 0.0, 22.8)
	var test_rot_deg: float = 270.0
	var test_scale: float = 1.5

	var style := PropStyleScript.new(
		&"sarcophagus_stone_closed", PropStyleScript.Type.SARCOPHAGUS,
		PropPlacementModeScript.Mode.CENTER, PropCollisionModeScript.Mode.BLOCKING,
		null, &"sarcophagus_prop", {"style": 0}
	)
	style.scale = test_scale

	var directive := PropDirectiveScript.new(
		&"sarcophagus_stone_closed", 3, style, test_pos, test_rot_deg,
		[Vector2i(7, 11), Vector2i(7, 12)],
		PropPlacementModeScript.Mode.CENTER, PropCollisionModeScript.Mode.BLOCKING
	)

	var node = spawner.spawn_prop(directive, null)
	assert(node != null, "FAIL: Failed to spawn prop node")

	# 1. Comprobar posición con precisión
	assert(node.position.is_equal_approx(test_pos), "FAIL: World position mismatch: %s vs %s" % [str(node.position), str(test_pos)])

	# 2. Comprobar rotación en Y con precisión
	var expected_rad = deg_to_rad(test_rot_deg)
	assert(is_equal_approx(node.rotation.y, expected_rad), "FAIL: Rotation Y mismatch: %f vs %f" % [node.rotation.y, expected_rad])

	# 3. Comprobar escala con precisión
	var expected_scale = Vector3.ONE * test_scale
	assert(node.scale.is_equal_approx(expected_scale), "FAIL: Scale mismatch: %s vs %s" % [str(node.scale), str(expected_scale)])

	node.free()
	print("  [OK] Mathematical fidelity of position, rotation and scale verified.")

	print("[PASS] test_prop_transformation_integrity completed successfully!")
	quit(0)
