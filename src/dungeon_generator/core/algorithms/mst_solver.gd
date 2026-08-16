class_name MSTSolver
extends RefCounted

## Sólver de Árbol de Expansión Mínimo (MST) con Kruskal y reintroducción de ciclos de exploración.

static func solve(num_rooms: int, edges: Array, loop_chance: float = 0.15, rng: RandomNumberGenerator = null) -> Array[Vector2i]:
	if rng == null:
		rng = RandomNumberGenerator.new()

	if num_rooms < 2:
		return []

	# Ordenar aristas por peso (distancia) ascendente
	var sorted_edges: Array = edges.duplicate()
	sorted_edges.sort_custom(func(a, b): return a.weight < b.weight)

	var parent: Array[int] = []
	parent.resize(num_rooms)
	for i in range(num_rooms):
		parent[i] = i

	var union_sets = func(a: int, b: int) -> void:
		var root_a: int = a
		while root_a != parent[root_a]:
			root_a = parent[root_a]
		var root_b: int = b
		while root_b != parent[root_b]:
			root_b = parent[root_b]
		parent[root_a] = root_b

	var mst_edges: Array[Vector2i] = []
	var discarded_edges: Array = []

	for edge in sorted_edges:
		var u: int = edge.u
		var v: int = edge.v
		if u >= num_rooms or v >= num_rooms:
			continue

		var root_u: int = u
		while root_u != parent[root_u]:
			root_u = parent[root_u]

		var root_v: int = v
		while root_v != parent[root_v]:
			root_v = parent[root_v]

		if root_u != root_v:
			union_sets.call(root_u, root_v)
			mst_edges.append(Vector2i(u, v))
		else:
			discarded_edges.append(edge)

	# Reintroducir ciclos de exploración controlados (loops)
	for edge in discarded_edges:
		if rng.randf() < loop_chance:
			mst_edges.append(Vector2i(edge.u, edge.v))

	# Garantizar 100% de conexidad matemática
	for i in range(1, num_rooms):
		var root_i: int = i
		while root_i != parent[root_i]:
			root_i = parent[root_i]
		var root_0: int = 0
		while root_0 != parent[root_0]:
			root_0 = parent[root_0]

		if root_i != root_0:
			union_sets.call(root_i, root_0)
			mst_edges.append(Vector2i(root_0, root_i))

	return mst_edges
