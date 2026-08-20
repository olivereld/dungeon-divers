class_name MultiFloorGenerator
extends RefCounted

## Fachada y adaptador de compatibilidad para la generación multinivel (Fase 10 / M8).
## Delega internamente a MultiFloorOrchestrator preservando 100% de retrocompatibilidad.

const _MultiFloorOrchestratorScript = preload("res://src/dungeon_generator/core/multilevel/multi_floor_orchestrator.gd")
const _DungeonMultiFloorResultScript = preload("res://src/dungeon_generator/core/data/dungeon_multi_floor_result.gd")

var _orchestrator: MultiFloorOrchestrator

func _init(pipeline: DungeonPipeline = null, _unused_stair_planner = null) -> void:
	_orchestrator = _MultiFloorOrchestratorScript.new(pipeline)

## Genera una mazmorra completa multinivel delegando al orquestador modular.
func generate_multi_floor(
	config: DungeonConfig,
	master_seed: int = 0,
	diagnostics_enabled: bool = true
) -> DungeonMultiFloorResult:
	return _orchestrator.generate_multi_floor(config, master_seed, diagnostics_enabled)
