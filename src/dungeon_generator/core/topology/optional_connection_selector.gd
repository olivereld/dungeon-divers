class_name OptionalConnectionSelector
extends RefCounted

## Selector de conexiones opcionales (ciclos/loops) sobre aristas no pertenecientes al MST.
## Utiliza exclusivamente topology_seed para garantizar reproducibilidad absoluta.

static func select_optional_edges(
	non_mst_edges: Array,
	topology_seed: int,
	loop_chance: float = 0.15,
	initial_mst_edges: Array = [],
	max_degree: int = 4
) -> Array:
	if non_mst_edges.is_empty() or loop_chance <= 0.0:
		return []

	# 1. Ordenar de forma estable antes de cualquier operación pseudoaleatoria
	var pool: Array = non_mst_edges.duplicate()
	pool.sort_custom(func(a, b):
		if not is_equal_approx(a.weight, b.weight):
			return a.weight < b.weight
		if a.room_a_id != b.room_a_id:
			return a.room_a_id < b.room_a_id
		return a.room_b_id < b.room_b_id
	)

	# Calcular grados iniciales de los nodos a partir del MST
	var degrees: Dictionary = {}
	for edge in initial_mst_edges:
		degrees[edge.room_a_id] = degrees.get(edge.room_a_id, 0) + 1
		degrees[edge.room_b_id] = degrees.get(edge.room_b_id, 0) + 1

	# 2. Inicializar RNG exclusivamente con topology_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = topology_seed if topology_seed != 0 else 1337

	var selected: Array = []
	var target_count: int = mini(pool.size(), maxi(1, int(ceil(float(pool.size()) * loop_chance))))

	# Shuffle determinista controlado sobre los índices
	var indices: Array[int] = []
	for i in range(pool.size()):
		indices.append(i)

	# Fisher-Yates determinista con el RNG de etapa
	for i in range(indices.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = indices[i]
		indices[i] = indices[j]
		indices[j] = tmp

	for i in range(indices.size()):
		if selected.size() >= target_count:
			break
		var edge = pool[indices[i]]
		var deg_a: int = degrees.get(edge.room_a_id, 0)
		var deg_b: int = degrees.get(edge.room_b_id, 0)

		# Respetar grado máximo
		if deg_a < max_degree and deg_b < max_degree:
			edge.is_mandatory = false
			selected.append(edge)
			degrees[edge.room_a_id] = deg_a + 1
			degrees[edge.room_b_id] = deg_b + 1

	# Re-ordenar las aristas seleccionadas por estabilidad
	selected.sort_custom(func(a, b):
		if a.room_a_id != b.room_a_id:
			return a.room_a_id < b.room_a_id
		return a.room_b_id < b.room_b_id
	)

	return selected
