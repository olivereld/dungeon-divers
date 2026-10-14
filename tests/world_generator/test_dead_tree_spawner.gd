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
	assert(mmi.multimesh.instance_count >= 3, "Must spawn at least 3 dead trees in funeral/corruption zones")
	
	var transforms: Array = mmi.get_meta("tree_transforms", [])
	assert(transforms.size() >= 3, "Must have at least 3 transforms")
	for i in range(transforms.size()):
		var t: Transform3D = transforms[i]
		var dist = Vector2(t.origin.x, t.origin.z).length()
		assert(dist >= prof.entrance_clear_radius - 0.1, "Dead tree #%d at %.2fm is too close to entrance" % [i, dist])

	node.free()
	print("[PASS] test_dead_tree_spawner")
	quit(0)
