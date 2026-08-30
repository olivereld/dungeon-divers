extends SceneTree

const _LabConfigScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_configuration.gd")
const _LabControllerScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_controller.gd")

func _init() -> void:
	print("--- Running test_dungeon_lab_controller ---")
	var cfg = _LabConfigScript.new()
	cfg.seed = 100001
	cfg.generator_type = "Hybrid"
	cfg.archetype_id = &"necropolis"
	cfg.grid_size = Vector2i(64, 64)
	cfg.floor_count = 2

	var d_cfg = cfg.to_dungeon_config()
	assert(d_cfg.seed == 100001, "FAIL: seed mismatch")
	assert(d_cfg.algorithm == "Hybrid", "FAIL: algorithm mismatch")
	assert(cfg.validate().is_empty(), "FAIL: valid config should have no validation errors")

	var bad_cfg = _LabConfigScript.new()
	bad_cfg.grid_size = Vector2i(0, 0)
	bad_cfg.floor_count = 0
	var errors = bad_cfg.validate()
	assert(not errors.is_empty(), "FAIL: invalid config must report errors")

	var controller = _LabControllerScript.new()
	var failed_reason: String = ""
	controller.generation_failed.connect(func(reason: String): failed_reason = reason)

	var res = controller.generate_dungeon(cfg)
	assert(res != null and res.has("floors"), "FAIL: generation must return floors dict")
	assert(res["floors"].size() == 2, "FAIL: multi-floor must produce 2 floors")

	controller.set_current_floor(1)
	var floor_res = controller.get_current_floor_result()
	assert(floor_res != null, "FAIL: get_current_floor_result must return the selected floor")

	print("PASS: test_dungeon_lab_controller passed!")
	quit(0)
