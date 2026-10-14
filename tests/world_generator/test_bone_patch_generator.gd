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
	assert(patch_node.get_child_count() > 0, "Must contain MultiMeshInstance3D children")

	var found_bones := false
	var found_webs := false
	var bone_y_max := -999.0
	var web_y_min := 999.0

	for child in patch_node.get_children():
		var mmi = child as MultiMeshInstance3D
		assert(mmi != null and mmi.multimesh != null, "Child must be MultiMeshInstance3D")
		assert(mmi.material_override is ShaderMaterial, "Material must be ShaderMaterial with custom alpha shader")
		
		var is_web: bool = mmi.get_meta("is_web", false)
		var transforms: Array = mmi.get_meta("patch_transforms", [])
		if is_web:
			found_webs = true
			for t in transforms:
				if t.origin.y < web_y_min:
					web_y_min = t.origin.y
		else:
			found_bones = true
			for t in transforms:
				if t.origin.y > bone_y_max:
					bone_y_max = t.origin.y

	assert(found_bones, "Must have generated bone patch groups")
	assert(found_webs, "Must have generated web patch groups")
	assert(web_y_min > bone_y_max, "Layering: Web patches (%.4f) must be placed on a plane above bone patches (%.4f)" % [web_y_min, bone_y_max])

	patch_node.free()
	print("[PASS] test_bone_patch_generator")
	quit(0)
