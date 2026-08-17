extends SceneTree

const _RoomGraphBuilderScript = preload("res://src/dungeon_generator/core/topology/room_graph_builder.gd")
const _TopologyValidatorScript = preload("res://src/dungeon_generator/core/topology/topology_validator.gd")
const _CandidateEdgeScript = preload("res://src/dungeon_generator/core/topology/candidate_edge.gd")
const _DisjointSetScript = preload("res://src/dungeon_generator/core/topology/disjoint_set.gd")
const _MinimumSpanningTreeScript = preload("res://src/dungeon_generator/core/topology/minimum_spanning_tree.gd")
const _DelaunayCandidateBuilderScript = preload("res://src/dungeon_generator/core/topology/delaunay_candidate_builder.gd")

func _init() -> void:
	print("--- Running test_phase3_topology ---")

	# Test 1: Caso 0 y 1 Habitación
	var res_0 = _RoomGraphBuilderScript.build_topology([], 12345)
	assert(res_0.is_connected, "0 rooms must be connected")
	assert(res_0.connections.is_empty(), "0 rooms must have 0 connections")
	print("  [OK] Test 1.1: 0 rooms handled cleanly")

	var r0 := RoomData.new(0, Rect2i(10, 10, 6, 6), &"start")
	var res_1 = _RoomGraphBuilderScript.build_topology([r0], 12345)
	assert(res_1.is_connected, "1 room must be connected")
	assert(res_1.connections.is_empty(), "1 room must have 0 connections")
	print("  [OK] Test 1.2: 1 room handled cleanly")

	# Test 2: Caso 2 Habitaciones
	var r1 := RoomData.new(1, Rect2i(30, 10, 6, 6), &"combat")
	var res_2 = _RoomGraphBuilderScript.build_topology([r0, r1], 12345)
	assert(res_2.is_connected, "2 rooms must be connected")
	assert(res_2.mst_edges.size() == 1, "2 rooms must have exactly 1 MST edge")
	assert(res_2.connections.size() == 1, "2 rooms must have exactly 1 RoomConnection")
	assert(res_2.connections[0].room_a_id == 0 and res_2.connections[0].room_b_id == 1, "Connection must link 0 and 1")
	assert(res_2.connections[0].is_required, "MST edge must be marked required (mandatory)")
	print("  [OK] Test 2: 2 rooms produce 1 normalized mandatory connection")

	# Test 3: Caso 3 Habitaciones (Triángulo Delaunay)
	var r2 := RoomData.new(2, Rect2i(20, 30, 6, 6), &"boss")
	var res_3 = _RoomGraphBuilderScript.build_topology([r0, r1, r2], 12345, 0.0)
	assert(res_3.is_connected, "3 rooms must be connected")
	assert(res_3.candidate_edges.size() == 3, "3 non-collinear rooms must have 3 candidate edges")
	assert(res_3.mst_edges.size() == 2, "3 rooms must have exactly 2 MST edges (N-1)")
	print("  [OK] Test 3: 3 rooms produce Delaunay triangle and N-1 MST edges")

	# Test 4: Casos Degenerados (Puntos Colineales)
	var col_rooms: Array[RoomData] = [
		RoomData.new(0, Rect2i(10, 10, 4, 4)),
		RoomData.new(1, Rect2i(20, 10, 4, 4)),
		RoomData.new(2, Rect2i(30, 10, 4, 4)),
		RoomData.new(3, Rect2i(40, 10, 4, 4))
	]
	var res_col = _RoomGraphBuilderScript.build_topology(col_rooms, 9999, 0.0)
	assert(res_col.is_connected, "Collinear rooms must be 100% connected via deterministic fallback")
	assert(res_col.mst_edges.size() == 3, "4 collinear rooms must produce exactly 3 MST edges")
	print("  [OK] Test 4: Collinear degenerate rooms handled deterministically without NaN")

	# Test 5: MST determinista Kruskal + DisjointSet (sin RNG)
	var dset = _DisjointSetScript.new(5)
	assert(dset.get_component_count() == 5, "Initial disjoint set has 5 components")
	dset.union(0, 1)
	dset.union(2, 3)
	assert(dset.connected(0, 1), "0 and 1 must be connected")
	assert(not dset.connected(0, 2), "0 and 2 must not be connected")
	assert(dset.get_component_count() == 3, "Components must be 3 after 2 unions")
	dset.union(1, 3)
	assert(dset.connected(0, 2), "0 and 2 must be connected through transitive union")
	print("  [OK] Test 5: Pure DisjointSet operations verified")

	# Test 6: Conexiones Opcionales (~15%)
	var grid_rooms: Array[RoomData] = []
	var id: int = 0
	for y in range(4):
		for x in range(4):
			grid_rooms.append(RoomData.new(id, Rect2i(x * 20 + 5, y * 20 + 5, 8, 8)))
			id += 1

	var res_grid = _RoomGraphBuilderScript.build_topology(grid_rooms, 77777, 0.15)
	assert(res_grid.is_connected, "16-room grid must be connected")
	assert(res_grid.mst_edges.size() == 15, "16 rooms must have exactly 15 MST edges (N-1)")
	var non_mst_count: int = res_grid.metrics["non_mst_edge_count"]
	var expected_opt_count: int = mini(non_mst_count, int(ceil(float(non_mst_count) * 0.15)))
	assert(res_grid.optional_edges.size() == expected_opt_count, "Optional count must match ~15%% formula")
	print("  [OK] Test 6: 15%% optional cycle injection formula verified (%d optional edges from %d non-MST)" % [
		res_grid.optional_edges.size(), non_mst_count
	])

	# Test 7: Validación Topológica BFS/DFS
	var val_report = _TopologyValidatorScript.validate(grid_rooms, res_grid.connections)
	assert(val_report.is_valid, "TopologyValidator must approve generated graph: %s" % str(val_report.errors))
	assert(val_report.reachable_rooms == 16, "All 16 rooms must be reachable via BFS")

	# Test 7.1: Detección de grafo desconectado
	var broken_conns = res_grid.connections.slice(0, 10) # Faltan aristas para conectar todo
	var broken_report = _TopologyValidatorScript.validate(grid_rooms, broken_conns)
	assert(not broken_report.is_valid, "TopologyValidator must catch disconnected graph")
	print("  [OK] Test 7: TopologyValidator BFS reachability verified")

	# Test 8: Determinismo Absoluto de la Topología
	var run1 = _RoomGraphBuilderScript.build_topology(grid_rooms, 424242, 0.15)
	var run2 = _RoomGraphBuilderScript.build_topology(grid_rooms, 424242, 0.15)
	assert(run1.connections.size() == run2.connections.size(), "Connection counts must match")
	for i in range(run1.connections.size()):
		var c1 = run1.connections[i]
		var c2 = run2.connections[i]
		assert(c1.id == c2.id, "Connection ID must match at %d" % i)
		assert(c1.room_a_id == c2.room_a_id and c1.room_b_id == c2.room_b_id, "Endpoints must match at %d" % i)
		assert(c1.is_required == c2.is_required, "Requirement flag must match at %d" % i)
	print("  [OK] Test 8: 100% deterministic topology snapshot verified")

	print("[PASS] test_phase3_topology succeeded completely.")
	quit(0)
