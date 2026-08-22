class_name StairsPresentationContextBuilder
extends RefCounted

## Constructor puro de contextos de presentación para conexiones verticales (escaleras).
## Mapea StairData -> StairsPresentationContext en tiempo O(rooms + stairs),
## resolviendo tanto la sala/perfil de origen (source_profile) como la de destino (target_profile).
## 100% puro: no accede a CellGrid ni genera nodos 3D.

const _StairsPresentationContextScript = preload("res://src/presentation/architecture/stairs_presentation_context.gd")
const _PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const _StairDataScript = preload("res://src/dungeon_generator/core/data/stair_data.gd")

func build(
	stairs: Array, # Array[StairData]
	room_contexts: Array, # Array[PresentationRoomContext]
	partition = null, # PresentationGeometryPartition
	target_room_contexts_by_floor: Dictionary = {} # floor_number -> Array[PresentationRoomContext]
) -> Array:
	var stairs_contexts: Array = []
	if stairs.is_empty():
		return stairs_contexts

	# 1. Crear índice de contextos del piso actual por room_id en O(rooms)
	var context_by_room_id: Dictionary = {}
	for ctx in room_contexts:
		if ctx is _PresentationRoomContextScript:
			context_by_room_id[ctx.room_id] = ctx

	# 2. Construir StairsPresentationContext por cada StairData en O(stairs)
	for st in stairs:
		if st == null:
			continue

		var src_r_id: int = -1
		if partition != null:
			src_r_id = partition.get_room_id_at(st.cell)

		var src_ctx: _PresentationRoomContextScript = context_by_room_id.get(src_r_id, null)
		var src_prof = src_ctx.profile if src_ctx != null else null

		# Resolver perfil del piso destino si se proporcionan contextos multinivel
		var dst_prof = null
		if target_room_contexts_by_floor.has(st.target_floor):
			var dst_contexts: Array = target_room_contexts_by_floor[st.target_floor]
			for d_ctx in dst_contexts:
				if d_ctx is _PresentationRoomContextScript and d_ctx.rect.has_point(st.cell):
					dst_prof = d_ctx.profile
					break

		var s_ctx = _StairsPresentationContextScript.new(
			st.stair_id,
			st.connection_id,
			st.floor_number,
			st.target_floor,
			st.cell,
			src_r_id,
			src_prof,
			dst_prof,
			st.is_downward,
			st.orientation
		)
		stairs_contexts.append(s_ctx)

	return stairs_contexts
