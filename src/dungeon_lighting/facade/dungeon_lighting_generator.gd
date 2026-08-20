class_name DungeonLightingGenerator
extends RefCounted

## Fachada central de generación de iluminación lógica para mazmorras.
## Orquesta la búsqueda de muros, planificación de salas y corredores sin instanciar Node3D.
## 100% Determinista y seguro para entornos Headless / CI.

const _LightingResultScript = preload("res://src/dungeon_lighting/data/lighting_result.gd")
const _LightPlacementScript = preload("res://src/dungeon_lighting/data/light_placement.gd")
const _DungeonLightingConfigScript = preload("res://src/dungeon_lighting/config/dungeon_lighting_config.gd")
const _WallLightCandidateFinderScript = preload("res://src/dungeon_lighting/planning/wall_light_candidate_finder.gd")
const _RoomLightPlannerScript = preload("res://src/dungeon_lighting/planning/room_light_planner.gd")
const _CorridorLightPlannerScript = preload("res://src/dungeon_lighting/planning/corridor_light_planner.gd")
const _DungeonSemanticResultScript = preload("res://src/dungeon_generator/core/semantic/data/dungeon_semantic_result.gd")

var _candidate_finder: _WallLightCandidateFinderScript = _WallLightCandidateFinderScript.new()
var _room_planner: _RoomLightPlannerScript = _RoomLightPlannerScript.new()
var _corridor_planner: _CorridorLightPlannerScript = _CorridorLightPlannerScript.new()

## Genera la distribución lógica de antorchas y luces a partir del modelo semántico de la mazmorra.
func generate_lighting(
	semantic_result: DungeonSemanticResult,
	config: DungeonLightingConfig = null,
	seed_val: int = 1337
) -> LightingResult:
	var result := _LightingResultScript.new()
	result.seed_used = seed_val

	if config == null:
		config = _DungeonLightingConfigScript.new()

	if not config.enabled or semantic_result == null or semantic_result.grid == null:
		return result

	var start_time: int = Time.get_ticks_usec()
	var global_light_id: int = 1

	# 1. Iluminación de Habitaciones
	for room in semantic_result.rooms:
		if room == null:
			continue

		var room_seed: int = (seed_val ^ (room.id * 73856093) ^ 0x5bd1e995) & 0x7FFFFFFF
		var candidates = _candidate_finder.find_room_wall_candidates(
			room,
			semantic_result.grid,
			semantic_result.door_pairs,
			config.avoid_door_proximity,
			config.avoid_corners
		)

		var selected = _room_planner.plan_room_lights(room, candidates, config, room_seed)
		for p in selected:
			p.light_id = global_light_id
			global_light_id += 1
			result.placements.append(p)

	# 2. Iluminación de Pasillos
	if config.corridor_lighting_enabled and not semantic_result.corridor_paths.is_empty():
		for corridor in semantic_result.corridor_paths:
			if corridor == null:
				continue

			var corr_seed: int = (seed_val ^ (corridor.connection_id * 19349663) ^ 0x3a4b5c6d) & 0x7FFFFFFF
			var candidates = _candidate_finder.find_corridor_wall_candidates(
				corridor,
				semantic_result.grid,
				config.avoid_corners
			)

			var selected = _corridor_planner.plan_corridor_lights(corridor, candidates, config, corr_seed)
			for p in selected:
				p.light_id = global_light_id
				global_light_id += 1
				result.placements.append(p)

	result.generation_time_ms = float(Time.get_ticks_usec() - start_time) / 1000.0
	return result
