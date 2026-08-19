class_name DungeonPipeline
extends RefCounted

## Orquestador del pipeline de generación procedural de mazmorras.
## Coordina etapas desacopladas y utiliza DungeonGenerationContext
## como único canal de estado entre fases.
##
## No contiene lógica algorítmica de generación.
## No depende de nodos de escena.
## Diseñado para ejecución headless y determinista.

signal generation_started
signal phase_completed(phase_name: String, elapsed_ms: float)
signal generation_completed(result: DungeonResult)
signal generation_failed(error: String)

const _DungeonGenerationContextScript = preload(
	"res://src/dungeon_generator/core/data/dungeon_generation_context.gd"
)
const _DungeonSeedFactoryScript = preload(
	"res://src/dungeon_generator/core/generation/dungeon_seed_factory.gd"
)

const _DungeonMissionStageScript = preload(
	"res://src/dungeon_generator/core/stages/dungeon_mission_stage.gd"
)
const _DungeonRoomStageScript = preload(
	"res://src/dungeon_generator/core/stages/dungeon_room_stage.gd"
)
const _DungeonTopologyStageScript = preload(
	"res://src/dungeon_generator/core/stages/dungeon_topology_stage.gd"
)
const _DungeonEntranceStageScript = preload(
	"res://src/dungeon_generator/core/stages/dungeon_entrance_stage.gd"
)
const _DungeonCorridorStageScript = preload(
	"res://src/dungeon_generator/core/stages/dungeon_corridor_stage.gd"
)
const _DungeonDoorStageScript = preload(
	"res://src/dungeon_generator/core/stages/dungeon_door_stage.gd"
)
const _DungeonMarkerStageScript = preload(
	"res://src/dungeon_generator/core/stages/dungeon_marker_stage.gd"
)
const _DungeonValidationStageScript = preload(
	"res://src/dungeon_generator/core/stages/dungeon_validation_stage.gd"
)

const MAX_ATTEMPTS: int = 5

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


