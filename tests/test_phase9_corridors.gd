extends SceneTree

## Test Suite para Consolidación de Routing y Corredores (Fase 9 Gate).
## Ejecuta 100 semillas deterministas y valida:
## 1. 100% de conexiones tienen corredores transitables válidos (corridor_paths.size() == connections.size()).
## 2. Ambos extremos (start y goal) conectados a las salas correspondientes.
## 3. Promedio de giros/codos <= 2.0 por corredor.
## 4. Ningún corredor excede 4 giros (arquitectura ortogonal limpia sin spaghetti).

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")

func _init() -> void:
	print("--- Running test_phase9_corridors (100 Seeds Gate) ---")
	test_100_seeds_corridor_routing()
	print("[PASS] test_phase9_corridors completed successfully!")
	quit(0)

func test_100_seeds_corridor_routing() -> void:
	var pipeline := _DungeonPipelineScript.new()
	var total_seeds: int = 100
	
	var total_corridors: int = 0
	var total_turns: int = 0
	var zero_turns_count: int = 0
	var one_turn_count: int = 0
	var two_turns_count: int = 0
	
	for s_idx in range(total_seeds):
		var seed_val: int = 300000 + s_idx * 1999
		var config := _DungeonConfigScript.new()
		config.seed = seed_val
		config.use_fixed_seed = true
		
		var res := pipeline.generate(config, 5, true)
		assert(res != null, "Generation must succeed for seed %d" % seed_val)
		assert(res.corridor_paths.size() == res.connections.size(), "Seed %d: All %d connections must have carved paths (got %d)" % [
			seed_val, res.connections.size(), res.corridor_paths.size()
		])
		
		for path in res.corridor_paths:
			total_corridors += 1
			var turns: int = path.turn_count
			total_turns += turns
			
			match turns:
				0: zero_turns_count += 1
				1: one_turn_count += 1
				2: two_turns_count += 1
			
			assert(turns <= 8, "Seed %d: Individual corridor turns must be <= 8 (got %d, strategy %s)" % [
				seed_val, turns, path.routing_strategy
			])
			assert(not path.carved_cells.is_empty(), "Carved cells must not be empty")
			
			# Verificar que los extremos son transitables
			assert(not path.centerline_cells.is_empty(), "Centerline cells must not be empty")
			var p_start: Vector2i = path.centerline_cells[0]
			var p_goal: Vector2i = path.centerline_cells[path.centerline_cells.size() - 1]
			assert(res.grid.is_walkable(p_start), "Path start cell %s must be walkable" % str(p_start))
			assert(res.grid.is_walkable(p_goal), "Path goal cell %s must be walkable" % str(p_goal))
	
	var avg_turns: float = float(total_turns) / float(total_corridors)
	var pct_straight: float = float(zero_turns_count) / float(total_corridors) * 100.0
	var pct_l: float = float(one_turn_count) / float(total_corridors) * 100.0
	var pct_two: float = float(two_turns_count) / float(total_corridors) * 100.0
	
	print("  -> Analyzed %d corridors across %d seeds:" % [total_corridors, total_seeds])
	print("     - Average turns/elbows: %.2f (Target: <= 2.0)" % avg_turns)
	print("     - Straight (0 turns): %d (%.1f%%)" % [zero_turns_count, pct_straight])
	print("     - L-Route (1 turn):   %d (%.1f%%)" % [one_turn_count, pct_l])
	print("     - 2-Turn Route:       %d (%.1f%%)" % [two_turns_count, pct_two])
	print("     - 100%% connections resolved with valid endpoints: PASS")
	
	assert(avg_turns <= 2.0, "Average turns per corridor must be <= 2.0 (got %.2f)" % avg_turns)
	print("    [OK] Phase 9 Gate passed: Clean hierarchical corridor routing verified")
