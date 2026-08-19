extends SceneTree

func _init() -> void:
	print("--- Running test_dungeon_graph ---")
	var graph := DungeonGraph.new()

	var n1: int = graph.add_node(&"START", {"info": "start_point"})
	var n2: int = graph.add_node(&"TASK", {"info": "task_1"})
	var n3: int = graph.add_node(&"GOAL", {"info": "goal_point"})

	graph.add_edge(n1, n2)
	graph.add_edge(n2, n3)

	assert(graph.get_node_count() == 3, "Graph should have 3 nodes")
	assert(graph.get_edge_count() == 2, "Graph should have 2 edges")
	assert(graph.has_edge(n1, n2), "Edge n1->n2 must exist")
	assert(not graph.has_edge(n1, n3), "Edge n1->n3 should not exist directly")
	assert(graph.is_reachable(n1, n3), "n3 should be reachable from n1")

	var path := graph.get_shortest_path(n1, n3)
	assert(path.size() == 3, "Shortest path should be [n1, n2, n3]")
	assert(path[0] == n1 and path[1] == n2 and path[2] == n3, "Path order correct")

	var topo := graph.get_topological_order()
	assert(topo.size() == 3, "Topological order should have 3 elements")
	assert(topo.find(n1) < topo.find(n2), "n1 should precede n2")
	assert(topo.find(n2) < topo.find(n3), "n2 should precede n3")

	# Test determinismo y ordenación ascendente
	var all_ids: Array[int] = graph.get_all_node_ids()
	assert(all_ids.size() == 3, "Should have 3 node IDs")
	assert(all_ids[0] == n1 and all_ids[1] == n2 and all_ids[2] == n3, "Node IDs must be ascending")
	assert(graph.get_successors(n1) == [n2], "Successors must match and be sorted")
	assert(graph.get_predecessors(n2) == [n1], "Predecessors must match and be sorted")

	# Test 1: Grafo con Ciclo (debe retornar [])
	var cyclic_graph := DungeonGraph.new()
	var c1: int = cyclic_graph.add_node(&"ROOM_A")
	var c2: int = cyclic_graph.add_node(&"ROOM_B")
	var c3: int = cyclic_graph.add_node(&"ROOM_C")
	cyclic_graph.add_edge(c1, c2)
	cyclic_graph.add_edge(c2, c3)
	cyclic_graph.add_edge(c3, c1)
	var cyclic_order: Array[int] = cyclic_graph.get_topological_order()
	assert(cyclic_order.is_empty(), "Cyclic graph must return empty topological order")

	# Test 2: Grafo DAG con bifurcación
	var dag_graph := DungeonGraph.new()
	var d1: int = dag_graph.add_node(&"N1")
	var d2: int = dag_graph.add_node(&"N2")
	var d3: int = dag_graph.add_node(&"N3")
	var d4: int = dag_graph.add_node(&"N4")
	dag_graph.add_edge(d1, d2)
	dag_graph.add_edge(d2, d3)
	dag_graph.add_edge(d1, d4)

	var dag_order: Array[int] = dag_graph.get_topological_order()
	assert(dag_order.size() == 4, "DAG topological order must have 4 nodes")
	assert(dag_order.has(d1) and dag_order.has(d2) and dag_order.has(d3) and dag_order.has(d4), "Must contain all nodes")
	assert(dag_order.find(d1) < dag_order.find(d2), "d1 must precede d2")
	assert(dag_order.find(d2) < dag_order.find(d3), "d2 must precede d3")
	assert(dag_order.find(d1) < dag_order.find(d4), "d1 must precede d4")

	# Test subgraph matching
	var pattern_nodes := [
		{"id": 0, "type": &"START", "match_any": false},
		{"id": 1, "type": &"TASK", "match_any": false}
	]
	var pattern_edges := [
		{"from": 0, "to": 1}
	]
	var matches := graph.find_matching_subgraph(pattern_nodes, pattern_edges)
	assert(matches.size() == 1, "Should find exactly 1 match for pattern")
	assert(matches[0][0] == n1 and matches[0][1] == n2, "Match IDs should be n1 and n2")

	print("[PASS] test_dungeon_graph succeeded.")
	quit(0)
