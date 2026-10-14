extends SceneTree

const _BonePatchGenScript = preload("res://src/world_generator/poi/bone_patch_generator.gd")
const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")
const _DungeonPOIScript = preload("res://src/world_generator/poi/dungeon_poi.gd")
const _DungeonIdentityScript = preload("res://src/world_generator/poi/dungeon_identity.gd")

class MockQuery extends RefCounted:
	func get_elevation(_x: int, _z: int) -> float:
		return 6.0

func _init() -> void:
	print("Running test_bone_patch_generator...")
	var ident = _DungeonIdentityScript.new(&"necropolis_01", Vector2i(0, 0), 0, 777)
	var poi = _DungeonPOIScript.new(ident, Vector3(50.0, 6.0, 50.0), Transform3D.IDENTITY, &"necropolis", 1)
	var prof = _ProfileScript.new()
	var query = MockQuery.new()

	var patch_node = _BonePatchGenScript.generate_bone_patches(poi, prof, query)
	assert(patch_node != null, "BonePatch node must be generated")
	assert(patch_node.get_child_count() > 0, "Must contain MultiMeshInstance3D children for bone textures")
	
	var mmi = patch_node.get_child(0) as MultiMeshInstance3D
	assert(mmi != null and mmi.multimesh != null, "Child must be MultiMeshInstance3D")
	assert(mmi.multimesh.instance_count > 0, "Must have generated bone instances")
	
	patch_node.free()
	print("[PASS] test_bone_patch_generator")
	quit(0)
