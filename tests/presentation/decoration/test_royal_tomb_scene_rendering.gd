extends SceneTree

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const _SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const _DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const _BiomeProfileScript = preload("res://src/dungeon_generator/presentation/biome_profile.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_royal_tomb_scene_rendering ---")
	print("==================================================================")

	var config := _DungeonConfigScript.new()
	config.grid_width = 48
	config.grid_height = 48
	config.seed = 2026
	config.dungeon_archetype = 1 # MAUSOLEUM

	var pipeline := _DungeonPipelineScript.new()
	var d_res = pipeline.generate(config)
	assert(d_res != null, "FAIL: Pipeline generate failed")

	var sem_orchestrator := _SemanticOrchestratorScript.new()
	var sem_res = sem_orchestrator.generate_semantics(d_res, config)
	assert(sem_res != null, "FAIL: Semantic orchestration failed")

	var builder := _DungeonPresentationBuilderScript.new()
	var root := Node3D.new()
	var biome := _BiomeProfileScript.new()
	var pres_res = builder.build_presentation(sem_res, root, biome, config)
	assert(pres_res != null, "FAIL: Presentation build failed")

	# Find Boss / Royal Tomb room
	var royal_tomb_room_id: int = -1
	for room in sem_res.rooms:
		if room.room_type == &"goal" or room.room_type == &"boss":
			royal_tomb_room_id = room.id
			break

	print("  Royal Tomb Room ID: %d" % royal_tomb_room_id)

	var pillars_found: int = 0
	var sarcophagus_found: bool = false

	for entity in pres_res.spawned_entities:
		if entity != null:
			var entity_name := String(entity.name)
			if entity_name.begins_with("Prop_pillar_stone"):
				pillars_found += 1
				print("  [OK] Found 3D Pillar Instance: ", entity_name, " Position: ", entity.position)
				assert(entity.get_child_count() > 0, "FAIL: Pillar entity must contain 3D mesh children")
			elif entity_name.begins_with("Prop_sarcophagus"):
				sarcophagus_found = true
				print("  [OK] Found Central Sarcophagus Instance: ", entity_name, " Position: ", entity.position)

	print("  Total 3D pillar models found in dungeon: %d" % pillars_found)
	print("  Central Sarcophagus found: %s" % str(sarcophagus_found))

	assert(pillars_found > 0, "FAIL: Expected 3D pillar models in dungeon")
	assert(sarcophagus_found, "FAIL: Expected central sarcophagus in dungeon")

	print("==================================================================")
	print("[PASS] test_royal_tomb_scene_rendering passed successfully!")
	print("==================================================================")
	quit(0)
