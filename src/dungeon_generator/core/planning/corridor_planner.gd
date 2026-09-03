class_name CorridorPlanner
extends RefCounted

## Planificador de Pasillos (Fase 5: Corridor Planning).
## Asigna la intención semántica de corredor a cada arista/conexión entre salas
## basándose en SpatialIntentResult, RoomPlacementPlan y MissionGraph.
## Produce un CorridorPlan inmutable compuesto por CorridorRequests enriquecidas,
## desacoplando la intención de ruteo del tallado físico en AStarCarver.

const CorridorPlan = preload("res://src/dungeon_generator/core/data/corridor_plan.gd")
const CorridorRequest = preload("res://src/dungeon_generator/core/data/corridor_request.gd")
const RoomData = preload("res://src/dungeon_generator/core/data/room_data.gd")
const RoomPlacementPlan = preload("res://src/dungeon_generator/core/data/room_placement_plan.gd")
const SpatialIntent = preload("res://src/dungeon_generator/core/data/spatial_intent.gd")
const SpatialIntentResult = preload("res://src/dungeon_generator/core/data/spatial_intent_result.gd")
const SpatialIntentBuilder = preload("res://src/dungeon_generator/core/grammars/spatial_intent_builder.gd")
const DungeonGraph = preload("res://src/dungeon_generator/core/data/dungeon_graph.gd")
const EntrancePair = preload("res://src/dungeon_generator/core/data/entrance_pair.gd")

func plan_corridors(
	rooms: Array[RoomData],
	connections: Array,
	entrance_pairs: Array,
	placement_plan: RoomPlacementPlan = null,
	spatial_intent: SpatialIntentResult = null,
	mission_graph: DungeonGraph = null
) -> CorridorPlan:
	var plan := CorridorPlan.new()

	if entrance_pairs.is_empty():
		plan.seal()
		return plan

	# Asegurar presencia de SpatialIntentResult si hay mission_graph
	if spatial_intent == null and mission_graph != null:
		var builder := SpatialIntentBuilder.new()
		spatial_intent = builder.build(mission_graph)

	# Indexar conexiones por id para comprobación de obligatoriedad
	var conn_map: Dictionary = {}
	for conn in connections:
		if conn != null:
			conn_map[conn.id] = conn

	# Indexar salas por id
	var room_by_id: Dictionary = {}
	for r in rooms:
		if r != null:
			room_by_id[r.id] = r

	# Generar CorridorRequest para cada EntrancePair
	for pair in entrance_pairs:
		if pair == null or pair.entrance_a == null or pair.entrance_b == null:
			continue

		var conn = conn_map.get(pair.connection_id, null)
		var is_req: bool = conn.is_required if (conn != null and "is_required" in conn) else true

		var r_a: RoomData = room_by_id.get(pair.entrance_a.room_id, null)
		var r_b: RoomData = room_by_id.get(pair.entrance_b.room_id, null)

		var node_a: int = r_a.mission_node_id if r_a != null else -1
		var node_b: int = r_b.mission_node_id if r_b != null else -1

		var is_mission_edge: bool = false
		if mission_graph != null and node_a >= 0 and node_b >= 0:
			is_mission_edge = mission_graph.has_edge(node_a, node_b) or mission_graph.has_edge(node_b, node_a)

		var intent_a: SpatialIntent = spatial_intent.get_intent(node_a) if (spatial_intent != null and node_a >= 0) else null
		var intent_b: SpatialIntent = spatial_intent.get_intent(node_b) if (spatial_intent != null and node_b >= 0) else null

		var role: StringName = CorridorRequest.ROLE_MAIN_PATH
		var routing_pref: StringName = CorridorRequest.ROUTING_DIRECT
		var min_len: int = 2
		var max_len: int = 50

		var a_on_main: bool = intent_a != null and intent_a.is_on_main_path()
		var b_on_main: bool = intent_b != null and intent_b.is_on_main_path()

		if a_on_main and b_on_main:
			# Ambas salas están en la ruta principal: ruteo directo y prioritario
			role = CorridorRequest.ROLE_MAIN_PATH
			routing_pref = CorridorRequest.ROUTING_DIRECT
			max_len = 40
		elif (a_on_main and not b_on_main) or (b_on_main and not a_on_main):
			# Conexión de ramificación (Main Path a Side Path): evitar cruzar otras salas
			role = CorridorRequest.ROLE_SIDE_PATH
			routing_pref = CorridorRequest.ROUTING_AVOID_ROOMS
			max_len = 45
		elif not a_on_main and not b_on_main and is_mission_edge:
			# Ramal secundario interno
			role = CorridorRequest.ROLE_SIDE_PATH
			routing_pref = CorridorRequest.ROUTING_AVOID_ROOMS
			max_len = 45
		else:
			# Conexión opcional, ciclo secundario o shortcut
			role = CorridorRequest.ROLE_SHORTCUT if not is_req else CorridorRequest.ROLE_OPTIONAL
			routing_pref = CorridorRequest.ROUTING_MANHATTAN
			max_len = 60

		var dist: float = float(pair.entrance_a.outer_cell.distance_to(pair.entrance_b.outer_cell))

		var req := CorridorRequest.new(
			pair.connection_id,
			pair.entrance_a.room_id,
			pair.entrance_b.room_id,
			pair.entrance_a.outer_cell,
			pair.entrance_b.outer_cell,
			pair.entrance_a.boundary_cell,
			pair.entrance_b.boundary_cell,
			pair.entrance_a.get_outward_direction(),
			pair.entrance_b.get_outward_direction(),
			is_req,
			role,
			Vector2i(node_a, node_b)
		)
		req.preferred_length = dist
		req.min_length = min_len
		req.max_length = max_len
		req.routing_preference = routing_pref

		plan.add_request(req)

	plan.seal()
	return plan
