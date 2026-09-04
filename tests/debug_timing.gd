extends SceneTree

func _init():
	var pipeline = load("res://src/dungeon_generator/core/dungeon_pipeline.gd").new()
	var config_cls = load("res://src/dungeon_generator/config/dungeon_config.gd")
	for s in [10001, 10002, 10003, 10004, 10005]:
		for ver in [1, 2]:
			var cfg = config_cls.new()
			cfg.seed = s
			cfg.grid_width = 64
			cfg.grid_height = 64
			cfg.composition_version = ver
			var t0 = Time.get_ticks_msec()
			var res = pipeline.generate(cfg)
			var wall_ms = Time.get_ticks_msec() - t0
			print("Seed %d V%d: wall=%.1fms attempts=%s total_res=%.1fms" % [
				s, ver, wall_ms, str(res.seed_trace if res else "FAIL"), res.generation_time_ms if res else -1.0
			])
	quit()
