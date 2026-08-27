extends SceneTree

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const _SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const _DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const _BiomeProfileScript = preload("res://src/dungeon_generator/presentation/biome_profile.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_debug_royal_tomb_generation ---")
	print("==================================================================")

	var pipeline := _DungeonPipelineScript.new()
	var sem_orchestrator := _SemanticOrchestratorScript.new()
	var builder := _DungeonPresentationBuilderScript.new()

	var tested_royal_tombs: int = 0

	for s in range(100):
		var seed_val: int = 5000 + s
		var config := _DungeonConfigScript.new()
		config.grid_width = 48
		config.grid_height = 48
		config.seed = seed_val
		config.dungeon_archetype = 1 # MAUSOLEUM

		var d_res = pipeline.generate(config)
		if d_res == null:
			continue

		var sem_res = sem_orchestrator.generate_semantics(d_res, config)
		if sem_res == null:
			continue

		for room in sem_res.rooms:
			var purpose: int = sem_res.room_purposes.get(room.id, 0)
			if purpose == _RoomPurposeScript.Type.ROYAL_TOMB:
				tested_royal_tombs += 1
				print("\n>> Checking Seed %d - Royal Tomb Room %d (Rect: %s)" % [seed_val, room.id, str(room.rect)])

				var root := Node3D.new()
				var pres_res = builder.build_presentation(sem_res, root, _BiomeProfileScript.new(), config)

				var room_props: Array = []
				for entity in pres_res.spawned_entities:
					if entity != null and entity.has_meta("room_id") and entity.get_meta("room_id") == room.id:
						room_props.append(entity.name)

				print("   Props spawned in Royal Tomb: ", room_props)

				var has_sarc: bool = false
				var pillar_count: int = 0
				for p in room_props:
					if p.contains("sarcophagus"):
						has_sarc = true
					elif p.contains("pillar_stone"):
						pillar_count += 1

				print("   Sarcophagus: %s | Pillars: %d" % [str(has_sarc), pillar_count])
				assert(has_sarc, "FAIL: Royal Tomb must spawn central sarcophagus!")
				assert(pillar_count == 4, "FAIL: Royal Tomb must spawn 4 pillars, got %d" % pillar_count)
				root.free()

	print("\n  [OK] Successfully validated %d Royal Tomb rooms across seeds!" % tested_royal_tombs)
	print("==================================================================")
	print("[PASS] test_debug_royal_tomb_generation completed successfully!")
	print("==================================================================")
	quit(0)
