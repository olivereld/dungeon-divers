class_name DoorPresentationResolver
extends RefCounted

## Resolvedor puro de estilos y propiedades de presentación para puertas.
## Traduce un DoorPresentationContext a especificaciones geométricas concretas (DoorStyle, FrameStyle, dimensiones).
## 100% puro: no genera mallas ni nodos de escena.

const _DoorPresentationContextScript = preload("res://src/presentation/architecture/door_presentation_context.gd")
const _ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")

func resolve_door_style(context: _DoorPresentationContextScript) -> _ArchitecturalStyleScript.DoorStyle:
	if context == null:
		return _ArchitecturalStyleScript.DoorStyle.STONE_ARCH

	var prof_a = context.source_profile
	var prof_b = context.target_profile

	if prof_a != null and prof_a.door_style != _ArchitecturalStyleScript.DoorStyle.STONE_ARCH:
		return prof_a.door_style
	elif prof_b != null and prof_b.door_style != _ArchitecturalStyleScript.DoorStyle.STONE_ARCH:
		return prof_b.door_style
	elif prof_a != null:
		return prof_a.door_style
	elif prof_b != null:
		return prof_b.door_style

	return _ArchitecturalStyleScript.DoorStyle.STONE_ARCH

func resolve_door_specs(
	context: _DoorPresentationContextScript,
	tile_size: float = 2.0,
	wall_height: int = 2
) -> Dictionary:
	var style: _ArchitecturalStyleScript.DoorStyle = resolve_door_style(context)

	var frame_width: float = tile_size
	var frame_height: float = float(wall_height) * tile_size
	var opening_width: float = tile_size * 0.55
	var opening_height: float = frame_height * 0.70

	return {
		"door_style": style,
		"frame_width": frame_width,
		"frame_height": frame_height,
		"opening_width": opening_width,
		"opening_height": opening_height,
		"source_room_id": context.source_room_id if context != null else -1,
		"target_room_id": context.target_room_id if context != null else -1
	}
