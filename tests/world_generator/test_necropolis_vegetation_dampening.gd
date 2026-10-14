extends SceneTree

const _RockClusterScript = preload("res://src/world_generator/poi/necropolis_rock_cluster.gd")
const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")
const _DungeonPOIScript = preload("res://src/world_generator/poi/dungeon_poi.gd")
const _DungeonIdentityScript = preload("res://src/world_generator/poi/dungeon_identity.gd")
const _EvaluatorScript = preload("res://src/world_generator/poi/necropolis_influence_evaluator.gd")

class MockQuery extends RefCounted:
	func get_elevation(_x: int, _z: int) -> float:
		return 2.0
	func is_water(_x: int, _z: int) -> bool:
		return false

func _init() -> void:
	print("Running test_necropolis_vegetation_dampening...")
	var ident = _DungeonIdentityScript.new(&"necropolis_01", Vector2i(0, 0), 0, 555)
	var poi = _DungeonPOIScript.new(ident, Vector3(0.0, 2.0, 0.0), Transform3D.IDENTITY, &"necropolis", 1)
	var prof = _ProfileScript.new()
	var query = MockQuery.new()

	# Test rock clusters
	var rock_node = _RockClusterScript.generate_dark_rocks(poi, prof, query)
	assert(rock_node != null, "Rock cluster node must generate")
	var mmi = rock_node.get_node_or_null("DarkRocksMultiMesh") as MultiMeshInstance3D
	assert(mmi != null and mmi.multimesh != null, "Must contain DarkRocksMultiMesh")
	assert(mmi.multimesh.instance_count >= 2, "Must spawn dark rock clusters")
	
	# Verify rocks are outside clear radius
	var transforms: Array = mmi.get_meta("rock_transforms", [])
	for t in transforms:
		var dist = Vector2(t.origin.x, t.origin.z).length()
		assert(dist >= prof.entrance_clear_radius, "Rock at %.2fm too close to entrance" % dist)

	rock_node.free()

	# Test vegetation evaluation / dampening logic
	var eval_clear = _EvaluatorScript.evaluate_point(Vector2(0, 0), Vector2(0, 0), 555, prof)
	assert(eval_clear.is_cleared == true, "Center must be fully cleared of vegetation")
	
	var eval_funeral = _EvaluatorScript.evaluate_point(Vector2(10, 0), Vector2(0, 0), 555, prof)
	assert(eval_funeral.influence >= 0.7, "Funeral zone must have high influence dampening")

	print("[PASS] test_necropolis_vegetation_dampening")
	quit(0)
