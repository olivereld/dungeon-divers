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

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _ProfileValidatorScript = preload("res://src/dungeon_generator/profiles/profile_validator.gd")
const _ProfileBundleScript = preload("res://src/dungeon_generator/profiles/profile_bundle.gd")
const _ProfileValidationResultScript = preload("res://src/dungeon_generator/profiles/profile_validation_result.gd")

const MAX_ATTEMPTS: int = 5

var _seed_registry: DungeonSeedRegistry = DungeonSeedRegistry.new()
var _profile_loader := _ProfileLoaderScript.new()
var _profile_validator := _ProfileValidatorScript.new()
var _profile_bundle: _ProfileBundleScript = null

var _mission_stage := _DungeonMissionStageScript.new()
var _room_stage := _DungeonRoomStageScript.new()
var _topology_stage := _DungeonTopologyStageScript.new()
var _entrance_stage := _DungeonEntranceStageScript.new()
var _corridor_stage := _DungeonCorridorStageScript.new()
var _door_stage := _DungeonDoorStageScript.new()
var _marker_stage := _DungeonMarkerStageScript.new()
var _validation_stage := _DungeonValidationStageScript.new()

# Diagnósticos y trazabilidad de fallos
var last_failure_type: String = ""
var last_failure_reason: String = ""
var last_failure_stage: String = ""
var last_failure_seed: int = 0

func get_seed_registry() -> DungeonSeedRegistry:
	return _seed_registry

## Carga y valida el ProfileBundle para un arquetipo específico.
## Retorna el ProfileValidationResult con el estado de validación.
func load_profiles(archetype_id: String) -> _ProfileValidationResultScript:
	var bundle = _profile_loader.load_full_archetype_bundle(archetype_id)
	var val_res: _ProfileValidationResultScript = _profile_validator.validate(bundle)
	if val_res.is_valid:
		_profile_bundle = bundle
	else:
		_profile_bundle = null
		generation_failed.emit("Profile validation failed:\n" + val_res.to_summary_string())
	return val_res

func get_profile_bundle() -> _ProfileBundleScript:
	return _profile_bundle

