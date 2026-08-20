class_name StairPlanner
extends RefCounted

## Adaptador de compatibilidad para la planificación de escaleras (Fase 10 / M8).
## Delega internamente a FloorConnectionPlanner garantizando scoring y colocación no destructiva.

const _FloorConnectionPlannerScript = preload("res://src/dungeon_generator/core/multilevel/floor_connection_planner.gd")

var _planner: RefCounted

func _init() -> void:
	_planner = _FloorConnectionPlannerScript.new()

## Planifica y conecta dos pisos adyacentes mediante un enlace vertical (FloorConnection).
func plan_stairs_between_floors(
	floor_a: DungeonFloorData,
	floor_b: DungeonFloorData,
	seed_val: int = 0
) -> FloorConnection:
	return _planner.plan_stairs_between_floors(floor_a, floor_b, seed_val)
