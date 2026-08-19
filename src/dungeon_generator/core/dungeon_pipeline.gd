class_name DungeonPipeline
extends RefCounted

## Orquestador del pipeline de generación procedural de mazmorras (Fase 3).
## Coordinador puro de alto nivel: delega la lógica algorítmica a etapas modulares desacopladas
## y comunica el estado mediante DungeonGenerationContext.
## Cero dependencias de nodos de escena — lógica pura testeable en headless.

signal generation_started
signal phase_completed(phase_name: String, elapsed_ms: float)
signal generation_completed(result: DungeonResult)
signal generation_failed(error: String)

const _DungeonGenerationContextScript = preload("res://src/dungeon_generator/core/data/dungeon_generation_context.gd")
const _DungeonSeedFactoryScript = preload("res://src/dungeon_generator/core/generation/dungeon_seed_factory.gd")

const _DungeonMissionStageScript = preload("res://src/dungeon_generator/core/stages/dungeon_mission_stage.gd")
const _DungeonRoomStageScript = preload("res://src/dungeon_generator/core/stages/dungeon_room_stage.gd")
const _DungeonTopologyStageScript = preload("res://src/dungeon_generator/core/stages/dungeon_topology_stage.gd")
const _DungeonEntranceStageScript = preload("res://src/dungeon_generator/core/stages/dungeon_entrance_stage.gd")
const _DungeonCorridorStageScript = preload("res://src/dungeon_generator/core/stages/dungeon_corridor_stage.gd")
const _DungeonDoorStageScript = preload("res://src/dungeon_generator/core/stages/dungeon_door_stage.gd")
const _DungeonMarkerStageScript = preload("res://src/dungeon_generator/core/stages/dungeon_marker_stage.gd")
const _DungeonValidationStageScript = preload("res://src/dungeon_generator/core/stages/dungeon_validation_stage.gd")

var _seed_registry: DungeonSeedRegistry = DungeonSeedRegistry.new()

var _mission_stage := _DungeonMissionStageScript.new()
var _room_stage := _DungeonRoomStageScript.new()
var _topology_stage := _DungeonTopologyStageScript.new()
var _entrance_stage := _DungeonEntranceStageScript.new()
var _corridor_stage := _DungeonCorridorStageScript.new()
var _door_stage := _DungeonDoorStageScript.new()
var _marker_stage := _DungeonMarkerStageScript.new()
var _validation_stage := _DungeonValidationStageScript.new()

func get_seed_registry() -> DungeonSeedRegistry:
	return _seed_registry

const MAX_ATTEMPTS: int = 5

## Ejecuta la orquestación completa del pipeline de generación de mazmorras.
func generate(config: DungeonConfig = null, max_retries: int = MAX_ATTEMPTS, force_new_seed: bool = false) -> DungeonResult:
	if config == null:
		config = DungeonConfig.new()

	if force_new_seed:
		_seed_registry.clear_dungeon(config.dungeon_id)

	generation_started.emit()

	var base_seed: int = _resolve_seed(config, 0)

	for attempt in range(max_retries):
		var ctx := _DungeonGenerationContextScript.new(config, base_seed, attempt)
		ctx.attempt_seed = _DungeonSeedFactoryScript.derive_seed(base_seed, attempt, &"attempt")

		# 1. Etapa de Misión y Resolubilidad
		if not _mission_stage.execute(ctx):
			continue
		_emit_stage_signals(ctx, ["mission_grammar", "winnability_check"])

		# 2. Etapa de Habitaciones y Conectividad Interna
		if not _room_stage.execute(ctx):
			continue
		_emit_stage_signals(ctx, ["space_grammar", "room_construction"])

		# 3. Etapa de Topología (Delaunay + MST + Loops)
		if not _topology_stage.execute(ctx):
			continue
		_emit_stage_signals(ctx, ["topology_builder"])

		# 4. Etapa de Entradas Perimetrales (EntranceSolver)
		if not _entrance_stage.execute(ctx):
			continue
		_emit_stage_signals(ctx, ["entrance_solver"])

		# 5. Etapa de Tallado de Pasillos, Limpieza y Reparación
		if not _corridor_stage.execute(ctx):
			continue
		_emit_stage_signals(ctx, ["corridor_carving"])

		# 6. Etapa de Puertas y Umbrales
		if not _door_stage.execute(ctx):
			continue
		_emit_stage_signals(ctx, ["door_resolver"])

		# 7. Etapa de Marcadores Especiales
		_marker_stage.execute(ctx)

		# 8. Etapa de Validación de Conectividad y Fitness
		if not _validation_stage.execute(ctx):
			continue
		_emit_stage_signals(ctx, ["flood_fill_connectivity"])

		# Ensamblar y retornar el resultado inmutable
		var result: DungeonResult = ctx.to_dungeon_result()
		generation_completed.emit(result)
		return result

	generation_failed.emit("Failed to generate a valid dungeon within max retries.")
	return null

func _emit_stage_signals(ctx: DungeonGenerationContext, stage_keys: Array[String]) -> void:
	for k in stage_keys:
		if ctx.stage_timings_ms.has(k):
			phase_completed.emit(k, ctx.stage_timings_ms[k])

func _resolve_seed(config: DungeonConfig, attempt_offset: int) -> int:
	if config.use_fixed_seed:
		return config.seed + attempt_offset
	var base: int = config.seed
	if base == 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		base = rng.randi_range(100000, 999999999)
	return _seed_registry.get_or_create_seed(config.dungeon_id, config.floor_number, base + attempt_offset)