func set_profile_bundle(bundle: _ProfileBundleScript) -> void:
	_profile_bundle = bundle



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
	param2 = null,
	param3 = null,
	param4 = null
) -> DungeonResult:
	if config == null:
		config = DungeonConfig.new()

	var max_retries: int = MAX_ATTEMPTS
	var force_new_seed: bool = false
	var diagnostics_enabled: bool = true

	if param2 is _ProfileBundleScript:
		_profile_bundle = param2
	elif param2 is int:
		if param3 is _ProfileBundleScript:
			config.seed = param2
			_profile_bundle = param3
		elif param2 > 50:
			config.seed = param2
			config.use_fixed_seed = true
			if param3 is int:
				max_retries = param3
			if param4 is bool:
				force_new_seed = param4
		else:
			max_retries = param2
			if param3 is bool:
				force_new_seed = param3
			if param4 is bool:
				diagnostics_enabled = param4
			elif param4 is _ProfileBundleScript:
				_profile_bundle = param4

	if force_new_seed:
		_seed_registry.clear_dungeon(config.dungeon_id)

	var target_arch: String = str(config.get_effective_archetype_id()) if config != null else "necropolis"
	if target_arch.is_empty() or target_arch == "default":
		target_arch = "necropolis"

	if _profile_bundle == null or (_profile_bundle.archetype != null and str(_profile_bundle.archetype.id) != target_arch):
		load_profiles(target_arch)

	generation_started.emit()

	var base_seed: int = _resolve_seed(config, 0)

	last_failure_type = ""
	last_failure_reason = ""
	last_failure_stage = ""
	last_failure_seed = base_seed

	for attempt in range(max_retries):
		var ctx := _DungeonGenerationContextScript.new(
			config,
			base_seed,
			attempt
		)
		ctx.profile_bundle = _profile_bundle

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
			last_failure_type = ctx.failure_type
			last_failure_reason = ctx.failure_reason
			last_failure_stage = "mission"
			last_failure_seed = ctx.attempt_seed
			if ctx.failure_type == "STRUCTURAL" or not _handle_stage_failure(ctx):
				break
			continue

		_emit_stage_signals(
			ctx,
			["mission_grammar", "winnability_check"]
		)

		# -------------------------------------------------------------
		# 2. Rooms
		# -------------------------------------------------------------
		if not _room_stage.execute(ctx):
			last_failure_type = ctx.failure_type
			last_failure_reason = ctx.failure_reason
			last_failure_stage = "room"
			last_failure_seed = ctx.attempt_seed
			if ctx.failure_type == "STRUCTURAL" or not _handle_stage_failure(ctx):
				break
			continue

		_emit_stage_signals(
			ctx,
			["space_grammar", "room_construction"]
		)

		# -------------------------------------------------------------
		# 3. Topology
		# -------------------------------------------------------------
		if not _topology_stage.execute(ctx):
			last_failure_type = ctx.failure_type
			last_failure_reason = ctx.failure_reason
			last_failure_stage = "topology"
			last_failure_seed = ctx.attempt_seed
			if ctx.failure_type == "STRUCTURAL" or not _handle_stage_failure(ctx):
				break
			continue

		_emit_stage_signals(
			ctx,
			["topology_builder"]
		)

		# -------------------------------------------------------------
		# 4. Entrance
		# -------------------------------------------------------------
		if not _entrance_stage.execute(ctx):
			last_failure_type = ctx.failure_type
			last_failure_reason = ctx.failure_reason
			last_failure_stage = "entrance"
			last_failure_seed = ctx.attempt_seed
			if ctx.failure_type == "STRUCTURAL" or not _handle_stage_failure(ctx):
				break
			continue

		_emit_stage_signals(
			ctx,
			["entrance_solver"]
		)

		# -------------------------------------------------------------
		# 5. Corridors
		# -------------------------------------------------------------
		if not _corridor_stage.execute(ctx):
			last_failure_type = ctx.failure_type
			last_failure_reason = ctx.failure_reason
			last_failure_stage = "corridor"
			last_failure_seed = ctx.attempt_seed
			if ctx.failure_type == "STRUCTURAL" or not _handle_stage_failure(ctx):
				break
			continue

		_emit_stage_signals(
			ctx,
			["corridor_carving"]
		)

		# -------------------------------------------------------------
		# 6. Doors
		# -------------------------------------------------------------
		if not _door_stage.execute(ctx):
			last_failure_type = ctx.failure_type
			last_failure_reason = ctx.failure_reason
			last_failure_stage = "door"
			last_failure_seed = ctx.attempt_seed
			if ctx.failure_type == "STRUCTURAL" or not _handle_stage_failure(ctx):
				break
			continue

		_emit_stage_signals(
			ctx,
			["door_resolver"]
		)

		# -------------------------------------------------------------
		# 7. Markers
		# -------------------------------------------------------------
		if not _marker_stage.execute(ctx):
			last_failure_type = ctx.failure_type
			last_failure_reason = ctx.failure_reason
			last_failure_stage = "marker"
			last_failure_seed = ctx.attempt_seed
			if ctx.failure_type == "STRUCTURAL" or not _handle_stage_failure(ctx):
				break
			continue

		# -------------------------------------------------------------
		# 8. Validation
		# -------------------------------------------------------------
		if not _validation_stage.execute(ctx):
			last_failure_type = ctx.failure_type
			last_failure_reason = ctx.failure_reason
			last_failure_stage = "validation"
			last_failure_seed = ctx.attempt_seed
			if ctx.failure_type == "STRUCTURAL" or not _handle_stage_failure(ctx):
				break
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
	var error_message: String = (
		"Failed to generate a valid dungeon. Seed=%d Type=%s Reason=%s"
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
				"[DungeonPipeline] STRUCTURAL FAILURE: %s"
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
