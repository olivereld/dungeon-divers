class_name EntranceResolutionResult
extends RefCounted

## Resultado del proceso de resolución de entradas para todas las conexiones del pipeline.

var is_valid: bool = true
var entrance_pairs: Array = [] # Array[EntrancePair]
var failed_connection_ids: Array[int] = []
var rejected_connection_ids: Array[int] = []
var diagnostics: Array[Dictionary] = []

func add_pair(pair: EntrancePair, diag: Dictionary = {}) -> void:
	entrance_pairs.append(pair)
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
	lines.append("=== ENTRANCE RESOLUTION RESULT (Valid: %s) ===" % str(is_valid))
	lines.append("Pairs resolved: %d, Failed: %d, Rejected (Optional): %d" % [
		entrance_pairs.size(), failed_connection_ids.size(), rejected_connection_ids.size()
	])
	for ep in entrance_pairs:
		if ep != null:
			lines.append("  %s" % ep.to_debug_string())
	for diag in diagnostics:
		lines.append("  Diag Conn %d [%s]: %s" % [
			diag.get("connection_id", -1),
			diag.get("status", "UNKNOWN"),
			diag.get("reason", "OK")
		])
	return "\n".join(lines)
