class_name DecorationCompositionResolver
extends RefCounted

## Motor de composición espacial semántica para habitaciones de mazmorra.
## Conecta de forma pura el DecorationCompositionPlanner con los perfiles, paletas y geometrías.
## 100% puro: no crea nodos Node3D ni muta CellGrid.

const _DecorationCompositionScript = preload("res://src/presentation/decoration/decoration_composition.gd")
const _DecorationPaletteScript = preload("res://src/presentation/decoration/decoration_palette.gd")
const _PresentationSeedContextScript = preload("res://src/presentation/architecture/presentation_seed_context.gd")
const _DecorationCompositionPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")

var _planner := _DecorationCompositionPlannerScript.new()

func resolve_room_composition(
	room_context,
	palette: _DecorationPaletteScript,
	room_geometry,
	partition = null,
	base_seed: int = 1337,
	tile_size: float = 2.0,
	composition_profile = null
) -> _DecorationCompositionScript:
	var room_id: int = room_context.room_id if room_context != null and "room_id" in room_context else (room_geometry.room_id if room_geometry != null and "room_id" in room_geometry else -1)
	var comp := _DecorationCompositionScript.new(room_id)

	if room_context == null or palette == null or room_geometry == null:
		return comp

	var seed_ctx := _PresentationSeedContextScript.for_room(base_seed, room_id)

	# Si no se pasó un composition_profile explícito, usar room_context.room_profile si existe
	var active_profile = composition_profile
	if active_profile == null and room_context != null and "room_profile" in room_context:
		active_profile = room_context.room_profile

	# Delegar la composición espacial al planificador inteligente
	return _planner.plan_room_composition(
		active_profile,
		palette,
		room_geometry,
		room_context,
		partition,
		seed_ctx,
		tile_size
	)

