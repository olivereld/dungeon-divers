class_name SemanticOrchestrator
extends RefCounted

## Orquestador central de la Fase 7.
## Ejecuta secuencialmente la resolución de Start/Boss, Camino Crítico, Llaves/Cerraduras y Objetivos,
## realizando la validación formal de jugabilidad y emitiendo un DungeonSemanticResult inmutable.
## 100% puro: no muta el CellGrid ni depende de nodos de escena.

signal semantic_generation_completed(result: DungeonSemanticResult)
signal semantic_generation_failed(diagnostics: Dictionary)

const _DungeonSeedFactoryScript = preload("res://src/dungeon_generator/core/generation/dungeon_seed_factory.gd")
const _StartBossSolverScript = preload("res://src/dungeon_generator/core/semantic/start_boss_solver.gd")
const _CriticalPathSolverScript = preload("res://src/dungeon_generator/core/semantic/critical_path_solver.gd")
const _KeyLockPlannerScript = preload("res://src/dungeon_generator/core/semantic/key_lock_planner.gd")
const _ObjectiveAssignerScript = preload("res://src/dungeon_generator/core/semantic/objective_assigner.gd")
const _GameplayValidatorScript = preload("res://src/dungeon_generator/core/semantic/gameplay_validator.gd")
const _DungeonSemanticResultScript = preload("res://src/dungeon_generator/core/semantic/data/dungeon_semantic_result.gd")
const _RoomPurposeAssignerScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose_assigner.gd")
const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

var _start_boss_solver := _StartBossSolverScript.new()
var _critical_path_solver := _CriticalPathSolverScript.new()
var _key_lock_planner := _KeyLockPlannerScript.new()
var _objective_assigner := _ObjectiveAssignerScript.new()
var _gameplay_validator := _GameplayValidatorScript.new()
var _room_purpose_assigner := _RoomPurposeAssignerScript.new()
var _profile_loader := _ProfileLoaderScript.new()


