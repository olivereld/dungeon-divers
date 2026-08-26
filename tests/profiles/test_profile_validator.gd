extends SceneTree

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _ProfileValidatorScript = preload("res://src/dungeon_generator/profiles/profile_validator.gd")
const _ProfileBundleScript = preload("res://src/dungeon_generator/profiles/profile_bundle.gd")
const _ProfileArchetypeScript = preload("res://src/dungeon_generator/profiles/profile_archetype.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_profile_validator ---")

	var loader := _ProfileLoaderScript.new()
	var validator := _ProfileValidatorScript.new()

	# 1. Valid bundle test (Mausoleum)
	var bundle = loader.load_full_archetype_bundle("mausoleum")
	var valid_res = validator.validate(bundle)
	if not valid_res.is_valid:
		print("Validation errors:")
		for e in valid_res.errors:
			print(" - ", e)
	assert(valid_res.is_valid, "FAIL: Mausoleum bundle should be valid")

	# 2. Corrupted distribution sum test
	var corrupted_bundle = loader.load_full_archetype_bundle("mausoleum")
	corrupted_bundle.archetype.room_purpose_distribution[&"crypt"] = 0.50 # Sum will be 1.25
	var corrupt_res = validator.validate(corrupted_bundle)
	assert(not corrupt_res.is_valid, "FAIL: Corrupted distribution sum should fail validation")
	var has_dist_err: bool = false
	for e in corrupt_res.errors:
		if e.contains("room_purpose_distribution must sum to 1.0"):
			has_dist_err = true
			break
	assert(has_dist_err, "FAIL: Should report distribution sum error")

	# 3. Unknown material profile reference test
	var mat_bundle = loader.load_full_archetype_bundle("mausoleum")
	mat_bundle.archetype.architectural_style.material_profile = &"unknown_material_nonexistent"
	var mat_res = validator.validate(mat_bundle)
	assert(not mat_res.is_valid, "FAIL: Unknown material profile should fail validation")

	# 4. Unknown prop in room relationship test
	var prop_bundle = loader.load_full_archetype_bundle("mausoleum")
	var tomb_room = prop_bundle.get_room(&"tomb")
	tomb_room.relationships[0].source.append(&"nonexistent_prop_xyz")
	var prop_res = validator.validate(prop_bundle)
	assert(not prop_res.is_valid, "FAIL: Unknown prop in relationship should fail validation")

	print("[PASS] test_profile_validator completed successfully!")
	quit(0)
