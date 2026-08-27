extends SceneTree

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _ProfileValidatorScript = preload("res://src/dungeon_generator/profiles/profile_validator.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_wall_variant_profile_resolution ---")
	print("==================================================================")

	var loader := _ProfileLoaderScript.new()
	var bundle = loader.load_full_archetype_bundle("mausoleum")
	assert(bundle != null, "FAIL: bundle loaded")

	var validator := _ProfileValidatorScript.new()
	var val_res = validator.validate(bundle)
	assert(val_res.is_valid, "FAIL: bundle validation failed: %s" % str(val_res.errors))

	# 1. Crypt tiene policy con normal y cracked
	var crypt = bundle.get_room(&"crypt")
	assert(crypt != null, "FAIL: crypt room exists")
	assert(crypt.architecture != null, "FAIL: crypt architecture exists")
	assert(crypt.architecture.wall_variants != null, "FAIL: crypt wall_variants exists")
	assert(crypt.architecture.wall_variants.enabled == true, "FAIL: crypt wall_variants enabled")
	assert(crypt.architecture.wall_variants.allowed.has(&"cracked"), "FAIL: crypt allowed cracked")
	assert(crypt.architecture.wall_variants.weights[&"cracked"] == 20.0, "FAIL: crypt cracked weight")

	# 2. Royal Tomb tiene policy con normal y ornate
	var royal_tomb = bundle.get_room(&"royal_tomb")
	assert(royal_tomb != null, "FAIL: royal_tomb room exists")
	assert(royal_tomb.architecture.wall_variants != null, "FAIL: royal_tomb wall_variants exists")
	assert(royal_tomb.architecture.wall_variants.allowed.has(&"ornate"), "FAIL: royal_tomb allowed ornate")
	assert(royal_tomb.architecture.wall_variants.weights[&"ornate"] == 20.0, "FAIL: royal_tomb ornate weight")

	print("  [OK] Wall variant policies loaded from room JSON profiles and validated.")
	print("==================================================================")
	print("[PASS] test_wall_variant_profile_resolution passed successfully!")
	print("==================================================================")
	quit(0)