func generate_semantics(dungeon_result: DungeonResult, config: DungeonConfig = null) -> DungeonSemanticResult:
	if dungeon_result == null or dungeon_result.grid == null:
		push_error("[SemanticOrchestrator] dungeon_result is null or invalid.")
		return null

	if config == null:
		config = DungeonConfig.new()

	var base_seed: int = dungeon_result.seed_used
	var attempt: int = 0
	if "final_attempt" in dungeon_result.seed_trace:
		attempt = int(dungeon_result.seed_trace["final_attempt"])

	var attempt_seed: int = _DungeonSeedFactoryScript.derive_seed(base_seed, attempt, &"semantic_attempt")
	var seed_trace: Array[Dictionary] = []

	var semantic_result: DungeonSemanticResult = _DungeonSemanticResultScript.new()
	semantic_result.base_seed = base_seed
	semantic_result.attempt = attempt
	semantic_result.attempt_seed = attempt_seed
	semantic_result.grid = dungeon_result.grid
	semantic_result.rooms = dungeon_result.rooms
	semantic_result.connections = dungeon_result.connections
	semantic_result.entrance_pairs = dungeon_result.entrance_pairs
	semantic_result.corridor_paths = dungeon_result.corridor_paths
	semantic_result.door_pairs = dungeon_result.door_pairs

	# 1. Start / Boss Solver (Reutilizando semántica de SpatialIntentBuilder / MissionGraph)
	var start_boss_seed: int = _DungeonSeedFactoryScript.derive_seed(attempt_seed, 0, &"start_boss")
	seed_trace.append({ "stage": "start_boss", "seed": start_boss_seed })

	var depth_map_preliminary := _critical_path_solver.compute_depth_map(0, dungeon_result.rooms, dungeon_result.connections)
	var sb_res := _start_boss_solver.resolve_start_and_boss(
		dungeon_result.rooms,
		dungeon_result.connections,
		dungeon_result.grid,
		config,
		depth_map_preliminary,
		dungeon_result.mission_graph
	)
	var start_id: int = sb_res["start_room_id"]
	var boss_id: int = sb_res["boss_room_id"]

	semantic_result.start_room_id = start_id
	semantic_result.boss_room_id = boss_id
	semantic_result.start_node_id = sb_res.get("start_node_id", -1)
	semantic_result.boss_node_id = sb_res.get("boss_node_id", -1)

	# 2. Critical Path Solver (Determinista sobre MissionGraph)
	var critical_seed: int = _DungeonSeedFactoryScript.derive_seed(attempt_seed, 0, &"critical_path")
	seed_trace.append({ "stage": "critical_path", "seed": critical_seed })

	var cp_res := _critical_path_solver.solve_critical_path(
		start_id,
		boss_id,
		dungeon_result.rooms,
		dungeon_result.connections,
		dungeon_result.mission_graph
	)
	semantic_result.critical_path_rooms = cp_res["critical_path_rooms"]
	semantic_result.critical_path_connections = cp_res["critical_path_connections"]
	semantic_result.mandatory_connections = cp_res["mandatory_connections"]
	semantic_result.depth_map = cp_res["depth_map"]
	if cp_res.has("mission_critical_path"):
		semantic_result.main_path = cp_res["mission_critical_path"]
	else:
		semantic_result.main_path = cp_res["critical_path_rooms"]

	# 3. Key / Lock Planner
	var key_lock_seed: int = _DungeonSeedFactoryScript.derive_seed(attempt_seed, 0, &"key_lock")
	seed_trace.append({ "stage": "key_lock", "seed": key_lock_seed })

	var kl_res := _key_lock_planner.plan_keys_and_locks(
		start_id,
		boss_id,
		dungeon_result.rooms,
		dungeon_result.connections,
		semantic_result.critical_path_rooms,
		semantic_result.critical_path_connections,
		semantic_result.mandatory_connections,
		semantic_result.depth_map,
		dungeon_result.grid,
		config,
		key_lock_seed
	)
	semantic_result.keys = kl_res["keys"]
	semantic_result.locks = kl_res["locks"]

	# 4. Objective Assigner
	var obj_seed: int = _DungeonSeedFactoryScript.derive_seed(attempt_seed, 0, &"objectives")
	seed_trace.append({ "stage": "objectives", "seed": obj_seed })

	var objectives := _objective_assigner.assign_objectives(
		start_id,
		boss_id,
		dungeon_result.rooms,
		semantic_result.depth_map,
		dungeon_result.grid,
		config,
		obj_seed,
		semantic_result.critical_path_rooms,
		dungeon_result.connections,
		dungeon_result.mission_graph,
		semantic_result.keys
	)
	semantic_result.objectives = objectives

	# 5. Archetype & Room Purpose Assigner
	var arch_seed: int = _DungeonSeedFactoryScript.derive_seed(attempt_seed, 0, &"archetype_purposes")
	seed_trace.append({ "stage": "archetype_purposes", "seed": arch_seed })

	var target_arch_id: StringName = config.get_effective_archetype_id()
	var arch_profile = null

	# Cargar ProfileBundle data-driven desde ProfileLoader y ArchetypeCatalog
	if _profile_loader != null and target_arch_id != &"generic":
		var bundle = _profile_loader.load_full_archetype_bundle(str(target_arch_id))
		if bundle != null and bundle.archetype != null:
			arch_profile = bundle

	var room_purposes := _room_purpose_assigner.assign_purposes(
		start_id,
		boss_id,
		dungeon_result.rooms,
		semantic_result.objectives,
		arch_profile,
		arch_seed
	)
	semantic_result.archetype_id = target_arch_id
	semantic_result.dungeon_archetype = int(config.dungeon_archetype) if config.dungeon_archetype is int else 0
	semantic_result.dungeon_archetype_name = str(target_arch_id)
	semantic_result.room_purposes = room_purposes
	semantic_result.seed_trace = seed_trace


	# 6. Final Gameplay Validator
	var final_val := _gameplay_validator.validate_gameplay(
		start_id,
		boss_id,
		dungeon_result.rooms,
		dungeon_result.connections,
		semantic_result.keys,
		semantic_result.locks,
		semantic_result.objectives
	)

	semantic_result.gameplay_valid = final_val["is_resolvable"]
	semantic_result.gameplay_diagnostics = final_val
	semantic_result.mark_committed()

	if semantic_result.gameplay_valid:
		semantic_generation_completed.emit(semantic_result)
	else:
		semantic_generation_failed.emit(semantic_result.gameplay_diagnostics)

	return semantic_result
