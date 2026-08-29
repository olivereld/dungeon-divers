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

	for r in res.rooms:
		print("--- Checking Room %d: rect=%s type=%s ---" % [r.id, str(r.rect), r.room_type])
		for tpl in bundle.template_registry.get_all_templates():
			var val = validator.validate_all(tpl, r.rect, [])
			var comp = matcher.is_compatible(tpl, r, null, [])
			if not comp:
				print("  Tpl %s: compatible=false (geom_val=%s, errors=%s)" % [tpl.id, val.is_valid, str(val.errors)])
			else:
				print("  Tpl %s: COMPATIBLE!" % tpl.id)

	print("PASS: test_tomb_template_in_pipeline passed successfully!")
	quit(0)
