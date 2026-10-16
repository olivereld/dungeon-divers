extends SceneTree

const _SpawnerScript = preload("res://src/world_generator/poi/dead_tree_spawner.gd")
const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")
const _DungeonPOIScript = preload("res://src/world_generator/poi/dungeon_poi.gd")
const _DungeonIdentityScript = preload("res://src/world_generator/poi/dungeon_identity.gd")

class MockQuery extends RefCounted:
	func get_elevation(_x: int, _z: int) -> float:
		return 4.0
	func is_water(_x: int, _z: int) -> bool:
		return false

func _init() -> void:
	print("Running test_dead_tree_spawner...")
	var ident = _DungeonIdentityScript.new(&"necropolis_01", Vector2i(0, 0), 0, 999)
	var poi = _DungeonPOIScript.new(ident, Vector3(0.0, 4.0, 0.0), Transform3D.IDENTITY, &"necropolis", 1)
	var prof = _ProfileScript.new()
	var query = MockQuery.new()

	var node = _SpawnerScript.generate_dead_trees(poi, prof, query)
	assert(node != null, "Dead tree node must generate")
	var mmi = node.get_node_or_null("DeadTreesMultiMesh") as MultiMeshInstance3D
	assert(mmi != null, "Must contain DeadTreesMultiMesh")
	
	var transforms: Array = mmi.get_meta("tree_transforms", [])
	assert(transforms.size() >= 3, "Must spawn trees according to density")
	
	const _EvaluatorScript = preload("res://src/world_generator/poi/necropolis_influence_evaluator.gd")
	for i in range(transforms.size()):
		var t: Transform3D = transforms[i]
		var dist = Vector2(t.origin.x, t.origin.z).length()
		assert(dist >= prof.entrance_clear_radius - 0.1, "Dead tree #%d is too close to entrance" % i)
		var in_corridor = _EvaluatorScript.is_in_frontal_corridor(Vector2(t.origin.x, t.origin.z), Vector2.ZERO, poi.orientation_deg, 8.5, 3.5)
		assert(not in_corridor, "Dead tree #%d must not block frontal corridor" % i)

		# Verify physical height: base mesh height is 5.8m
		var tree_scale = t.basis.get_scale().y
		var tree_height = tree_scale * 5.8
		assert(tree_height >= prof.dead_tree_height_min - 0.05 and tree_height <= prof.dead_tree_height_max + 0.05,
			"Tree #%d height %.2fm outside [%.2f, %.2f]" % [i, tree_height, prof.dead_tree_height_min, prof.dead_tree_height_max])

	# Test density scaling
	prof.dead_tree_density = 0.05
	var low_density_node = _SpawnerScript.generate_dead_trees(poi, prof, query)
	var low_mmi = low_density_node.get_node_or_null("DeadTreesMultiMesh") as MultiMeshInstance3D
	var low_transforms: Array = low_mmi.get_meta("tree_transforms", []) if low_mmi != null else []
	assert(low_transforms.size() < transforms.size(), "Lower density must yield fewer trees")

	node.free()
	if low_density_node != null:
		low_density_node.free()
	print("[PASS] test_dead_tree_spawner")
	quit(0)
