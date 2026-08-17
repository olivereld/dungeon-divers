class_name OptionalConnectionSelector
extends RefCounted

## Selector de conexiones opcionales (ciclos/loops) sobre aristas no pertenecientes al MST.
## Utiliza exclusivamente topology_seed para garantizar reproducibilidad absoluta.

static func select_optional_edges(
	non_mst_edges: Array,
	topology_seed: int,
	loop_chance: float = 0.15
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

	# 2. Inicializar RNG exclusivamente con topology_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = topology_seed if topology_seed != 0 else 1337

	var selected: Array = []
	var target_count: int = mini(pool.size(), int(ceil(float(pool.size()) * loop_chance)))

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

	for i in range(target_count):
		var edge = pool[indices[i]]
		edge.is_mandatory = false
		selected.append(edge)

	# Re-ordenar las aristas seleccionadas por estabilidad
	selected.sort_custom(func(a, b):
		if a.room_a_id != b.room_a_id:
			return a.room_a_id < b.room_a_id
		return a.room_b_id < b.room_b_id
	)

	return selected