## Ejecuta la generación completa.
##
## TRANSIENT:
##     El intento actual puede descartarse y volver a generarse.
##
## STRUCTURAL:
##     El contrato de generación se ha roto.
##     No tiene sentido rerollear el mismo pipeline.
##     Se aborta inmediatamente.
func generate(
	config: DungeonConfig = null,
	max_retries: int = MAX_ATTEMPTS,
	force_new_seed: bool = false,
	diagnostics_enabled: bool = true
) -> DungeonResult:
	if config == null:
		config = DungeonConfig.new()

	if force_new_seed:
		_seed_registry.clear_dungeon(config.dungeon_id)

	generation_started.emit()

	var base_seed: int = _resolve_seed(config, 0)

	var last_failure_type: String = ""
	var last_failure_reason: String = ""

	for attempt in range(max_retries):
		var ctx := _DungeonGenerationContextScript.new(
			config,
			base_seed,
			attempt
		)

		ctx.attempt_seed = _DungeonSeedFactoryScript.derive_seed(
			base_seed,
			attempt,
			&"attempt"
		)

		ctx.diagnostics_enabled = diagnostics_enabled

		# -------------------------------------------------------------
		# 1. Mission
		# -------------------------------------------------------------
		if not _mission_stage.execute(ctx):
			if not _handle_stage_failure(ctx):
				last_failure_type = ctx.failure_type
				last_failure_reason = ctx.failure_reason
				break

			last_failure_type = ctx.failure_type
			last_failure_reason = ctx.failure_reason
			continue

		_emit_stage_signals(
			ctx,
			["mission_grammar", "winnability_check"]
		)

		# -------------------------------------------------------------
		# 2. Rooms
		# -------------------------------------------------------------
		if not _room_stage.execute(ctx):
			if not _handle_stage_failure(ctx):
				last_failure_type = ctx.failure_type
				last_failure_reason = ctx.failure_reason
				break

			last_failure_type = ctx.failure_type
			last_failure_reason = ctx.failure_reason
			continue

		_emit_stage_signals(
			ctx,
			["space_grammar", "room_construction"]
		)

		# -------------------------------------------------------------
		# 3. Topology
		# -------------------------------------------------------------
		if not _topology_stage.execute(ctx):
			if not _handle_stage_failure(ctx):
				last_failure_type = ctx.failure_type
				last_failure_reason = ctx.failure_reason
				break

			last_failure_type = ctx.failure_type
			last_failure_reason = ctx.failure_reason
			continue

		_emit_stage_signals(
			ctx,
			["topology_builder"]
		)

		# -------------------------------------------------------------
		# 4. Entrance
		# -------------------------------------------------------------
		if not _entrance_stage.execute(ctx):
			if not _handle_stage_failure(ctx):
				last_failure_type = ctx.failure_type
				last_failure_reason = ctx.failure_reason
				break

			last_failure_type = ctx.failure_type
			last_failure_reason = ctx.failure_reason
			continue

		_emit_stage_signals(
			ctx,
			["entrance_solver"]
		)

		# -------------------------------------------------------------
		# 5. Corridors
		# -------------------------------------------------------------
		if not _corridor_stage.execute(ctx):
			if not _handle_stage_failure(ctx):
				last_failure_type = ctx.failure_type
				last_failure_reason = ctx.failure_reason
				break

			last_failure_type = ctx.failure_type
			last_failure_reason = ctx.failure_reason
			continue

		_emit_stage_signals(
			ctx,
			["corridor_carving"]
		)

		# -------------------------------------------------------------
		# 6. Doors
		# -------------------------------------------------------------
		if not _door_stage.execute(ctx):
			if not _handle_stage_failure(ctx):
				last_failure_type = ctx.failure_type
				last_failure_reason = ctx.failure_reason
				break

			last_failure_type = ctx.failure_type
			last_failure_reason = ctx.failure_reason
			continue

		_emit_stage_signals(
			ctx,
			["door_resolver"]
		)

		# -------------------------------------------------------------
		# 7. Markers
		# -------------------------------------------------------------
		if not _marker_stage.execute(ctx):
			if not _handle_stage_failure(ctx):
				last_failure_type = ctx.failure_type
				last_failure_reason = ctx.failure_reason
				break

			last_failure_type = ctx.failure_type
			last_failure_reason = ctx.failure_reason
			continue

		# -------------------------------------------------------------
		# 8. Validation
		# -------------------------------------------------------------
		if not _validation_stage.execute(ctx):
			if not _handle_stage_failure(ctx):
				last_failure_type = ctx.failure_type
				last_failure_reason = ctx.failure_reason
				break

			last_failure_type = ctx.failure_type
			last_failure_reason = ctx.failure_reason
			continue

		_emit_stage_signals(
			ctx,
			["flood_fill_connectivity"]
		)

		# -------------------------------------------------------------
		# SUCCESS
		# -------------------------------------------------------------
		var result: DungeonResult = ctx.to_dungeon_result()

		generation_completed.emit(result)

		return result

	# -------------------------------------------------------------
	# FAILURE
	# -------------------------------------------------------------
	var error_message := (
		"Failed to generate a valid dungeon. "
		"Seed=%d Type=%s Reason=%s"
		% [
			base_seed,
			last_failure_type,
			last_failure_reason
		]
	)

	if diagnostics_enabled:
		push_warning("[DungeonPipeline] %s" % error_message)

	generation_failed.emit(error_message)

	return null


## Devuelve false únicamente para fallos STRUCTURAL.
##
## true  -> el caller puede reintentar.
## false -> el caller debe abortar inmediatamente.
func _handle_stage_failure(
	ctx: DungeonGenerationContext
) -> bool:
	if ctx.failure_type == "STRUCTURAL":
		if ctx.diagnostics_enabled:
			push_warning(
				"[DungeonPipeline] "
				"STRUCTURAL FAILURE: %s"
				% ctx.failure_reason
			)

		return false

	return true


func _emit_stage_signals(
	ctx: DungeonGenerationContext,
	stage_keys: Array[String]
) -> void:
	for key in stage_keys:
		if ctx.stage_timings_ms.has(key):
			phase_completed.emit(
				key,
				ctx.stage_timings_ms[key]
			)


func _resolve_seed(
	config: DungeonConfig,
	attempt_offset: int
) -> int:
	if config.use_fixed_seed:
		return config.seed + attempt_offset

	var base: int = config.seed

	if base == 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		base = rng.randi_range(
			100000,
			999999999
		)

	return _seed_registry.get_or_create_seed(
		config.dungeon_id,
		config.floor_number,
		base + attempt_offset
	)