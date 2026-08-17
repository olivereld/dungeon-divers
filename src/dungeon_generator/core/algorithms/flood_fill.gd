class_name FloodFill
extends RefCounted

## Algoritmo de inundación (Flood Fill) no recursivo para validación y corrección de conectividad.
## Garantiza que no existan islas inaccesibles en la mazmorra.

## Encuentra todas las componentes conexas transitables en el grid.
## Retorna Array[Array[Vector2i]] ordenadas de mayor a menor tamaño.
func find_all_regions(grid: CellGrid) -> Array:
	var regions: Array = []
	var visited: Dictionary = {}

	for y in range(grid.height):
		for x in range(grid.width):
			var pos := Vector2i(x, y)
			if grid.is_walkable(pos) and not visited.has(pos):
				var region: Array[Vector2i] = _flood_region(grid, pos, visited)
				if not region.is_empty():
					regions.append(region)

	# Ordenar descendente por tamaño
	regions.sort_custom(func(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
		return a.size() > b.size()
	)

	return regions

func _flood_region(grid: CellGrid, start_pos: Vector2i, visited: Dictionary) -> Array[Vector2i]:
	var region: Array[Vector2i] = []
	var stack: Array[Vector2i] = [start_pos]
	visited[start_pos] = true

	while not stack.is_empty():
		var curr: Vector2i = stack.pop_back()
		region.append(curr)

		for n in grid.get_neighbors_4(curr):
			if grid.is_walkable(n) and not visited.has(n):
				visited[n] = true
				stack.append(n)

	return region

## Conecta todas las regiones desconectadas a la región principal más grande.
## Retorna el número de puentes/corredores tallados.
func ensure_connectivity(grid: CellGrid, carver: CorridorCarver = null, rng: RandomNumberGenerator = null) -> int:
	if carver == null:
		carver = CorridorCarver.new()
		carver.width = 1
	if rng == null:
		rng = RandomNumberGenerator.new()

	var regions: Array = find_all_regions(grid)
	if regions.size() <= 1:
		return 0

	var main_region: Array[Vector2i] = regions[0]
	var bridges_carved: int = 0

	# Conectar cada región secundaria a la región principal
	for i in range(1, regions.size()):
		var sub_region: Array[Vector2i] = regions[i]
		var closest_pair: Array[Vector2i] = _find_closest_pair(main_region, sub_region)
		if closest_pair.size() == 2:
			carver.carve(grid, closest_pair[0], closest_pair[1], rng)
			bridges_carved += 1
			# Agregar celdas de la subregión a la principal
			main_region.append_array(sub_region)

	return bridges_carved

func _find_closest_pair(region_a: Array[Vector2i], region_b: Array[Vector2i]) -> Array[Vector2i]:
	var best_dist: int = 999999999
	var best_a := Vector2i.ZERO
	var best_b := Vector2i.ZERO

	# Para regiones grandes, samplear un subconjunto para rendimiento
	var sample_step_a: int = maxi(1, region_a.size() / 50)
	var sample_step_b: int = maxi(1, region_b.size() / 50)

	var i: int = 0
	while i < region_a.size():
		var pa: Vector2i = region_a[i]
		var j: int = 0
		while j < region_b.size():
			var pb: Vector2i = region_b[j]
			var dist: int = absi(pa.x - pb.x) + absi(pa.y - pb.y)
			if dist < best_dist:
				best_dist = dist
				best_a = pa
				best_b = pb
				if dist <= 1:
					break
			j += sample_step_b
		if best_dist <= 1:
			break
		i += sample_step_a

	return [best_a, best_b]

## Verifica que dos celdas concretas estén conectadas por suelo transitable.
func are_connected(grid: CellGrid, from_pos: Vector2i, to_pos: Vector2i) -> bool:
	if not grid.is_walkable(from_pos) or not grid.is_walkable(to_pos):
		return false
	if from_pos == to_pos:
		return true

	var visited: Dictionary = {from_pos: true}
	var stack: Array[Vector2i] = [from_pos]

	while not stack.is_empty():
		var curr: Vector2i = stack.pop_back()
		if curr == to_pos:
			return true

		for n in grid.get_neighbors_4(curr):
			if grid.is_walkable(n) and not visited.has(n):
				visited[n] = true
				stack.append(n)

	return false

## Verifica que todos los puntos SPAWN puedan alcanzar todos los puntos OBJECTIVE.
func verify_critical_path(grid: CellGrid) -> bool:
	var spawns: Array[Vector2i] = grid.find_cells_of_type(CellGrid.CellType.SPAWN)
	var objectives: Array[Vector2i] = grid.find_cells_of_type(CellGrid.CellType.OBJECTIVE)

	if spawns.is_empty() or objectives.is_empty():
		# Si no hay spawn u objetivo explícito, verificar conectividad general
		var regions: Array = find_all_regions(grid)
		return regions.size() <= 1

	for s in spawns:
		for o in objectives:
			if not are_connected(grid, s, o):
				return false

	return true

## Verifica que todas las habitaciones de la mazmorra estén conectadas entre sí.
func verify_all_rooms_reachable(grid: CellGrid, rooms: Array[RoomData]) -> bool:
	if rooms.size() <= 1:
		return true

	var first_pt: Vector2i = rooms[0].get_walkable_point(grid)
	for i in range(1, rooms.size()):
		var room_pt: Vector2i = rooms[i].get_walkable_point(grid)
		if not are_connected(grid, first_pt, room_pt):
			return false

	return true

## Verifica estrictamente que el 100% de las celdas transitables pertenezcan a una única componente conexa.
func verify_100_percent_walkable_connected(grid: CellGrid) -> bool:
	var regions: Array = find_all_regions(grid)
	return regions.size() <= 1

## Genera un reporte detallado de diagnóstico de conectividad (de solo lectura).
func get_connectivity_diagnostics(grid: CellGrid, rooms: Array[RoomData] = []) -> Dictionary:
	var regions: Array = find_all_regions(grid)
	var report: Dictionary = {
		"region_count": regions.size(),
		"main_region_size": regions[0].size() if not regions.is_empty() else 0,
		"isolated_regions_count": maxi(0, regions.size() - 1),
		"isolated_regions": []
	}

	if regions.size() > 1:
		for i in range(1, regions.size()):
			var sub_region: Array[Vector2i] = regions[i]
			var sample_pos: Vector2i = sub_region[0]
			var min_x: int = sample_pos.x
			var max_x: int = sample_pos.x
			var min_y: int = sample_pos.y
			var max_y: int = sample_pos.y

			for p in sub_region:
				min_x = mini(min_x, p.x)
				max_x = maxi(max_x, p.x)
				min_y = mini(min_y, p.y)
				max_y = maxi(max_y, p.y)

			var containing_room_id: int = -1
			for r in rooms:
				if r != null and r.rect.has_point(sample_pos):
					containing_room_id = r.id
					break

			report["isolated_regions"].append({
				"index": i,
				"size": sub_region.size(),
				"sample_cell": sample_pos,
				"bounding_box": Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1),
				"room_id": containing_room_id
			})

	return report
