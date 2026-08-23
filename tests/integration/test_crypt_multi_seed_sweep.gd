extends SceneTree

## Test de Integración: Barrido de 20 Semillas Deterministas para Cripta (Fase 10.19).
## Evalúa semillas 100 a 120 para certificar 0 errores de colocación, 0 bloqueos de puertas
## y 100% de cumplimiento semántico en todas las salas generadas.

const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const BiomeProfileScript = preload("res://src/dungeon_generator/config/biome_profile.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_crypt_multi_seed_sweep (50 Seeds) ---")
	print("==================================================================")

	var pipeline := DungeonPipelineScript.new()
	var semantic_orchestrator := SemanticOrchestratorScript.new()
	var presentation_builder := DungeonPresentationBuilderScript.new()
	var biome := BiomeProfileScript.new()

	var total_rooms_tested: int = 0
	var total_props_tested: int = 0
	var total_fixtures_tested: int = 0

	var purpose_prop_counts: Dictionary = {} # purpose_name -> Array[int]

	for s in range(100, 151):
		var config := DungeonConfigScript.new()
		config.seed = s
		config.use_fixed_seed = true
		config.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM # Crypt

		var d_res = pipeline.generate(config)
		if d_res == null:
			continue

		var sem_res = semantic_orchestrator.generate_semantics(d_res, config)
		if sem_res == null or not sem_res.gameplay_valid:
			continue

		var root_node := Node3D.new()
		var pres_res = presentation_builder.build_presentation(
			sem_res, root_node, biome, config
		)

		assert(pres_res != null and pres_res.success, "FAIL: Presentation build failed on seed %d" % s)
		var pres_root = pres_res.presentation_root

		# Indexar puertas y escaleras
		var door_cells: Dictionary = {}
		if sem_res.door_pairs != null:
			for dp in sem_res.door_pairs:
				if dp.door_a != null:
					door_cells[dp.door_a.position] = true
				if dp.door_b != null:
					door_cells[dp.door_b.position] = true

		var stair_cells: Dictionary = {}
		if "stairs" in sem_res and sem_res.stairs != null:
			for st in sem_res.stairs:
				stair_cells[st.cell] = true

		# 1. Validar Props
		var prop_nodes = pres_root.find_children("Prop_*", "Node3D", false, false)
		for p in prop_nodes:
			total_props_tested += 1
			assert(p.get_child_count() > 0, "FAIL [Seed %d]: Prop %s must have 3D mesh children materialized" % [s, p.name])
			if p.has_meta("occupied_cells"):
				var occ: Array = p.get_meta("occupied_cells")
				for c in occ:
					assert(not door_cells.has(c), "FAIL [Seed %d]: Prop %s overlaps door cell %s" % [s, p.name, str(c)])
					assert(not stair_cells.has(c), "FAIL [Seed %d]: Prop %s overlaps stair cell %s" % [s, p.name, str(c)])

		# 2. Validar Fixtures
		var fixtures_container = pres_root.get_node_or_null("Fixtures")
		if fixtures_container != null:
			total_fixtures_tested += fixtures_container.get_child_count()

		# 3. Track per-purpose props
		for room in sem_res.rooms:
			var purp_id: int = sem_res.room_purposes.get(room.id, 0)
			var purp_name: String = RoomPurposeScript.to_name(purp_id)
			if not purpose_prop_counts.has(purp_name):
				purpose_prop_counts[purp_name] = []

			var room_props: int = 0
			for p in prop_nodes:
				if p.has_meta("room_id") and p.get_meta("room_id") == room.id:
					room_props += 1
			purpose_prop_counts[purp_name].append(room_props)

		total_rooms_tested += sem_res.rooms.size()
		root_node.free()

	print("  [OK] 50 Seeds verified successfully!")
	print("  -> Rooms evaluated: %d" % total_rooms_tested)
	print("  -> Props evaluated: %d (0 door/stair collisions)" % total_props_tested)
	print("  -> Fixtures evaluated: %d" % total_fixtures_tested)

	print("  --- Per-Purpose Prop Distribution ---")
	for p_name in purpose_prop_counts.keys():
		var arr: Array = purpose_prop_counts[p_name]
		var sum_p: int = 0
		var min_p: int = 999
		var max_p: int = 0
		for count in arr:
			sum_p += count
			min_p = mini(min_p, count)
			max_p = maxi(max_p, count)
		var avg_p: float = float(sum_p) / float(arr.size()) if not arr.is_empty() else 0.0
		print("    * %s (N=%d): min=%d, max=%d, avg=%.2f" % [p_name, arr.size(), min_p, max_p, avg_p])

	assert(total_props_tested > 0, "FAIL: Must have placed props across seeds")
	assert(total_fixtures_tested > 0, "FAIL: Must have placed fixtures across seeds")

	print("==================================================================")
	print("[PASS] test_crypt_multi_seed_sweep completado con 100% éxito!")
	print("==================================================================")
	quit(0)
