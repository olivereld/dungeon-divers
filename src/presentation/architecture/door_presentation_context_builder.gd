class_name DoorPresentationContextBuilder
extends RefCounted

## Constructor puro de contextos de presentación para puertas.
## Mapea DoorPair -> DoorPresentationContext relacionando salas conectadas en tiempo O(rooms + doors).
## 100% puro: no accede a CellGrid ni genera nodos 3D.

const _DoorPresentationContextScript = preload("res://src/presentation/architecture/door_presentation_context.gd")
const _PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const _DoorPairScript = preload("res://src/dungeon_generator/core/data/door_pair.gd")

func build(
	door_pairs: Array, # Array[DoorPair]
	room_contexts: Array # Array[PresentationRoomContext]
) -> Array:
	var door_contexts: Array = []
	if door_pairs.is_empty() or room_contexts.is_empty():
		return door_contexts

	# 1. Crear índice de contextos por room_id en O(rooms)
	var context_by_room_id: Dictionary = {}
	for ctx in room_contexts:
		if ctx is _PresentationRoomContextScript:
			context_by_room_id[ctx.room_id] = ctx

	# 2. Construir DoorPresentationContext por cada DoorPair en O(doors)
	for dp in door_pairs:
		if dp == null or not dp.is_valid():
			continue

		var src_id: int = dp.door_a.room_id
		var dst_id: int = dp.door_b.room_id

		var src_ctx: _PresentationRoomContextScript = context_by_room_id.get(src_id, null)
		var dst_ctx: _PresentationRoomContextScript = context_by_room_id.get(dst_id, null)

		var src_prof = src_ctx.profile if src_ctx != null else null
		var dst_prof = dst_ctx.profile if dst_ctx != null else null

		var door_id_str: String = "conn_%d_door" % dp.connection_id
		var d_ctx = _DoorPresentationContextScript.new(
			dp.connection_id,
			door_id_str,
			src_id,
			dst_id,
			src_prof,
			dst_prof,
			dp.door_a.position,
			dp.door_b.position
		)
		door_contexts.append(d_ctx)

	return door_contexts
