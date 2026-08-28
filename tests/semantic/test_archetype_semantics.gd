extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_archetype_semantics ---")
	print("==================================================================")

	var loader := ProfileLoaderScript.new()
	var pipeline := DungeonPipelineScript.new()
	var orchestrator := SemanticOrchestratorScript.new()

	var available_archetypes = loader.list_available_archetypes()
	assert(not available_archetypes.is_empty(), "FAIL: Archetype catalog must discover available archetypes")

	# Validar de forma completamente dinámica para TODOS los arquetipos descubiertos
	for arch_id in available_archetypes:
		var bundle = loader.load_full_archetype_bundle(str(arch_id))
		assert(bundle != null and bundle.archetype != null, "FAIL: Must load valid bundle for %s" % str(arch_id))
		assert(bundle.archetype.schema_version == 1, "FAIL: Archetype must have schema_version 1")

		var declared_rooms = bundle.rooms.keys()
		assert(not declared_rooms.is_empty(), "FAIL: Archetype %s must declare rooms" % str(arch_id))

		for test_seed in [1010, 2020, 3030]:
			var cfg := DungeonConfigScript.new()
			cfg.seed = test_seed
			cfg.archetype_id = arch_id
			var d_res = pipeline.generate(cfg)
			assert(d_res != null and d_res.grid != null, "FAIL: Pipeline generation failed for archetype %s" % str(arch_id))

			var sem_res = orchestrator.generate_semantics(d_res, cfg)
			assert(sem_res != null and sem_res.gameplay_valid, "FAIL: Semantic generation failed for archetype %s" % str(arch_id))
			assert(sem_res.archetype_id == arch_id, "FAIL: Semantic result archetype_id must match requested archetype")

			# Verificar que todos los propósitos asignados sean semánticamente válidos según el arquetipo
			for r_id in sem_res.room_purposes:
				var assigned_purpose: StringName = sem_res.get_room_purpose(r_id)
				assert(assigned_purpose != &"", "FAIL: Room %d has empty purpose" % r_id)

				# El propósito asignado debe existir en las salas del arquetipo o en su mapa de distribución/pesos
				var is_known: bool = bundle.rooms.has(assigned_purpose) or \
					bundle.archetype.purpose_weights.has(assigned_purpose) or \
					bundle.archetype.room_purpose_distribution.has(assigned_purpose) or \
					assigned_purpose == &"generic"
				assert(is_known, "FAIL: Assigned purpose '%s' is not defined in archetype '%s'" % [str(assigned_purpose), str(arch_id)])

		print("  [OK] Archetype semantic validation passed for: %s" % str(arch_id))

	print("[PASS] test_archetype_semantics completed successfully!")
	quit(0)
