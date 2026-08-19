class_name DungeonMarkerStage
extends RefCounted

## Etapa 7: Colocación de Marcadores Especiales (Spawn, Objetivo, Ítems de Misión).

const _DungeonReservedMaskScript = preload("res://src/dungeon_generator/core/data/dungeon_reserved_mask.gd")

func execute(ctx: DungeonGenerationContext) -> bool:
	var mask = _DungeonReservedMaskScript.new()
	ctx.reserved_mask = mask

	# 1. Reservar puertas y celdas de despeje de puerta
	for d in ctx.doors:
		if d != null and ctx.grid.is_in_bounds(d.position):
			mask.force_reserve(d.position, "DOORWAY")

	for dp in ctx.door_pairs:
		if dp != null:
			if dp.door_a != null:
				mask.force_reserve(dp.door_a.position, "DOORWAY")
			if dp.door_b != null:
				mask.force_reserve(dp.door_b.position, "DOORWAY")

	# 2. Reservar línea central de pasillos para evitar bloquear rutas
	for path in ctx.corridor_paths:
		for cell in path.centerline_cells:
			if not mask.is_reserved(cell):
				mask.reserve(cell, "CORRIDOR_CLEARANCE")

	# 3. Identificar nodo BOSS de la misión para asignación por identidad estricta
	var boss_node_id: int = -1
	if ctx.mission_graph != null:
		for nid in ctx.mission_graph.get_all_node_ids():
			var nd: Dictionary = ctx.mission_graph.get_node_data(nid)
			if int(nd.get("action", -1)) == MissionNode.ActionType.BOSS:
				boss_node_id = nid
				break

	# 4. Colocar y reservar marcadores de habitación
	for room in ctx.rooms:
		var center := room.get_center()
		if not ctx.grid.is_in_bounds(center):
			continue

		# Si el centro está reservado por un pasillo que cruza o puerta, buscar celda transitable libre
		var target_pos := center
		if mask.is_reserved(target_pos):
			for y in range(room.rect.position.y + 1, room.rect.end.y - 1):
				for x in range(room.rect.position.x + 1, room.rect.end.x - 1):
					var candidate := Vector2i(x, y)
					if ctx.grid.is_walkable(candidate) and not mask.is_reserved(candidate):
						target_pos = candidate
						break
				if not mask.is_reserved(target_pos):
					break

		var is_boss_room: bool = (boss_node_id != -1 and room.mission_node_id == boss_node_id) or (boss_node_id == -1 and room.room_type == &"boss")

		if room.room_type == &"start":
			ctx.grid.set_cell(target_pos, CellGrid.CellType.SPAWN)
			ctx.start_room_id = room.id
			mask.reserve(target_pos, "SPAWN")
		elif is_boss_room:
			ctx.grid.set_cell(target_pos, CellGrid.CellType.OBJECTIVE)
			ctx.grid.set_metadata(target_pos, "objective_type", "boss")
			ctx.grid.set_metadata(target_pos, "mission_node_id", room.mission_node_id)
			ctx.boss_room_id = room.id
			mask.reserve(target_pos, "BOSS")
		elif room.room_type == &"goal":
			ctx.grid.set_cell(target_pos, CellGrid.CellType.OBJECTIVE)
			ctx.grid.set_metadata(target_pos, "objective_type", "goal")
			ctx.grid.set_metadata(target_pos, "mission_node_id", room.mission_node_id)
			mask.reserve(target_pos, "GOAL")
		elif room.room_type == &"treasure":
			mask.reserve(target_pos, "CHEST")
			if room.mission_node_id != -1 and ctx.mission_graph != null and ctx.mission_graph.has_node(room.mission_node_id):
				var m_data := ctx.mission_graph.get_node_data(room.mission_node_id)
				var m_node := MissionNode.from_dictionary(m_data)
				if not m_node.grants_items.is_empty():
					ctx.grid.set_metadata(target_pos, "granted_item", m_node.grants_items[0])
		elif room.room_type == &"puzzle":
			mask.reserve(target_pos, "PUZZLE")
			if room.mission_node_id != -1 and ctx.mission_graph != null and ctx.mission_graph.has_node(room.mission_node_id):
				var m_data := ctx.mission_graph.get_node_data(room.mission_node_id)
				var m_node := MissionNode.from_dictionary(m_data)
				if not m_node.required_items.is_empty():
					ctx.grid.set_metadata(target_pos, "required_item", m_node.required_items[0])

	return true
