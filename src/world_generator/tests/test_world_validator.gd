extends SceneTree

func _init() -> void:
	var result := WorldPipeline.generate(12345, TaigaWorldProfile.new())
	var report := WorldValidator.validate(result)
	assert(report["valid"], "Validation failed: %s" % str(report["errors"]))
	assert(report["walkable_ratio"] >= 0.60)
	print("test_world_validator: OK")
	quit()
