class_name CorridorCarveResult
extends RefCounted

## Contenedor de resultado del proceso de tallado de corredores para todas las conexiones del pipeline.

var is_valid: bool = true
var paths: Array = [] # Array[CorridorPath]
var failed_connection_ids: Array[int] = []
var rejected_connection_ids: Array[int] = []
var diagnostics: Array[Dictionary] = []

func add_path(path: CorridorPath, diag: Dictionary = {}) -> void:
	paths.append(path)
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
	lines.append("=== CORRIDOR CARVE RESULT (Valid: %s) ===" % str(is_valid))
	lines.append("Paths carved: %d, Failed: %d, Rejected (Optional): %d" % [
		paths.size(), failed_connection_ids.size(), rejected_connection_ids.size()
	])
	for p in paths:
		if p != null:
			lines.append("  %s" % p.to_debug_string())
	for diag in diagnostics:
		lines.append("  Diag Conn %d [%s]: %s" % [
			diag.get("connection_id", -1),
			diag.get("status", "UNKNOWN"),
			diag.get("reason", "OK")
		])
	return "\n".join(lines)
