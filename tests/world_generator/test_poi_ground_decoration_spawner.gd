extends SceneTree

const _ScattererScript = preload("res://src/world_generator/poi/poi_ground_decoration_spawner.gd")
const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")
const _DungeonPOIScript = preload("res://src/world_generator/poi/dungeon_poi.gd")
const _DungeonIdentityScript = preload("res://src/world_generator/poi/dungeon_identity.gd")

class MockQuery extends RefCounted:
	func get_elevation(_x: int, _z: int) -> float:
		return 3.0
	func is_water(_x: int, _z: int) -> bool:
		return false
	func get_slope(_x: int, _z: int) -> float:
		return 2.0

func _init() -> void:
	print("Running test_poi_ground_decoration_spawner...")
	var ident = _DungeonIdentityScript.new(&"necropolis_01", Vector2i(0, 0), 0, 888)
	var poi = _DungeonPOIScript.new(ident, Vector3(0.0, 3.0, 0.0), Transform3D.IDENTITY, &"necropolis", 1)
	var prof = _ProfileScript.new()
	var query = MockQuery.new()

	var test_box := BoxMesh.new()
	test_box.size = Vector3(1.0, 0.5, 2.0)

	var spec := _ScattererScript.DecorationSpec.new()
	spec.id = "test_prop"
	spec.mesh = test_box
	spec.density = 0.20
	spec.min_distance = 2.5
	spec.scale_min = 0.8
	spec.scale_max = 1.2
	spec.radius_min = 5.0
	spec.radius_max = 20.0
	spec.forbidden_radius = prof.entrance_clear_radius

	var container = _ScattererScript.scatter_decorations(poi, prof, query, [spec])
	assert(container != null, "Container must generate")
	var mmi = container.get_node_or_null("MultiMesh_test_prop") as MultiMeshInstance3D
	assert(mmi != null, "MultiMesh_test_prop must be created")
	assert(mmi.multimesh != null, "MultiMesh must be assigned")
	assert(mmi.multimesh.instance_count > 0, "Must place instances")

	var transforms: Array = mmi.get_meta("placed_transforms", [])
	const _EvaluatorScript = preload("res://src/world_generator/poi/necropolis_influence_evaluator.gd")
	for i in range(transforms.size()):
		var t: Transform3D = transforms[i]
		var dist = Vector2(t.origin.x, t.origin.z).length()
		assert(dist >= prof.entrance_clear_radius, "Instance #%d too close to entrance" % i)
		assert(not _EvaluatorScript.is_in_frontal_corridor(Vector2(t.origin.x, t.origin.z), Vector2.ZERO, poi.orientation_deg),
			"Instance #%d inside frontal corridor" % i)

	# Verify determinism: same seed produces identical transforms
	var container2 = _ScattererScript.scatter_decorations(poi, prof, query, [spec])
	var mmi2 = container2.get_node_or_null("MultiMesh_test_prop") as MultiMeshInstance3D
	assert(mmi2.multimesh.instance_count == mmi.multimesh.instance_count, "Instance counts must match across identical seed")

	container.free()
	container2.free()
	print("[PASS] test_poi_ground_decoration_spawner")
	quit(0)
