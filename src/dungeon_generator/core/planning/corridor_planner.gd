class_name CorridorPlanner
extends RefCounted

## Planificador de Pasillos (Fase 5: Corridor Planning).
## Dueño definitivo de la intención de pasillos (Intent Owner).
## Entradas: MissionGraph, SpatialIntentResult, RoomConnection[], RoomData[], RoomPlacementPlan.
## Salida: CorridorPlan (conteniendo CorridorRequest[]).
## Decisiones: Rol, Required, Mission Edge, Routing Preference, Longitudes teóricas/soft.
## Desacoplado de la resolución física de entradas (EntranceSolver).

const CorridorPlan = preload("res://src/dungeon_generator/core/data/corridor_plan.gd")
const CorridorRequest = preload("res://src/dungeon_generator/core/data/corridor_request.gd")
const RoomData = preload("res://src/dungeon_generator/core/data/room_data.gd")
const RoomPlacementPlan = preload("res://src/dungeon_generator/core/data/room_placement_plan.gd")
const SpatialIntent = preload("res://src/dungeon_generator/core/data/spatial_intent.gd")
const SpatialIntentResult = preload("res://src/dungeon_generator/core/data/spatial_intent_result.gd")
const DungeonGraph = preload("res://src/dungeon_generator/core/data/dungeon_graph.gd")

func plan_corridors(
	rooms: Array[RoomData],
	connections: Array,
	placement_plan: RoomPlacementPlan = null,
	spatial_intent: SpatialIntentResult = null,
	mission_graph: DungeonGraph = null
) -> CorridorPlan:
	var plan := CorridorPlan.new()

	if connections.is_empty():
		plan.seal()
		return plan

	if spatial_intent == null and mission_graph != null:
		push_warning("[CorridorPlanner] spatial_intent was not provided forward from context.")

	# Indexar salas por id
	var room_by_id: Dictionary = {}
	for r in rooms:
		if r != null:
			room_by_id[r.id] = r

	# Generar CorridorRequest lógico para cada RoomConnection
	for conn in connections:
		if conn == null:
			continue

		var is_req: bool = conn.is_required if ("is_required" in conn) else true
		var r_a: RoomData = room_by_id.get(conn.room_a_id, null)
		var r_b: RoomData = room_by_id.get(conn.room_b_id, null)

		var node_a: int = r_a.mission_node_id if r_a != null else -1
		var node_b: int = r_b.mission_node_id if r_b != null else -1

		var is_mission_edge: bool = false
		if mission_graph != null and node_a >= 0 and node_b >= 0:
			is_mission_edge = mission_graph.has_edge(node_a, node_b) or mission_graph.has_edge(node_b, node_a)

		var intent_a: SpatialIntent = spatial_intent.get_intent(node_a) if (spatial_intent != null and node_a >= 0) else null
		var intent_b: SpatialIntent = spatial_intent.get_intent(node_b) if (spatial_intent != null and node_b >= 0) else null

		var role: StringName = CorridorRequest.ROLE_MAIN_PATH
		var routing_pref: StringName = CorridorRequest.ROUTING_DIRECT
		var min_len: int = 1
		var max_len: int = 64

		var a_on_main: bool = intent_a != null and intent_a.is_on_main_path()
		var b_on_main: bool = intent_b != null and intent_b.is_on_main_path()

		var dist: float = 10.0
		if r_a != null and r_b != null:
			dist = float(r_a.get_center().distance_to(r_b.get_center()))

		if a_on_main and b_on_main:
			# Ambas salas están en la ruta principal: ruteo directo y prioritario
			role = CorridorRequest.ROLE_MAIN_PATH
			routing_pref = CorridorRequest.ROUTING_DIRECT
			max_len = maxi(64, int(dist * 2.5))
			min_len = 1
		elif (a_on_main and not b_on_main) or (b_on_main and not a_on_main):
			# Conexión de ramificación (Main Path a Side Path): evitar cruzar otras salas
			role = CorridorRequest.ROLE_SIDE_PATH
			routing_pref = CorridorRequest.ROUTING_AVOID_ROOMS
			max_len = maxi(72, int(dist * 2.8))
			min_len = 1
		elif not a_on_main and not b_on_main and is_mission_edge:
			# Ramal secundario interno
			role = CorridorRequest.ROLE_SIDE_PATH
			routing_pref = CorridorRequest.ROUTING_AVOID_ROOMS
			max_len = maxi(72, int(dist * 2.8))
			min_len = 1
		else:
			# Conexión opcional, ciclo secundario o shortcut
			role = CorridorRequest.ROLE_SHORTCUT if not is_req else CorridorRequest.ROLE_OPTIONAL
			routing_pref = CorridorRequest.ROUTING_MANHATTAN
			max_len = maxi(80, int(dist * 3.0))
			min_len = 1

		var req := CorridorRequest.create_planned(
			conn.id,
			conn.room_a_id,
			conn.room_b_id,
			Vector2i.ZERO,
			Vector2i.ZERO,
			Vector2i.ZERO,
			Vector2i.ZERO,
			Vector2i.ZERO,
			Vector2i.ZERO,
			is_req,
			role,
			Vector2i(node_a, node_b),
			dist,
			min_len,
			max_len,
			routing_pref
		)

		plan.add_request(req)

	# Nota: El plan permanece abierto para que EntranceSolver enlace las coordenadas físicas
	return plan
