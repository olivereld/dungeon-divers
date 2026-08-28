class_name StairsPresentationResolver
extends RefCounted

## Resolvedor puro de estilos y propiedades de presentación para escaleras y conexiones verticales.
## Traduce un StairsPresentationContext a especificaciones geométricas concretas (StairsStyle, dimensiones).
## 100% puro: no genera mallas ni nodos de escena y opera con StringName.

const _StairsPresentationContextScript = preload("res://src/presentation/architecture/stairs_presentation_context.gd")
const _ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")

func resolve_stairs_style(context: _StairsPresentationContextScript) -> StringName:
	if context == null or context.source_profile == null:
		return &"stone"
	return context.source_profile.stairs_style

func resolve_stairs_specs(
	context: _StairsPresentationContextScript,
	tile_size: float = 2.0,
	floor_height: float = 6.0
) -> Dictionary:
	var style: StringName = resolve_stairs_style(context)

	var visual_rise: float = 1.8
	var is_down: bool = context.is_downward if context != null else false

	return {
		"stairs_style": style,
		"tile_size": tile_size,
		"floor_height": floor_height,
		"visual_rise": visual_rise,
		"is_downward": is_down,
		"room_id": context.room_id if context != null else -1,
		"target_floor": context.target_floor if context != null else -1
	}
