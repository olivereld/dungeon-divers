extends SceneTree

## Test Suite para DungeonGenerationContext (Fase 2).
## Valida el encapsulamiento de estado lógico de una generación,
## métodos de conversión limpia a DungeonResult y trazabilidad de diagnósticos.

const _DungeonGenerationContextScript = preload("res://src/dungeon_generator/core/data/dungeon_generation_context.gd")
const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const _CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")
const _RoomDataScript = preload("res://src/dungeon_generator/core/data/room_data.gd")
const _RoomConnectionScript = preload("res://src/dungeon_generator/core/data/room_connection.gd")

func _init() -> void:
	print("--- Running test_phase2_generation_context ---")
	test_context_initialization()
	test_context_state_recording()
	test_context_conversion_to_dungeon_result()
	test_context_failure_handling()
	print("[PASS] test_phase2_generation_context completed successfully!")
	quit(0)

func test_context_initialization() -> void:
	print("  -> Testing context initialization...")
	var cfg := _DungeonConfigScript.new()
	var ctx := _DungeonGenerationContextScript.new(cfg, 123456, 0)
	assert(ctx.config == cfg, "Config reference must match")
	assert(ctx.base_seed == 123456, "Base seed must match")
	assert(ctx.attempt == 0, "Attempt must match")
	assert(ctx.is_attempt_failed == false, "Initial attempt must not be failed")
	print("    [OK] Context initialized with clean state")

func test_context_state_recording() -> void:
	print("  -> Testing context state recording and metrics...")
	var cfg := _DungeonConfigScript.new()
	var ctx := _DungeonGenerationContextScript.new(cfg, 123456, 0)
	
	ctx.record_timing("mission_grammar", 1.5)
	ctx.record_timing("room_shape", 3.2)
	assert(ctx.stage_timings_ms["mission_grammar"] == 1.5, "Timing must be recorded accurately")
	assert(ctx.stage_timings_ms["room_shape"] == 3.2, "Timing must be recorded accurately")
	
	ctx.record_repair("room_repair", 9999, true, { "room_id": 1 })
	assert(ctx.repair_seed_chain.size() == 1, "Repair record must be appended")
	assert(ctx.repair_seed_chain[0]["stage"] == "room_repair", "Repair stage must match")
	assert(ctx.repair_seed_chain[0]["success"] == true, "Repair success must match")
	print("    [OK] Timing and repair recording work cleanly")

func test_context_conversion_to_dungeon_result() -> void:
	print("  -> Testing to_dungeon_result() conversion...")
	var cfg := _DungeonConfigScript.new()
	var ctx := _DungeonGenerationContextScript.new(cfg, 123456, 1)
	ctx.grid = _CellGridScript.new(32, 32, _CellGridScript.CellType.WALL)
	var room := _RoomDataScript.new(1, Rect2i(2, 2, 6, 6), &"combat")
	ctx.rooms.append(room)
	var conn := _RoomConnectionScript.new(0, 1, 2, true)
	ctx.connections.append(conn)
	ctx.fitness_score = 0.85
	
	var res := ctx.to_dungeon_result()
	assert(res != null, "DungeonResult must not be null")
	assert(res.grid == ctx.grid, "Result grid must match context grid")
	assert(res.rooms.size() == 1, "Result rooms count must match")
	assert(res.connections.size() == 1, "Result connections count must match")
	assert(res.fitness_score == 0.85, "Fitness score must match")
	assert(res.seed_used == 123456, "Seed used must match")
	print("    [OK] Conversion to DungeonResult is faithful and complete")

func test_context_failure_handling() -> void:
	print("  -> Testing context failure handling...")
	var cfg := _DungeonConfigScript.new()
	var ctx := _DungeonGenerationContextScript.new(cfg, 123456, 2)
	assert(ctx.is_attempt_failed == false, "Must start as not failed")
	ctx.mark_attempt_failed("ENTRANCE_SOLVER_NO_CANDIDATE")
	assert(ctx.is_attempt_failed == true, "Must be flagged as failed")
	assert(ctx.failure_reason == "ENTRANCE_SOLVER_NO_CANDIDATE", "Failure reason must match")
	print("    [OK] Failure handling is explicit and traceable")
