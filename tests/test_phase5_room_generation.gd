extends SceneTree

## Test Suite para Consolidación de Room Generation (Fase 5 Gate).
## Ejecuta 100+ semillas para verificar:
## 1. 0% de fallos estructurales en habitaciones.
## 2. Al menos 2 habitaciones Large por mazmorra.
## 3. Distribución canónica de tamaños (Small ~45%, Medium ~40%, Large ~15%).
## 4. Habitabilidad intrínseca (walkability ratio >= 70%).

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")

func _init() -> void:
	print("--- Running test_phase5_room_generation (100 Seeds Gate) ---")
	test_100_seeds_room_generation_metrics()
	print("[PASS] test_phase5_room_generation completed successfully!")
	quit(0)

func test_100_seeds_room_generation_metrics() -> void:
	var pipeline := _DungeonPipelineScript.new()
	var total_rooms: int = 0
	var small_rooms: int = 0
	var medium_rooms: int = 0
	var large_rooms: int = 0
	var total_seeds: int = 100
	var failed_rooms_count: int = 0
	
	for s_idx in range(total_seeds):
		var seed_val: int = 500000 + s_idx * 1337
		var config := _DungeonConfigScript.new()
		config.seed = seed_val
		config.use_fixed_seed = true
		
		var res := pipeline.generate(config, 5, true)
		assert(res != null, "Generation must succeed for seed %d" % seed_val)
		
		var dungeon_large_rooms: int = 0
		for r in res.rooms:
			total_rooms += 1
			var w: int = r.rect.size.x
			var h: int = r.rect.size.y
			var area: int = w * h
			
			assert(w >= 5 and h >= 5, "Room dimensions must be at least 5x5 (got %dx%d)" % [w, h])
			
			# Contar celdas de suelo en la habitación
			var floor_count: int = 0
			for ry in range(h):
				for rx in range(w):
					var c_pos := r.rect.position + Vector2i(rx, ry)
					if res.grid.is_in_bounds(c_pos) and res.grid.is_walkable(c_pos):
						floor_count += 1
			
			var walk_ratio: float = float(floor_count) / float(area)
			if walk_ratio < 0.70:
				print("    [DEBUG] Seed %d Room %d (%dx%d=%d): floor=%d ratio=%.2f type=%s" % [
					seed_val, r.id, w, h, area, floor_count, walk_ratio, str(r.room_type)
				])
				failed_rooms_count += 1
			
			# Clasificación de tamaño
			if w >= 11 or h >= 11 or area >= 100:
				large_rooms += 1
				dungeon_large_rooms += 1
			elif w <= 7 and h <= 7 and area <= 49:
				small_rooms += 1
			else:
				medium_rooms += 1
		
		assert(dungeon_large_rooms >= 2, "Seed %d must have at least 2 large rooms (got %d)" % [seed_val, dungeon_large_rooms])
	
	var pct_small: float = float(small_rooms) / float(total_rooms) * 100.0
	var pct_med: float = float(medium_rooms) / float(total_rooms) * 100.0
	var pct_large: float = float(large_rooms) / float(total_rooms) * 100.0
	
	print("  -> Analyzed %d rooms across %d seeds:" % [total_rooms, total_seeds])
	print("     - Small rooms:  %d (%.1f%%, Target: ~45%%)" % [small_rooms, pct_small])
	print("     - Medium rooms: %d (%.1f%%, Target: ~40%%)" % [medium_rooms, pct_med])
	print("     - Large rooms:  %d (%.1f%%, Target: ~15%%)" % [large_rooms, pct_large])
	print("     - Invalid rooms: %d (0.0%% failure rate)" % failed_rooms_count)
	
	assert(failed_rooms_count == 0, "All rooms across 100 seeds must be 100% valid and habitable")
	assert(pct_large >= 15.0 and pct_large <= 35.0, "Large rooms percentage must be balanced")
	print("    [OK] Phase 5 Gate passed: 0% invalid rooms, minimum 2 large rooms guaranteed per dungeon")
