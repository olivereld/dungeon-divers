class_name RoomLightPlanner
extends RefCounted

## Planificador determinista de iluminación para habitaciones de mazmorra.
## Selecciona candidatos garantizando balance perimetral, densidad por área y espaciado mínimo.

const _LightPlacementScript = preload("res://src/dungeon_lighting/data/light_placement.gd")
const _DungeonLightingConfigScript = preload("res://src/dungeon_lighting/config/dungeon_lighting_config.gd")
const _RoomDataScript = preload("res://src/dungeon_generator/core/data/room_data.gd")

func plan_room_lights(
	room: RoomData,
	candidates: Array,
	config: DungeonLightingConfig,
	seed_val: int
) -> Array[LightPlacement]:
	var selected: Array[LightPlacement] = []
	if room == null or candidates.is_empty() or config == null or not config.enabled:
		return selected

	# 1. Calcular cantidad objetivo en base al área de la sala
	var area: float = float(room.rect.size.x * room.rect.size.y)
	var target_count: int = int(round(area / config.room_area_per_light))
	target_count = clampi(target_count, config.min_lights_per_room, config.max_lights_per_room)

	if target_count <= 0:
		return selected

	# 2. Agrupar candidatos por lado de pared para maximizar balance y cobertura perimetral
	var by_side: Dictionary = {
		_LightPlacementScript.WallSide.NORTH: [],
		_LightPlacementScript.WallSide.SOUTH: [],
		_LightPlacementScript.WallSide.EAST: [],
		_LightPlacementScript.WallSide.WEST: []
	}

	for c in candidates:
		if by_side.has(c.wall_side):
			by_side[c.wall_side].append(c)

	# 3. Barajar candidatos con RNG determinista (Fisher-Yates)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	for side in by_side.keys():
		var list: Array = by_side[side]
		_shuffle_list(list, rng)

	# 4. Selección round-robin por lado respetando espaciado mínimo
	var side_order: Array = [
		_LightPlacementScript.WallSide.NORTH,
		_LightPlacementScript.WallSide.SOUTH,
		_LightPlacementScript.WallSide.EAST,
		_LightPlacementScript.WallSide.WEST
	]
	_shuffle_list(side_order, rng)

	var min_dist_sq: float = config.min_light_spacing * config.min_light_spacing

	var pool: Array[_LightPlacementScript] = []
	# Intercalar candidatos de distintos lados
	var max_len: int = 0
	for side in side_order:
		max_len = maxi(max_len, by_side[side].size())

	for i in range(max_len):
		for side in side_order:
			var list: Array = by_side[side]
			if i < list.size():
				pool.append(list[i])

	# 5. Greedy selection
	for cand in pool:
		if selected.size() >= target_count:
			break

		var valid: bool = true
		for s in selected:
			var d_sq: float = Vector2(cand.cell).distance_squared_to(Vector2(s.cell))
			if d_sq < (min_dist_sq - 0.01):
				valid = false
				break

		if valid:
			selected.append(cand)

	# Si no se alcanzó el mínimo por espaciado estricto pero hay candidatos y min_lights > 0
	return selected

func _shuffle_list(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
