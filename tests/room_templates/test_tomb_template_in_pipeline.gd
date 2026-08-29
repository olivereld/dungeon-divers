extends SceneTree

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

func _init() -> void:
	print("--- Running test_tomb_template_in_pipeline ---")
	var pipeline := _DungeonPipelineScript.new()
	var val_res = pipeline.load_profiles("necropolis")
	print("Profile validation result: is_valid=", val_res.is_valid, " summary: ", val_res.to_summary_string())
	var bundle = pipeline.get_profile_bundle()
	print("Bundle: ", bundle)
	print("Loaded templates in bundle registry: ", bundle.template_registry.get_all_templates().map(func(t): return t.id))

	var matcher := RoomTemplateMatcher.new(bundle.template_registry)
	var validator := RoomTemplateValidator.new()

	var config := DungeonConfig.new()
	config.algorithm = "Template"
	config.seed = 431433195
	config.grid_width = 64
	config.grid_height = 64

	var res = pipeline.generate(config)
	assert(res != null, "FAIL: pipeline generation failed")

	var resolver := RoomTemplateResolver.new(bundle.template_registry)
	var boss_room = res.rooms[5]
	var boss_profile = bundle.get_room("royal_tomb")
	var chosen_tpl = resolver.resolve_template(boss_room, boss_profile, [], 1337)
	print(">>> Boss Room chosen template: ", chosen_tpl.id)

	print("PASS: test_tomb_template_in_pipeline passed successfully!")
	quit(0)
