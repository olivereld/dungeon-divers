class_name RoomGraphBuilder
extends RefCounted

## Orquestador del grafo topológico de la mazmorra (Fase 3).
## Integra Delaunay + MST determinista + ciclos opcionales produciendo RoomConnection[].

const _CandidateEdgeScript = preload("res://src/dungeon_generator/core/topology/candidate_edge.gd")
const _DelaunayCandidateBuilderScript = preload("res://src/dungeon_generator/core/topology/delaunay_candidate_builder.gd")
const _MinimumSpanningTreeScript = preload("res://src/dungeon_generator/core/topology/minimum_spanning_tree.gd")
const _OptionalConnectionSelectorScript = preload("res://src/dungeon_generator/core/topology/optional_connection_selector.gd")
const _RoomConnectionScript = preload("res://src/dungeon_generator/core/data/room_connection.gd")

class TopologyResult extends RefCounted:
	var connections: Array = []           # Array[RoomConnection]
	var candidate_edges: Array = []       # Array[CandidateEdge]
	var mst_edges: Array = []             # Array[CandidateEdge]
	var optional_edges: Array = []        # Array[CandidateEdge]
	var metrics: Dictionary = {}
	var is_connected: bool = false

static func build_topology(
	rooms: Array[RoomData],
	topology_seed: int,
	loop_chance: float = 0.15
) -> TopologyResult:
	var result := TopologyResult.new()
	var n: int = rooms.size()

	if n == 0:
		result.is_connected = true
		result.metrics = _calc_metrics(0, 0, 0, 0, 0, 0, true, 0.0)
		return result

	if n == 1:
		result.is_connected = true
		result.metrics = _calc_metrics(1, 0, 0, 0, 0, 0, true, 0.0)
		return result

	# 1. Delaunay: Generar aristas candidatas planares
	var candidates: Array = _DelaunayCandidateBuilderScript.build_candidates(rooms)
	result.candidate_edges = candidates

	# 2. MST: Calcular Árbol de Expansión Mínimo determinista
	var mst_res = _MinimumSpanningTreeScript.solve(rooms, candidates)
	result.mst_edges = mst_res.mst_edges
	result.is_connected = mst_res.is_connected

	# 3. Ciclos: Seleccionar aristas opcionales (~15%) respetando grado máximo <= 4
	var optional: Array = _OptionalConnectionSelectorScript.select_optional_edges(
		mst_res.non_mst_edges,
		topology_seed,
		loop_chance,
		mst_res.mst_edges,
		4
	)
	result.optional_edges = optional

	# 4. Construir RoomConnection[] final
	var final_conns: Array = []
	var conn_id: int = 0
	var total_length: float = 0.0

	for edge in result.mst_edges:
		var c = _RoomConnectionScript.new(conn_id, edge.room_a_id, edge.room_b_id, true, &"corridor")
		final_conns.append(c)
		total_length += edge.weight
		conn_id += 1

	for edge in result.optional_edges:
		var c = _RoomConnectionScript.new(conn_id, edge.room_a_id, edge.room_b_id, false, &"corridor")
		final_conns.append(c)
		total_length += edge.weight
		conn_id += 1

	result.connections = final_conns

	# 5. Métricas de diagnóstico
	var avg_len: float = total_length / float(maxi(1, final_conns.size()))
	var cyclomatic: int = final_conns.size() - n + 1 if n > 0 else 0
	result.metrics = _calc_metrics(
		n,
		candidates.size(),
		result.mst_edges.size(),
		mst_res.non_mst_edges.size(),
		optional.size(),
		final_conns.size(),
		result.is_connected,
		avg_len,
		cyclomatic
	)

	return result

static func _calc_metrics(
	room_count: int,
	candidate_count: int,
	mst_count: int,
	non_mst_count: int,
	opt_count: int,
	final_count: int,
	connected: bool,
	avg_len: float,
	cyclomatic: int = 0
) -> Dictionary:
	return {
		"room_count": room_count,
		"candidate_edge_count": candidate_count,
		"mst_edge_count": mst_count,
		"non_mst_edge_count": non_mst_count,
		"optional_edge_count": opt_count,
		"final_edge_count": final_count,
		"is_connected": connected,
		"average_edge_length": avg_len,
		"cyclomatic_complexity": cyclomatic
	}
