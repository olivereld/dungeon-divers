extends SceneTree

const _MushroomClusterScript = preload("res://src/world_generator/poi/necropolis_mushroom_cluster.gd")
const _ScattererScript = preload("res://src/world_generator/poi/poi_ground_decoration_spawner.gd")
const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")
const _DungeonPOIScript = preload("res://src/world_generator/poi/dungeon_poi.gd")
const _DungeonIdentityScript = preload("res://src/world_generator/poi/dungeon_identity.gd")

class MockQuery extends RefCounted:
	func get_elevation(_x: int, _z: int) -> float:
		return 1.0
	func is_water(_x: int, _z: int) -> bool:
		return false
	func get_slope(_x: int, _z: int) -> float:
		return 2.0

func _init() -> void:
	print("Running test_necropolis_mushroom_accents...")
	var ident = _DungeonIdentityScript.new(&"necropolis_01", Vector2i(0, 0), 0, 555)
	var poi = _DungeonPOIScript.new(ident, Vector3(0.0, 1.0, 0.0), Transform3D.IDENTITY, &"necropolis", 1)
	var prof = _ProfileScript.new()
	var query = MockQuery.new()

	var dummy_anchors := [Vector2(6.0, 5.0), Vector2(-5.0, 7.0)]
	var specs = _MushroomClusterScript.build_specs(prof, dummy_anchors)
	assert(not specs.is_empty(), "Must build mushroom accent specs")

	var container = _ScattererScript.scatter_decorations(poi, prof, query, specs)
	assert(container != null, "Container must generate")

	var mush_mmi = container.get_node_or_null("MultiMesh_necropolis_mushrooms") as MultiMeshInstance3D
	assert(mush_mmi != null and mush_mmi.multimesh.instance_count > 0, "Mushrooms must spawn")

	var transforms: Array = mush_mmi.get_meta("placed_transforms", [])
	for i in range(transforms.size()):
		var t: Transform3D = transforms[i]
		var dist = Vector2(t.origin.x, t.origin.z).length()
		assert(dist >= prof.entrance_clear_radius, "Mushroom #%d must respect clear radius" % i)

	container.free()
	print("[PASS] test_necropolis_mushroom_accents")
	quit(0)
