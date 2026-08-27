extends SceneTree

const _WallSectionScript = preload("res://src/geometry_generator/data/wall_section.gd")
const _WallVariantPolicyScript = preload("res://src/geometry_generator/data/wall_variant_policy.gd")
const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_wall_section_data ---")
	print("==================================================================")

	var pts: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(3, 0),
		Vector2i(6, 0)
	]
	var sec := _WallSectionScript.new(1, 42, pts, 10, &"cracked", false)
	assert(sec.id == 1, "FAIL: section id")
	assert(sec.component_id == 42, "FAIL: component_id")
	assert(sec.room_id == 10, "FAIL: room_id")
	assert(sec.variant_id == &"cracked", "FAIL: variant_id")
	assert(sec.start_point == Vector2i(0, 0), "FAIL: start_point")
	assert(sec.end_point == Vector2i(6, 0), "FAIL: end_point")
	assert(sec.length == 6.0, "FAIL: length")
	assert(sec.orientation == Vector2i(1, 0), "FAIL: orientation")

	var policy := _WallVariantPolicyScript.new(true, [&"normal", &"cracked"], { &"normal": 80.0, &"cracked": 20.0 })
	assert(policy.enabled == true, "FAIL: policy enabled")
	assert(policy.allowed_variants.size() == 2, "FAIL: allowed variants size")
	assert(policy.variant_weights[&"cracked"] == 20.0, "FAIL: variant weight")

	var gm := _GeneratedMeshScript.new()
	gm.component_id = 42
	gm.section_id = 1
	gm.variant_id = &"cracked"
	gm.room_id = 10
	var mi = gm.to_mesh_instance("WallSection")
	assert(mi.name == "WallSection_42_1", "FAIL: MeshInstance3D name format, got %s" % mi.name)

	print("  [OK] WallSection, WallVariantPolicy and GeneratedMesh metadata verified.")
	print("==================================================================")
	print("[PASS] test_wall_section_data passed successfully!")
	print("==================================================================")
	quit(0)
