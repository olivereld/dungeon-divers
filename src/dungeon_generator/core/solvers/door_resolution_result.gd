class_name DoorResolutionResult
extends RefCounted

## Resultado del proceso de resolución y colocación de puertas estructurales para el pipeline.

var is_valid: bool = true
var doors: Array = [] # Array[DoorPlacement]
var door_pairs: Array = [] # Array[DoorPair]
var failed_connection_ids: Array[int] = []
var rejected_connection_ids: Array[int] = []
var diagnostics: Array[Dictionary] = []

func add_door_pair(pair: DoorPair, diag: Dictionary = {}) -> void:
	door_pairs.append(pair)
	if pair.door_a != null:
		doors.append(pair.door_a)
	if pair.door_b != null:
		doors.append(pair.door_b)
	if not diag.is_empty():
		diagnostics.append(diag)

func add_failure(connection_id: int, reason: String, diag: Dictionary = {}) -> void:
	is_valid = false
	failed_connection_ids.append(connection_id)
	var d := diag.duplicate()
	d["connection_id"] = connection_id
	d["status"] = "FAILED"
	d["reason"] = reason
	diagnostics.append(d)

func add_rejection(connection_id: int, reason: String, diag: Dictionary = {}) -> void:
	rejected_connection_ids.append(connection_id)
	var d := diag.duplicate()
	d["connection_id"] = connection_id
	d["status"] = "REJECTED"
	d["reason"] = reason
	diagnostics.append(d)

func to_debug_string() -> String:
	var lines: PackedStringArray = []
	lines.append("=== DOOR RESOLUTION RESULT (Valid: %s) ===" % str(is_valid))
	lines.append("Doors placed: %d, Pairs: %d, Failed: %d, Rejected (Optional): %d" % [
		doors.size(), door_pairs.size(), failed_connection_ids.size(), rejected_connection_ids.size()
	])
	for dp in door_pairs:
		if dp != null:
			lines.append("  %s" % dp.to_debug_string())
	for diag in diagnostics:
		lines.append("  Diag Conn %d [%s]: %s" % [
			diag.get("connection_id", -1),
			diag.get("status", "UNKNOWN"),
			diag.get("reason", "OK")
		])
	return "\n".join(lines)
