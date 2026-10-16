extends SceneTree

const _WoodPropsScript = preload("res://src/world_generator/poi/necropolis_wood_props.gd")
const _ScattererScript = preload("res://src/world_generator/poi/poi_ground_decoration_spawner.gd")
const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")
const _DungeonPOIScript = preload("res://src/world_generator/poi/dungeon_poi.gd")
const _DungeonIdentityScript = preload("res://src/world_generator/poi/dungeon_identity.gd")

class MockQuery extends RefCounted:
	func get_elevation(_x: int, _z: int) -> float:
		return 2.5
	func is_water(_x: int, _z: int) -> bool:
		return false
	func get_slope(_x: int, _z: int) -> float:
		return 3.0

func _init() -> void:
	print("Running test_necropolis_fallen_wood...")
	var ident = _DungeonIdentityScript.new(&"necropolis_01", Vector2i(0, 0), 0, 777)
	var poi = _DungeonPOIScript.new(ident, Vector3(0.0, 2.5, 0.0), Transform3D.IDENTITY, &"necropolis", 1)
	var prof = _ProfileScript.new()
	var query = MockQuery.new()

	var dummy_tree_pos := [Vector2(8.0, 4.0), Vector2(-7.0, -8.0)]
	var specs = _WoodPropsScript.build_specs(prof, dummy_tree_pos)
	assert(specs.size() >= 2, "Must build specs for stumps and logs")

	var container = _ScattererScript.scatter_decorations(poi, prof, query, specs)
	assert(container != null, "Container must generate")

	var stump_mmi = container.get_node_or_null("MultiMesh_stump") as MultiMeshInstance3D
	var log_mmi = container.get_node_or_null("MultiMesh_wood_log") as MultiMeshInstance3D

	assert(stump_mmi != null and stump_mmi.multimesh.instance_count > 0, "Stumps must spawn")
	assert(log_mmi != null and log_mmi.multimesh.instance_count > 0, "Wood logs must spawn")

	var log_transforms: Array = log_mmi.get_meta("placed_transforms", [])
	for i in range(log_transforms.size()):
		var t: Transform3D = log_transforms[i]
		var dist = Vector2(t.origin.x, t.origin.z).length()
		assert(dist >= prof.entrance_clear_radius, "Log #%d must not block crypt door" % i)

	container.free()
	print("[PASS] test_necropolis_fallen_wood")
	quit(0)
