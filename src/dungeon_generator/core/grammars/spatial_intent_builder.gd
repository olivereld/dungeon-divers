class_name SpatialIntentBuilder
extends RefCounted

## Constructor semántico de intención espacial.
## Transforma un MissionGraph (DungeonGraph) en una descripción de intención espacial
## explícita (SpatialIntentResult), clasificando nodos en MAIN_PATH y SIDE_PATH,
## calculando factores de progresión continua y determinando las anclas de ramificación.
## No muta el MissionGraph ni genera posiciones geométricas.

const SpatialIntent = preload("res://src/dungeon_generator/core/data/spatial_intent.gd")
const SpatialIntentResult = preload("res://src/dungeon_generator/core/data/spatial_intent_result.gd")
const DungeonGraph = preload("res://src/dungeon_generator/core/data/dungeon_graph.gd")
const MissionNode = preload("res://src/dungeon_generator/core/data/mission_node.gd")

func build(mission_graph: DungeonGraph) -> SpatialIntentResult:
	var result := SpatialIntentResult.new()
	if mission_graph == null or mission_graph.get_all_node_ids().is_empty():
		result.valid = false
		result.seal()
		return result

	var all_node_ids: Array[int] = mission_graph.get_all_node_ids()
	
	# 1. Resolver nodo START
	var start_nodes: Array[int] = []
	for nid in all_node_ids:
		var node_data: Dictionary = mission_graph.get_node_data(nid)
		var m_node: MissionNode = MissionNode.from_dictionary(node_data)
		var ntype_lower: String = String(mission_graph.get_node_type(nid)).to_lower()
		if m_node.action == MissionNode.ActionType.START or ntype_lower == "start":
			start_nodes.append(nid)

	if start_nodes.size() != 1:
		push_warning("[SpatialIntentBuilder] Invalid START count: expected 1, found %d." % start_nodes.size())
		result.valid = false
		result.seal()
		return result

	var start_id: int = start_nodes[0]

	# 2. Resolver nodo Terminal (Priorizar BOSS, luego GOAL/PASSAGE_DOWN, luego nodo más profundo)
	var terminal_id: int = -1
	for nid in all_node_ids:
		var node_data: Dictionary = mission_graph.get_node_data(nid)
		var m_node: MissionNode = MissionNode.from_dictionary(node_data)
		var ntype_lower: String = String(mission_graph.get_node_type(nid)).to_lower()
		if m_node.action == MissionNode.ActionType.BOSS or ntype_lower == "boss":
			terminal_id = nid
			break

	if terminal_id == -1:
		for nid in all_node_ids:
			var node_data: Dictionary = mission_graph.get_node_data(nid)
			var m_node: MissionNode = MissionNode.from_dictionary(node_data)
			var ntype_lower: String = String(mission_graph.get_node_type(nid)).to_lower()
			if m_node.action == MissionNode.ActionType.GOAL or m_node.action == MissionNode.ActionType.PASSAGE_DOWN or ntype_lower == "goal":
				terminal_id = nid
				break

	var depths: Dictionary = mission_graph.calculate_depths(start_id)

	if terminal_id == -1:
		# Fallback al nodo alcanzable con mayor profundidad
		var max_d: int = -1
		for nid in all_node_ids:
			var d: int = depths.get(nid, -1)
			if d > max_d:
				max_d = d
				terminal_id = nid

	if terminal_id == -1 or terminal_id == start_id:
		# Si solo existe un nodo o no hay terminal distinto, usar el último en orden topológico
		var topo := mission_graph.get_topological_order()
		terminal_id = topo[topo.size() - 1] if not topo.is_empty() else start_id

	# 3. Calcular Main Path
	var main_path: Array[int] = mission_graph.get_shortest_path(start_id, terminal_id)
	if main_path.is_empty():
		push_warning("[SpatialIntentBuilder] No path found from START (%d) to Terminal (%d)." % [start_id, terminal_id])
		result.valid = false
		result.seal()
		return result

	result.start_node_id = start_id
	result.terminal_node_id = terminal_id
	result.main_path = main_path

	var main_path_set: Dictionary = {}
	for idx in range(main_path.size()):
		main_path_set[main_path[idx]] = idx

	# 4. Generar SpatialIntent para los nodos de MAIN_PATH
	var main_count: int = main_path.size()
	for idx in range(main_count):
		var nid: int = main_path[idx]
		var node_data: Dictionary = mission_graph.get_node_data(nid)
		var m_node: MissionNode = MissionNode.from_dictionary(node_data)

		var role: StringName = SpatialIntent.ROLE_MAIN_PATH
		if idx == 0:
			role = SpatialIntent.ROLE_START
		elif nid == terminal_id:
			if m_node.action == MissionNode.ActionType.BOSS:
				role = SpatialIntent.ROLE_BOSS
			elif m_node.action == MissionNode.ActionType.GOAL or m_node.action == MissionNode.ActionType.PASSAGE_DOWN:
				role = SpatialIntent.ROLE_GOAL
			else:
				role = SpatialIntent.ROLE_MAIN_PATH

		var factor: float = float(idx) / float(maxi(1, main_count - 1))
		var intent_depth: int = depths.get(nid, idx)

		var intent := SpatialIntent.new(
			nid,
			role,
			factor,
			intent_depth,
			idx,
			nid # En la ruta principal, el ancla es el mismo nodo
		)
		result.add_intent(intent)

	# 5. Clasificar SIDE_PATH y determinar su main_path_anchor
	for nid in all_node_ids:
		if main_path_set.has(nid):
			continue

		var node_data: Dictionary = mission_graph.get_node_data(nid)
		var m_node: MissionNode = MissionNode.from_dictionary(node_data)

		# Búsqueda hacia atrás de su ancla en main_path
		var anchor_id: int = _find_main_path_anchor(nid, mission_graph, main_path_set, start_id)
		var anchor_intent: SpatialIntent = result.get_intent(anchor_id)
		var anchor_factor: float = anchor_intent.progression_factor if anchor_intent != null else 0.5
		var anchor_depth: int = anchor_intent.depth if anchor_intent != null else 0

		var node_depth: int = depths.get(nid, anchor_depth + 1)
		var branch_step: int = maxi(1, node_depth - anchor_depth)
		# Progresión lateral ligeramente avanzada respecto al ancla
		var prog_factor: float = clampf(anchor_factor + float(branch_step) * 0.05, 0.0, 1.0)

		var role: StringName = SpatialIntent.ROLE_SIDE_PATH
		if m_node.is_optional or m_node.action == MissionNode.ActionType.TREASURE or m_node.action == MissionNode.ActionType.PUZZLE:
			role = SpatialIntent.ROLE_OPTIONAL

		var intent := SpatialIntent.new(
			nid,
			role,
			prog_factor,
			node_depth,
			-1,
			anchor_id
		)
		result.add_intent(intent)

	result.valid = true
	result.seal()
	return result

## Encuentra el nodo antecesor más cercano que pertenezca a la ruta principal
func _find_main_path_anchor(
	node_id: int,
	graph: DungeonGraph,
	main_path_set: Dictionary,
	start_id: int
) -> int:
	var queue: Array[int] = [node_id]
	var visited: Dictionary = {node_id: true}

	while not queue.is_empty():
		var curr: int = queue.pop_front()
		var preds: Array[int] = graph.get_predecessors(curr)
		for p in preds:
			if main_path_set.has(p):
				return p
			if not visited.has(p):
				visited[p] = true
				queue.append(p)

	return start_id
