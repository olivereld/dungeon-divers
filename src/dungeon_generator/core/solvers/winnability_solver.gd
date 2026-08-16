class_name WinnabilitySolver
extends RefCounted

## Validador de resolubilidad (Winnability).
## Simula la progresión lógica del jugador en el grafo de misiones con manejo de llaves e inventario.

class ValidationResult extends RefCounted:
	var is_winnable: bool = false
	var critical_path: Array[int] = []
	var unreachable_nodes: Array[int] = []
	var missing_items: Array[StringName] = []
	var estimated_length: int = 0

	func _to_string() -> String:
		return "Winnable: %s | Length: %d | Unreachable: %d | Missing: %s" % [
			str(is_winnable),
			estimated_length,
			unreachable_nodes.size(),
			str(missing_items)
		]

func validate(graph: DungeonGraph) -> ValidationResult:
	var result := ValidationResult.new()

	var start_nodes: Array[int] = graph.find_nodes_by_type(
		StringName(MissionNode.ActionType.keys()[MissionNode.ActionType.START])
	)
	var goal_nodes: Array[int] = graph.find_nodes_by_type(
		StringName(MissionNode.ActionType.keys()[MissionNode.ActionType.GOAL])
	)

	if start_nodes.is_empty() or goal_nodes.is_empty():
		result.is_winnable = false
		return result

	var start_id: int = start_nodes[0]
	var goal_id: int = goal_nodes[0]

	# Simulación iterativa de avance
	var inventory: Array[StringName] = []
	var visited_nodes: Dictionary = {}        # int id -> bool
	var pending_nodes: Dictionary = {}        # int id -> MissionNode (bloqueados por falta de llave)
	var parent_map: Dictionary = {}

	# Comenzar en START
	var frontier: Array[int] = [start_id]
	visited_nodes[start_id] = true

	var progress_made := true
	while progress_made and not visited_nodes.has(goal_id):
		progress_made = false

		# 1. Expandir nodos actualmente alcanzables
		while not frontier.is_empty():
			var curr: int = frontier.pop_front()
			var curr_data: Dictionary = graph.get_node_data(curr)
			var m_node: MissionNode = MissionNode.from_dictionary(curr_data)

			# Adquirir recompensas de este nodo
			for item in m_node.grants_items:
				if not inventory.has(item):
					inventory.append(item)
					progress_made = true

			# Explorar sucesores
			for succ in graph.get_successors(curr):
				if visited_nodes.has(succ):
					continue

				var succ_data: Dictionary = graph.get_node_data(succ)
				var succ_node: MissionNode = MissionNode.from_dictionary(succ_data)

				# Comprobar si requiere ítems
				var has_all_reqs := true
				for req in succ_node.required_items:
					if not inventory.has(req):
						has_all_reqs = false
						if not result.missing_items.has(req):
							result.missing_items.append(req)

				if has_all_reqs:
					# Consumir llave al usar puerta/cerradura
					for req in succ_node.required_items:
						inventory.erase(req)

					visited_nodes[succ] = true
					parent_map[succ] = curr
					frontier.append(succ)
					progress_made = true
				else:
					pending_nodes[succ] = succ_node

		# 2. Re-evaluar nodos que estaban bloqueados
		var unlocked_keys: Array[int] = []
		for pending_id in pending_nodes.keys():
			var p_node: MissionNode = pending_nodes[pending_id]
			var can_unlock := true
			for req in p_node.required_items:
				if not inventory.has(req):
					can_unlock = false
					break

			if can_unlock:
				for req in p_node.required_items:
					inventory.erase(req)
				visited_nodes[pending_id] = true
				frontier.append(pending_id)
				unlocked_keys.append(pending_id)
				progress_made = true

		for unl in unlocked_keys:
			pending_nodes.erase(unl)

	# Evaluar resultado
	result.is_winnable = visited_nodes.has(goal_id)

	# Identificar nodos inalcanzables
	for id in graph.get_all_node_ids():
		if not visited_nodes.has(id):
			result.unreachable_nodes.append(id)

	# Reconstruir camino crítico si es ganable
	if result.is_winnable:
		var path: Array[int] = []
		var curr_trace: int = goal_id
		while curr_trace != start_id and parent_map.has(curr_trace):
			path.push_front(curr_trace)
			curr_trace = parent_map[curr_trace]
		path.push_front(start_id)
		result.critical_path = path
		result.estimated_length = path.size()

	return result
