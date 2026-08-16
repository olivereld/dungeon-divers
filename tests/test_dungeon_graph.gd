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
