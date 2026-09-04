extends SceneTree

func _init():
	var pipeline = load("res://src/dungeon_generator/core/dungeon_pipeline.gd").new()
	var config_cls = load("res://src/dungeon_generator/config/dungeon_config.gd")
	var SpatialIntentBuilderScript = load("res://src/dungeon_generator/core/grammars/spatial_intent_builder.gd")
	
	for s in [10001]:
		for ver in [1, 2]:
			var cfg = config_cls.new()
			cfg.seed = s
			cfg.grid_width = 64
			cfg.grid_height = 64
			cfg.composition_version = ver
			var res = pipeline.generate(cfg)
			var intent = SpatialIntentBuilderScript.new().build(res.mission_graph)
			print("\n=== SEED %d V%d (Prog dir in comp: %s) ===" % [
				s, ver, str(res.metadata.get("progression_direction", "none"))
			])
			var room_by_node = {}
			for r in res.rooms:
				room_by_node[r.mission_node_id] = r
				
			var start_c = Vector2.ZERO
			for nid in intent.main_path:
				var r = room_by_node[nid]
				if start_c == Vector2.ZERO:
					start_c = r.get_center()
				print("Node %d (%s): center=(%d, %d), rect=%s" % [
					nid, r.room_type, r.get_center().x, r.get_center().y, str(r.rect)
				])
	quit()
