class_name TopologyValidator
extends RefCounted

## Validador topológico puro mediante BFS/DFS (Fase 3).
## Verifica que todas las habitaciones formen un grafo 100% conexo antes de cualquier tallado físico.

class ValidationReport extends RefCounted:
	var is_valid: bool = true
	var reachable_rooms: int = 0
	var total_rooms: int = 0
	var errors: Array[String] = []

	func add_error(msg: String) -> void:
		is_valid = false
		errors.append(msg)

static func validate(rooms: Array[RoomData], connections: Array) -> ValidationReport:
	var report := ValidationReport.new()
	var n: int = rooms.size()
	report.total_rooms = n

	if n == 0 or n == 1:
		report.is_valid = true
		report.reachable_rooms = n
		return report

	# 1. Construir lista de adyacencia
	var adj: Dictionary = {}
	var room_ids: Dictionary = {}
	for r in rooms:
		adj[r.id] = []
		room_ids[r.id] = true

	for conn in connections:
		if conn == null:
			report.add_error("Null connection in list")
			continue
		var u: int = conn.room_a_id
		var v: int = conn.room_b_id

		if not room_ids.has(u) or not room_ids.has(v):
			report.add_error("Connection references unknown room IDs: %d-%d" % [u, v])
			continue

		if u == v:
			report.add_error("Self-connection detected on room %d" % u)
			continue

		adj[u].append(v)
		adj[v].append(u)

	# 2. BFS desde la primera habitación
	var start_id: int = rooms[0].id
	var visited: Dictionary = {start_id: true}
	var queue: Array[int] = [start_id]

	while not queue.is_empty():
		var curr: int = queue.pop_front()
		for neighbor in adj.get(curr, []):
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)

	report.reachable_rooms = visited.size()

	if report.reachable_rooms < n:
		report.add_error("Topology graph disconnected: %d of %d rooms reachable from room %d" % [
			report.reachable_rooms, n, start_id
		])

	return report
