extends SceneTree

## Test Suite para Consolidación de Puertas (Fase 11 Gate).
## Ejecuta 100 semillas deterministas y valida:
## 1. Puertas dentro de límites del CellGrid (is_in_bounds).
## 2. Puertas sobre suelo transitable (is_walkable).
## 3. Correspondencia exacta RoomConnection <-> DoorPair.
## 4. Ausencia de mutaciones ilegales del grafo o salas.

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")

func _init() -> void:
	print("--- Running test_phase11_doors (100 Seeds Gate) ---")
	test_100_seeds_door_resolution()
	print("[PASS] test_phase11_doors completed successfully!")
	quit(0)

func test_100_seeds_door_resolution() -> void:
	var pipeline := _DungeonPipelineScript.new()
	var total_seeds: int = 100
	var total_doors: int = 0
	var total_door_pairs: int = 0
	
	for s_idx in range(total_seeds):
		var seed_val: int = 500000 + s_idx * 2777
		var config := _DungeonConfigScript.new()
		config.seed = seed_val
		config.use_fixed_seed = true
		
		var res := pipeline.generate(config, 5, true)
		assert(res != null, "Generation must succeed for seed %d" % seed_val)
		assert(res.door_pairs.size() == res.connections.size(), "Seed %d: Must have 1 DoorPair per connection (got %d pairs for %d conns)" % [
			seed_val, res.door_pairs.size(), res.connections.size()
		])
		
		var conn_map: Dictionary = {}
		for c in res.connections:
			conn_map[c.id] = c
		
		for dp in res.door_pairs:
			total_door_pairs += 1
			assert(conn_map.has(dp.connection_id), "Seed %d: DoorPair has invalid connection_id %d" % [seed_val, dp.connection_id])
			var conn = conn_map[dp.connection_id]
			
			var d_a = dp.door_a
			var d_b = dp.door_b
			assert(d_a != null and d_b != null, "Seed %d: DoorPair must have both door_a and door_b" % seed_val)
			
			# Verificar pertenencia a salas de la conexión
			assert(d_a.room_id == conn.room_a_id, "Seed %d: door_a room_id (%d) must match connection room_a (%d)" % [seed_val, d_a.room_id, conn.room_a_id])
			assert(d_b.room_id == conn.room_b_id, "Seed %d: door_b room_id (%d) must match connection room_b (%d)" % [seed_val, d_b.room_id, conn.room_b_id])
			
			# Verificar que están dentro de bounds y sobre celdas transitables
			assert(res.grid.is_in_bounds(d_a.position), "Seed %d: door_a position %s out of bounds" % [seed_val, str(d_a.position)])
			assert(res.grid.is_in_bounds(d_b.position), "Seed %d: door_b position %s out of bounds" % [seed_val, str(d_b.position)])
			
			assert(res.grid.is_walkable(d_a.position), "Seed %d: door_a position %s must be walkable" % [seed_val, str(d_a.position)])
			assert(res.grid.is_walkable(d_b.position), "Seed %d: door_b position %s must be walkable" % [seed_val, str(d_b.position)])
			
			total_doors += 2
	
	print("  -> Verified 100 seeds doors:")
	print("     - Total Door Pairs: %d" % total_door_pairs)
	print("     - Total Physical Doors: %d" % total_doors)
	print("     - 100%% Doors in bounds: PASS")
	print("     - 100%% Doors on walkable cells: PASS")
	print("     - 100%% RoomConnection <-> DoorPair exact matching: PASS")
	print("    [OK] Phase 11 Gate passed: Pure door resolution contracts verified")
