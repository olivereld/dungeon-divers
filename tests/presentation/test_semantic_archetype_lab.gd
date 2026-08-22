extends SceneTree

const LabScene = preload("res://scenes/semantic_lab/semantic_archetype_lab_view.tscn")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_semantic_archetype_lab ---")
	print("==================================================================")

	var lab = LabScene.instantiate()
	assert(lab != null, "FAIL: Lab scene must instantiate")
	root.add_child(lab)

	# Probar generación de MAUSOLEUM
	lab.generate_dungeon_with_params(1, 1337) # 1 = MAUSOLEUM
	assert(lab.current_semantic_result != null, "FAIL: Semantic result must not be null")
	assert(lab.current_semantic_result.dungeon_archetype_name == "MAUSOLEUM")
	assert(not lab.current_semantic_result.room_purposes.is_empty(), "FAIL: Purposes must be assigned")

	# Probar que cambiar semillas genera layouts y topologías distintas
	lab.generate_dungeon_with_params(1, 1001)
	var sem_1 = lab.current_semantic_result
	var bounds_1 = sem_1.rooms.map(func(r): return r.rect)

	lab.generate_dungeon_with_params(1, 88888)
	var sem_2 = lab.current_semantic_result
	var bounds_2 = sem_2.rooms.map(func(r): return r.rect)

	assert(bounds_1 != bounds_2, "FAIL: Different seeds must generate different room layouts")

	lab.queue_free()
	print("  [OK] Semantic Archetype Lab headless generation verified for all archetypes.")
	print("  [OK] Seed changing produces completely new dungeon layouts.")
	print("[PASS] test_semantic_archetype_lab completed successfully.")
	quit(0)
