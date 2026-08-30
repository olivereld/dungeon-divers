extends SceneTree

const _PipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")

func _init() -> void:
	print("--- Running test_rng_isolation ---")
	var pipeline = _PipelineScript.new()
	var test_seed: int = 100001

	var config := DungeonConfig.new()
	config.seed = test_seed
	config.algorithm = "Hybrid"
	config.archetype_id = &"necropolis"
	config.grid_width = 64
	config.grid_height = 64

	# 1. First generation of seed X
	var res1 = pipeline.generate(config)
	assert(res1 != null, "FAIL: first generation failed")
	var fp1 = _hash_result(res1)

	# 2. Run 49 unrelated generations with random seeds
	for i in range(49):
		var noise_cfg := DungeonConfig.new()
		noise_cfg.seed = 200000 + i * 17
		noise_cfg.algorithm = "Hybrid"
		noise_cfg.archetype_id = &"necropolis"
		noise_cfg.grid_width = 64
		noise_cfg.grid_height = 64
		pipeline.generate(noise_cfg)

	# 3. Regenerate seed X
	var res2 = pipeline.generate(config)
	assert(res2 != null, "FAIL: second generation failed")
	var fp2 = _hash_result(res2)

	assert(fp1 == fp2, "FAIL: RNG state leakage! Fingerprint 1 (%s) != Fingerprint 2 (%s)" % [fp1, fp2])
	print("PASS: test_rng_isolation passed! Fingerprint match: %s" % fp1)
	quit(0)

func _hash_result(res) -> String:
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)

	# Hash rooms
	var room_str := ""
	for r in res.rooms:
		room_str += "%d:%s:%s:%s;" % [r.id, str(r.rect), str(r.room_type), str(r.custom_data.get("resolved_template_id", ""))]
	ctx.update(room_str.to_utf8_buffer())

	# Hash grid
	var grid_bytes := PackedByteArray()
	for y in range(res.grid.height):
		for x in range(res.grid.width):
			grid_bytes.append(res.grid.get_cell(Vector2i(x, y)))
	ctx.update(grid_bytes)

	var digest := ctx.finish()
	return digest.hex_encode()
