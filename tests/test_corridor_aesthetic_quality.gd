extends SceneTree

## Test de métricas de calidad estética y configuración de corredores y puertas (Fase Refined).

const _CorridorPathScript = preload("res://src/dungeon_generator/core/data/corridor_path.gd")

func _init() -> void:
	print("--- Running test_corridor_aesthetic_quality (Task 1) ---")
	var cfg := DungeonConfig.new()

	# 1. Validar parámetros de calidad de corredores en DungeonConfig
	assert("corridor_turn_penalty" in cfg, "Config must have corridor_turn_penalty")
	assert("corridor_proximity_penalty" in cfg, "Config must have corridor_proximity_penalty")
	assert("corridor_max_preferred_turns" in cfg, "Config must have corridor_max_preferred_turns")
	assert("prefer_orthogonal_routes" in cfg, "Config must have prefer_orthogonal_routes")
	assert("allow_astar_fallback" in cfg, "Config must have allow_astar_fallback")

	# 2. Validar parámetros de calidad de puertas en DungeonConfig
	assert("minimum_corridor_door_spacing" in cfg, "Config must have minimum_corridor_door_spacing")
	assert("same_side_door_penalty" in cfg, "Config must have same_side_door_penalty")
	assert("corridor_door_proximity_penalty" in cfg, "Config must have corridor_door_proximity_penalty")
	assert("distribute_room_doors_across_sides" in cfg, "Config must have distribute_room_doors_across_sides")

	# 3. Validar valores por defecto razonables
	assert(cfg.corridor_turn_penalty >= 5.0, "Turn penalty should be >= 5.0")
	assert(cfg.corridor_max_preferred_turns >= 2, "Preferred turns should be >= 2")
	assert(cfg.minimum_corridor_door_spacing >= 3, "Corridor door spacing should be >= 3")
	assert(cfg.prefer_orthogonal_routes == true, "prefer_orthogonal_routes default must be true")

	# 4. Validar campos y constructor de CorridorPath
	var cl: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var path: _CorridorPathScript = _CorridorPathScript.new(1, 0, 1, cl, cl, 3.0, 0)
	assert("turn_count" in path, "CorridorPath must track turn_count")
	assert("straight_run_count" in path, "CorridorPath must track straight_run_count")
	assert("longest_straight_run" in path, "CorridorPath must track longest_straight_run")
	assert("routing_strategy" in path, "CorridorPath must track routing_strategy")

	path.turn_count = 1
	path.straight_run_count = 2
	path.longest_straight_run = 8
	path.routing_strategy = "L_HV"

	var dbg: String = path.to_debug_string()
	assert("L_HV" in dbg or "Turns" in dbg or "Cost" in dbg, "to_debug_string must format properly")

	print("  [OK] Task 1 assertions passed successfully!")
	quit(0)
