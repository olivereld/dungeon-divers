class_name SemanticMappingValidator
extends RefCounted

## Valida que el mapeo semántico entre MissionGraph y RoomData sea correcto.
## Específicamente verifica:
## - Si boss_enabled: mission_boss_count == 1, room_boss_count == 1 y mapeo exacto de Boss.
## - Si no boss_enabled: mission_boss_count == 0 y room_boss_count == 0.

static func validate_mission_to_room_semantics(mission_graph: DungeonGraph, rooms: Array[RoomData], ctx: DungeonGenerationContext) -> bool:
	var t0 := Time.get_ticks_msec()
	
	var is_boss_enabled: bool = (ctx.config == null or ctx.config.boss_enabled)
	var expected_boss_count: int = 1 if is_boss_enabled else 0

	# Contar bosses en el grafo de misiones
	var mission_boss_count: int = 0
	var mission_boss_node_id: int = -1
	for node_id in mission_graph.get_all_node_ids():
		var node_data: Dictionary = mission_graph.get_node_data(node_id)
		var m_node: MissionNode = MissionNode.from_dictionary(node_data)
		if m_node.room_type_hint == &"boss":
			mission_boss_count += 1
			mission_boss_node_id = node_id
	
	# Contar bosses en RoomData
	var room_boss_count: int = 0
	var room_boss_id: int = -1
	for room in rooms:
		if room.room_type == &"boss":
			room_boss_count += 1
			room_boss_id = room.id
	
	# Validar contrato de Boss en misión
	if mission_boss_count != expected_boss_count:
		if ctx.diagnostics_enabled:
			push_warning("[SemanticMappingValidator] Attempt %d: Expected %d mission boss, got %d." % [ctx.attempt, expected_boss_count, mission_boss_count])
		ctx.mark_attempt_failed("SEMANTIC_MISSION_BOSS_COUNT", "TRANSIENT")
		ctx.record_timing("semantic_validation", float(Time.get_ticks_msec() - t0))
		return false
	
	# Validar contrato de Boss en RoomData
	if room_boss_count != expected_boss_count:
		if ctx.diagnostics_enabled:
			push_warning("[SemanticMappingValidator] Attempt %d: Expected %d room boss, got %d." % [ctx.attempt, expected_boss_count, room_boss_count])
		ctx.mark_attempt_failed("SEMANTIC_ROOM_BOSS_COUNT", "TRANSIENT")
		ctx.record_timing("semantic_validation", float(Time.get_ticks_msec() - t0))
		return false
	
	# Si el boss está habilitado, validar mapeo bidireccional
	if is_boss_enabled:
		var boss_room: RoomData = null
		for room in rooms:
			if room.room_type == &"boss":
				boss_room = room
				break

		if boss_room == null or boss_room.mission_node_id != mission_boss_node_id:
			if ctx.diagnostics_enabled:
				push_warning("[SemanticMappingValidator] Attempt %d: Mission boss node %d does not map to room boss %d." % [
					ctx.attempt, mission_boss_node_id, room_boss_id
				])
			ctx.mark_attempt_failed("SEMANTIC_BOSS_MAPPING", "TRANSIENT")
			ctx.record_timing("semantic_validation", float(Time.get_ticks_msec() - t0))
			return false
		
		# Validación bidireccional: verificar que el mission_node_id del boss room corresponde al nodo boss del grafo
		if boss_room.mission_node_id != mission_boss_node_id:
			if ctx.diagnostics_enabled:
				push_warning("[SemanticMappingValidator] Attempt %d: Boss room mission_node_id %d does not match %d." % [
					ctx.attempt, boss_room.mission_node_id, mission_boss_node_id
				])
			ctx.mark_attempt_failed("SEMANTIC_BOSS_ID_MISMATCH", "TRANSIENT")
			return false
	
	# Validación adicional: no debe haber más de un tipo especial por categoría
	var start_count: int = 0
	var goal_count: int = 0
	for room in rooms:
		if room.room_type == &"start":
			start_count += 1
		elif room.room_type == &"goal":
			goal_count += 1
	
	if start_count != 1:
		if ctx.diagnostics_enabled:
			push_warning("[SemanticMappingValidator] Attempt %d: Expected exactly 1 start room, got %d." % [ctx.attempt, start_count])
		ctx.mark_attempt_failed("SEMANTIC_START_COUNT", "TRANSIENT")
		ctx.record_timing("semantic_validation", float(Time.get_ticks_msec() - t0))
		return false
	
	if goal_count != 1:
		if ctx.diagnostics_enabled:
			push_warning("[SemanticMappingValidator] Attempt %d: Expected exactly 1 goal room, got %d." % [ctx.attempt, goal_count])
		ctx.mark_attempt_failed("SEMANTIC_GOAL_COUNT", "TRANSIENT")
		ctx.record_timing("semantic_validation", float(Time.get_ticks_msec() - t0))
		return false
	
	ctx.record_timing("semantic_validation", float(Time.get_ticks_msec() - t0))
	return true
