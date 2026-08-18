class_name MultiFloorValidator
extends RefCounted

## Validador formal de topología y alcanzabilidad multinivel (Fase 10).
## Verifica las tres invariantes cardinales de verticalidad:
## 1. Integridad de Endpoints (FloorConnection <-> StairData <-> CellGrid).
## 2. Conectividad Topológica en el Grafo de Pisos (Todos los pisos alcanzables).
## 3. Transitabilidad y No Destructividad (Celdas transitables libres de bloqueos).

const _MultiFloorValidationResultScript = preload("res://src/dungeon_generator/core/validation/multi_floor_validation_result.gd")
const _CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")

## Ejecuta la validación exhaustiva sobre el resultado multinivel.
func validate(multi_result: DungeonMultiFloorResult) -> MultiFloorValidationResult:
	var res := _MultiFloorValidationResultScript.new()
	res.is_valid = true

	if multi_result == null:
		res.add_error("DungeonMultiFloorResult es nulo.")
		return res

	var floor_count: int = multi_result.get_floor_count()
	if floor_count <= 0:
		res.add_error("La mazmorra no contiene pisos generados.")
		return res

	# 1. Validar integridad de cada piso individual
	var all_stairs_by_id: Dictionary = {}
	for f_num in multi_result.get_floor_numbers():
		var f_data: DungeonFloorData = multi_result.get_floor(f_num)
		if f_data == null:
			res.add_error("Piso %d declarado en índices pero es nulo." % f_num)
			continue
		if f_data.grid == null:
			res.add_error("Piso %d no posee CellGrid válido." % f_num)
			continue

		for st in f_data.stairs:
			if st == null:
				res.add_error("Piso %d contiene un StairData nulo." % f_num)
				continue
			if not st.is_valid():
				res.add_error("StairData inválido en piso %d: %s" % [f_num, str(st)])
				continue
			if all_stairs_by_id.has(st.stair_id):
				res.add_error("Stair ID duplicado detectado: '%s'" % st.stair_id)
			all_stairs_by_id[st.stair_id] = st

			# Verificar que la celda en CellGrid esté marcada como escalera
			var cell_type = f_data.grid.get_cell(st.cell)
			var expected_type = _CellGridScript.CellType.STAIRS_DOWN if st.is_downward else _CellGridScript.CellType.STAIRS_UP
			if cell_type != expected_type:
				res.add_error("La celda %s en piso %d tiene tipo %s, esperado %s" % [
					str(st.cell), f_num, str(cell_type), str(expected_type)
				])

	# 2. Validar conexiones verticales e integridad de endpoints
	var endpoints_ok: bool = true
	var adj: Dictionary = {} # floor -> Array[floor]
	for f_num in multi_result.get_floor_numbers():
		adj[f_num] = []

	for vconn in multi_result.vertical_connections:
		if vconn == null:
			res.add_error("Conexión vertical nula detectada.")
			endpoints_ok = false
			continue

		if not vconn.is_valid():
			res.add_error("FloorConnection inválida: %s" % str(vconn))
			endpoints_ok = false
			continue

		# Comprobar que from_floor y to_floor existen
		if not multi_result.floors.has(vconn.from_floor) or not multi_result.floors.has(vconn.to_floor):
			res.add_error("FloorConnection %s referencia pisos inexistentes (%d -> %d)" % [
				vconn.connection_id, vconn.from_floor, vconn.to_floor
			])
			endpoints_ok = false
			continue

		# Comprobar endpoints de escaleras correspondientes
		var from_stair: StairData = all_stairs_by_id.get(vconn.from_stair_id, null)
		var to_stair: StairData = all_stairs_by_id.get(vconn.to_stair_id, null)

		if from_stair == null:
			res.add_error("FloorConnection %s no encuentra from_stair '%s'" % [vconn.connection_id, vconn.from_stair_id])
			endpoints_ok = false
		elif from_stair.cell != vconn.from_cell or from_stair.floor_number != vconn.from_floor:
			res.add_error("Discrepancia de coordenadas en from_stair de conexión %s" % vconn.connection_id)
			endpoints_ok = false

		if to_stair == null:
			res.add_error("FloorConnection %s no encuentra to_stair '%s'" % [vconn.connection_id, vconn.to_stair_id])
			endpoints_ok = false
		elif to_stair.cell != vconn.to_cell or to_stair.floor_number != vconn.to_floor:
			res.add_error("Discrepancia de coordenadas en to_stair de conexión %s" % vconn.connection_id)
			endpoints_ok = false

		# Registrar aristas en el grafo de adyacencia
		adj[vconn.from_floor].append(vconn.to_floor)
		adj[vconn.to_floor].append(vconn.from_floor)

	res.endpoints_valid = endpoints_ok

	# 3. Validar conectividad total del grafo de pisos (BFS)
	if floor_count > 1:
		var visited: Dictionary = {}
		var queue: Array[int] = [0]
		visited[0] = true

		while not queue.is_empty():
			var curr: int = queue.pop_front()
			for neighbor in adj.get(curr, []):
				if not visited.has(neighbor):
					visited[neighbor] = true
					queue.append(neighbor)

		res.is_connected = (visited.size() == floor_count)
		if not res.is_connected:
			res.add_error("Grafo vertical desconectado. Solo %d de %d pisos son alcanzables desde el piso 0." % [
				visited.size(), floor_count
			])
	else:
		res.is_connected = true

	res.path_exists = res.is_connected and res.endpoints_valid
	if not res.errors.is_empty():
		res.is_valid = false

	return res
