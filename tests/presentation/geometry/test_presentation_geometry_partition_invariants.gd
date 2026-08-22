extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const PresentationContextBuilderScript = preload("res://src/presentation/architecture/presentation_context_builder.gd")
const PresentationGeometryPartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_presentation_geometry_partition_invariants ---")
	print("==================================================================")

	var cfg := DungeonConfigScript.new()
	cfg.seed = 998877
	cfg.use_fixed_seed = true
	var pipeline := DungeonPipelineScript.new()
	var res = pipeline.generate(cfg, 5, true)
	var orchestrator := SemanticOrchestratorScript.new()
	var sem = orchestrator.generate_semantics(res, cfg)

	var initial_byte_buffer = res.grid.get_raw_byte_buffer()

	var ctx_builder := PresentationContextBuilderScript.new()
	var contexts = ctx_builder.build_contexts(sem)

	var partition := PresentationGeometryPartitionScript.new()
	partition.build_partition(res.grid, contexts, sem)

	# 1. Invariante de Inmutabilidad de CellGrid
	assert(res.grid.get_raw_byte_buffer() == initial_byte_buffer, "FAIL: CellGrid was mutated by partition!")

	# 2. Invariante de Conteo de Salas
	var rooms = partition.get_rooms()
	assert(rooms.size() == res.rooms.size(), "FAIL: Rooms count mismatch")

	# 3. Invariante de Disyunción entre Salas (Room A ∩ Room B = ∅)
	var seen_room_cells: Dictionary = {} # Vector2i -> int (room_id)
	for r_geom in rooms:
		for cell in r_geom.floor_cells:
			assert(not seen_room_cells.has(cell), "FAIL: Overlapping room cells detected!")
			seen_room_cells[cell] = r_geom.room_id

	# 4. Invariante de Disyunción entre Salas y Corredores (Rooms ∩ Corridors = ∅)
	for c_cell in partition.corridor_floor_cells:
		assert(not seen_room_cells.has(c_cell), "FAIL: Corridor cell overlaps with room floor!")

	# 5. Invariante de Cobertura Total de Celdas Transitables
	var total_walkable_grid: int = 0
	for y in range(res.grid.height):
		for x in range(res.grid.width):
			var p := Vector2i(x, y)
			if res.grid.is_walkable(p):
				total_walkable_grid += 1
				var is_in_room = seen_room_cells.has(p)
				var is_in_corridor = partition.corridor_floor_cells.has(p)
				assert(is_in_room or is_in_corridor, "FAIL: Walkable cell unassigned!")
				assert(not (is_in_room and is_in_corridor), "FAIL: Walkable cell assigned to both room and corridor!")

	var total_partition_floor: int = seen_room_cells.size() + partition.corridor_floor_cells.size()
	assert(total_walkable_grid == total_partition_floor, "FAIL: Total walkable count mismatch")

	# 6. Verificación de Indexación O(1) (get_room_id_at & is_room_cell)
	for cell in seen_room_cells:
		var expected_id: int = seen_room_cells[cell]
		assert(partition.get_room_id_at(cell) == expected_id, "FAIL: O(1) index mismatch")
		assert(partition.is_room_cell(cell), "FAIL: is_room_cell returned false for room cell")

	for c_cell in partition.corridor_floor_cells:
		assert(partition.get_room_id_at(c_cell) == -1, "FAIL: Corridor cell must return -1 for room_id")
		assert(not partition.is_room_cell(c_cell), "FAIL: is_room_cell returned true for corridor cell")

	print("  [OK] Invariant 1: CellGrid immutability preserved.")
	print("  [OK] Invariant 2: Room disjointness (Room A ∩ Room B = ∅).")
	print("  [OK] Invariant 3: Corridor disjointness (Rooms ∩ Corridors = ∅).")
	print("  [OK] Invariant 4: Total coverage of all walkable cells.")
	print("  [OK] Invariant 5: O(1) spatial index (get_room_id_at & is_room_cell).")
	print("[PASS] test_presentation_geometry_partition_invariants completed successfully.")
	quit(0)
