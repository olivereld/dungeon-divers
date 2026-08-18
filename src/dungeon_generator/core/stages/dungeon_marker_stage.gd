class_name DungeonMarkerStage
extends RefCounted

## Etapa 7: Colocación de Marcadores Especiales (Spawn, Objetivo, Ítems de Misión).

func execute(ctx: DungeonGenerationContext) -> bool:
	for room in ctx.rooms:
		var center := room.get_center()
		if not ctx.grid.is_in_bounds(center):
			continue

		if room.room_type == &"start":
			ctx.grid.set_cell(center, CellGrid.CellType.SPAWN)
		elif room.room_type == &"goal":
			ctx.grid.set_cell(center, CellGrid.CellType.OBJECTIVE)
		elif room.room_type == &"treasure":
			if room.mission_node_id != -1 and ctx.mission_graph != null and ctx.mission_graph.has_node(room.mission_node_id):
				var m_data := ctx.mission_graph.get_node_data(room.mission_node_id)
				var m_node := MissionNode.from_dictionary(m_data)
				if not m_node.grants_items.is_empty():
					ctx.grid.set_metadata(center, "granted_item", m_node.grants_items[0])
		elif room.room_type == &"puzzle":
			if room.mission_node_id != -1 and ctx.mission_graph != null and ctx.mission_graph.has_node(room.mission_node_id):
				var m_data := ctx.mission_graph.get_node_data(room.mission_node_id)
				var m_node := MissionNode.from_dictionary(m_data)
				if not m_node.required_items.is_empty():
					ctx.grid.set_metadata(center, "required_item", m_node.required_items[0])

	return true
